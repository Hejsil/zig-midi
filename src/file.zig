const midi = @import("../midi.zig");
const std = @import("std");

pub const Header = struct {
    chunk: Chunk,
    format: u16,
    tracks: u16,
    division: u16,

    pub const size = 6;
};

pub const Chunk = struct {
    kind: [4]u8,
    len: u32,

    pub const file_header = "MThd";
    pub const track_header = "MTrk";
};

pub const MetaEvent = struct {
    kind_byte: u8,
    len: u28,

    pub fn kind(event: MetaEvent) Kind {
        return switch (event.kind_byte) {
            0x00 => .SequenceNumber,
            0x01 => .TextEvent,
            0x02 => .CopyrightNotice,
            0x03 => .TrackName,
            0x04 => .InstrumentName,
            0x05 => .Luric,
            0x06 => .Marker,
            0x20 => .MidiChannelPrefix,
            0x2F => .EndOfTrack,
            0x51 => .SetTempo,
            0x54 => .SmpteOffset,
            0x58 => .TimeSignature,
            0x59 => .KeySignature,
            0x7F => .SequencerSpecificMetaEvent,
            else => .Undefined,
        };
    }

    pub const Kind = enum {
        Undefined,
        SequenceNumber,
        TextEvent,
        CopyrightNotice,
        TrackName,
        InstrumentName,
        Luric,
        Marker,
        CuePoint,
        MidiChannelPrefix,
        EndOfTrack,
        SetTempo,
        SmpteOffset,
        TimeSignature,
        KeySignature,
        SequencerSpecificMetaEvent,
    };
};

pub const TrackEvent = struct {
    delta_time: u28,
    kind: Kind,

    pub const Kind = union(enum) {
        MidiEvent: midi.Message,
        MetaEvent: MetaEvent,
    };
};
