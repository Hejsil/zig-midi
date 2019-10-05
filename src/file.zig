const midi = @import("index.zig");
const std = @import("std");

const mem = std.mem;

pub const Header = struct {
    format: u16,
    tracks: u16,
    division: u16,
};

pub const Chunk = struct {
    kind: [4]u8,
    len: u32,
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
        Undefined: void,
        MidiEvent: ChannelMessage,
        SystemExclusiveF0: SystemExclusive,
        SystemExclusiveF7: SystemExclusive,
        MetaEvent: MetaEvent,

        /// When used with the streaming API, SystemExclusive is a single
        /// event and contains no data. It is the feeders responsibility
        /// to keep track of the data after the event.
        /// With the none streaming API, the data field will contain the data
        /// after the event. data.len should always be the same as len using
        /// this API.
        pub const SystemExclusive = struct {
            len: u28,
            data: []u8,
        };
    };
};
