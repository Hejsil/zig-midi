const std = @import("std");
const midi = @import("index.zig");

const debug = std.debug;
const math = std.math;
const mem = std.mem;

const decode = @This();

/// Accepts input one byte at a time and returns midi channel messages as they are decoded.
///
/// For a non-byte based wrapper, consider using ChannelMessageDecoder instead.
pub const StreamingChannelMessageDecoder = struct {
    const State = union(enum) {
        Status: void,
        Running: ChannelMessage(0),

        ChannelValue1: ChannelMessage(0),
        ChannelValue2: ChannelMessage(1),

        fn ChannelMessage(comptime count: usize) type {
            return struct {
                kind: midi.ChannelMessage.Kind,
                channel: u4,
                values: [count]u7,
            };
        }
    };

    state: State,

    pub fn init() StreamingChannelMessageDecoder {
        return StreamingChannelMessageDecoder{ .state = State.Status };
    }

    fn feed(stream: *StreamingChannelMessageDecoder, b: u8) !?midi.ChannelMessage {
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

                    return error.InvalidChannelMessage;
                },
                State.Running => |msg| {
                    stream.state = if (b & 0x80 != 0) State{ .Status = {} } else State{ .ChannelValue1 = msg };
                    continue :repeat;
                },

                State.ChannelValue1 => |msg| {
                    const value = math.cast(u7, b) catch return error.InvalidChannelMessage;

                    stream.state = State{ .Running = msg };
                    switch (msg.kind) {
                        midi.ChannelMessage.Kind.NoteOff,
                        midi.ChannelMessage.Kind.NoteOn,
                        midi.ChannelMessage.Kind.PolyphonicKeyPressure,
                        midi.ChannelMessage.Kind.PitchBendChange,
                        midi.ChannelMessage.Kind.ControlChange,
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
                        midi.ChannelMessage.Kind.ProgramChange => return midi.ChannelMessage{
                            .ProgramChange = midi.ChannelMessage.ProgramChange{
                                .channel = msg.channel,
                                .program = value,
                            },
                        },
                        midi.ChannelMessage.Kind.ChannelPressure => return midi.ChannelMessage{
                            .ChannelPressure = midi.ChannelMessage.ChannelPressure{
                                .channel = msg.channel,
                                .pressure = value,
                            },
                        },
                        else => unreachable,
                    }
                },
                State.ChannelValue2 => |msg| {
                    const value = math.cast(u7, b) catch return error.InvalidChannelMessage;

                    stream.state = State{
                        .Running = State.ChannelMessage(0){
                            .channel = msg.channel,
                            .kind = msg.kind,
                            .values = []u7{},
                        },
                    };
                    switch (msg.kind) {
                        midi.ChannelMessage.Kind.ControlChange => switch (msg.values[0]) {
                            120 => return midi.ChannelMessage{
                                .AllSoundOff = midi.ChannelMessage.AllSoundOff{ .channel = msg.channel },
                            },
                            121 => return midi.ChannelMessage{
                                .ResetAllControllers = midi.ChannelMessage.ResetAllControllers{
                                    .channel = msg.channel,
                                    .value = value,
                                },
                            },
                            122 => return midi.ChannelMessage{
                                .LocalControl = midi.ChannelMessage.LocalControl{
                                    .channel = msg.channel,
                                    .on = switch (value) {
                                        0 => false,
                                        127 => true,
                                        else => return error.InvalidChannelMessage,
                                    },
                                },
                            },
                            123 => return midi.ChannelMessage{
                                .AllNotesOff = midi.ChannelMessage.AllNotesOff{ .channel = msg.channel },
                            },
                            124 => return midi.ChannelMessage{
                                .OmniModeOff = midi.ChannelMessage.OmniModeOff{ .channel = msg.channel },
                            },
                            125 => return midi.ChannelMessage{
                                .OmniModeOn = midi.ChannelMessage.OmniModeOn{ .channel = msg.channel },
                            },
                            126 => return midi.ChannelMessage{
                                .MonoModeOn = midi.ChannelMessage.MonoModeOn{
                                    .channel = msg.channel,
                                    .value = value,
                                },
                            },
                            127 => return midi.ChannelMessage{
                                .PolyModeOn = midi.ChannelMessage.PolyModeOn{ .channel = msg.channel },
                            },
                            else => return midi.ChannelMessage{
                                .ControlChange = midi.ChannelMessage.ControlChange{
                                    .channel = msg.channel,
                                    .controller = msg.values[0],
                                    .value = value,
                                },
                            },
                        },
                        midi.ChannelMessage.Kind.NoteOff => return midi.ChannelMessage{
                            .NoteOff = midi.ChannelMessage.NoteOff{
                                .channel = msg.channel,
                                .note = msg.values[0],
                                .velocity = value,
                            },
                        },
                        midi.ChannelMessage.Kind.NoteOn => return midi.ChannelMessage{
                            .NoteOn = midi.ChannelMessage.NoteOn{
                                .channel = msg.channel,
                                .note = msg.values[0],
                                .velocity = value,
                            },
                        },
                        midi.ChannelMessage.Kind.PolyphonicKeyPressure => return midi.ChannelMessage{
                            .PolyphonicKeyPressure = midi.ChannelMessage.PolyphonicKeyPressure{
                                .channel = msg.channel,
                                .note = msg.values[0],
                                .pressure = value,
                            },
                        },
                        midi.ChannelMessage.Kind.PitchBendChange => return midi.ChannelMessage{
                            .PitchBendChange = midi.ChannelMessage.PitchBendChange{
                                .channel = msg.channel,
                                .bend = u14(msg.values[0]) | u14(value) << 7,
                            },
                        },
                        else => unreachable,
                    }
                },
            }
        }
    }

    pub fn reset(stream: *StreamingChannelMessageDecoder) void {
        stream.state = State{ .Status = void{} };
    }

    pub fn done(stream: *StreamingChannelMessageDecoder) !void {
        switch (stream.state) {
            State.Status, State.Running => {
                stream.reset();
                return;
            },
            else => return error.InvalidChannelMessage,
        }
    }

    const channel_message_table = blk: {
        var res = []?midi.ChannelMessage.Kind{null} ** (math.maxInt(u4) + 1);
        res[0b1000] = midi.ChannelMessage.Kind.NoteOff;
        res[0b1001] = midi.ChannelMessage.Kind.NoteOn;
        res[0b1010] = midi.ChannelMessage.Kind.PolyphonicKeyPressure;
        res[0b1011] = midi.ChannelMessage.Kind.ControlChange;
        res[0b1100] = midi.ChannelMessage.Kind.ProgramChange;
        res[0b1101] = midi.ChannelMessage.Kind.ChannelPressure;
        res[0b1110] = midi.ChannelMessage.Kind.PitchBendChange;
        break :blk res;
    };
};

