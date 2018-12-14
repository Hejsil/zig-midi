const std = @import("std");
const midi = @import("index.zig");

const debug = std.debug;
const math = std.math;
const mem = std.mem;

const decode = @This();

/// Accepts input one byte at a time and returns midi messages as they are decoded.
///
/// For a non-byte based wrapper, consider using MessageDecoder instead.
pub const StreamingMessageDecoder = struct {
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
                kind: midi.Message.Kind,
                channel: u4,
                values: [count]u7,
            };
        }

        fn SystemMessage(comptime count: usize) type {
            return struct {
                kind: midi.Message.Kind,
                values: [count]u7,
            };
        }
    };

    state: State,

    pub fn init() StreamingMessageDecoder {
        return StreamingMessageDecoder{ .state = State.Status };
    }

    fn feed(stream: *StreamingMessageDecoder, b: u8) !?midi.Message {
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
                            midi.Message.Kind.SystemExclusiveStart => blk: {
                                stream.state = State.SystemExclusive;
                                return midi.Message{ .SystemExclusiveStart = {} };
                            },
                            midi.Message.Kind.MidiTimeCodeQuarterFrame,
                            midi.Message.Kind.SongPositionPointer,
                            midi.Message.Kind.SongSelect,
                            => {
                                stream.state = State{
                                    .SystemValue1 = State.SystemMessage(0){
                                        .kind = kind,
                                        .values = []u7{},
                                    },
                                };
                                return null;
                            },

                            midi.Message.Kind.SystemExclusiveEnd => return error.InvalidMessage,
                            midi.Message.Kind.TuneRequest => return midi.Message{ .TuneRequest = {} },
                            midi.Message.Kind.TimingClock => return midi.Message{ .TimingClock = {} },
                            midi.Message.Kind.Start => return midi.Message{ .Start = {} },
                            midi.Message.Kind.Continue => return midi.Message{ .Continue = {} },
                            midi.Message.Kind.Stop => return midi.Message{ .Stop = {} },
                            midi.Message.Kind.ActiveSensing => return midi.Message{ .ActiveSensing = {} },
                            midi.Message.Kind.Reset => return midi.Message{ .Reset = {} },
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
                        midi.Message.Kind.NoteOff,
                        midi.Message.Kind.NoteOn,
                        midi.Message.Kind.PolyphonicKeyPressure,
                        midi.Message.Kind.PitchBendChange,
                        midi.Message.Kind.ControlChange,
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
                        midi.Message.Kind.ProgramChange => return midi.Message{
                            .ProgramChange = midi.Message.ProgramChange{
                                .channel = msg.channel,
                                .program = value,
                            },
                        },
                        midi.Message.Kind.ChannelPressure => return midi.Message{
                            .ChannelPressure = midi.Message.ChannelPressure{
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
                        midi.Message.Kind.ControlChange => switch (msg.values[0]) {
                            120 => return midi.Message{
                                .AllSoundOff = midi.Message.AllSoundOff{ .channel = msg.channel },
                            },
                            121 => return midi.Message{
                                .ResetAllControllers = midi.Message.ResetAllControllers{
                                    .channel = msg.channel,
                                    .value = value,
                                },
                            },
                            122 => return midi.Message{
                                .LocalControl = midi.Message.LocalControl{
                                    .channel = msg.channel,
                                    .on = switch (value) {
                                        0 => false,
                                        127 => true,
                                        else => return error.InvalidMessage,
                                    },
                                },
                            },
                            123 => return midi.Message{
                                .AllNotesOff = midi.Message.AllNotesOff{ .channel = msg.channel },
                            },
                            124 => return midi.Message{
                                .OmniModeOff = midi.Message.OmniModeOff{ .channel = msg.channel },
                            },
                            125 => return midi.Message{
                                .OmniModeOn = midi.Message.OmniModeOn{ .channel = msg.channel },
                            },
                            126 => return midi.Message{
                                .MonoModeOn = midi.Message.MonoModeOn{
                                    .channel = msg.channel,
                                    .value = value,
                                },
                            },
                            127 => return midi.Message{
                                .PolyModeOn = midi.Message.PolyModeOn{ .channel = msg.channel },
                            },
                            else => return midi.Message{
                                .ControlChange = midi.Message.ControlChange{
                                    .channel = msg.channel,
                                    .controller = msg.values[0],
                                    .value = value,
                                },
                            },
                        },
                        midi.Message.Kind.NoteOff => return midi.Message{
                            .NoteOff = midi.Message.NoteOff{
                                .channel = msg.channel,
                                .note = msg.values[0],
                                .velocity = value,
                            },
                        },
                        midi.Message.Kind.NoteOn => return midi.Message{
                            .NoteOn = midi.Message.NoteOn{
                                .channel = msg.channel,
                                .note = msg.values[0],
                                .velocity = value,
                            },
                        },
                        midi.Message.Kind.PolyphonicKeyPressure => return midi.Message{
                            .PolyphonicKeyPressure = midi.Message.PolyphonicKeyPressure{
                                .channel = msg.channel,
                                .note = msg.values[0],
                                .pressure = value,
                            },
                        },
                        midi.Message.Kind.PitchBendChange => return midi.Message{
                            .PitchBendChange = midi.Message.PitchBendChange{
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
                        midi.Message.Kind.SongPositionPointer => {
                            stream.state = State{
                                .SystemValue2 = State.SystemMessage(1){
                                    .kind = msg.kind,
                                    .values = []u7{value},
                                },
                            };
                            return null;
                        },
                        midi.Message.Kind.MidiTimeCodeQuarterFrame => return midi.Message{
                            .MidiTimeCodeQuarterFrame = midi.Message.MidiTimeCodeQuarterFrame{
                                .message_type = @intCast(u3, value >> 4),
                                .values = @truncate(u4, value),
                            },
                        },
                        midi.Message.Kind.SongSelect => return midi.Message{
                            .SongSelect = midi.Message.SongSelect{ .sequence = value },
                        },
                        else => unreachable,
                    }
                },
                State.SystemValue2 => |msg| {
                    const value = math.cast(u7, b) catch return error.InvalidMessage;

                    stream.state = State.Status;
                    switch (msg.kind) {
                        midi.Message.Kind.SongPositionPointer => return midi.Message{
                            .SongPositionPointer = midi.Message.SongPositionPointer{ .beats = u14(msg.values[0]) | u14(value) << 7 },
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
                        if (kind != midi.Message.Kind.SystemExclusiveEnd)
                            return error.InvalidMessage;
                    }

                    stream.state = State.Status;
                    return midi.Message{ .SystemExclusiveEnd = {} };
                },
            }
        }
    }

    pub fn reset(stream: *StreamingMessageDecoder) void {
        stream.state = State{ .Status = void{} };
    }

    pub fn done(stream: *StreamingMessageDecoder) !void {
        const old_state = stream.state;
        stream.reset();
        switch (old_state) {
            State.Status, State.Running => return,
            else => return error.InvalidMessage,
        }
    }

    const channel_message_table = blk: {
        var res = []?midi.Message.Kind{null} ** (math.maxInt(u4) + 1);
        res[0b1000] = midi.Message.Kind.NoteOff;
        res[0b1001] = midi.Message.Kind.NoteOn;
        res[0b1010] = midi.Message.Kind.PolyphonicKeyPressure;
        res[0b1011] = midi.Message.Kind.ControlChange;
        res[0b1100] = midi.Message.Kind.ProgramChange;
        res[0b1101] = midi.Message.Kind.ChannelPressure;
        res[0b1110] = midi.Message.Kind.PitchBendChange;
        break :blk res;
    };

    const system_message_table = blk: {
        var res = []?midi.Message.Kind{null} ** (math.maxInt(u4) + 1);
        res[0b0000] = midi.Message.Kind.SystemExclusiveStart;
        res[0b0001] = midi.Message.Kind.MidiTimeCodeQuarterFrame;
        res[0b0010] = midi.Message.Kind.SongPositionPointer;
        res[0b0011] = midi.Message.Kind.SongSelect;
        res[0b0110] = midi.Message.Kind.TuneRequest;
        res[0b0110] = midi.Message.Kind.TuneRequest;
        res[0b0111] = midi.Message.Kind.SystemExclusiveEnd;
        res[0b1000] = midi.Message.Kind.TimingClock;
        res[0b1010] = midi.Message.Kind.Start;
        res[0b1011] = midi.Message.Kind.Continue;
        res[0b1100] = midi.Message.Kind.Stop;
        res[0b1110] = midi.Message.Kind.ActiveSensing;
        res[0b1111] = midi.Message.Kind.Reset;
        break :blk res;
    };
};

