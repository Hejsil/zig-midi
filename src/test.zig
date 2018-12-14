const std = @import("std");
const midi = @import("index.zig");

const debug = std.debug;
const mem = std.mem;

const decode = midi.decode;
const file = midi.file;

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

test "midi.decode.SystemMessageDecoder" {
    try testSystemMessageDecoder("\xF0\x01\x0F\x7F\xF7", []midi.SystemMessage{
        midi.SystemMessage{ .ExclusiveStart = midi.SystemMessage.ExclusiveStart{ .data = "" } },
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
        midi.Message{ .System = midi.SystemMessage{ .ExclusiveStart = midi.SystemMessage.ExclusiveStart{ .data = "" } } },
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

test "decode.chunkInfo" {
    debug.assert(decode.chunkInfo("abcd\x00\x00\x00\x04").equal(midi.file.Chunk.Info{
        .kind = "abcd",
        .len = 0x04,
    }));
    debug.assert(decode.chunkInfo("efgh\x00\x00\x04\x00").equal(midi.file.Chunk.Info{
        .kind = "efgh",
        .len = 0x0400,
    }));
    debug.assert(decode.chunkInfo("ijkl\x00\x04\x00\x00").equal(midi.file.Chunk.Info{
        .kind = "ijkl",
        .len = 0x040000,
    }));
    debug.assert(decode.chunkInfo("mnop\x04\x00\x00\x00").equal(midi.file.Chunk.Info{
        .kind = "mnop",
        .len = 0x04000000,
    }));
}

test "decode.fileHeader" {
    debug.assert((try decode.fileHeader("MThd\x00\x00\x00\x06\x00\x00\x00\x01\x01\x10")).equal(midi.file.Header{
        .format = midi.file.Header.Format.SingleMultiChannelTrack,
        .tracks = 0x0001,
        .division = midi.file.Header.Division{ .TicksPerQuarterNote = 0x0110 },
    }));
    debug.assert((try decode.fileHeader("MThd\x00\x00\x00\x06\x00\x01\x01\x01\x01\x10")).equal(midi.file.Header{
        .format = midi.file.Header.Format.ManySimultaneousTracks,
        .tracks = 0x0101,
        .division = midi.file.Header.Division{ .TicksPerQuarterNote = 0x0110 },
    }));
    debug.assert((try decode.fileHeader("MThd\x00\x00\x00\x06\x00\x02\x01\x01\x01\x10")).equal(midi.file.Header{
        .format = midi.file.Header.Format.ManyIndependentTracks,
        .tracks = 0x0101,
        .division = midi.file.Header.Division{ .TicksPerQuarterNote = 0x0110 },
    }));
    debug.assert((try decode.fileHeader("MThd\x00\x00\x00\x06\x00\x00\x00\x01\xFF\x10")).equal(midi.file.Header{
        .format = midi.file.Header.Format.SingleMultiChannelTrack,
        .tracks = 0x0001,
        .division = midi.file.Header.Division{
            .SubdivisionsOfSecond = midi.file.Header.Division.SubdivisionsOfSecond{
                .smpte_format = -1,
                .ticks_per_frame = 0x10,
            },
        },
    }));
    debug.assert((try decode.fileHeader("MThd\x00\x00\x00\x06\x00\x01\x01\x01\xFF\x10")).equal(midi.file.Header{
        .format = midi.file.Header.Format.ManySimultaneousTracks,
        .tracks = 0x0101,
        .division = midi.file.Header.Division{
            .SubdivisionsOfSecond = midi.file.Header.Division.SubdivisionsOfSecond{
                .smpte_format = -1,
                .ticks_per_frame = 0x10,
            },
        },
    }));
    debug.assert((try decode.fileHeader("MThd\x00\x00\x00\x06\x00\x02\x01\x01\xFF\x10")).equal(midi.file.Header{
        .format = midi.file.Header.Format.ManyIndependentTracks,
        .tracks = 0x0101,
        .division = midi.file.Header.Division{
            .SubdivisionsOfSecond = midi.file.Header.Division.SubdivisionsOfSecond{
                .smpte_format = -1,
                .ticks_per_frame = 0x10,
            },
        },
    }));

    debug.assertError(decode.fileHeader("Mthd\x00\x00\x00\x06\x00\x00\x00\x01\x01\x10"), error.InvalidHeaderKind);
    debug.assertError(decode.fileHeader("MThd\x00\x00\x00\x05\x00\x00\x00\x01\x01\x10"), error.InvalidHeaderLength);
    debug.assertError(decode.fileHeader("MThd\x00\x00\x00\x06\x00\x03\x00\x01\x01\x10"), error.InvalidHeaderFormat);
    debug.assertError(decode.fileHeader("MThd\x00\x00\x00\x06\x00\x00\x00\x02\x01\x10"), error.InvalidHeaderNumberOfTracks);
}

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

test "decode.MetaEventDecoder" {
    try testMetaEventDecoder("\xFF\x00\x00" ++
        "\xFF\x00\x02\x01\x02", []midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.SequenceNumber,
            .len = 0,
            .data = "\x01"[0..].ptr,
        },
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.SequenceNumber,
            .len = 2,
            .data = "\x01\x02"[0..].ptr,
        },
    });
    try testMetaEventDecoder("\xFF\x01\x00" ++
        "\xFF\x01\x02\x01\x02", []midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.TextEvent,
            .len = 0,
            .data = "\x01"[0..].ptr,
        },
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.TextEvent,
            .len = 2,
            .data = "\x01\x02"[0..].ptr,
        },
    });
    try testMetaEventDecoder("\xFF\x02\x00" ++
        "\xFF\x02\x02\x01\x02", []midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.CopyrightNotice,
            .len = 0,
            .data = "\x01"[0..].ptr,
        },
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.CopyrightNotice,
            .len = 2,
            .data = "\x01\x02"[0..].ptr,
        },
    });
    try testMetaEventDecoder("\xFF\x03\x00" ++
        "\xFF\x03\x02\x01\x02", []midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.TrackName,
            .len = 0,
            .data = "\x01"[0..].ptr,
        },
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.TrackName,
            .len = 2,
            .data = "\x01\x02"[0..].ptr,
        },
    });
    try testMetaEventDecoder("\xFF\x04\x00" ++
        "\xFF\x04\x02\x01\x02", []midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.InstrumentName,
            .len = 0,
            .data = "\x01"[0..].ptr,
        },
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.InstrumentName,
            .len = 2,
            .data = "\x01\x02"[0..].ptr,
        },
    });
    try testMetaEventDecoder("\xFF\x05\x00" ++
        "\xFF\x05\x02\x01\x02", []midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.Luric,
            .len = 0,
            .data = "\x01"[0..].ptr,
        },
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.Luric,
            .len = 2,
            .data = "\x01\x02"[0..].ptr,
        },
    });
    try testMetaEventDecoder("\xFF\x06\x00" ++
        "\xFF\x06\x02\x01\x02", []midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.Marker,
            .len = 0,
            .data = "\x01"[0..].ptr,
        },
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.Marker,
            .len = 2,
            .data = "\x01\x02"[0..].ptr,
        },
    });
    try testMetaEventDecoder("\xFF\x20\x00" ++
        "\xFF\x20\x02\x01\x02", []midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.MidiChannelPrefix,
            .len = 0,
            .data = "\x01"[0..].ptr,
        },
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.MidiChannelPrefix,
            .len = 2,
            .data = "\x01\x02"[0..].ptr,
        },
    });
    try testMetaEventDecoder("\xFF\x2F\x00" ++
        "\xFF\x2F\x02\x01\x02", []midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.EndOfTrack,
            .len = 0,
            .data = "\x01"[0..].ptr,
        },
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.EndOfTrack,
            .len = 2,
            .data = "\x01\x02"[0..].ptr,
        },
    });
    try testMetaEventDecoder("\xFF\x2F\x00" ++
        "\xFF\x2F\x02\x01\x02", []midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.EndOfTrack,
            .len = 0,
            .data = "\x01"[0..].ptr,
        },
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.EndOfTrack,
            .len = 2,
            .data = "\x01\x02"[0..].ptr,
        },
    });
    try testMetaEventDecoder("\xFF\x51\x00" ++
        "\xFF\x51\x02\x01\x02", []midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.SetTempo,
            .len = 0,
            .data = "\x01"[0..].ptr,
        },
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.SetTempo,
            .len = 2,
            .data = "\x01\x02"[0..].ptr,
        },
    });
    try testMetaEventDecoder("\xFF\x54\x00" ++
        "\xFF\x54\x02\x01\x02", []midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.SmpteOffset,
            .len = 0,
            .data = "\x01"[0..].ptr,
        },
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.SmpteOffset,
            .len = 2,
            .data = "\x01\x02"[0..].ptr,
        },
    });
    try testMetaEventDecoder("\xFF\x58\x00" ++
        "\xFF\x58\x02\x01\x02", []midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.TimeSignature,
            .len = 0,
            .data = "\x01"[0..].ptr,
        },
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.TimeSignature,
            .len = 2,
            .data = "\x01\x02"[0..].ptr,
        },
    });
    try testMetaEventDecoder("\xFF\x59\x00" ++
        "\xFF\x59\x02\x01\x02", []midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.KeySignature,
            .len = 0,
            .data = "\x01"[0..].ptr,
        },
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.KeySignature,
            .len = 2,
            .data = "\x01\x02"[0..].ptr,
        },
    });
    try testMetaEventDecoder("\xFF\x7F\x00" ++
        "\xFF\x7F\x02\x01\x02", []midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.SequencerSpecificMetaEvent,
            .len = 0,
            .data = "\x01"[0..].ptr,
        },
        midi.file.MetaEvent{
            .kind = midi.file.MetaEvent.Kind.SequencerSpecificMetaEvent,
            .len = 2,
            .data = "\x01\x02"[0..].ptr,
        },
    });
}

