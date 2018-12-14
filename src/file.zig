const midi = @import("index.zig");
const std = @import("std");

const mem = std.mem;

pub const Header = struct {
    format: Format,
    tracks: u16,
    division: Division,

    pub const Division = union(enum) {
        TicksPerQuarterNote: u15,
        SubdivisionsOfSecond: SubdivisionsOfSecond,

        const Kind = @TagType(Division);

        pub const SubdivisionsOfSecond = struct {
            smpte_format: i8,
            ticks_per_frame: u8,
        };

        pub fn equal(a: Division, b: Division) bool {
            if (Division.Kind(a) != Division.Kind(b))
                return false;
            switch (a) {
                Division.Kind.TicksPerQuarterNote => |a_ticks| {
                    const b_ticks = b.TicksPerQuarterNote;
                    return a_ticks == b_ticks;
                },
                Division.Kind.SubdivisionsOfSecond => |a_subs| {
                    const b_subs = b.SubdivisionsOfSecond;
                    return a_subs.smpte_format == b_subs.smpte_format and
                        a_subs.ticks_per_frame == b_subs.ticks_per_frame;
                },
            }
        }
    };

    pub const Format = enum {
        SingleMultiChannelTrack = 0,
        ManySimultaneousTracks = 1,
        ManyIndependentTracks = 2,
    };

    pub fn equal(a: Header, b: Header) bool {
        return a.format == b.format and
            a.tracks == b.tracks and
            a.division.equal(b.division);
    }
};

pub const Chunk = struct {
    info: Info,
    data: []const u8,

    pub fn equal(a: Chunk, b: Chunk) bool {
        return mem.eql(u8, a.data, b.data) and
            a.info.equal(b.info);
    }

    pub const Info = struct {
        kind: [4]u8,
        len: u32,

        pub fn equal(a: Info, b: Info) bool {
            return mem.eql(u8, a.kind, b.kind) and
                a.len == b.len;
        }
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

/// Events are variable length. This means, that when using the streaming
/// API these events data field will always be null. It is the feeders
/// responsability to keep track of the bytes the event contains.
/// Using the none streaming API, the data field will always point to data
/// and never be null. Use the len field to slice the data.
pub const MetaEvent = struct {
    kind: Kind,
    len: u28,
    data: ?[*]const u8,

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

    pub fn equal(a: MetaEvent, b: MetaEvent) bool {
        if (a.len != b.len)
            return false;
        if (a.kind != b.kind)
            return false;

        return (a.data != null and b.data != null and mem.eql(u8, a.data.?[0..a.len], b.data.?[0..b.len])) or
            a.data == null and b.data == null;
    }
};