/// A wrapper for the StreamingMessageDecoder. Accepts a slice of bytes which can be iterated
/// to get all midi messages in these bytes.
pub const MessageDecoder = struct {
    stream: StreamingMessageDecoder,
    bytes: []const u8,
    i: usize,

    pub fn init(bytes: []const u8) MessageDecoder {
        return MessageDecoder{
            .stream = StreamingMessageDecoder.init(),
            .bytes = bytes,
            .i = 0,
        };
    }

    pub fn next(iter: *MessageDecoder) !?midi.Message {
        while (iter.i < iter.bytes.len) {
            defer iter.i += 1;
            if (try iter.stream.feed(iter.bytes[iter.i])) |message|
                return message;
        }

        try iter.stream.done();
        return null;
    }
};

test "midi.decode.MessageDecoder: NoteOff" {
    try testMessageDecoder("\x80\x00\x00" ++
        "\x7F\x7F" ++
        "\x8F\x7F\x7F", []midi.Message{
        midi.Message{
            .NoteOff = midi.Message.NoteOff{
                .channel = 0x0,
                .note = 0x00,
                .velocity = 0x00,
            },
        },
        midi.Message{
            .NoteOff = midi.Message.NoteOff{
                .channel = 0x0,
                .note = 0x7F,
                .velocity = 0x7F,
            },
        },
        midi.Message{
            .NoteOff = midi.Message.NoteOff{
                .channel = 0xF,
                .note = 0x7F,
                .velocity = 0x7F,
            },
        },
    });
}

