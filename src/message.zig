const std = @import("std");
const mem = std.mem;
const math = std.math;
const debug = std.debug;

pub const Message = union(enum) {
    Channel: Channel,
    System: System,

    pub const Channel = struct {
        channel: u4,
        kind: Kind,

        pub const Kind = union(enum(u4)) {
            NoteOff: Note = 0b1000,
            NoteOn: Note = 0b1001,
            PolyphonicKeyPressure: PolyphonicKeyPressure = 0b1010,
            ControlChange: ControlChange = 0b1011, // TODO: Channel Mode Message
            ProgramChange: u7 = 0b1100,
            ChannelPressure: u7 = 0b1101,
            PitchBendChange: u14 = 0b1110,
        };

        pub const Note = struct {
            note: u7,
            velocity: u7,
        };

        pub const PolyphonicKeyPressure = struct {
            note: u7,
            pressure: u7,
        };

        pub const ControlChange = struct {
            controller: u7,
            value: u7,
        };
    };

    pub const System = union(enum(u8)) {
        SystemExclusive: []u7 = 0b11110000,
        MidiTimeCodeQuarterFrame: MidiTimeCodeQuarterFrame = 0b11110001,
        SongPositionPointer: u14 = 0b11110010,
        SongSelect: u7 = 0b11110011,
        TuneRequest: void = 0b11110110,
        EndOfExclusive: void = 0b11110111,
        TimingClock: void = 0b11111000,
        Start: void = 0b11111010,
        Continue: void = 0b11111011,
        Stop: void = 0b11111100,
        ActiveSensing: void = 0b11111110,
        Reset: void = 0b11111111,

        pub const MidiTimeCodeQuarterFrame = struct {
            messageType: u3,
            values: u4,
        };
    };
};

fn valueToEnum(comptime Enum: type, value: @TagType(Enum)) ?Enum {
    const fields = @typeInfo(Enum).Enum.fields;
    inline for (fields) |field| {
        if (field.value == value)
            return @intToEnum(Enum, @intCast(@TagType(Enum), field.value));
    }

    return null;
}

