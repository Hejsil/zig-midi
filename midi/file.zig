const decode = @import("./decode.zig");
const midi = @import("../midi.zig");
const std = @import("std");

const io = std.io;
const mem = std.mem;

test {
    std.testing.refAllDecls(@This());
}

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

pub const File = struct {
    format: u16,
    division: u16,
    header_data: []const u8 = &[_]u8{},
    chunks: []const FileChunk = &[_]FileChunk{},

    pub const FileChunk = struct {
        kind: [4]u8,
        bytes: []const u8,
    };

    pub fn deinit(file: File, allocator: mem.Allocator) void {
        for (file.chunks) |chunk|
            allocator.free(chunk.bytes);
        allocator.free(file.chunks);
        allocator.free(file.header_data);
    }
};

pub const TrackIterator = struct {
    stream: io.FixedBufferStream([]const u8),
    last_event: ?TrackEvent = null,

    pub fn init(bytes: []const u8) TrackIterator {
        return .{ .stream = io.fixedBufferStream(bytes) };
    }

    pub const Result = struct {
        event: TrackEvent,
        data: []const u8,
    };

    pub fn next(it: *TrackIterator) ?Result {
        const s = it.stream.inStream();
        const event = decode.trackEvent(s, it.last_event) catch return null;
        it.last_event = event;

        const start = it.stream.pos;

        const end = switch (event.kind) {
            .MetaEvent => |meta_event| blk: {
                it.stream.pos += meta_event.len;
                break :blk it.stream.pos;
            },
            .MidiEvent => |midi_event| blk: {
                if (midi_event.kind() == .ExclusiveStart) {
                    while ((try s.readByte()) != 0xF7) {}
                    break :blk it.stream.pos - 1;
                }
                break :blk it.stream.pos;
            },
        };

        return Result{
            .event = event,
            .data = s.buffer[start..end],
        };
    }
};