test "midi.decode.StreamingMessageDecoder: NoteOn" {
    try testMessageDecoder("\x90\x00\x00" ++
        "\x7F\x7F" ++
        "\x9F\x7F\x7F", []midi.Message{
        midi.Message{
            .NoteOn = midi.Message.NoteOn{
                .channel = 0x0,
                .note = 0x00,
                .velocity = 0x00,
            },
        },
        midi.Message{
            .NoteOn = midi.Message.NoteOn{
                .channel = 0x0,
                .note = 0x7F,
                .velocity = 0x7F,
            },
        },
        midi.Message{
            .NoteOn = midi.Message.NoteOn{
                .channel = 0xF,
                .note = 0x7F,
                .velocity = 0x7F,
            },
        },
    });
}

test "midi.decode.StreamingMessageDecoder: PolyphonicKeyPressure" {
    try testMessageDecoder("\xA0\x00\x00" ++
        "\x7F\x7F" ++
        "\xAF\x7F\x7F", []midi.Message{
        midi.Message{
            .PolyphonicKeyPressure = midi.Message.PolyphonicKeyPressure{
                .channel = 0x0,
                .note = 0x00,
                .pressure = 0x00,
            },
        },
        midi.Message{
            .PolyphonicKeyPressure = midi.Message.PolyphonicKeyPressure{
                .channel = 0x0,
                .note = 0x7F,
                .pressure = 0x7F,
            },
        },
        midi.Message{
            .PolyphonicKeyPressure = midi.Message.PolyphonicKeyPressure{
                .channel = 0xF,
                .note = 0x7F,
                .pressure = 0x7F,
            },
        },
    });
}

test "midi.decode.StreamingMessageDecoder: ControlChange" {
    try testMessageDecoder("\xB0\x00\x00" ++
        "\x77\x7F" ++
        "\xBF\x77\x7F", []midi.Message{
        midi.Message{
            .ControlChange = midi.Message.ControlChange{
                .channel = 0x0,
                .controller = 0x0,
                .value = 0x0,
            },
        },
        midi.Message{
            .ControlChange = midi.Message.ControlChange{
                .channel = 0x0,
                .controller = 0x77,
                .value = 0x7F,
            },
        },
        midi.Message{
            .ControlChange = midi.Message.ControlChange{
                .channel = 0xF,
                .controller = 0x77,
                .value = 0x7F,
            },
        },
    });
}

test "midi.decode.StreamingMessageDecoder: AllSoundOff" {
    try testMessageDecoder("\xB0\x78\x00" ++
        "\x78\x00" ++
        "\xBF\x78\x00", []midi.Message{
        midi.Message{ .AllSoundOff = midi.Message.AllSoundOff{ .channel = 0x0 } },
        midi.Message{ .AllSoundOff = midi.Message.AllSoundOff{ .channel = 0x0 } },
        midi.Message{ .AllSoundOff = midi.Message.AllSoundOff{ .channel = 0xF } },
    });
}

test "midi.decode.StreamingMessageDecoder: ResetAllControllers" {
    try testMessageDecoder("\xB0\x79\x00" ++
        "\x79\x7F" ++
        "\xBF\x79\x7F", []midi.Message{
        midi.Message{
            .ResetAllControllers = midi.Message.ResetAllControllers{
                .channel = 0x0,
                .value = 0x0,
            },
        },
        midi.Message{
            .ResetAllControllers = midi.Message.ResetAllControllers{
                .channel = 0x0,
                .value = 0x7F,
            },
        },
        midi.Message{
            .ResetAllControllers = midi.Message.ResetAllControllers{
                .channel = 0xF,
                .value = 0x7F,
            },
        },
    });
}