pub const MessageStream = struct {
    const SystemKind = @TagType(Message.System);
    const ChannelKind = @TagType(Message.Channel.Kind);

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
                kind: ChannelKind,
                channel: u4,
                values: [count]u7
            };
        }

        fn SystemMessage(comptime count: usize) type {
            return struct {
                kind: SystemKind,
                values: [count]u7
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
                    if (valueToEnum(ChannelKind, @truncate(u4, b >> 4))) |kind| {
                        stream.state = State{
                            .ChannelValue1 = State.ChannelMessage(0){
                                .channel = @truncate(u4, b),
                                .kind = kind,
                                .values = []u7{},
                            },
                        };
                        return null;
                    }

                    if (valueToEnum(SystemKind, b)) |kind| {
                        const system = switch (kind) {
                            SystemKind.SystemExclusive => blk: {
                                stream.state = State.SystemExclusive;
                                break :blk Message.System{
                                    .SystemExclusive = (([*]u7)(undefined))[0..0],
                                };
                            },
                            SystemKind.MidiTimeCodeQuarterFrame, SystemKind.SongPositionPointer, SystemKind.SongSelect => {
                                stream.state = State{
                                    .SystemValue1 = State.SystemMessage(0){
                                        .kind = kind,
                                        .values = []u7{},
                                    },
                                };
                                return null;
                            },

                            SystemKind.TuneRequest => Message.System{ .TuneRequest = void{} },
                            SystemKind.EndOfExclusive => return error.InvalidMessage,
                            SystemKind.TimingClock => Message.System{ .TimingClock = void{} },
                            SystemKind.Start => Message.System{ .Start = void{} },
                            SystemKind.Continue => Message.System{ .Continue = void{} },
                            SystemKind.Stop => Message.System{ .Stop = void{} },
                            SystemKind.ActiveSensing => Message.System{ .ActiveSensing = void{} },
                            SystemKind.Reset => Message.System{ .Reset = void{} },
                        };

                        return Message{ .System = system };
                    }

                    return error.InvalidMessage;
                },
                State.Running => |msg| {
                    stream.state = if (b & 0x80 == 1) State{ .Status = void{} } else State{ .ChannelValue1 = msg };
                    continue :repeat;
                },

                State.ChannelValue1 => |msg| {
                    const value = math.cast(u7, b) catch return error.InvalidMessage;
                    const kind = switch (msg.kind) {
                        ChannelKind.NoteOff, ChannelKind.NoteOn, ChannelKind.PolyphonicKeyPressure, ChannelKind.PitchBendChange, ChannelKind.ControlChange => {
                            stream.state = State {
                                .ChannelValue2 = State.ChannelMessage(1){
                                    .kind = msg.kind,
                                    .channel = msg.channel,
                                    .values = []u7{value},
                                }
                            };
                            return null;
                        },
                        ChannelKind.ProgramChange => Message.Channel.Kind{
                            .ProgramChange = value,
                        },
                        ChannelKind.ChannelPressure => Message.Channel.Kind{
                            .ChannelPressure = value,
                        },
                    };

                    stream.state = State { .Running = msg };
                    return Message{
                        .Channel = Message.Channel{
                            .channel = msg.channel,
                            .kind = kind,
                        },
                    };
                },
                State.ChannelValue2 => |msg| {
                    const value = math.cast(u7, b) catch return error.InvalidMessage;
                    const kind = switch (msg.kind) {
                        ChannelKind.ControlChange => Message.Channel.Kind{
                            .ControlChange = Message.Channel.ControlChange{
                                .controller = msg.values[0],
                                .value = value,
                            },
                        },
                        ChannelKind.NoteOff => Message.Channel.Kind{
                            .NoteOff = Message.Channel.Note{
                                .note = msg.values[0],
                                .velocity = value,
                            },
                        },
                        ChannelKind.NoteOn => Message.Channel.Kind{
                            .NoteOff = Message.Channel.Note{
                                .note = msg.values[0],
                                .velocity = value,
                            },
                        },
                        ChannelKind.PolyphonicKeyPressure => Message.Channel.Kind{
                            .PolyphonicKeyPressure = Message.Channel.PolyphonicKeyPressure{
                                .note = msg.values[0],
                                .pressure = value,
                            },
                        },
                        ChannelKind.PitchBendChange => Message.Channel.Kind{
                            .PitchBendChange = u14(msg.values[0]) | u14(value) << 7,
                        },
                        ChannelKind.ProgramChange, ChannelKind.ChannelPressure => unreachable
                    };

                    stream.state = State{ .Running = State.ChannelMessage(0){
                        .channel = msg.channel,
                        .kind = msg.kind,
                        .values = []u7{},
                    }};
                    return Message{
                        .Channel = Message.Channel{
                            .channel = msg.channel,
                            .kind = kind,
                        },
                    };
                },

                State.SystemValue1 => |msg| {
                    const value = math.cast(u7, b) catch return error.InvalidMessage;
                    const system = switch (msg.kind) {
                        SystemKind.MidiTimeCodeQuarterFrame => Message.System{
                            .MidiTimeCodeQuarterFrame = Message.System.MidiTimeCodeQuarterFrame{
                                .messageType = @intCast(u3, value >> 4),
                                .values = @truncate(u4, value),
                            },
                        },
                        SystemKind.SongSelect => Message.System{
                            .SongSelect = value,
                        },
                        SystemKind.SongPositionPointer => {
                            stream.state = State{
                                .SystemValue2 = State.SystemMessage(1){
                                    .kind = msg.kind,
                                    .values = []u7{value},
                                },
                            };
                            return null;
                        },

                        SystemKind.SystemExclusive, SystemKind.TuneRequest, SystemKind.EndOfExclusive, SystemKind.TimingClock,
                        SystemKind.Start, SystemKind.Continue, SystemKind.Stop, SystemKind.ActiveSensing, SystemKind.Reset => unreachable,
                    };

                    stream.state = State.Status;
                    return Message{
                        .System = system
                    };
                },
                State.SystemValue2 => |msg| {
                    const value = math.cast(u7, b) catch return error.InvalidMessage;
                    const system = switch (msg.kind) {
                        SystemKind.SongPositionPointer => Message.System{
                            .SongPositionPointer = u14(msg.values[0]) | u14(value) << 7,
                        },

                        SystemKind.MidiTimeCodeQuarterFrame, SystemKind.SongSelect,
                        SystemKind.SystemExclusive, SystemKind.TuneRequest, SystemKind.EndOfExclusive, SystemKind.TimingClock,
                        SystemKind.Start, SystemKind.Continue, SystemKind.Stop, SystemKind.ActiveSensing, SystemKind.Reset => unreachable,
                    };

                    stream.state = State.Status;
                    return Message{
                        .System = system
                    };
                },

                State.SystemExclusive => |msg| {
                    if (b & 0x80 == 1) {
                        if (b != @enumToInt(SystemKind.EndOfExclusive))
                            return error.InvalidMessage;

                        stream.state = State.Status;
                        return Message{
                            .System = Message.System.EndOfExclusive,
                        };
                    }

                    // Just eat all values in the system exclusive message
                    // and let the feeder be responisble for the bytes passed in.
                    return null;
                },

            }
        }
    }
};

