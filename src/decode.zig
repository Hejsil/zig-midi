const std = @import("std");
const midi = @import("index.zig");

const debug = std.debug;
const math = std.math;
const mem = std.mem;

const Message = midi.Message;
const ChunkHeader = midi.ChunkHeader;
const Chunk = midi.Chunk;

const channel_message_table = blk: {
    var res = []?Message.Kind{null} ** (math.maxInt(u4) + 1);
    res[0b1000] = Message.Kind.NoteOff;
    res[0b1001] = Message.Kind.NoteOn;
    res[0b1010] = Message.Kind.PolyphonicKeyPressure;
    res[0b1011] = Message.Kind.ControlChange;
    res[0b1100] = Message.Kind.ProgramChange;
    res[0b1101] = Message.Kind.ChannelPressure;
    res[0b1110] = Message.Kind.PitchBendChange;
    break :blk res;
};

const system_message_table = blk: {
    var res = []?Message.Kind{null} ** (math.maxInt(u4) + 1);
    res[0b0000] = Message.Kind.SystemExclusiveStart;
    res[0b0001] = Message.Kind.MidiTimeCodeQuarterFrame;
    res[0b0010] = Message.Kind.SongPositionPointer;
    res[0b0011] = Message.Kind.SongSelect;
    res[0b0110] = Message.Kind.TuneRequest;
    res[0b0110] = Message.Kind.TuneRequest;
    res[0b0111] = Message.Kind.SystemExclusiveEnd;
    res[0b1000] = Message.Kind.TimingClock;
    res[0b1010] = Message.Kind.Start;
    res[0b1011] = Message.Kind.Continue;
    res[0b1100] = Message.Kind.Stop;
    res[0b1110] = Message.Kind.ActiveSensing;
    res[0b1111] = Message.Kind.Reset;
    break :blk res;
};