/// A wrapper for the StreamingChannelMessageDecoder. Accepts a slice of bytes which can be iterated
/// to get all midi channel messages in these bytes.
pub const ChannelMessageDecoder = struct {
    stream: StreamingChannelMessageDecoder,
    bytes: []const u8,
    i: usize,

    pub fn init(bytes: []const u8) ChannelMessageDecoder {
        return ChannelMessageDecoder{
            .stream = StreamingChannelMessageDecoder.init(),
            .bytes = bytes,
            .i = 0,
        };
    }

    pub fn next(iter: *ChannelMessageDecoder) !?midi.ChannelMessage {
        while (iter.i < iter.bytes.len) {
            defer iter.i += 1;
            if (try iter.stream.feed(iter.bytes[iter.i])) |message|
                return message;
        }

        try iter.stream.done();
        return null;
    }
};

test "midi.decode.ChannelMessageDecoder" {
    try testChannelMessageDecoder("\x80\x00\x00" ++
        "\x7F\x7F" ++
        "\x8F\x7F\x7F", []midi.ChannelMessage{
        midi.ChannelMessage{
            .NoteOff = midi.ChannelMessage.NoteOff{
                .channel = 0x0,
                .note = 0x00,
                .velocity = 0x00,
            },
        },
        midi.ChannelMessage{
            .NoteOff = midi.ChannelMessage.NoteOff{
                .channel = 0x0,
                .note = 0x7F,
                .velocity = 0x7F,
            },
        },
        midi.ChannelMessage{
            .NoteOff = midi.ChannelMessage.NoteOff{
                .channel = 0xF,
                .note = 0x7F,
                .velocity = 0x7F,
            },
        },
    });
    try testChannelMessageDecoder("\x90\x00\x00" ++
        "\x7F\x7F" ++
        "\x9F\x7F\x7F", []midi.ChannelMessage{
        midi.ChannelMessage{
            .NoteOn = midi.ChannelMessage.NoteOn{
                .channel = 0x0,
                .note = 0x00,
                .velocity = 0x00,
            },
        },
        midi.ChannelMessage{
            .NoteOn = midi.ChannelMessage.NoteOn{
                .channel = 0x0,
                .note = 0x7F,
                .velocity = 0x7F,
            },
        },
        midi.ChannelMessage{
            .NoteOn = midi.ChannelMessage.NoteOn{
                .channel = 0xF,
                .note = 0x7F,
                .velocity = 0x7F,
            },
        },
    });
    try testChannelMessageDecoder("\xA0\x00\x00" ++
        "\x7F\x7F" ++
        "\xAF\x7F\x7F", []midi.ChannelMessage{
        midi.ChannelMessage{
            .PolyphonicKeyPressure = midi.ChannelMessage.PolyphonicKeyPressure{
                .channel = 0x0,
                .note = 0x00,
                .pressure = 0x00,
            },
        },
        midi.ChannelMessage{
            .PolyphonicKeyPressure = midi.ChannelMessage.PolyphonicKeyPressure{
                .channel = 0x0,
                .note = 0x7F,
                .pressure = 0x7F,
            },
        },
        midi.ChannelMessage{
            .PolyphonicKeyPressure = midi.ChannelMessage.PolyphonicKeyPressure{
                .channel = 0xF,
                .note = 0x7F,
                .pressure = 0x7F,
            },
        },
    });
    try testChannelMessageDecoder("\xB0\x00\x00" ++
        "\x77\x7F" ++
        "\xBF\x77\x7F", []midi.ChannelMessage{
        midi.ChannelMessage{
            .ControlChange = midi.ChannelMessage.ControlChange{
                .channel = 0x0,
                .controller = 0x0,
                .value = 0x0,
            },
        },
        midi.ChannelMessage{
            .ControlChange = midi.ChannelMessage.ControlChange{
                .channel = 0x0,
                .controller = 0x77,
                .value = 0x7F,
            },
        },
        midi.ChannelMessage{
            .ControlChange = midi.ChannelMessage.ControlChange{
                .channel = 0xF,
                .controller = 0x77,
                .value = 0x7F,
            },
        },
    });
    try testChannelMessageDecoder("\xB0\x78\x00" ++
        "\x78\x00" ++
        "\xBF\x78\x00", []midi.ChannelMessage{
        midi.ChannelMessage{ .AllSoundOff = midi.ChannelMessage.AllSoundOff{ .channel = 0x0 } },
        midi.ChannelMessage{ .AllSoundOff = midi.ChannelMessage.AllSoundOff{ .channel = 0x0 } },
        midi.ChannelMessage{ .AllSoundOff = midi.ChannelMessage.AllSoundOff{ .channel = 0xF } },
    });
    try testChannelMessageDecoder("\xB0\x79\x00" ++
        "\x79\x7F" ++
        "\xBF\x79\x7F", []midi.ChannelMessage{
        midi.ChannelMessage{
            .ResetAllControllers = midi.ChannelMessage.ResetAllControllers{
                .channel = 0x0,
                .value = 0x0,
            },
        },
        midi.ChannelMessage{
            .ResetAllControllers = midi.ChannelMessage.ResetAllControllers{
                .channel = 0x0,
                .value = 0x7F,
            },
        },
        midi.ChannelMessage{
            .ResetAllControllers = midi.ChannelMessage.ResetAllControllers{
                .channel = 0xF,
                .value = 0x7F,
            },
        },
    });
    try testChannelMessageDecoder("\xB0\x7A\x00" ++
        "\x7A\x7F" ++
        "\xBF\x7A\x7F", []midi.ChannelMessage{
        midi.ChannelMessage{
            .LocalControl = midi.ChannelMessage.LocalControl{
                .channel = 0x0,
                .on = false,
            },
        },
        midi.ChannelMessage{
            .LocalControl = midi.ChannelMessage.LocalControl{
                .channel = 0x0,
                .on = true,
            },
        },
        midi.ChannelMessage{
            .LocalControl = midi.ChannelMessage.LocalControl{
                .channel = 0xF,
                .on = true,
            },
        },
    });
    try testChannelMessageDecoder("\xB0\x7B\x00" ++
        "\x7B\x00" ++
        "\xBF\x7B\x00", []midi.ChannelMessage{
        midi.ChannelMessage{ .AllNotesOff = midi.ChannelMessage.AllNotesOff{ .channel = 0x0 } },
        midi.ChannelMessage{ .AllNotesOff = midi.ChannelMessage.AllNotesOff{ .channel = 0x0 } },
        midi.ChannelMessage{ .AllNotesOff = midi.ChannelMessage.AllNotesOff{ .channel = 0xF } },
    });
    try testChannelMessageDecoder("\xB0\x7C\x00" ++
        "\x7C\x00" ++
        "\xBF\x7C\x00", []midi.ChannelMessage{
        midi.ChannelMessage{ .OmniModeOff = midi.ChannelMessage.OmniModeOff{ .channel = 0x0 } },
        midi.ChannelMessage{ .OmniModeOff = midi.ChannelMessage.OmniModeOff{ .channel = 0x0 } },
        midi.ChannelMessage{ .OmniModeOff = midi.ChannelMessage.OmniModeOff{ .channel = 0xF } },
    });
    try testChannelMessageDecoder("\xB0\x7D\x00" ++
        "\x7D\x00" ++
        "\xBF\x7D\x00", []midi.ChannelMessage{
        midi.ChannelMessage{ .OmniModeOn = midi.ChannelMessage.OmniModeOn{ .channel = 0x0 } },
        midi.ChannelMessage{ .OmniModeOn = midi.ChannelMessage.OmniModeOn{ .channel = 0x0 } },
        midi.ChannelMessage{ .OmniModeOn = midi.ChannelMessage.OmniModeOn{ .channel = 0xF } },
    });
    try testChannelMessageDecoder("\xB0\x7E\x00" ++
        "\x7E\x7F" ++
        "\xBF\x7E\x7F", []midi.ChannelMessage{
        midi.ChannelMessage{
            .MonoModeOn = midi.ChannelMessage.MonoModeOn{
                .channel = 0x0,
                .value = 0x00,
            },
        },
        midi.ChannelMessage{
            .MonoModeOn = midi.ChannelMessage.MonoModeOn{
                .channel = 0x0,
                .value = 0x7F,
            },
        },
        midi.ChannelMessage{
            .MonoModeOn = midi.ChannelMessage.MonoModeOn{
                .channel = 0xF,
                .value = 0x7F,
            },
        },
    });
    try testChannelMessageDecoder("\xB0\x7F\x00" ++
        "\x7F\x00" ++
        "\xBF\x7F\x00", []midi.ChannelMessage{
        midi.ChannelMessage{ .PolyModeOn = midi.ChannelMessage.PolyModeOn{ .channel = 0x0 } },
        midi.ChannelMessage{ .PolyModeOn = midi.ChannelMessage.PolyModeOn{ .channel = 0x0 } },
        midi.ChannelMessage{ .PolyModeOn = midi.ChannelMessage.PolyModeOn{ .channel = 0xF } },
    });
    try testChannelMessageDecoder("\xC0\x00" ++
        "\x7F" ++
        "\xCF\x7F", []midi.ChannelMessage{
        midi.ChannelMessage{
            .ProgramChange = midi.ChannelMessage.ProgramChange{
                .channel = 0x0,
                .program = 0x00,
            },
        },
        midi.ChannelMessage{
            .ProgramChange = midi.ChannelMessage.ProgramChange{
                .channel = 0x0,
                .program = 0x7F,
            },
        },
        midi.ChannelMessage{
            .ProgramChange = midi.ChannelMessage.ProgramChange{
                .channel = 0xF,
                .program = 0x7F,
            },
        },
    });
    try testChannelMessageDecoder("\xD0\x00" ++
        "\x7F" ++
        "\xDF\x7F", []midi.ChannelMessage{
        midi.ChannelMessage{
            .ChannelPressure = midi.ChannelMessage.ChannelPressure{
                .channel = 0x0,
                .pressure = 0x00,
            },
        },
        midi.ChannelMessage{
            .ChannelPressure = midi.ChannelMessage.ChannelPressure{
                .channel = 0x0,
                .pressure = 0x7F,
            },
        },
        midi.ChannelMessage{
            .ChannelPressure = midi.ChannelMessage.ChannelPressure{
                .channel = 0xF,
                .pressure = 0x7F,
            },
        },
    });
    try testChannelMessageDecoder("\xE0\x00\x00" ++
        "\x7F\x7F" ++
        "\xEF\x7F\x7F", []midi.ChannelMessage{
        midi.ChannelMessage{
            .PitchBendChange = midi.ChannelMessage.PitchBendChange{
                .channel = 0x0,
                .bend = 0x00,
            },
        },
        midi.ChannelMessage{
            .PitchBendChange = midi.ChannelMessage.PitchBendChange{
                .channel = 0x0,
                .bend = 0x7F << 7 | 0x7F,
            },
        },
        midi.ChannelMessage{
            .PitchBendChange = midi.ChannelMessage.PitchBendChange{
                .channel = 0xF,
                .bend = 0x7F << 7 | 0x7F,
            },
        },
    });
}