fn messageEql(a: Message, b: Message) bool {
    const MessageTag = @TagType(Message);
    if (MessageTag(a) != MessageTag(b))
        return false;

    switch (a) {
        MessageTag.Channel => |a_channel| {
            const ChannelKindTag = @TagType(Message.Channel.Kind);
            const b_channel = b.Channel;
            if (a_channel.channel != b_channel.channel)
                return false;
            if (ChannelKindTag(a_channel.kind) != ChannelKindTag(b_channel.kind))
                return false;

            switch (a_channel.kind) {
                Message.Channel.Kind.NoteOff, Message.Channel.Kind.NoteOn => {
                    var a_note: Message.Channel.Note = undefined;
                    var b_note: Message.Channel.Note = undefined;
                    switch (a_channel.kind) {
                        Message.Channel.Kind.NoteOff => {
                            a_note = a_channel.kind.NoteOff;
                            b_note = b_channel.kind.NoteOff;
                        },
                        Message.Channel.Kind.NoteOn => {
                            a_note = a_channel.kind.NoteOn;
                            b_note = b_channel.kind.NoteOn;
                        },
                        else => unreachable,
                    }

                    return a_note.note == b_note.note and
                        a_note.velocity == b_note.velocity;
                },
                Message.Channel.Kind.PolyphonicKeyPressure => |a_pressure| {
                    const b_pressure = b_channel.kind.PolyphonicKeyPressure;
                    return a_pressure.note == b_pressure.note and
                        a_pressure.pressure == b_pressure.pressure;
                },
                Message.Channel.Kind.ControlChange => |a_change| {
                    const b_change = b_channel.kind.ControlChange;
                    return a_change.controller == b_change.controller and
                        a_change.value == b_change.value;
                },
                Message.Channel.Kind.ProgramChange => |a_change| {
                    const b_change = b_channel.kind.ProgramChange;
                    return a_change == b_change;
                },
                Message.Channel.Kind.ChannelPressure => |a_pressure| {
                    const b_pressure = b_channel.kind.ChannelPressure;
                    return a_pressure == b_pressure;
                },
                Message.Channel.Kind.PitchBendChange => |a_change| {
                    const b_change = b_channel.kind.ProgramChange;
                    return a_change == b_change;
                },
            }
        },
        MessageTag.System => |a_sys| {
            const SystemTag = @TagType(Message.System);
            const b_sys = b.System;
            if (SystemTag(a_sys) != SystemTag(b_sys))
                return false;

            switch (a_sys) {
                SystemTag.SystemExclusive => |a_msg| {
                    const b_msg = b_sys.SystemExclusive;
                    return mem.eql(u7, a_msg, b_msg);
                },
                SystemTag.MidiTimeCodeQuarterFrame => |a_frame| {
                    const b_frame = b_sys.MidiTimeCodeQuarterFrame;
                    return a_frame.messageType == b_frame.messageType and
                        a_frame.values == b_frame.values;
                },
                SystemTag.SongPositionPointer => |a_pos| {
                    const b_pos = b_sys.SongPositionPointer;
                    return a_pos == b_pos;
                },
                SystemTag.SongSelect => |a_select| {
                    const b_select = b_sys.SongSelect;
                    return a_select == b_select;
                },
                SystemTag.TuneRequest => return true,
                SystemTag.EndOfExclusive => return true,
                SystemTag.TimingClock => return true,
                SystemTag.Start => return true,
                SystemTag.Continue => return true,
                SystemTag.Stop => return true,
                SystemTag.ActiveSensing => return true,
                SystemTag.Reset => return true,
            }
        },
    }
}

fn testMessageStream(bytes: []const u8, results: []const Message) void {
    var next_message: usize = 0;
    var i: usize = 0;
    var stream = MessageStream.init();
    while (i < bytes.len) : (i += 1) {
        if (stream.feed(bytes[i]) catch unreachable) |actual| {
            const expected = results[next_message];
            next_message += 1;

            debug.assert(messageEql(expected, actual));
            if (next_message == results.len)
                break;
        }
    }

    debug.assert(next_message == results.len);
    debug.assert(i == bytes.len);
}