pub const MessageStream = struct {
    const State = union(enum) {
        Status: void,
        Running: ChannelMessage(0),

        ChannelValue1: ChannelMessage(0),
        ChannelValue2: ChannelMessage(1),

        SystemValue1: SystemMessage(0),
        SystemValue2: SystemMessage(1),

        SystemExclusive: void,

        fn ChannelMessage(comptime count: usize) type {
            return struct {
                kind: Message.Kind,
                channel: u4,
                values: [count]u7,
            };
        }

        fn SystemMessage(comptime count: usize) type {
            return struct {
                kind: Message.Kind,
                values: [count]u7,
            };
        }
    };

    state: State,

    pub fn init() MessageStream {
        return MessageStream{ .state = State.Status };
    }

    fn feed(stream: *MessageStream, b: u8) !?Message {
        repeat: while (true) {
            switch (stream.state) {
                State.Status => {
                    const upper = @truncate(u4, b >> 4);
                    const lower = @truncate(u4, b);
                    if (channel_message_table[upper]) |kind| {
                        stream.state = State{
                            .ChannelValue1 = State.ChannelMessage(0){
                                .kind = kind,
                                .channel = lower,
                                .values = []u7{},
                            },
                        };
                        return null;
                    }

                    if (upper != 0b1111)
                        return error.InvalidMessage;
                    if (system_message_table[lower]) |kind| {
                        switch (kind) {
                            Message.Kind.SystemExclusiveStart => blk: {
                                stream.state = State.SystemExclusive;
                                return Message{ .SystemExclusiveStart = {} };
                            },
                            Message.Kind.MidiTimeCodeQuarterFrame,
                            Message.Kind.SongPositionPointer,
                            Message.Kind.SongSelect,
                            => {
                                stream.state = State{
                                    .SystemValue1 = State.SystemMessage(0){
                                        .kind = kind,
                                        .values = []u7{},
                                    },
                                };
                                return null;
                            },

                            Message.Kind.SystemExclusiveEnd => return error.InvalidMessage,
                            Message.Kind.TuneRequest => return Message{ .TuneRequest = {} },
                            Message.Kind.TimingClock => return Message{ .TimingClock = {} },
                            Message.Kind.Start => return Message{ .Start = {} },
                            Message.Kind.Continue => return Message{ .Continue = {} },
                            Message.Kind.Stop => return Message{ .Stop = {} },
                            Message.Kind.ActiveSensing => return Message{ .ActiveSensing = {} },
                            Message.Kind.Reset => return Message{ .Reset = {} },
                            else => unreachable,
                        }
                    }
                },
                State.Running => |msg| {
                    stream.state = if (b & 0x80 != 0) State{ .Status = {} } else State{ .ChannelValue1 = msg };
                    continue :repeat;
                },

                State.ChannelValue1 => |msg| {
                    const value = math.cast(u7, b) catch return error.InvalidMessage;

                    stream.state = State{ .Running = msg };
                    switch (msg.kind) {
                        Message.Kind.NoteOff,
                        Message.Kind.NoteOn,
                        Message.Kind.PolyphonicKeyPressure,
                        Message.Kind.PitchBendChange,
                        Message.Kind.ControlChange,
                        => {
                            stream.state = State{
                                .ChannelValue2 = State.ChannelMessage(1){
                                    .kind = msg.kind,
                                    .channel = msg.channel,
                                    .values = []u7{value},
                                },
                            };
                            return null;
                        },
                        Message.Kind.ProgramChange => return Message{
                            .ProgramChange = Message.ProgramChange{
                                .channel = msg.channel,
                                .program = value,
                            },
                        },
                        Message.Kind.ChannelPressure => return Message{
                            .ChannelPressure = Message.ChannelPressure{
                                .channel = msg.channel,
                                .pressure = value,
                            },
                        },
                        else => unreachable,
                    }
                },
                State.ChannelValue2 => |msg| {
                    const value = math.cast(u7, b) catch return error.InvalidMessage;

                    stream.state = State{
                        .Running = State.ChannelMessage(0){
                            .channel = msg.channel,
                            .kind = msg.kind,
                            .values = []u7{},
                        },
                    };
                    switch (msg.kind) {
                        Message.Kind.ControlChange => switch (msg.values[0]) {
                            120 => return Message{
                                .AllSoundOff = Message.AllSoundOff{ .channel = msg.channel },
                            },
                            121 => return Message{
                                .ResetAllControllers = Message.ResetAllControllers{
                                    .channel = msg.channel,
                                    .value = value,
                                },
                            },
                            122 => return Message{
                                .LocalControl = Message.LocalControl{
                                    .channel = msg.channel,
                                    .on = switch (value) {
                                        0 => false,
                                        127 => true,
                                        else => return error.InvalidMessage,
                                    },
                                },
                            },
                            123 => return Message{
                                .AllNotesOff = Message.AllNotesOff{ .channel = msg.channel },
                            },
                            124 => return Message{
                                .OmniModeOff = Message.OmniModeOff{ .channel = msg.channel },
                            },
                            125 => return Message{
                                .OmniModeOn = Message.OmniModeOn{ .channel = msg.channel },
                            },
                            126 => return Message{
                                .MonoModeOn = Message.MonoModeOn{
                                    .channel = msg.channel,
                                    .value = value,
                                },
                            },
                            127 => return Message{
                                .PolyModeOn = Message.PolyModeOn{ .channel = msg.channel },
                            },
                            else => return Message{
                                .ControlChange = Message.ControlChange{
                                    .channel = msg.channel,
                                    .controller = msg.values[0],
                                    .value = value,
                                },
                            },
                        },
                        Message.Kind.NoteOff => return Message{
                            .NoteOff = Message.NoteOff{
                                .channel = msg.channel,
                                .note = msg.values[0],
                                .velocity = value,
                            },
                        },
                        Message.Kind.NoteOn => return Message{
                            .NoteOn = Message.NoteOn{
                                .channel = msg.channel,
                                .note = msg.values[0],
                                .velocity = value,
                            },
                        },
                        Message.Kind.PolyphonicKeyPressure => return Message{
                            .PolyphonicKeyPressure = Message.PolyphonicKeyPressure{
                                .channel = msg.channel,
                                .note = msg.values[0],
                                .pressure = value,
                            },
                        },
                        Message.Kind.PitchBendChange => return Message{
                            .PitchBendChange = Message.PitchBendChange{
                                .channel = msg.channel,
                                .bend = u14(msg.values[0]) | u14(value) << 7,
                            },
                        },
                        else => unreachable,
                    }
                },

                State.SystemValue1 => |msg| {
                    const value = math.cast(u7, b) catch return error.InvalidMessage;

                    stream.state = State.Status;
                    switch (msg.kind) {
                        Message.Kind.SongPositionPointer => {
                            stream.state = State{
                                .SystemValue2 = State.SystemMessage(1){
                                    .kind = msg.kind,
                                    .values = []u7{value},
                                },
                            };
                            return null;
                        },
                        Message.Kind.MidiTimeCodeQuarterFrame => return Message{
                            .MidiTimeCodeQuarterFrame = Message.MidiTimeCodeQuarterFrame{
                                .message_type = @intCast(u3, value >> 4),
                                .values = @truncate(u4, value),
                            },
                        },
                        Message.Kind.SongSelect => return Message{
                            .SongSelect = Message.SongSelect{ .sequence = value },
                        },
                        else => unreachable,
                    }
                },
                State.SystemValue2 => |msg| {
                    const value = math.cast(u7, b) catch return error.InvalidMessage;

                    stream.state = State.Status;
                    switch (msg.kind) {
                        Message.Kind.SongPositionPointer => return Message{
                            .SongPositionPointer = Message.SongPositionPointer{ .beats = u14(msg.values[0]) | u14(value) << 7 },
                        },
                        else => unreachable,
                    }
                },

                State.SystemExclusive => |msg| {
                    const upper = @truncate(u4, b >> 4);
                    const lower = @truncate(u4, b);

                    // Just eat all values in the system exclusive message
                    // and let the feeder be responisble for the bytes passed in.
                    if (upper & 0x8 == 0)
                        return null;
                    if (upper != 0b1111)
                        return error.InvalidMessage;
                    if (system_message_table[lower]) |kind| {
                        if (kind != Message.Kind.SystemExclusiveEnd)
                            return error.InvalidMessage;
                    }

                    stream.state = State.Status;
                    return Message{ .SystemExclusiveEnd = {} };
                },
            }
        }
    }

    pub fn reset(stream: *MessageStream) void {
        stream.state = State{ .Status = void{} };
    }

    pub fn done(stream: *MessageStream) !void {
        const old_state = stream.state;
        stream.reset();
        switch (old_state) {
            State.Status, State.Running => return,
            else => return error.InvalidMessage,
        }
    }
};