test "midi.decode.StreamingMessageDecoder: LocalControl" {
    try testMessageDecoder("\xB0\x7A\x00" ++
        "\x7A\x7F" ++
        "\xBF\x7A\x7F", []midi.Message{
        midi.Message{
            .LocalControl = midi.Message.LocalControl{
                .channel = 0x0,
                .on = false,
            },
        },
        midi.Message{
            .LocalControl = midi.Message.LocalControl{
                .channel = 0x0,
                .on = true,
            },
        },
        midi.Message{
            .LocalControl = midi.Message.LocalControl{
                .channel = 0xF,
                .on = true,
            },
        },
    });
}

test "midi.decode.StreamingMessageDecoder: AllNotesOff" {
    try testMessageDecoder("\xB0\x7B\x00" ++
        "\x7B\x00" ++
        "\xBF\x7B\x00", []midi.Message{
        midi.Message{ .AllNotesOff = midi.Message.AllNotesOff{ .channel = 0x0 } },
        midi.Message{ .AllNotesOff = midi.Message.AllNotesOff{ .channel = 0x0 } },
        midi.Message{ .AllNotesOff = midi.Message.AllNotesOff{ .channel = 0xF } },
    });
}

test "midi.decode.StreamingMessageDecoder: OmniModeOff" {
    try testMessageDecoder("\xB0\x7C\x00" ++
        "\x7C\x00" ++
        "\xBF\x7C\x00", []midi.Message{
        midi.Message{ .OmniModeOff = midi.Message.OmniModeOff{ .channel = 0x0 } },
        midi.Message{ .OmniModeOff = midi.Message.OmniModeOff{ .channel = 0x0 } },
        midi.Message{ .OmniModeOff = midi.Message.OmniModeOff{ .channel = 0xF } },
    });
}

test "midi.decode.StreamingMessageDecoder: OmniModeOn" {
    try testMessageDecoder("\xB0\x7D\x00" ++
        "\x7D\x00" ++
        "\xBF\x7D\x00", []midi.Message{
        midi.Message{ .OmniModeOn = midi.Message.OmniModeOn{ .channel = 0x0 } },
        midi.Message{ .OmniModeOn = midi.Message.OmniModeOn{ .channel = 0x0 } },
        midi.Message{ .OmniModeOn = midi.Message.OmniModeOn{ .channel = 0xF } },
    });
}

test "midi.decode.StreamingMessageDecoder: MonoModeOn" {
    try testMessageDecoder("\xB0\x7E\x00" ++
        "\x7E\x7F" ++
        "\xBF\x7E\x7F", []midi.Message{
        midi.Message{
            .MonoModeOn = midi.Message.MonoModeOn{
                .channel = 0x0,
                .value = 0x00,
            },
        },
        midi.Message{
            .MonoModeOn = midi.Message.MonoModeOn{
                .channel = 0x0,
                .value = 0x7F,
            },
        },
        midi.Message{
            .MonoModeOn = midi.Message.MonoModeOn{
                .channel = 0xF,
                .value = 0x7F,
            },
        },
    });
}

test "midi.decode.StreamingMessageDecoder: PolyModeOn" {
    try testMessageDecoder("\xB0\x7F\x00" ++
        "\x7F\x00" ++
        "\xBF\x7F\x00", []midi.Message{
        midi.Message{ .PolyModeOn = midi.Message.PolyModeOn{ .channel = 0x0 } },
        midi.Message{ .PolyModeOn = midi.Message.PolyModeOn{ .channel = 0x0 } },
        midi.Message{ .PolyModeOn = midi.Message.PolyModeOn{ .channel = 0xF } },
    });
}

test "midi.decode.StreamingMessageDecoder: ProgramChange" {
    try testMessageDecoder("\xC0\x00" ++
        "\x7F" ++
        "\xCF\x7F", []midi.Message{
        midi.Message{
            .ProgramChange = midi.Message.ProgramChange{
                .channel = 0x0,
                .program = 0x00,
            },
        },
        midi.Message{
            .ProgramChange = midi.Message.ProgramChange{
                .channel = 0x0,
                .program = 0x7F,
            },
        },
        midi.Message{
            .ProgramChange = midi.Message.ProgramChange{
                .channel = 0xF,
                .program = 0x7F,
            },
        },
    });
}