test "midi.message.MessageStream: NoteOff" {
    testMessageStream(
        "\x80\x00\x00" ++
        "\x8F\x7F\x7F",
        []Message{
            Message{ .Channel = Message.Channel{
                .channel = 0x0,
                .kind = Message.Channel.Kind{ .NoteOff = Message.Channel.Note{
                    .note = 0x00,
                    .velocity = 0x00,
                }}
            }},
            Message{ .Channel = Message.Channel{
                .channel = 0xF,
                .kind = Message.Channel.Kind{ .NoteOff = Message.Channel.Note{
                    .note = 0x7F,
                    .velocity = 0x7F,
                }}
            }},
        }
    );
}

test "midi.message.MessageStream: NoteOn" {
    testMessageStream(
        "\x90\x00\x00" ++
        "\x9F\x7F\x7F",
        []Message{
            Message{ .Channel = Message.Channel{
                .channel = 0x0,
                .kind = Message.Channel.Kind{ .NoteOn = Message.Channel.Note{
                    .note = 0x00,
                    .velocity = 0x00,
                }}
            }},
            Message{ .Channel = Message.Channel{
                .channel = 0xF,
                .kind = Message.Channel.Kind{ .NoteOn = Message.Channel.Note{
                    .note = 0x7F,
                    .velocity = 0x7F,
                }}
            }},
        }
    );
}

test "midi.message.MessageStream: PolyphonicKeyPressure" {
    testMessageStream(
        "\xA0\x00\x00" ++
        "\xAF\x7F\x7F",
        []Message{
            Message{ .Channel = Message.Channel{
                .channel = 0x0,
                .kind = Message.Channel.Kind{ .PolyphonicKeyPressure = Message.Channel.PolyphonicKeyPressure{
                    .note = 0x00,
                    .pressure = 0x00,
                }}
            }},
            Message{ .Channel = Message.Channel{
                .channel = 0xF,
                .kind = Message.Channel.Kind{ .PolyphonicKeyPressure = Message.Channel.PolyphonicKeyPressure{
                    .note = 0x7F,
                    .pressure = 0x7F,
                }}
            }},
        }
    );
}

test "midi.message.MessageStream: ProgramChange" {
    testMessageStream(
        "\xB0\x00" ++
        "\xBF\x7F",
        []Message{
            Message{ .Channel = Message.Channel{
                .channel = 0x0,
                .kind = Message.Channel.Kind{ .ProgramChange = 0x00 },
            }},
            Message{ .Channel = Message.Channel{
                .channel = 0xF,
                .kind = Message.Channel.Kind{ .ProgramChange = 0x7F },
            }},
        }
    );
}

test "midi.message.MessageStream: ControlChange" {
    testMessageStream(
        "\xC0\x00" ++
        "\xCF\x7F",
        []Message{
            Message{ .Channel = Message.Channel{
                .channel = 0x0,
                .kind = Message.Channel.Kind{ .ProgramChange = 0x00 },
            }},
            Message{ .Channel = Message.Channel{
                .channel = 0xF,
                .kind = Message.Channel.Kind{ .ProgramChange = 0x7F },
            }},
        }
    );
}

test "midi.message.MessageStream: ChannelPressure" {
    testMessageStream(
        "\xD0\x00" ++
        "\xDF\x7F",
        []Message{
            Message{ .Channel = Message.Channel{
                .channel = 0x0,
                .kind = Message.Channel.Kind{ .ChannelPressure = 0x00 },
            }},
            Message{ .Channel = Message.Channel{
                .channel = 0xF,
                .kind = Message.Channel.Kind{ .ChannelPressure = 0x7F },
            }},
        }
    );
}

test "midi.message.MessageStream: PitchBendChange" {
    testMessageStream(
        "\xE0\x00\x00" ++
        "\x7F\x7F\x7F",
        []Message{
            Message{ .Channel = Message.Channel{
                .channel = 0x0,
                .kind = Message.Channel.Kind{ .PitchBendChange = 0x00 },
            }},
            Message{ .Channel = Message.Channel{
                .channel = 0xF,
                .kind = Message.Channel.Kind{ .PitchBendChange = 0x0FFF },
            }},
        }
    );
}