pub const MessageIterator = struct {
    stream: MessageStream,
    bytes: []const u8,
    i: usize,

    pub fn init(bytes: []const u8) MessageIterator {
        return MessageIterator{
            .stream = MessageStream.init(),
            .bytes = bytes,
            .i = 0,
        };
    }

    pub fn next(iter: *MessageIterator) !?Message {
        while (iter.i < iter.bytes.len) {
            defer iter.i += 1;
            if (try iter.stream.feed(iter.bytes[iter.i])) |message|
                return message;
        }

        try iter.stream.done();
        return null;
    }
};

fn messageEql(a: Message, b: Message) bool {
    if (Message.Kind(a) != Message.Kind(b))
        return false;

    switch (a) {
        Message.Kind.NoteOff => |av| {
            const bv = b.NoteOff;
            return av.channel == bv.channel and
                av.note == bv.note and
                av.velocity == bv.velocity;
        },
        Message.Kind.NoteOn => |av| {
            const bv = b.NoteOn;
            return av.channel == bv.channel and
                av.note == bv.note and
                av.velocity == bv.velocity;
        },
        Message.Kind.PolyphonicKeyPressure => |av| {
            const bv = b.PolyphonicKeyPressure;
            return av.channel == bv.channel and
                av.note == bv.note and
                av.pressure == bv.pressure;
        },
        Message.Kind.ControlChange => |av| {
            const bv = b.ControlChange;
            return av.channel == bv.channel and
                av.controller == bv.controller and
                av.value == bv.value;
        },
        Message.Kind.AllSoundOff => |av| {
            const bv = b.AllSoundOff;
            return av.channel == bv.channel;
        },
        Message.Kind.ResetAllControllers => |av| {
            const bv = b.ResetAllControllers;
            return av.channel == bv.channel and
                av.value == bv.value;
        },
        Message.Kind.LocalControl => |av| {
            const bv = b.LocalControl;
            return av.channel == bv.channel and
                av.on == bv.on;
        },
        Message.Kind.AllNotesOff => |av| {
            const bv = b.AllNotesOff;
            return av.channel == bv.channel;
        },
        Message.Kind.OmniModeOff => |av| {
            const bv = b.OmniModeOff;
            return av.channel == bv.channel;
        },
        Message.Kind.OmniModeOn => |av| {
            const bv = b.OmniModeOn;
            return av.channel == bv.channel;
        },
        Message.Kind.MonoModeOn => |av| {
            const bv = b.MonoModeOn;
            return av.channel == bv.channel and
                av.value == bv.value;
        },
        Message.Kind.PolyModeOn => |av| {
            const bv = b.PolyModeOn;
            return av.channel == bv.channel;
        },
        Message.Kind.ProgramChange => |av| {
            const bv = b.ProgramChange;
            return av.channel == bv.channel and
                av.program == bv.program;
        },
        Message.Kind.ChannelPressure => |av| {
            const bv = b.ChannelPressure;
            return av.channel == bv.channel and
                av.pressure == bv.pressure;
        },
        Message.Kind.PitchBendChange => |av| {
            const bv = b.PitchBendChange;
            return av.channel == bv.channel and
                av.bend == bv.bend;
        },

        Message.Kind.SystemExclusive => |av| {
            const bv = b.SystemExclusive;
            return std.mem.eql(u7, av.id, bv.id) and
                std.mem.eql(u7, av.message, bv.message);
        },
        Message.Kind.SystemExclusiveStart => return true,
        Message.Kind.SystemExclusiveEnd => return true,
        Message.Kind.MidiTimeCodeQuarterFrame => |av| {
            const bv = b.MidiTimeCodeQuarterFrame;
            return av.message_type == bv.message_type and
                av.values == bv.values;
        },
        Message.Kind.SongPositionPointer => |av| {
            const bv = b.SongPositionPointer;
            return av.beats == bv.beats;
        },
        Message.Kind.SongSelect => |av| {
            const bv = b.SongSelect;
            return av.sequence == bv.sequence;
        },
        Message.Kind.TuneRequest => return true,
        Message.Kind.TimingClock => return true,
        Message.Kind.Start => return true,
        Message.Kind.Continue => return true,
        Message.Kind.Stop => return true,
        Message.Kind.ActiveSensing => return true,
        Message.Kind.Reset => return true,
    }
}