test "midi.decode.StreamingMessageDecoder: ChannelPressure" {
    try testMessageDecoder("\xD0\x00" ++
        "\x7F" ++
        "\xDF\x7F", []midi.Message{
        midi.Message{
            .ChannelPressure = midi.Message.ChannelPressure{
                .channel = 0x0,
                .pressure = 0x00,
            },
        },
        midi.Message{
            .ChannelPressure = midi.Message.ChannelPressure{
                .channel = 0x0,
                .pressure = 0x7F,
            },
        },
        midi.Message{
            .ChannelPressure = midi.Message.ChannelPressure{
                .channel = 0xF,
                .pressure = 0x7F,
            },
        },
    });
}

test "midi.decode.StreamingMessageDecoder: PitchBendChange" {
    try testMessageDecoder("\xE0\x00\x00" ++
        "\x7F\x7F" ++
        "\xEF\x7F\x7F", []midi.Message{
        midi.Message{
            .PitchBendChange = midi.Message.PitchBendChange{
                .channel = 0x0,
                .bend = 0x00,
            },
        },
        midi.Message{
            .PitchBendChange = midi.Message.PitchBendChange{
                .channel = 0x0,
                .bend = 0x7F << 7 | 0x7F,
            },
        },
        midi.Message{
            .PitchBendChange = midi.Message.PitchBendChange{
                .channel = 0xF,
                .bend = 0x7F << 7 | 0x7F,
            },
        },
    });
}

test "midi.decode.StreamingMessageDecoder: SystemExclusive" {
    try testMessageDecoder("\xF0\x01\x0F\x7F\xF7", []midi.Message{
        midi.Message{ .SystemExclusiveStart = {} },
        midi.Message{ .SystemExclusiveEnd = {} },
    });
}

test "midi.decode.StreamingMessageDecoder: MIDITimeCodeQuarterFrame" {
    try testMessageDecoder("\xF1\x00" ++
        "\xF1\x0F" ++
        "\xF1\x70" ++
        "\xF1\x7F", []midi.Message{
        midi.Message{
            .MidiTimeCodeQuarterFrame = midi.Message.MidiTimeCodeQuarterFrame{
                .message_type = 0,
                .values = 0,
            },
        },
        midi.Message{
            .MidiTimeCodeQuarterFrame = midi.Message.MidiTimeCodeQuarterFrame{
                .message_type = 0,
                .values = 0xF,
            },
        },
        midi.Message{
            .MidiTimeCodeQuarterFrame = midi.Message.MidiTimeCodeQuarterFrame{
                .message_type = 0x7,
                .values = 0x0,
            },
        },
        midi.Message{
            .MidiTimeCodeQuarterFrame = midi.Message.MidiTimeCodeQuarterFrame{
                .message_type = 0x7,
                .values = 0xF,
            },
        },
    });
}

test "midi.decode.StreamingMessageDecoder: SongPositionPointer" {
    try testMessageDecoder("\xF2\x00\x00" ++
        "\xF2\x7F\x7F", []midi.Message{
        midi.Message{ .SongPositionPointer = midi.Message.SongPositionPointer{ .beats = 0x0 } },
        midi.Message{ .SongPositionPointer = midi.Message.SongPositionPointer{ .beats = 0x7F << 7 | 0x7F } },
    });
}

test "midi.decode.StreamingMessageDecoder: SongSelect" {
    try testMessageDecoder("\xF3\x00" ++
        "\xF3\x7F", []midi.Message{
        midi.Message{ .SongSelect = midi.Message.SongSelect{ .sequence = 0x0 } },
        midi.Message{ .SongSelect = midi.Message.SongSelect{ .sequence = 0x7F } },
    });
}

test "midi.decode.StreamingMessageDecoder: TuneRequest" {
    try testMessageDecoder("\xF6\xF6", []midi.Message{
        midi.Message{ .TuneRequest = {} },
        midi.Message{ .TuneRequest = {} },
    });
}

test "midi.decode.StreamingMessageDecoder: TimingClock" {
    try testMessageDecoder("\xF8\xF8", []midi.Message{
        midi.Message{ .TimingClock = {} },
        midi.Message{ .TimingClock = {} },
    });
}

test "midi.decode.StreamingMessageDecoder: Start" {
    try testMessageDecoder("\xFA\xFA", []midi.Message{
        midi.Message{ .Start = {} },
        midi.Message{ .Start = {} },
    });
}

test "midi.decode.StreamingMessageDecoder: Continue" {
    try testMessageDecoder("\xFB\xFB", []midi.Message{
        midi.Message{ .Continue = {} },
        midi.Message{ .Continue = {} },
    });
}

test "midi.decode.StreamingMessageDecoder: Stop" {
    try testMessageDecoder("\xFC\xFC", []midi.Message{
        midi.Message{ .Stop = {} },
        midi.Message{ .Stop = {} },
    });
}