/// Accepts input one byte at a time and returns midi system messages as they are decoded.
///
/// For a non-byte based wrapper, consider using SystemMessageDecoder instead.
pub const StreamingSystemMessageDecoder = struct {
    const State = union(enum) {
        Status: void,

        SystemValue1: SystemMessage(0),
        SystemValue2: SystemMessage(1),

        SystemExclusive: void,

        fn SystemMessage(comptime count: usize) type {
            return struct {
                kind: midi.SystemMessage.Kind,
                values: [count]u7,
            };
        }
    };

    state: State,

    pub fn init() StreamingSystemMessageDecoder {
        return StreamingSystemMessageDecoder{ .state = State.Status };
    }

    fn feed(stream: *StreamingSystemMessageDecoder, b: u8) !?midi.SystemMessage {
        switch (stream.state) {
            State.Status => {
                const upper = @truncate(u4, b >> 4);
                const lower = @truncate(u4, b);

                if (upper != 0b1111)
                    return error.InvalidSystemMessage;
                if (system_message_table[lower]) |kind| {
                    switch (kind) {
                        midi.SystemMessage.Kind.ExclusiveStart => blk: {
                            stream.state = State.SystemExclusive;
                            return midi.SystemMessage{ .ExclusiveStart = {} };
                        },
                        midi.SystemMessage.Kind.MidiTimeCodeQuarterFrame,
                        midi.SystemMessage.Kind.SongPositionPointer,
                        midi.SystemMessage.Kind.SongSelect,
                        => {
                            stream.state = State{
                                .SystemValue1 = State.SystemMessage(0){
                                    .kind = kind,
                                    .values = []u7{},
                                },
                            };
                            return null;
                        },

                        midi.SystemMessage.Kind.ExclusiveEnd => return error.InvalidSystemMessage,
                        midi.SystemMessage.Kind.TuneRequest => return midi.SystemMessage{ .TuneRequest = {} },
                        midi.SystemMessage.Kind.TimingClock => return midi.SystemMessage{ .TimingClock = {} },
                        midi.SystemMessage.Kind.Start => return midi.SystemMessage{ .Start = {} },
                        midi.SystemMessage.Kind.Continue => return midi.SystemMessage{ .Continue = {} },
                        midi.SystemMessage.Kind.Stop => return midi.SystemMessage{ .Stop = {} },
                        midi.SystemMessage.Kind.ActiveSensing => return midi.SystemMessage{ .ActiveSensing = {} },
                        midi.SystemMessage.Kind.Reset => return midi.SystemMessage{ .Reset = {} },
                        else => unreachable,
                    }
                }

                return error.InvalidSystemMessage;
            },

            State.SystemValue1 => |msg| {
                const value = math.cast(u7, b) catch return error.InvalidSystemMessage;

                stream.state = State.Status;
                switch (msg.kind) {
                    midi.SystemMessage.Kind.SongPositionPointer => {
                        stream.state = State{
                            .SystemValue2 = State.SystemMessage(1){
                                .kind = msg.kind,
                                .values = []u7{value},
                            },
                        };
                        return null;
                    },
                    midi.SystemMessage.Kind.MidiTimeCodeQuarterFrame => return midi.SystemMessage{
                        .MidiTimeCodeQuarterFrame = midi.SystemMessage.MidiTimeCodeQuarterFrame{
                            .message_type = @intCast(u3, value >> 4),
                            .values = @truncate(u4, value),
                        },
                    },
                    midi.SystemMessage.Kind.SongSelect => return midi.SystemMessage{
                        .SongSelect = midi.SystemMessage.SongSelect{ .sequence = value },
                    },
                    else => unreachable,
                }
            },
            State.SystemValue2 => |msg| {
                const value = math.cast(u7, b) catch return error.InvalidSystemMessage;

                stream.state = State.Status;
                switch (msg.kind) {
                    midi.SystemMessage.Kind.SongPositionPointer => return midi.SystemMessage{
                        .SongPositionPointer = midi.SystemMessage.SongPositionPointer{ .beats = u14(msg.values[0]) | u14(value) << 7 },
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
                    return error.InvalidSystemMessage;
                if (system_message_table[lower]) |kind| {
                    if (kind != midi.SystemMessage.Kind.ExclusiveEnd)
                        return error.InvalidSystemMessage;
                }

                stream.state = State.Status;
                return midi.SystemMessage{ .ExclusiveEnd = {} };
            },
        }
    }

    pub fn reset(stream: *StreamingSystemMessageDecoder) void {
        stream.state = State{ .Status = void{} };
    }

    pub fn done(stream: *StreamingSystemMessageDecoder) !void {
        switch (stream.state) {
            State.Status => {
                stream.reset();
                return;
            },
            else => return error.InvalidSystemMessage,
        }
    }

    const system_message_table = blk: {
        var res = []?midi.SystemMessage.Kind{null} ** (math.maxInt(u4) + 1);
        res[0b0000] = midi.SystemMessage.Kind.ExclusiveStart;
        res[0b0001] = midi.SystemMessage.Kind.MidiTimeCodeQuarterFrame;
        res[0b0010] = midi.SystemMessage.Kind.SongPositionPointer;
        res[0b0011] = midi.SystemMessage.Kind.SongSelect;
        res[0b0110] = midi.SystemMessage.Kind.TuneRequest;
        res[0b0110] = midi.SystemMessage.Kind.TuneRequest;
        res[0b0111] = midi.SystemMessage.Kind.ExclusiveEnd;
        res[0b1000] = midi.SystemMessage.Kind.TimingClock;
        res[0b1010] = midi.SystemMessage.Kind.Start;
        res[0b1011] = midi.SystemMessage.Kind.Continue;
        res[0b1100] = midi.SystemMessage.Kind.Stop;
        res[0b1110] = midi.SystemMessage.Kind.ActiveSensing;
        res[0b1111] = midi.SystemMessage.Kind.Reset;
        break :blk res;
    };
};

/// A wrapper for the StreamingSystemMessageDecoder. Accepts a slice of bytes which can be iterated
/// to get all midi system messages in these bytes.
pub const SystemMessageDecoder = struct {
    stream: StreamingSystemMessageDecoder,
    bytes: []const u8,
    i: usize,

    pub fn init(bytes: []const u8) SystemMessageDecoder {
        return SystemMessageDecoder{
            .stream = StreamingSystemMessageDecoder.init(),
            .bytes = bytes,
            .i = 0,
        };
    }

    pub fn next(iter: *SystemMessageDecoder) !?midi.SystemMessage {
        while (iter.i < iter.bytes.len) {
            defer iter.i += 1;
            if (try iter.stream.feed(iter.bytes[iter.i])) |message|
                return message;
        }

        try iter.stream.done();
        return null;
    }
};

test "midi.decode.StreamingMessageDecoder: SystemExclusive" {
    try testSystemMessageDecoder("\xF0\x01\x0F\x7F\xF7", []midi.SystemMessage{
        midi.SystemMessage{ .ExclusiveStart = {} },
        midi.SystemMessage{ .ExclusiveEnd = {} },
    });
    try testSystemMessageDecoder("\xF1\x00" ++
        "\xF1\x0F" ++
        "\xF1\x70" ++
        "\xF1\x7F", []midi.SystemMessage{
        midi.SystemMessage{
            .MidiTimeCodeQuarterFrame = midi.SystemMessage.MidiTimeCodeQuarterFrame{
                .message_type = 0,
                .values = 0,
            },
        },
        midi.SystemMessage{
            .MidiTimeCodeQuarterFrame = midi.SystemMessage.MidiTimeCodeQuarterFrame{
                .message_type = 0,
                .values = 0xF,
            },
        },
        midi.SystemMessage{
            .MidiTimeCodeQuarterFrame = midi.SystemMessage.MidiTimeCodeQuarterFrame{
                .message_type = 0x7,
                .values = 0x0,
            },
        },
        midi.SystemMessage{
            .MidiTimeCodeQuarterFrame = midi.SystemMessage.MidiTimeCodeQuarterFrame{
                .message_type = 0x7,
                .values = 0xF,
            },
        },
    });
    try testSystemMessageDecoder("\xF2\x00\x00" ++
        "\xF2\x7F\x7F", []midi.SystemMessage{
        midi.SystemMessage{ .SongPositionPointer = midi.SystemMessage.SongPositionPointer{ .beats = 0x0 } },
        midi.SystemMessage{ .SongPositionPointer = midi.SystemMessage.SongPositionPointer{ .beats = 0x7F << 7 | 0x7F } },
    });
    try testSystemMessageDecoder("\xF3\x00" ++
        "\xF3\x7F", []midi.SystemMessage{
        midi.SystemMessage{ .SongSelect = midi.SystemMessage.SongSelect{ .sequence = 0x0 } },
        midi.SystemMessage{ .SongSelect = midi.SystemMessage.SongSelect{ .sequence = 0x7F } },
    });
    try testSystemMessageDecoder("\xF6\xF6", []midi.SystemMessage{
        midi.SystemMessage{ .TuneRequest = {} },
        midi.SystemMessage{ .TuneRequest = {} },
    });
    try testSystemMessageDecoder("\xF8\xF8", []midi.SystemMessage{
        midi.SystemMessage{ .TimingClock = {} },
        midi.SystemMessage{ .TimingClock = {} },
    });
    try testSystemMessageDecoder("\xFA\xFA", []midi.SystemMessage{
        midi.SystemMessage{ .Start = {} },
        midi.SystemMessage{ .Start = {} },
    });
    try testSystemMessageDecoder("\xFB\xFB", []midi.SystemMessage{
        midi.SystemMessage{ .Continue = {} },
        midi.SystemMessage{ .Continue = {} },
    });
    try testSystemMessageDecoder("\xFC\xFC", []midi.SystemMessage{
        midi.SystemMessage{ .Stop = {} },
        midi.SystemMessage{ .Stop = {} },
    });
    try testSystemMessageDecoder("\xFE\xFE", []midi.SystemMessage{
        midi.SystemMessage{ .ActiveSensing = {} },
        midi.SystemMessage{ .ActiveSensing = {} },
    });
    try testSystemMessageDecoder("\xFF\xFF", []midi.SystemMessage{
        midi.SystemMessage{ .Reset = {} },
        midi.SystemMessage{ .Reset = {} },
    });
}

/// Accepts input one byte at a time and returns midi messages as they are decoded.
///
/// For a non-byte based wrapper, consider using MessageDecoder instead.
pub const StreamingMessageDecoder = struct {
    const State = union(enum) {
        Status: void,
        Channel: StreamingChannelMessageDecoder,
        System: StreamingSystemMessageDecoder,
    };

    state: State,

    pub fn init() StreamingMessageDecoder {
        return StreamingMessageDecoder{ .state = State.Status };
    }

    fn feed(stream: *StreamingMessageDecoder, b: u8) !?midi.Message {
        repeat: while (true) switch (stream.state) {
            State.Status => {
                var channel_decoder = StreamingChannelMessageDecoder.init();
                if (channel_decoder.feed(b)) |m_message| {
                    stream.state = State{ .Channel = channel_decoder };
                    if (m_message) |message|
                        return midi.Message{ .Channel = message };

                    return null;
                } else |_| {}

                var system_decoder = StreamingSystemMessageDecoder.init();
                if (system_decoder.feed(b)) |m_message| {
                    stream.state = State{ .System = system_decoder };
                    if (m_message) |message|
                        return midi.Message{ .System = message };

                    return null;
                } else |_| {}

                return error.InvalidMessage;
            },
            State.Channel => |*decoder| {
                const m_message = decoder.feed(b) catch {
                    try decoder.done();
                    stream.state = State.Status;
                    continue :repeat;
                };
                if (m_message) |message|
                    return midi.Message{ .Channel = message };

                return null;
            },
            State.System => |*decoder| {
                const m_message = decoder.feed(b) catch {
                    try decoder.done();
                    stream.state = State.Status;
                    continue :repeat;
                };
                if (m_message) |message|
                    return midi.Message{ .System = message };

                return null;
            },
        };
    }

    pub fn reset(stream: *StreamingMessageDecoder) void {
        stream.state = State{ .Status = void{} };
    }

    pub fn done(stream: *StreamingMessageDecoder) !void {
        switch (stream.state) {
            State.Status => stream.reset(),
            State.Channel => |*decoder| {
                try decoder.done();
                stream.reset();
            },
            State.System => |*decoder| {
                try decoder.done();
                stream.reset();
            },
        }
    }
};

/// A wrapper for the StreamingMessageDecoder. Accepts a slice of bytes which can be iterated
/// to get all midi system messages in these bytes.
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

test "midi.decode.MessageDecoder" {
    try testMessageDecoder("\x80\x00\x00" ++
        "\x7F\x7F" ++
        "\x8F\x7F\x7F", []midi.Message{
        midi.Message{
            .Channel = midi.ChannelMessage{
                .NoteOff = midi.ChannelMessage.NoteOff{
                    .channel = 0x0,
                    .note = 0x00,
                    .velocity = 0x00,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .NoteOff = midi.ChannelMessage.NoteOff{
                    .channel = 0x0,
                    .note = 0x7F,
                    .velocity = 0x7F,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .NoteOff = midi.ChannelMessage.NoteOff{
                    .channel = 0xF,
                    .note = 0x7F,
                    .velocity = 0x7F,
                },
            },
        },
    });
    try testMessageDecoder("\x90\x00\x00" ++
        "\x7F\x7F" ++
        "\x9F\x7F\x7F", []midi.Message{
        midi.Message{
            .Channel = midi.ChannelMessage{
                .NoteOn = midi.ChannelMessage.NoteOn{
                    .channel = 0x0,
                    .note = 0x00,
                    .velocity = 0x00,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .NoteOn = midi.ChannelMessage.NoteOn{
                    .channel = 0x0,
                    .note = 0x7F,
                    .velocity = 0x7F,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .NoteOn = midi.ChannelMessage.NoteOn{
                    .channel = 0xF,
                    .note = 0x7F,
                    .velocity = 0x7F,
                },
            },
        },
    });
    try testMessageDecoder("\xA0\x00\x00" ++
        "\x7F\x7F" ++
        "\xAF\x7F\x7F", []midi.Message{
        midi.Message{
            .Channel = midi.ChannelMessage{
                .PolyphonicKeyPressure = midi.ChannelMessage.PolyphonicKeyPressure{
                    .channel = 0x0,
                    .note = 0x00,
                    .pressure = 0x00,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .PolyphonicKeyPressure = midi.ChannelMessage.PolyphonicKeyPressure{
                    .channel = 0x0,
                    .note = 0x7F,
                    .pressure = 0x7F,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .PolyphonicKeyPressure = midi.ChannelMessage.PolyphonicKeyPressure{
                    .channel = 0xF,
                    .note = 0x7F,
                    .pressure = 0x7F,
                },
            },
        },
    });
    try testMessageDecoder("\xB0\x00\x00" ++
        "\x77\x7F" ++
        "\xBF\x77\x7F", []midi.Message{
        midi.Message{
            .Channel = midi.ChannelMessage{
                .ControlChange = midi.ChannelMessage.ControlChange{
                    .channel = 0x0,
                    .controller = 0x0,
                    .value = 0x0,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .ControlChange = midi.ChannelMessage.ControlChange{
                    .channel = 0x0,
                    .controller = 0x77,
                    .value = 0x7F,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .ControlChange = midi.ChannelMessage.ControlChange{
                    .channel = 0xF,
                    .controller = 0x77,
                    .value = 0x7F,
                },
            },
        },
    });
    try testMessageDecoder("\xB0\x78\x00" ++
        "\x78\x00" ++
        "\xBF\x78\x00", []midi.Message{
        midi.Message{ .Channel = midi.ChannelMessage{ .AllSoundOff = midi.ChannelMessage.AllSoundOff{ .channel = 0x0 } } },
        midi.Message{ .Channel = midi.ChannelMessage{ .AllSoundOff = midi.ChannelMessage.AllSoundOff{ .channel = 0x0 } } },
        midi.Message{ .Channel = midi.ChannelMessage{ .AllSoundOff = midi.ChannelMessage.AllSoundOff{ .channel = 0xF } } },
    });
    try testMessageDecoder("\xB0\x79\x00" ++
        "\x79\x7F" ++
        "\xBF\x79\x7F", []midi.Message{
        midi.Message{
            .Channel = midi.ChannelMessage{
                .ResetAllControllers = midi.ChannelMessage.ResetAllControllers{
                    .channel = 0x0,
                    .value = 0x0,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .ResetAllControllers = midi.ChannelMessage.ResetAllControllers{
                    .channel = 0x0,
                    .value = 0x7F,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .ResetAllControllers = midi.ChannelMessage.ResetAllControllers{
                    .channel = 0xF,
                    .value = 0x7F,
                },
            },
        },
    });
    try testMessageDecoder("\xB0\x7A\x00" ++
        "\x7A\x7F" ++
        "\xBF\x7A\x7F", []midi.Message{
        midi.Message{
            .Channel = midi.ChannelMessage{
                .LocalControl = midi.ChannelMessage.LocalControl{
                    .channel = 0x0,
                    .on = false,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .LocalControl = midi.ChannelMessage.LocalControl{
                    .channel = 0x0,
                    .on = true,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .LocalControl = midi.ChannelMessage.LocalControl{
                    .channel = 0xF,
                    .on = true,
                },
            },
        },
    });
    try testMessageDecoder("\xB0\x7B\x00" ++
        "\x7B\x00" ++
        "\xBF\x7B\x00", []midi.Message{
        midi.Message{ .Channel = midi.ChannelMessage{ .AllNotesOff = midi.ChannelMessage.AllNotesOff{ .channel = 0x0 } } },
        midi.Message{ .Channel = midi.ChannelMessage{ .AllNotesOff = midi.ChannelMessage.AllNotesOff{ .channel = 0x0 } } },
        midi.Message{ .Channel = midi.ChannelMessage{ .AllNotesOff = midi.ChannelMessage.AllNotesOff{ .channel = 0xF } } },
    });
    try testMessageDecoder("\xB0\x7C\x00" ++
        "\x7C\x00" ++
        "\xBF\x7C\x00", []midi.Message{
        midi.Message{ .Channel = midi.ChannelMessage{ .OmniModeOff = midi.ChannelMessage.OmniModeOff{ .channel = 0x0 } } },
        midi.Message{ .Channel = midi.ChannelMessage{ .OmniModeOff = midi.ChannelMessage.OmniModeOff{ .channel = 0x0 } } },
        midi.Message{ .Channel = midi.ChannelMessage{ .OmniModeOff = midi.ChannelMessage.OmniModeOff{ .channel = 0xF } } },
    });
    try testMessageDecoder("\xB0\x7D\x00" ++
        "\x7D\x00" ++
        "\xBF\x7D\x00", []midi.Message{
        midi.Message{ .Channel = midi.ChannelMessage{ .OmniModeOn = midi.ChannelMessage.OmniModeOn{ .channel = 0x0 } } },
        midi.Message{ .Channel = midi.ChannelMessage{ .OmniModeOn = midi.ChannelMessage.OmniModeOn{ .channel = 0x0 } } },
        midi.Message{ .Channel = midi.ChannelMessage{ .OmniModeOn = midi.ChannelMessage.OmniModeOn{ .channel = 0xF } } },
    });
    try testMessageDecoder("\xB0\x7E\x00" ++
        "\x7E\x7F" ++
        "\xBF\x7E\x7F", []midi.Message{
        midi.Message{
            .Channel = midi.ChannelMessage{
                .MonoModeOn = midi.ChannelMessage.MonoModeOn{
                    .channel = 0x0,
                    .value = 0x00,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .MonoModeOn = midi.ChannelMessage.MonoModeOn{
                    .channel = 0x0,
                    .value = 0x7F,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .MonoModeOn = midi.ChannelMessage.MonoModeOn{
                    .channel = 0xF,
                    .value = 0x7F,
                },
            },
        },
    });
    try testMessageDecoder("\xB0\x7F\x00" ++
        "\x7F\x00" ++
        "\xBF\x7F\x00", []midi.Message{
        midi.Message{ .Channel = midi.ChannelMessage{ .PolyModeOn = midi.ChannelMessage.PolyModeOn{ .channel = 0x0 } } },
        midi.Message{ .Channel = midi.ChannelMessage{ .PolyModeOn = midi.ChannelMessage.PolyModeOn{ .channel = 0x0 } } },
        midi.Message{ .Channel = midi.ChannelMessage{ .PolyModeOn = midi.ChannelMessage.PolyModeOn{ .channel = 0xF } } },
    });
    try testMessageDecoder("\xC0\x00" ++
        "\x7F" ++
        "\xCF\x7F", []midi.Message{
        midi.Message{
            .Channel = midi.ChannelMessage{
                .ProgramChange = midi.ChannelMessage.ProgramChange{
                    .channel = 0x0,
                    .program = 0x00,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .ProgramChange = midi.ChannelMessage.ProgramChange{
                    .channel = 0x0,
                    .program = 0x7F,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .ProgramChange = midi.ChannelMessage.ProgramChange{
                    .channel = 0xF,
                    .program = 0x7F,
                },
            },
        },
    });
    try testMessageDecoder("\xD0\x00" ++
        "\x7F" ++
        "\xDF\x7F", []midi.Message{
        midi.Message{
            .Channel = midi.ChannelMessage{
                .ChannelPressure = midi.ChannelMessage.ChannelPressure{
                    .channel = 0x0,
                    .pressure = 0x00,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .ChannelPressure = midi.ChannelMessage.ChannelPressure{
                    .channel = 0x0,
                    .pressure = 0x7F,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .ChannelPressure = midi.ChannelMessage.ChannelPressure{
                    .channel = 0xF,
                    .pressure = 0x7F,
                },
            },
        },
    });
    try testMessageDecoder("\xE0\x00\x00" ++
        "\x7F\x7F" ++
        "\xEF\x7F\x7F", []midi.Message{
        midi.Message{
            .Channel = midi.ChannelMessage{
                .PitchBendChange = midi.ChannelMessage.PitchBendChange{
                    .channel = 0x0,
                    .bend = 0x00,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .PitchBendChange = midi.ChannelMessage.PitchBendChange{
                    .channel = 0x0,
                    .bend = 0x7F << 7 | 0x7F,
                },
            },
        },
        midi.Message{
            .Channel = midi.ChannelMessage{
                .PitchBendChange = midi.ChannelMessage.PitchBendChange{
                    .channel = 0xF,
                    .bend = 0x7F << 7 | 0x7F,
                },
            },
        },
    });
    try testMessageDecoder("\xF0\x01\x0F\x7F\xF7", []midi.Message{
        midi.Message{ .System = midi.SystemMessage{ .ExclusiveStart = {} } },
        midi.Message{ .System = midi.SystemMessage{ .ExclusiveEnd = {} } },
    });
    try testMessageDecoder("\xF1\x00" ++
        "\xF1\x0F" ++
        "\xF1\x70" ++
        "\xF1\x7F", []midi.Message{
        midi.Message{
            .System = midi.SystemMessage{
                .MidiTimeCodeQuarterFrame = midi.SystemMessage.MidiTimeCodeQuarterFrame{
                    .message_type = 0,
                    .values = 0,
                },
            },
        },
        midi.Message{
            .System = midi.SystemMessage{
                .MidiTimeCodeQuarterFrame = midi.SystemMessage.MidiTimeCodeQuarterFrame{
                    .message_type = 0,
                    .values = 0xF,
                },
            },
        },
        midi.Message{
            .System = midi.SystemMessage{
                .MidiTimeCodeQuarterFrame = midi.SystemMessage.MidiTimeCodeQuarterFrame{
                    .message_type = 0x7,
                    .values = 0x0,
                },
            },
        },
        midi.Message{
            .System = midi.SystemMessage{
                .MidiTimeCodeQuarterFrame = midi.SystemMessage.MidiTimeCodeQuarterFrame{
                    .message_type = 0x7,
                    .values = 0xF,
                },
            },
        },
    });
    try testMessageDecoder("\xF2\x00\x00" ++
        "\xF2\x7F\x7F", []midi.Message{
        midi.Message{ .System = midi.SystemMessage{ .SongPositionPointer = midi.SystemMessage.SongPositionPointer{ .beats = 0x0 } } },
        midi.Message{ .System = midi.SystemMessage{ .SongPositionPointer = midi.SystemMessage.SongPositionPointer{ .beats = 0x7F << 7 | 0x7F } } },
    });
    try testMessageDecoder("\xF3\x00" ++
        "\xF3\x7F", []midi.Message{
        midi.Message{ .System = midi.SystemMessage{ .SongSelect = midi.SystemMessage.SongSelect{ .sequence = 0x0 } } },
        midi.Message{ .System = midi.SystemMessage{ .SongSelect = midi.SystemMessage.SongSelect{ .sequence = 0x7F } } },
    });
    try testMessageDecoder("\xF6\xF6", []midi.Message{
        midi.Message{ .System = midi.SystemMessage{ .TuneRequest = {} } },
        midi.Message{ .System = midi.SystemMessage{ .TuneRequest = {} } },
    });
    try testMessageDecoder("\xF8\xF8", []midi.Message{
        midi.Message{ .System = midi.SystemMessage{ .TimingClock = {} } },
        midi.Message{ .System = midi.SystemMessage{ .TimingClock = {} } },
    });
    try testMessageDecoder("\xFA\xFA", []midi.Message{
        midi.Message{ .System = midi.SystemMessage{ .Start = {} } },
        midi.Message{ .System = midi.SystemMessage{ .Start = {} } },
    });
    try testMessageDecoder("\xFB\xFB", []midi.Message{
        midi.Message{ .System = midi.SystemMessage{ .Continue = {} } },
        midi.Message{ .System = midi.SystemMessage{ .Continue = {} } },
    });
    try testMessageDecoder("\xFC\xFC", []midi.Message{
        midi.Message{ .System = midi.SystemMessage{ .Stop = {} } },
        midi.Message{ .System = midi.SystemMessage{ .Stop = {} } },
    });
    try testMessageDecoder("\xFE\xFE", []midi.Message{
        midi.Message{ .System = midi.SystemMessage{ .ActiveSensing = {} } },
        midi.Message{ .System = midi.SystemMessage{ .ActiveSensing = {} } },
    });
    try testMessageDecoder("\xFF\xFF", []midi.Message{
        midi.Message{ .System = midi.SystemMessage{ .Reset = {} } },
        midi.Message{ .System = midi.SystemMessage{ .Reset = {} } },
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
///
/// TODO: "We may decide to define other format IDs to support other structures. A program encountering
///        an unknown format ID may still read other MTrk chunks it finds from the file, as format 1 or
///        2, if its user can make sense of them and arrange them into some other structure if
///        appropriate. Also, more parameters may be added to the MThd chunk in the future: it is
///        important to read and honor the length, even if it is longer than 6." -The Midi Spec
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

test "decode.variableLengthInt" {
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

fn testChannelMessageDecoder(bytes: []const u8, results: []const midi.ChannelMessage) !void {
    var next_message: usize = 0;
    var iter = ChannelMessageDecoder.init(bytes);
    while (try iter.next()) |actual| : (next_message += 1) {
        const expected = results[next_message];
        debug.assert(expected.equal(actual));
    }

    debug.assert(next_message == results.len);
    debug.assert((try iter.next()) == null);
}

fn testSystemMessageDecoder(bytes: []const u8, results: []const midi.SystemMessage) !void {
    var next_message: usize = 0;
    var iter = SystemMessageDecoder.init(bytes);
    while (try iter.next()) |actual| : (next_message += 1) {
        const expected = results[next_message];
        debug.assert(expected.equal(actual));
    }

    debug.assert(next_message == results.len);
    debug.assert((try iter.next()) == null);
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