fn testMessageIterator(bytes: []const u8, results: []const Message) !void {
    var next_message: usize = 0;
    var iter = MessageIterator.init(bytes);
    while (try iter.next()) |actual| : (next_message += 1) {
        const expected = results[next_message];
        debug.assert(messageEql(expected, actual));
    }

    debug.assert(next_message == results.len);
    debug.assert((try iter.next()) == null);
}

test "midi.decode.MessageStream: NoteOff" {
    try testMessageIterator("\x80\x00\x00" ++
        "\x7F\x7F" ++
        "\x8F\x7F\x7F", []Message{
        Message{
            .NoteOff = Message.NoteOff{
                .channel = 0x0,
                .note = 0x00,
                .velocity = 0x00,
            },
        },
        Message{
            .NoteOff = Message.NoteOff{
                .channel = 0x0,
                .note = 0x7F,
                .velocity = 0x7F,
            },
        },
        Message{
            .NoteOff = Message.NoteOff{
                .channel = 0xF,
                .note = 0x7F,
                .velocity = 0x7F,
            },
        },
    });
}

test "midi.decode.MessageStream: NoteOn" {
    try testMessageIterator("\x90\x00\x00" ++
        "\x7F\x7F" ++
        "\x9F\x7F\x7F", []Message{
        Message{
            .NoteOn = Message.NoteOn{
                .channel = 0x0,
                .note = 0x00,
                .velocity = 0x00,
            },
        },
        Message{
            .NoteOn = Message.NoteOn{
                .channel = 0x0,
                .note = 0x7F,
                .velocity = 0x7F,
            },
        },
        Message{
            .NoteOn = Message.NoteOn{
                .channel = 0xF,
                .note = 0x7F,
                .velocity = 0x7F,
            },
        },
    });
}