test "midi.decode.StreamingMessageDecoder: ActiveSensing" {
    try testMessageDecoder("\xFE\xFE", []midi.Message{
        midi.Message{ .ActiveSensing = {} },
        midi.Message{ .ActiveSensing = {} },
    });
}

test "midi.decode.StreamingMessageDecoder: Reset" {
    try testMessageDecoder("\xFF\xFF", []midi.Message{
        midi.Message{ .Reset = {} },
        midi.Message{ .Reset = {} },
    });
}

/// Accepts a slice of bytes which can be iterated to get all midi chunks and their data in these
/// bytes.
pub const ChunkIterator = struct {
    bytes: []const u8,
    i: usize,

    pub fn init(bytes: []const u8) ChunkIterator {
        return ChunkIterator{
            .bytes = bytes,
            .i = 0,
        };
    }

    pub fn next(iter: *ChunkIterator) !?midi.file.Chunk {
        if (iter.i == iter.bytes.len)
            return null;
        if (iter.bytes.len - iter.i < 8)
            return error.OutOfBounds;

        const info_bytes = @ptrCast(*const [8]u8, iter.bytes[iter.i..][0..8].ptr).*;
        const info = decode.chunkInfo(info_bytes);
        iter.i += info_bytes.len;

        return midi.file.Chunk{
            .info = info,
            .data = try iter.chunkData(info),
        };
    }

    fn chunkData(iter: *ChunkIterator, header: midi.file.Chunk.Info) ![]const u8 {
        const start = iter.i;
        const end = iter.i + header.len;
        if (iter.bytes.len < end)
            return error.OutOfBounds;

        defer iter.i += header.len;
        return iter.bytes[start..end];
    }
};

test "midi.decode.ChunkIterator" {
    try testChunkIterator("abcd\x00\x00\x00\x04" ++
        "data" ++
        "efgh\x00\x00\x00\x05" ++
        "data2", []midi.file.Chunk{
        midi.file.Chunk{
            .info = midi.file.Chunk.Info{
                .kind = "abcd",
                .len = 4,
            },
            .data = "data",
        },
        midi.file.Chunk{
            .info = midi.file.Chunk.Info{
                .kind = "efgh",
                .len = 5,
            },
            .data = "data2",
        },
    });
}

/// Decodes 8 bytes into a midi.file.Chunk.Info.
pub fn chunkInfo(bytes: [8]u8) midi.file.Chunk.Info {
    return midi.file.Chunk.Info{
        .kind = @ptrCast(*const [4]u8, bytes[0..4].ptr).*,
        .len = mem.readIntBig(u32, @ptrCast(*const [4]u8, bytes[4..8].ptr)),
    };
}

test "decode.chunkInfo" {
    debug.assert(chunkInfo("abcd\x00\x00\x00\x04").equal(midi.file.Chunk.Info{
        .kind = "abcd",
        .len = 0x04,
    }));
    debug.assert(chunkInfo("efgh\x00\x00\x04\x00").equal(midi.file.Chunk.Info{
        .kind = "efgh",
        .len = 0x0400,
    }));
    debug.assert(chunkInfo("ijkl\x00\x04\x00\x00").equal(midi.file.Chunk.Info{
        .kind = "ijkl",
        .len = 0x040000,
    }));
    debug.assert(chunkInfo("mnop\x04\x00\x00\x00").equal(midi.file.Chunk.Info{
        .kind = "mnop",
        .len = 0x04000000,
    }));
}

/// Decodes 14 bytes into a midi.file.Header. This wraps decode.chunkInfo and validates that the
/// file header is correct.
pub fn fileHeader(bytes: [14]u8) !midi.file.Header {
    const info = decode.chunkInfo(@ptrCast(*const [8]u8, bytes[0..8].ptr).*);
    const format = mem.readIntBig(u16, @ptrCast(*const [2]u8, bytes[8..10].ptr));
    const ntrks = mem.readIntBig(u16, @ptrCast(*const [2]u8, bytes[10..12].ptr));
    const division = mem.readIntBig(u16, @ptrCast(*const [2]u8, bytes[12..14].ptr));

    if (!mem.eql(u8, info.kind, "MThd"))
        return error.InvalidHeaderKind;
    if (info.len != 6)
        return error.InvalidHeaderLength;
    if (format > 2)
        return error.InvalidHeaderFormat;

    return midi.file.Header{
        .format = @intToEnum(midi.file.Header.Format, @intCast(u2, format)),
        .tracks = switch (@intToEnum(midi.file.Header.Format, @intCast(u2, format))) {
            midi.file.Header.Format.SingleMultiChannelTrack => blk: {
                if (ntrks != 1)
                    return error.InvalidHeaderNumberOfTracks;
                break :blk ntrks;
            },
            midi.file.Header.Format.ManySimultaneousTracks => ntrks,
            midi.file.Header.Format.ManyIndependentTracks => ntrks,
        },
        .division = switch (@truncate(u1, division >> 15)) {
            0 => midi.file.Header.Division{ .TicksPerQuarterNote = @truncate(u15, division) },
            1 => midi.file.Header.Division{
                .SubdivisionsOfSecond = midi.file.Header.Division.SubdivisionsOfSecond{
                    .smpte_format = @bitCast(i8, @truncate(u8, division >> 8)),
                    .ticks_per_frame = @truncate(u8, division),
                },
            },
        },
    };
}

