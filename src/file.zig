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