test "midi.decode.MessageStream: PolyphonicKeyPressure" {
    try testMessageIterator("\xA0\x00\x00" ++
        "\x7F\x7F" ++
        "\xAF\x7F\x7F", []Message{
        Message{
            .PolyphonicKeyPressure = Message.PolyphonicKeyPressure{
                .channel = 0x0,
                .note = 0x00,
                .pressure = 0x00,
            },
        },
        Message{
            .PolyphonicKeyPressure = Message.PolyphonicKeyPressure{
                .channel = 0x0,
                .note = 0x7F,
                .pressure = 0x7F,
            },
        },
        Message{
            .PolyphonicKeyPressure = Message.PolyphonicKeyPressure{
                .channel = 0xF,
                .note = 0x7F,
                .pressure = 0x7F,
            },
        },
    });
}

test "midi.decode.MessageStream: ControlChange" {
    try testMessageIterator("\xB0\x00\x00" ++
        "\x77\x7F" ++
        "\xBF\x77\x7F", []Message{
        Message{
            .ControlChange = Message.ControlChange{
                .channel = 0x0,
                .controller = 0x0,
                .value = 0x0,
            },
        },
        Message{
            .ControlChange = Message.ControlChange{
                .channel = 0x0,
                .controller = 0x77,
                .value = 0x7F,
            },
        },
        Message{
            .ControlChange = Message.ControlChange{
                .channel = 0xF,
                .controller = 0x77,
                .value = 0x7F,
            },
        },
    });
}

test "midi.decode.MessageStream: AllSoundOff" {
    try testMessageIterator("\xB0\x78\x00" ++
        "\x78\x00" ++
        "\xBF\x78\x00", []Message{
        Message{ .AllSoundOff = Message.AllSoundOff{ .channel = 0x0 } },
        Message{ .AllSoundOff = Message.AllSoundOff{ .channel = 0x0 } },
        Message{ .AllSoundOff = Message.AllSoundOff{ .channel = 0xF } },
    });
}

test "midi.decode.MessageStream: ResetAllControllers" {
    try testMessageIterator("\xB0\x79\x00" ++
        "\x79\x7F" ++
        "\xBF\x79\x7F", []Message{
        Message{
            .ResetAllControllers = Message.ResetAllControllers{
                .channel = 0x0,
                .value = 0x0,
            },
        },
        Message{
            .ResetAllControllers = Message.ResetAllControllers{
                .channel = 0x0,
                .value = 0x7F,
            },
        },
        Message{
            .ResetAllControllers = Message.ResetAllControllers{
                .channel = 0xF,
                .value = 0x7F,
            },
        },
    });
}