test "decode.fileHeader" {
    debug.assert((try fileHeader("MThd\x00\x00\x00\x06\x00\x00\x00\x01\x01\x10")).equal(midi.file.Header{
        .format = midi.file.Header.Format.SingleMultiChannelTrack,
        .tracks = 0x0001,
        .division = midi.file.Header.Division{ .TicksPerQuarterNote = 0x0110 },
    }));
    debug.assert((try fileHeader("MThd\x00\x00\x00\x06\x00\x01\x01\x01\x01\x10")).equal(midi.file.Header{
        .format = midi.file.Header.Format.ManySimultaneousTracks,
        .tracks = 0x0101,
        .division = midi.file.Header.Division{ .TicksPerQuarterNote = 0x0110 },
    }));
    debug.assert((try fileHeader("MThd\x00\x00\x00\x06\x00\x02\x01\x01\x01\x10")).equal(midi.file.Header{
        .format = midi.file.Header.Format.ManyIndependentTracks,
        .tracks = 0x0101,
        .division = midi.file.Header.Division{ .TicksPerQuarterNote = 0x0110 },
    }));
    debug.assert((try fileHeader("MThd\x00\x00\x00\x06\x00\x00\x00\x01\xFF\x10")).equal(midi.file.Header{
        .format = midi.file.Header.Format.SingleMultiChannelTrack,
        .tracks = 0x0001,
        .division = midi.file.Header.Division{
            .SubdivisionsOfSecond = midi.file.Header.Division.SubdivisionsOfSecond{
                .smpte_format = -1,
                .ticks_per_frame = 0x10,
            },
        },
    }));
    debug.assert((try fileHeader("MThd\x00\x00\x00\x06\x00\x01\x01\x01\xFF\x10")).equal(midi.file.Header{
        .format = midi.file.Header.Format.ManySimultaneousTracks,
        .tracks = 0x0101,
        .division = midi.file.Header.Division{
            .SubdivisionsOfSecond = midi.file.Header.Division.SubdivisionsOfSecond{
                .smpte_format = -1,
                .ticks_per_frame = 0x10,
            },
        },
    }));
    debug.assert((try fileHeader("MThd\x00\x00\x00\x06\x00\x02\x01\x01\xFF\x10")).equal(midi.file.Header{
        .format = midi.file.Header.Format.ManyIndependentTracks,
        .tracks = 0x0101,
        .division = midi.file.Header.Division{
            .SubdivisionsOfSecond = midi.file.Header.Division.SubdivisionsOfSecond{
                .smpte_format = -1,
                .ticks_per_frame = 0x10,
            },
        },
    }));

    debug.assertError(fileHeader("Mthd\x00\x00\x00\x06\x00\x00\x00\x01\x01\x10"), error.InvalidHeaderKind);
    debug.assertError(fileHeader("MThd\x00\x00\x00\x05\x00\x00\x00\x01\x01\x10"), error.InvalidHeaderLength);
    debug.assertError(fileHeader("MThd\x00\x00\x00\x06\x00\x03\x00\x01\x01\x10"), error.InvalidHeaderFormat);
    debug.assertError(fileHeader("MThd\x00\x00\x00\x06\x00\x00\x00\x02\x01\x10"), error.InvalidHeaderNumberOfTracks);
}

/// Accepts input one byte at a time and returns variable-length integers as they are decoded.
pub const StreamingVariableLengthIntDecoder = struct {
    res: u28,

    pub fn init() StreamingVariableLengthIntDecoder {
        return StreamingVariableLengthIntDecoder{ .res = 0 };
    }

    pub fn feed(decoder: *StreamingVariableLengthIntDecoder, b: u8) !?u28 {
        const is_last = @truncate(u1, b >> 7) == 0;
        const value = @truncate(u7, b);
        decoder.res = try math.mul(u28, decoder.res, math.maxInt(u7) + 1);
        decoder.res = try math.add(u28, decoder.res, value);

        if (!is_last)
            return null;

        defer decoder.res = 0;
        return decoder.res;
    }
};

