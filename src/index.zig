const std = @import("std");

const mem = std.mem;

pub const decode = @import("decode.zig");
pub const file = @import("file.zig");

test "midi" {
    _ = @import("test.zig");
    _ = decode;
    _ = file;
}

pub const Message = struct {
    status: u7,
    values: [2]u7,

    pub fn kind(message: Message) Kind {
        const _kind = @truncate(u3, message.status >> 4);
        const _channel = @truncate(u4, message.status);
        return switch (_kind) {
            0x0 => Kind.NoteOff,
            0x1 => Kind.NoteOn,
            0x2 => Kind.PolyphonicKeyPressure,
            0x3 => Kind.ControlChange,
            0x4 => Kind.ProgramChange,
            0x5 => Kind.ChannelPressure,
            0x6 => Kind.PitchBendChange,
            0x7 => switch (_channel) {
                0x0 => Kind.ExclusiveStart,
                0x1 => Kind.MidiTimeCodeQuarterFrame,
                0x2 => Kind.SongPositionPointer,
                0x3 => Kind.SongSelect,
                0x6 => Kind.TuneRequest,
                0x7 => Kind.ExclusiveEnd,
                0x8 => Kind.TimingClock,
                0xA => Kind.Start,
                0xB => Kind.Continue,
                0xC => Kind.Stop,
                0xE => Kind.ActiveSensing,
                0xF => Kind.Reset,

                0x4, 0x5, 0x9, 0xD => Kind.Undefined,
            },
        };
    }

    pub fn channel(message: Message) ?u4 {
        const _kind = message.kind();
        const _channel = @truncate(u4, message.status);
        switch (_kind) {
            // Channel events
            .NoteOff, .NoteOn, .PolyphonicKeyPressure, .ControlChange, .ProgramChange, .ChannelPressure, .PitchBendChange => return _channel,

            // System events
            .ExclusiveStart, .MidiTimeCodeQuarterFrame, .SongPositionPointer, .SongSelect, .TuneRequest, .ExclusiveEnd, .TimingClock, .Start, .Continue, .Stop, .ActiveSensing, .Reset => return null,

            .Undefined => return null,
        }
    }

    pub const Kind = enum {
        // Channel events
        NoteOff,
        NoteOn,
        PolyphonicKeyPressure,
        ControlChange,
        ProgramChange,
        ChannelPressure,
        PitchBendChange,

        // System events
        ExclusiveStart,
        MidiTimeCodeQuarterFrame,
        SongPositionPointer,
        SongSelect,
        TuneRequest,
        ExclusiveEnd,
        TimingClock,
        Start,
        Continue,
        Stop,
        ActiveSensing,
        Reset,

        Undefined,
    };
};