test "midi.decode.MessageStream: LocalControl" {
    try testMessageIterator("\xB0\x7A\x00" ++
        "\x7A\x7F" ++
        "\xBF\x7A\x7F", []Message{
        Message{
            .LocalControl = Message.LocalControl{
                .channel = 0x0,
                .on = false,
            },
        },
        Message{
            .LocalControl = Message.LocalControl{
                .channel = 0x0,
                .on = true,
            },
        },
        Message{
            .LocalControl = Message.LocalControl{
                .channel = 0xF,
                .on = true,
            },
        },
    });
}

test "midi.decode.MessageStream: AllNotesOff" {
    try testMessageIterator("\xB0\x7B\x00" ++
        "\x7B\x00" ++
        "\xBF\x7B\x00", []Message{
        Message{ .AllNotesOff = Message.AllNotesOff{ .channel = 0x0 } },
        Message{ .AllNotesOff = Message.AllNotesOff{ .channel = 0x0 } },
        Message{ .AllNotesOff = Message.AllNotesOff{ .channel = 0xF } },
    });
}

test "midi.decode.MessageStream: OmniModeOff" {
    try testMessageIterator("\xB0\x7C\x00" ++
        "\x7C\x00" ++
        "\xBF\x7C\x00", []Message{
        Message{ .OmniModeOff = Message.OmniModeOff{ .channel = 0x0 } },
        Message{ .OmniModeOff = Message.OmniModeOff{ .channel = 0x0 } },
        Message{ .OmniModeOff = Message.OmniModeOff{ .channel = 0xF } },
    });
}

test "midi.decode.MessageStream: OmniModeOn" {
    try testMessageIterator("\xB0\x7D\x00" ++
        "\x7D\x00" ++
        "\xBF\x7D\x00", []Message{
        Message{ .OmniModeOn = Message.OmniModeOn{ .channel = 0x0 } },
        Message{ .OmniModeOn = Message.OmniModeOn{ .channel = 0x0 } },
        Message{ .OmniModeOn = Message.OmniModeOn{ .channel = 0xF } },
    });
}

test "midi.decode.MessageStream: MonoModeOn" {
    try testMessageIterator("\xB0\x7E\x00" ++
        "\x7E\x7F" ++
        "\xBF\x7E\x7F", []Message{
        Message{
            .MonoModeOn = Message.MonoModeOn{
                .channel = 0x0,
                .value = 0x00,
            },
        },
        Message{
            .MonoModeOn = Message.MonoModeOn{
                .channel = 0x0,
                .value = 0x7F,
            },
        },
        Message{
            .MonoModeOn = Message.MonoModeOn{
                .channel = 0xF,
                .value = 0x7F,
            },
        },
    });
}

test "midi.decode.MessageStream: PolyModeOn" {
    try testMessageIterator("\xB0\x7F\x00" ++
        "\x7F\x00" ++
        "\xBF\x7F\x00", []Message{
        Message{ .PolyModeOn = Message.PolyModeOn{ .channel = 0x0 } },
        Message{ .PolyModeOn = Message.PolyModeOn{ .channel = 0x0 } },
        Message{ .PolyModeOn = Message.PolyModeOn{ .channel = 0xF } },
    });
}

test "midi.decode.MessageStream: ProgramChange" {
    try testMessageIterator("\xC0\x00" ++
        "\x7F" ++
        "\xCF\x7F", []Message{
        Message{
            .ProgramChange = Message.ProgramChange{
                .channel = 0x0,
                .program = 0x00,
            },
        },
        Message{
            .ProgramChange = Message.ProgramChange{
                .channel = 0x0,
                .program = 0x7F,
            },
        },
        Message{
            .ProgramChange = Message.ProgramChange{
                .channel = 0xF,
                .program = 0x7F,
            },
        },
    });
}