test "decode.StreamingVariableLengthIntDecoder" {
    try testStreamingVariableLengthIntDecoder("\x00" ++
        "\x40" ++
        "\x7F" ++
        "\x81\x00" ++
        "\xC0\x00" ++
        "\xFF\x7F" ++
        "\x81\x80\x00" ++
        "\xC0\x80\x00" ++
        "\xFF\xFF\x7F" ++
        "\x81\x80\x80\x00" ++
        "\xC0\x80\x80\x00" ++
        "\xFF\xFF\xFF\x7F", []u28{
        0x00000000,
        0x00000040,
        0x0000007F,
        0x00000080,
        0x00002000,
        0x00003FFF,
        0x00004000,
        0x00100000,
        0x001FFFFF,
        0x00200000,
        0x08000000,
        0x0FFFFFFF,
    });
}

/// Decodes a variable-length integer and returns it, and its the length in bytes.
pub fn variableLengthInt(bytes: []const u8) !struct {
    res: u28,
    len: usize,
} {
    const Result = @typeOf(variableLengthInt).ReturnType.Payload;
    var decoder = StreamingVariableLengthIntDecoder.init();
    for (bytes) |b, i| {
        if (try decoder.feed(b)) |res| {
            return Result{
                .res = res,
                .len = i + 1,
            };
        }
    }

    return error.InputTooSmall;
}

test "decode.StreamingVariableLengthIntDecoder" {
    debug.assert((try decode.variableLengthInt("\x00")).res == 0x00000000);
    debug.assert((try decode.variableLengthInt("\x40")).res == 0x00000040);
    debug.assert((try decode.variableLengthInt("\x7F")).res == 0x0000007F);
    debug.assert((try decode.variableLengthInt("\x81\x00")).res == 0x00000080);
    debug.assert((try decode.variableLengthInt("\xC0\x00")).res == 0x00002000);
    debug.assert((try decode.variableLengthInt("\xFF\x7F")).res == 0x00003FFF);
    debug.assert((try decode.variableLengthInt("\x81\x80\x00")).res == 0x00004000);
    debug.assert((try decode.variableLengthInt("\xC0\x80\x00")).res == 0x00100000);
    debug.assert((try decode.variableLengthInt("\xFF\xFF\x7F")).res == 0x001FFFFF);
    debug.assert((try decode.variableLengthInt("\x81\x80\x80\x00")).res == 0x00200000);
    debug.assert((try decode.variableLengthInt("\xC0\x80\x80\x00")).res == 0x08000000);
    debug.assert((try decode.variableLengthInt("\xFF\xFF\xFF\x7F")).res == 0x0FFFFFFF);
    debug.assert((try decode.variableLengthInt("\x00\xFF\xFF\xFF\xFF")).len == 1);
    debug.assert((try decode.variableLengthInt("\x40\xFF\xFF\xFF\xFF")).len == 1);
    debug.assert((try decode.variableLengthInt("\x7F\xFF\xFF\xFF\xFF")).len == 1);
    debug.assert((try decode.variableLengthInt("\x81\x00\xFF\xFF\xFF")).len == 2);
    debug.assert((try decode.variableLengthInt("\xC0\x00\xFF\xFF\xFF")).len == 2);
    debug.assert((try decode.variableLengthInt("\xFF\x7F\xFF\xFF\xFF")).len == 2);
    debug.assert((try decode.variableLengthInt("\x81\x80\x00\xFF\xFF")).len == 3);
    debug.assert((try decode.variableLengthInt("\xC0\x80\x00\xFF\xFF")).len == 3);
    debug.assert((try decode.variableLengthInt("\xFF\xFF\x7F\xFF\xFF")).len == 3);
    debug.assert((try decode.variableLengthInt("\x81\x80\x80\x00\xFF")).len == 4);
    debug.assert((try decode.variableLengthInt("\xC0\x80\x80\x00\xFF")).len == 4);
    debug.assert((try decode.variableLengthInt("\xFF\xFF\xFF\x7F\xFF")).len == 4);
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

fn testStreamingVariableLengthIntDecoder(bytes: []const u8, results: []const u28) !void {
    var decoder = StreamingVariableLengthIntDecoder.init();
    var next_result: usize = 0;
    for (bytes) |b| {
        if (try decoder.feed(b)) |actual| {
            const expected = results[next_result];
            next_result += 1;
            debug.assert(actual == expected);
        }
    }

    debug.assert(next_result == results.len);
    debug.assert(decoder.res == 0);
}