fn testChannelMessageDecoder(bytes: []const u8, results: []const midi.ChannelMessage) !void {
    var next_message: usize = 0;
    var iter = decode.ChannelMessageDecoder.init(bytes);
    while (try iter.next()) |actual| : (next_message += 1) {
        const expected = results[next_message];
        debug.assert(expected.equal(actual));
    }

    debug.assert(next_message == results.len);
    debug.assert((try iter.next()) == null);
}

fn testSystemMessageDecoder(bytes: []const u8, results: []const midi.SystemMessage) !void {
    var next_message: usize = 0;
    var iter = decode.SystemMessageDecoder.init(bytes);
    while (try iter.next()) |actual| : (next_message += 1) {
        const expected = results[next_message];
        debug.assert(expected.equal(actual));
    }

    debug.assert(next_message == results.len);
    debug.assert((try iter.next()) == null);
}

fn testMessageDecoder(bytes: []const u8, results: []const midi.Message) !void {
    var next_message: usize = 0;
    var iter = decode.MessageDecoder.init(bytes);
    while (try iter.next()) |actual| : (next_message += 1) {
        const expected = results[next_message];
        debug.assert(expected.equal(actual));
    }

    debug.assert(next_message == results.len);
    debug.assert((try iter.next()) == null);
}

fn testMetaEventDecoder(bytes: []const u8, results: []const midi.file.MetaEvent) !void {
    var next_event: usize = 0;
    var iter = decode.MetaEventDecoder.init(bytes);
    while (try iter.next()) |actual| : (next_event += 1) {
        const expected = results[next_event];
        debug.assert(expected.equal(actual));
    }

    debug.assert(next_event == results.len);
    debug.assert((try iter.next()) == null);
}

fn testChunkIterator(bytes: []const u8, results: []const midi.file.Chunk) !void {
    var next_chunk: usize = 0;
    var iter = decode.ChunkIterator.init(bytes);
    while (try iter.next()) |actual| : (next_chunk += 1) {
        const expected = results[next_chunk];
        debug.assert(expected.equal(actual));
    }

    debug.assert(next_chunk == results.len);
    debug.assert((try iter.next()) == null);
}

fn testStreamingVariableLengthIntDecoder(bytes: []const u8, results: []const u28) !void {
    var decoder = decode.StreamingVariableLengthIntDecoder.init();
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