test "midi.decode.MessageStream: ChannelPressure" {
    try testMessageIterator("\xD0\x00" ++
        "\x7F" ++
        "\xDF\x7F", []Message{
        Message{
            .ChannelPressure = Message.ChannelPressure{
                .channel = 0x0,
                .pressure = 0x00,
            },
        },
        Message{
            .ChannelPressure = Message.ChannelPressure{
                .channel = 0x0,
                .pressure = 0x7F,
            },
        },
        Message{
            .ChannelPressure = Message.ChannelPressure{
                .channel = 0xF,
                .pressure = 0x7F,
            },
        },
    });
}

test "midi.decode.MessageStream: PitchBendChange" {
    try testMessageIterator("\xE0\x00\x00" ++
        "\x7F\x7F" ++
        "\xEF\x7F\x7F", []Message{
        Message{
            .PitchBendChange = Message.PitchBendChange{
                .channel = 0x0,
                .bend = 0x00,
            },
        },
        Message{
            .PitchBendChange = Message.PitchBendChange{
                .channel = 0x0,
                .bend = 0x7F << 7 | 0x7F,
            },
        },
        Message{
            .PitchBendChange = Message.PitchBendChange{
                .channel = 0xF,
                .bend = 0x7F << 7 | 0x7F,
            },
        },
    });
}

test "midi.decode.MessageStream: SystemExclusive" {
    try testMessageIterator("\xF0\x01\x0F\x7F\xF7", []Message{
        Message{ .SystemExclusiveStart = {} },
        Message{ .SystemExclusiveEnd = {} },
    });
}

test "midi.decode.MessageStream: MIDITimeCodeQuarterFrame" {
    try testMessageIterator("\xF1\x00" ++
        "\xF1\x0F" ++
        "\xF1\x70" ++
        "\xF1\x7F", []Message{
        Message{
            .MidiTimeCodeQuarterFrame = Message.MidiTimeCodeQuarterFrame{
                .message_type = 0,
                .values = 0,
            },
        },
        Message{
            .MidiTimeCodeQuarterFrame = Message.MidiTimeCodeQuarterFrame{
                .message_type = 0,
                .values = 0xF,
            },
        },
        Message{
            .MidiTimeCodeQuarterFrame = Message.MidiTimeCodeQuarterFrame{
                .message_type = 0x7,
                .values = 0x0,
            },
        },
        Message{
            .MidiTimeCodeQuarterFrame = Message.MidiTimeCodeQuarterFrame{
                .message_type = 0x7,
                .values = 0xF,
            },
        },
    });
}

test "midi.decode.MessageStream: SongPositionPointer" {
    try testMessageIterator("\xF2\x00\x00" ++
        "\xF2\x7F\x7F", []Message{
        Message{ .SongPositionPointer = Message.SongPositionPointer{ .beats = 0x0 } },
        Message{ .SongPositionPointer = Message.SongPositionPointer{ .beats = 0x7F << 7 | 0x7F } },
    });
}

test "midi.decode.MessageStream: SongSelect" {
    try testMessageIterator("\xF3\x00" ++
        "\xF3\x7F", []Message{
        Message{ .SongSelect = Message.SongSelect{ .sequence = 0x0 } },
        Message{ .SongSelect = Message.SongSelect{ .sequence = 0x7F } },
    });
}

test "midi.decode.MessageStream: TuneRequest" {
    try testMessageIterator("\xF6\xF6", []Message{
        Message{ .TuneRequest = {} },
        Message{ .TuneRequest = {} },
    });
}

test "midi.decode.MessageStream: TimingClock" {
    try testMessageIterator("\xF8\xF8", []Message{
        Message{ .TimingClock = {} },
        Message{ .TimingClock = {} },
    });
}

test "midi.decode.MessageStream: Start" {
    try testMessageIterator("\xFA\xFA", []Message{
        Message{ .Start = {} },
        Message{ .Start = {} },
    });
}

test "midi.decode.MessageStream: Continue" {
    try testMessageIterator("\xFB\xFB", []Message{
        Message{ .Continue = {} },
        Message{ .Continue = {} },
    });
}

