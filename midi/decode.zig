const std = @import("std");
const midi = @import("../midi.zig");

const debug = std.debug;
const math = std.math;
const mem = std.mem;
const io = std.io;

const decode = @This();

fn statusByte(b: u8) ?u7 {
    if (@truncate(u1, b >> 7) != 0)
        return @truncate(u7, b);

    return null;
}

fn readDataByte(stream: anytype) !u7 {
    return math.cast(u7, try stream.readByte()) catch return error.InvalidDataByte;
}

pub fn message(stream: anytype, last_message: ?midi.Message) !midi.Message {
    var first_byte: ?u8 = try stream.readByte();
    const status_byte = if (statusByte(first_byte.?)) |status_byte| blk: {
        first_byte = null;
        break :blk status_byte;
    } else if (last_message) |m| blk: {
        if (m.channel() == null)
            return error.InvalidMessage;

        break :blk m.status;
    } else return error.InvalidMessage;

    const kind = @truncate(u3, status_byte >> 4);
    const channel = @truncate(u4, status_byte);
    switch (kind) {
        0x0, 0x1, 0x2, 0x3, 0x6 => return midi.Message{
            .status = status_byte,
            .values = [2]u7{
                math.cast(u7, first_byte orelse try stream.readByte()) catch return error.InvalidDataByte,
                try readDataByte(stream),
            },
        },
        0x4, 0x5 => return midi.Message{
            .status = status_byte,
            .values = [2]u7{
                math.cast(u7, first_byte orelse try stream.readByte()) catch return error.InvalidDataByte,
                0,
            },
        },
        0x7 => {
            debug.assert(first_byte == null);
            switch (channel) {
                0x0, 0x6, 0x07, 0x8, 0xA, 0xB, 0xC, 0xE, 0xF => return midi.Message{
                    .status = status_byte,
                    .values = [2]u7{ 0, 0 },
                },
                0x1, 0x3 => return midi.Message{
                    .status = status_byte,
                    .values = [2]u7{
                        try readDataByte(stream),
                        0,
                    },
                },
                0x2 => return midi.Message{
                    .status = status_byte,
                    .values = [2]u7{
                        try readDataByte(stream),
                        try readDataByte(stream),
                    },
                },

                // Undefined
                0x4, 0x5, 0x9, 0xD => return midi.Message{
                    .status = status_byte,
                    .values = [2]u7{ 0, 0 },
                },
            }
        },
    }
}

pub fn chunk(stream: anytype) !midi.file.Chunk {
    var buf: [8]u8 = undefined;
    try stream.readNoEof(&buf);
    return decode.chunkFromBytes(buf);
}

pub fn chunkFromBytes(bytes: [8]u8) midi.file.Chunk {
    return midi.file.Chunk{
        .kind = bytes[0..4].*,
        .len = mem.readIntBig(u32, bytes[4..8]),
    };
}

pub fn fileHeader(stream: anytype) !midi.file.Header {
    var buf: [14]u8 = undefined;
    try stream.readNoEof(&buf);
    return decode.fileHeaderFromBytes(buf);
}

pub fn fileHeaderFromBytes(bytes: [14]u8) !midi.file.Header {
    const _chunk = decode.chunkFromBytes(bytes[0..8].*);
    if (!mem.eql(u8, &_chunk.kind, midi.file.Chunk.file_header))
        return error.InvalidFileHeader;
    if (_chunk.len < midi.file.Header.size)
        return error.InvalidFileHeader;

    return midi.file.Header{
        .chunk = _chunk,
        .format = mem.readIntBig(u16, bytes[8..10]),
        .tracks = mem.readIntBig(u16, bytes[10..12]),
        .division = mem.readIntBig(u16, bytes[12..14]),
    };
}

pub fn int(stream: anytype) !u28 {
    var res: u28 = 0;
    while (true) {
        const b = try stream.readByte();
        const is_last = @truncate(u1, b >> 7) == 0;
        const value = @truncate(u7, b);
        res = try math.mul(u28, res, math.maxInt(u7) + 1);
        res = try math.add(u28, res, value);

        if (is_last)
            return res;
    }
}

pub fn metaEvent(stream: anytype) !midi.file.MetaEvent {
    return midi.file.MetaEvent{
        .kind_byte = try stream.readByte(),
        .len = try decode.int(stream),
    };
}

pub fn trackEvent(stream: anytype, last_event: ?midi.file.TrackEvent) !midi.file.TrackEvent {
    var peek_stream = io.peekStream(1, stream);
    var in_stream = peek_stream.inStream();

    const delta_time = try decode.int(&in_stream);
    const first_byte = try in_stream.readByte();
    if (first_byte == 0xFF) {
        return midi.file.TrackEvent{
            .delta_time = delta_time,
            .kind = midi.file.TrackEvent.Kind{ .MetaEvent = try decode.metaEvent(&in_stream) },
        };
    }

    const last_midi_event = if (last_event) |e| switch (e.kind) {
        .MidiEvent => |m| m,
        .MetaEvent => null,
    } else null;

    peek_stream.putBackByte(first_byte) catch unreachable;
    return midi.file.TrackEvent{
        .delta_time = delta_time,
        .kind = midi.file.TrackEvent.Kind{ .MidiEvent = try decode.message(&in_stream, last_midi_event) },
    };
}

/// Decodes a midi file from a stream. Caller owns the returned value
///  (see: `midi.File.deinit`).
pub fn file(stream: anytype, allocator: *mem.Allocator) !midi.File {
    var chunks = std.ArrayList(midi.File.FileChunk).init(allocator);
    errdefer {
        (midi.File{
            .format = 0,
            .division = 0,
            .chunks = chunks.toOwnedSlice(),
        }).deinit(allocator);
    }

    const header = try decode.fileHeader(stream);
    const header_data = try allocator.alloc(u8, header.chunk.len - midi.file.Header.size);
    errdefer allocator.free(header_data);

    try stream.readNoEof(header_data);
    while (true) {
        const c = decode.chunk(stream) catch |err| switch (err) {
            error.EndOfStream => break,
            else => |e| return e,
        };

        const chunk_bytes = try allocator.alloc(u8, c.len);
        errdefer allocator.free(chunk_bytes);
        try stream.readNoEof(chunk_bytes);
        try chunks.append(.{
            .kind = c.kind,
            .bytes = chunk_bytes,
        });
    }

    return midi.File{
        .format = header.format,
        .division = header.division,
        .header_data = header_data,
        .chunks = chunks.toOwnedSlice(),
    };
}