test "midi.decode.MessageStream: Stop" {
    try testMessageIterator("\xFC\xFC", []Message{
        Message{ .Stop = {} },
        Message{ .Stop = {} },
    });
}

test "midi.decode.MessageStream: ActiveSensing" {
    try testMessageIterator("\xFE\xFE", []Message{
        Message{ .ActiveSensing = {} },
        Message{ .ActiveSensing = {} },
    });
}

test "midi.decode.MessageStream: Reset" {
    try testMessageIterator("\xFF\xFF", []Message{
        Message{ .Reset = {} },
        Message{ .Reset = {} },
    });
}

fn chunkHeader(bytes: *const [8]u8) ChunkHeader {
    return ChunkHeader{
        .kind = @ptrCast(*const [4]u8, bytes[0..4].ptr).*,
        .len = mem.readIntBig(u32, @ptrCast(*const [4]u8, bytes[4..8].ptr)),
    };
}

pub const ChunkIterator = struct {
    bytes: []const u8,
    i: usize,

    pub fn init(bytes: []const u8) ChunkIterator {
        return ChunkIterator{
            .bytes = bytes,
            .i = 0,
        };
    }

    pub fn next(iter: *ChunkIterator) !?Chunk {
        if (iter.i == iter.bytes.len)
            return null;
        if (iter.bytes.len - iter.i < 8)
            return error.OutOfBounds;

        const header_bytes = @ptrCast(*const [8]u8, iter.bytes[iter.i..][0..8].ptr);
        const header = chunkHeader(header_bytes);
        iter.i += header_bytes.len;

        return Chunk{
            .header = header,
            .data = try iter.chunkData(header),
        };
    }

    fn chunkData(iter: *ChunkIterator, header: ChunkHeader) ![]const u8 {
        const start = iter.i;
        const end = iter.i + header.len;
        if (iter.bytes.len < end)
            return error.OutOfBounds;

        defer iter.i += header.len;
        return iter.bytes[start..end];
    }
};

fn chunkEql(a: Chunk, b: Chunk) bool {
    if (!mem.eql(u8, a.header.kind, b.header.kind))
        return false;
    if (!mem.eql(u8, a.data, b.data))
        return false;
    return a.header.len == b.header.len;
}

fn testChunkIterator(bytes: []const u8, results: []const Chunk) !void {
    var next_chunk: usize = 0;
    var iter = ChunkIterator.init(bytes);
    while (try iter.next()) |actual| : (next_chunk += 1) {
        const expected = results[next_chunk];
        debug.assert(chunkEql(expected, actual));
    }

    debug.assert(next_chunk == results.len);
    debug.assert((try iter.next()) == null);
}

test "midi.decode.ChunkIterator" {
    try testChunkIterator("abcd\x00\x00\x00\x04" ++
        "data" ++
        "efgh\x00\x00\x00\x05" ++
        "data2", []Chunk{
        Chunk{
            .header = ChunkHeader{
                .kind = "abcd",
                .len = 4,
            },
            .data = "data",
        },
        Chunk{
            .header = ChunkHeader{
                .kind = "efgh",
                .len = 5,
            },
            .data = "data2",
        },
    });
}

fn testMessageDecoder(bytes: []const u8, results: []const midi.Message) !void {
    var next_message: usize = 0;
    var iter = MessageDecoder.init(bytes);
    while (try iter.next()) |actual| : (next_message += 1) {
        const expected = results[next_message];
        debug.assert(expected.equal(actual));
    }

    debug.assert(next_message == results.len);
    debug.assert((try iter.next()) == null);
}

fn testChunkIterator(bytes: []const u8, results: []const midi.file.Chunk) !void {
    var next_chunk: usize = 0;
    var iter = ChunkIterator.init(bytes);
    while (try iter.next()) |actual| : (next_chunk += 1) {
        const expected = results[next_chunk];
        debug.assert(expected.equal(actual));
    }

    debug.assert(next_chunk == results.len);
    debug.assert((try iter.next()) == null);
}
