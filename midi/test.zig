const midi = @import("../midi.zig");
const std = @import("std");

const io = std.io;
const mem = std.mem;
const testing = std.testing;

const decode = midi.decode;
const encode = midi.encode;
const file = midi.file;

test {
    std.testing.refAllDecls(@This());
}

test "midi.decode/encode.message" {
    try testMessage("\x80\x00\x00" ++
        "\x7F\x7F" ++
        "\x8F\x7F\x7F", &[_]midi.Message{
        midi.Message{
            .status = 0x00,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x00,
            .values = [2]u7{ 0x7F, 0x7F },
        },
        midi.Message{
            .status = 0x0F,
            .values = [2]u7{ 0x7F, 0x7F },
        },
    });
    try testMessage("\x90\x00\x00" ++
        "\x7F\x7F" ++
        "\x9F\x7F\x7F", &[_]midi.Message{
        midi.Message{
            .status = 0x10,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x10,
            .values = [2]u7{ 0x7F, 0x7F },
        },
        midi.Message{
            .status = 0x1F,
            .values = [2]u7{ 0x7F, 0x7F },
        },
    });
    try testMessage("\xA0\x00\x00" ++
        "\x7F\x7F" ++
        "\xAF\x7F\x7F", &[_]midi.Message{
        midi.Message{
            .status = 0x20,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x20,
            .values = [2]u7{ 0x7F, 0x7F },
        },
        midi.Message{
            .status = 0x2F,
            .values = [2]u7{ 0x7F, 0x7F },
        },
    });
    try testMessage("\xB0\x00\x00" ++
        "\x77\x7F" ++
        "\xBF\x77\x7F", &[_]midi.Message{
        midi.Message{
            .status = 0x30,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x30,
            .values = [2]u7{ 0x77, 0x7F },
        },
        midi.Message{
            .status = 0x3F,
            .values = [2]u7{ 0x77, 0x7F },
        },
    });
    try testMessage("\xC0\x00" ++
        "\x7F" ++
        "\xCF\x7F", &[_]midi.Message{
        midi.Message{
            .status = 0x40,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x40,
            .values = [2]u7{ 0x7F, 0x0 },
        },
        midi.Message{
            .status = 0x4F,
            .values = [2]u7{ 0x7F, 0x0 },
        },
    });
    try testMessage("\xD0\x00" ++
        "\x7F" ++
        "\xDF\x7F", &[_]midi.Message{
        midi.Message{
            .status = 0x50,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x50,
            .values = [2]u7{ 0x7F, 0x0 },
        },
        midi.Message{
            .status = 0x5F,
            .values = [2]u7{ 0x7F, 0x0 },
        },
    });
    try testMessage("\xE0\x00\x00" ++
        "\x7F\x7F" ++
        "\xEF\x7F\x7F", &[_]midi.Message{
        midi.Message{
            .status = 0x60,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x60,
            .values = [2]u7{ 0x7F, 0x7F },
        },
        midi.Message{
            .status = 0x6F,
            .values = [2]u7{ 0x7F, 0x7F },
        },
    });
    try testMessage("\xF0\xF0", &[_]midi.Message{
        midi.Message{
            .status = 0x70,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x70,
            .values = [2]u7{ 0x0, 0x0 },
        },
    });
    try testMessage("\xF1\x00" ++
        "\xF1\x0F" ++
        "\xF1\x70" ++
        "\xF1\x7F", &[_]midi.Message{
        midi.Message{
            .status = 0x71,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x71,
            .values = [2]u7{ 0x0F, 0x0 },
        },
        midi.Message{
            .status = 0x71,
            .values = [2]u7{ 0x70, 0x0 },
        },
        midi.Message{
            .status = 0x71,
            .values = [2]u7{ 0x7F, 0x0 },
        },
    });
    try testMessage("\xF2\x00\x00" ++
        "\xF2\x7F\x7F", &[_]midi.Message{
        midi.Message{
            .status = 0x72,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x72,
            .values = [2]u7{ 0x7F, 0x7F },
        },
    });
    try testMessage("\xF3\x00" ++
        "\xF3\x7F", &[_]midi.Message{
        midi.Message{
            .status = 0x73,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x73,
            .values = [2]u7{ 0x7F, 0x0 },
        },
    });
    try testMessage("\xF6\xF6", &[_]midi.Message{
        midi.Message{
            .status = 0x76,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x76,
            .values = [2]u7{ 0x0, 0x0 },
        },
    });
    try testMessage("\xF7\xF7", &[_]midi.Message{
        midi.Message{
            .status = 0x77,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x77,
            .values = [2]u7{ 0x0, 0x0 },
        },
    });
    try testMessage("\xF8\xF8", &[_]midi.Message{
        midi.Message{
            .status = 0x78,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x78,
            .values = [2]u7{ 0x0, 0x0 },
        },
    });
    try testMessage("\xFA\xFA", &[_]midi.Message{
        midi.Message{
            .status = 0x7A,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x7A,
            .values = [2]u7{ 0x0, 0x0 },
        },
    });
    try testMessage("\xFB\xFB", &[_]midi.Message{
        midi.Message{
            .status = 0x7B,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x7B,
            .values = [2]u7{ 0x0, 0x0 },
        },
    });
    try testMessage("\xFC\xFC", &[_]midi.Message{
        midi.Message{
            .status = 0x7C,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x7C,
            .values = [2]u7{ 0x0, 0x0 },
        },
    });
    try testMessage("\xFE\xFE", &[_]midi.Message{
        midi.Message{
            .status = 0x7E,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x7E,
            .values = [2]u7{ 0x0, 0x0 },
        },
    });
    try testMessage("\xFF\xFF", &[_]midi.Message{
        midi.Message{
            .status = 0x7F,
            .values = [2]u7{ 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x7F,
            .values = [2]u7{ 0x0, 0x0 },
        },
    });
}

test "midi.decode/encode.chunk" {
    try testChunk("abcd\x00\x00\x00\x04".*, midi.file.Chunk{ .kind = "abcd".*, .len = 0x04 });
    try testChunk("efgh\x00\x00\x04\x00".*, midi.file.Chunk{ .kind = "efgh".*, .len = 0x0400 });
    try testChunk("ijkl\x00\x04\x00\x00".*, midi.file.Chunk{ .kind = "ijkl".*, .len = 0x040000 });
    try testChunk("mnop\x04\x00\x00\x00".*, midi.file.Chunk{ .kind = "mnop".*, .len = 0x04000000 });
}

test "midi.decode/encode.fileHeader" {
    try testFileHeader("MThd\x00\x00\x00\x06\x00\x00\x00\x01\x01\x10".*, midi.file.Header{
        .chunk = midi.file.Chunk{
            .kind = "MThd".*,
            .len = 6,
        },
        .format = 0,
        .tracks = 0x0001,
        .division = 0x0110,
    });
    try testFileHeader("MThd\x00\x00\x00\x06\x00\x01\x01\x01\x01\x10".*, midi.file.Header{
        .chunk = midi.file.Chunk{
            .kind = "MThd".*,
            .len = 6,
        },
        .format = 1,
        .tracks = 0x0101,
        .division = 0x0110,
    });
    try testFileHeader("MThd\x00\x00\x00\x06\x00\x02\x01\x01\x01\x10".*, midi.file.Header{
        .chunk = midi.file.Chunk{
            .kind = "MThd".*,
            .len = 6,
        },
        .format = 2,
        .tracks = 0x0101,
        .division = 0x0110,
    });
    try testFileHeader("MThd\x00\x00\x00\x06\x00\x00\x00\x01\xFF\x10".*, midi.file.Header{
        .chunk = midi.file.Chunk{
            .kind = "MThd".*,
            .len = 6,
        },
        .format = 0,
        .tracks = 0x0001,
        .division = 0xFF10,
    });
    try testFileHeader("MThd\x00\x00\x00\x06\x00\x01\x01\x01\xFF\x10".*, midi.file.Header{
        .chunk = midi.file.Chunk{
            .kind = "MThd".*,
            .len = 6,
        },
        .format = 1,
        .tracks = 0x0101,
        .division = 0xFF10,
    });
    try testFileHeader("MThd\x00\x00\x00\x06\x00\x02\x01\x01\xFF\x10".*, midi.file.Header{
        .chunk = midi.file.Chunk{
            .kind = "MThd".*,
            .len = 6,
        },
        .format = 2,
        .tracks = 0x0101,
        .division = 0xFF10,
    });

    try testing.expectError(error.InvalidFileHeader, decode.fileHeaderFromBytes("MThd\x00\x00\x00\x05\x00\x00\x00\x01\x01\x10".*));
}

test "midi.decode/encode.int" {
    try testInt("\x00" ++
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
        "\xFF\xFF\xFF\x7F", &[_]u28{
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

test "midi.decode/encode.metaEvent" {
    try testMetaEvent("\x00\x00" ++
        "\x00\x02", &[_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 0,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 0,
            .len = 2,
        },
    });
    try testMetaEvent("\x01\x00" ++
        "\x01\x02", &[_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 1,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 1,
            .len = 2,
        },
    });
    try testMetaEvent("\x02\x00" ++
        "\x02\x02", &[_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 2,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 2,
            .len = 2,
        },
    });
    try testMetaEvent("\x03\x00" ++
        "\x03\x02", &[_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 3,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 3,
            .len = 2,
        },
    });
    try testMetaEvent("\x04\x00" ++
        "\x04\x02", &[_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 4,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 4,
            .len = 2,
        },
    });
    try testMetaEvent("\x05\x00" ++
        "\x05\x02", &[_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 5,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 5,
            .len = 2,
        },
    });
    try testMetaEvent("\x06\x00" ++
        "\x06\x02", &[_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 6,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 6,
            .len = 2,
        },
    });
    try testMetaEvent("\x20\x00" ++
        "\x20\x02", &[_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 0x20,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 0x20,
            .len = 2,
        },
    });
    try testMetaEvent("\x2F\x00" ++
        "\x2F\x02", &[_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 0x2F,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 0x2F,
            .len = 2,
        },
    });
    try testMetaEvent("\x51\x00" ++
        "\x51\x02", &[_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 0x51,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 0x51,
            .len = 2,
        },
    });
    try testMetaEvent("\x54\x00" ++
        "\x54\x02", &[_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 0x54,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 0x54,
            .len = 2,
        },
    });
    try testMetaEvent("\x58\x00" ++
        "\x58\x02", &[_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 0x58,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 0x58,
            .len = 2,
        },
    });
    try testMetaEvent("\x59\x00" ++
        "\x59\x02", &[_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 0x59,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 0x59,
            .len = 2,
        },
    });
    try testMetaEvent("\x7F\x00" ++
        "\x7F\x02", &[_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 0x7F,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 0x7F,
            .len = 2,
        },
    });
}

test "midi.decode/encode.trackEvent" {
    try testTrackEvent("\x00\xFF\x00\x00" ++
        "\x00\xFF\x00\x02", &[_]midi.file.TrackEvent{
        midi.file.TrackEvent{
            .delta_time = 0,
            .kind = midi.file.TrackEvent.Kind{
                .MetaEvent = midi.file.MetaEvent{
                    .kind_byte = 0,
                    .len = 0,
                },
            },
        },
        midi.file.TrackEvent{
            .delta_time = 0,
            .kind = midi.file.TrackEvent.Kind{
                .MetaEvent = midi.file.MetaEvent{
                    .kind_byte = 0,
                    .len = 2,
                },
            },
        },
    });
    try testTrackEvent("\x00\x80\x00\x00" ++
        "\x00\x7F\x7F" ++
        "\x00\xFF\x00\x02", &[_]midi.file.TrackEvent{
        midi.file.TrackEvent{
            .delta_time = 0,
            .kind = midi.file.TrackEvent.Kind{
                .MidiEvent = midi.Message{
                    .status = 0x00,
                    .values = [2]u7{ 0x0, 0x0 },
                },
            },
        },
        midi.file.TrackEvent{
            .delta_time = 0,
            .kind = midi.file.TrackEvent.Kind{
                .MidiEvent = midi.Message{
                    .status = 0x00,
                    .values = [2]u7{ 0x7F, 0x7F },
                },
            },
        },
        midi.file.TrackEvent{
            .delta_time = 0,
            .kind = midi.file.TrackEvent.Kind{
                .MetaEvent = midi.file.MetaEvent{
                    .kind_byte = 0,
                    .len = 2,
                },
            },
        },
    });
}

test "midi.decode/encode.file" {
    try testFile(
        // File header
        "MThd\x00\x00\x00\x08\x00\x02\x00\x02\xFF\x10\xFF\xFF" ++
            // Random chunk
            "abcd\x00\x00\x00\x04\xFF\xFF\xFF\xFF" ++
            // Track
            "MTrk\x00\x00\x00\x17" ++
            "\x00\xFF\x00\x00" ++
            "\x00\xFF\x00\x02\xaa\xbb" ++
            "\x00\x80\x00\x00" ++
            "\x00\x7F\x7F" ++
            "\x00\xFF\x00\x02\xaa\xbb",
    );
}

fn testFile(bytes: []const u8) !void {
    var out_buf: [1024]u8 = undefined;
    var fb_writer = io.fixedBufferStream(&out_buf);
    var fb_reader = io.fixedBufferStream(bytes);
    const writer = fb_writer.writer();
    const reader = fb_reader.reader();
    const allocator = testing.allocator;

    const actual = try decode.file(reader, allocator);
    defer actual.deinit(allocator);
    try encode.file(writer, actual);

    try testing.expectError(error.EndOfStream, reader.readByte());
    try testing.expectEqualSlices(u8, bytes, fb_writer.getWritten());
}

fn testMessage(bytes: []const u8, results: []const midi.Message) !void {
    var last: ?midi.Message = null;
    var out_buf: [1024]u8 = undefined;
    var fb_writer = io.fixedBufferStream(&out_buf);
    var fb_reader = io.fixedBufferStream(bytes);
    const writer = fb_writer.writer();
    const reader = fb_reader.reader();
    for (results) |expected| {
        const actual = try decode.message(reader, last);
        try encode.message(writer, last, actual);
        try testing.expectEqual(expected, actual);
        last = actual;
    }

    try testing.expectError(error.EndOfStream, reader.readByte());
    try testing.expectEqualSlices(u8, bytes, fb_writer.getWritten());
}

fn testInt(bytes: []const u8, results: []const u28) !void {
    var out_buf: [1024]u8 = undefined;
    var fb_reader = io.fixedBufferStream(bytes);
    const reader = fb_reader.reader();
    for (results) |expected| {
        var fb_writer = io.fixedBufferStream(&out_buf);
        const writer = fb_writer.writer();

        const before = fb_reader.pos;
        const actual = try decode.int(reader);
        const after = fb_reader.pos;

        try encode.int(writer, actual);

        try testing.expectEqual(expected, actual);
        try testing.expectEqualSlices(u8, bytes[before..after], fb_writer.getWritten());
    }

    try testing.expectError(error.EndOfStream, reader.readByte());
}

fn testMetaEvent(bytes: []const u8, results: []const midi.file.MetaEvent) !void {
    var out_buf: [1024]u8 = undefined;
    var fb_writer = io.fixedBufferStream(&out_buf);
    var fb_reader = io.fixedBufferStream(bytes);
    const writer = fb_writer.writer();
    const reader = fb_reader.reader();
    for (results) |expected| {
        const actual = try decode.metaEvent(reader);
        try encode.metaEvent(writer, actual);
        try testing.expectEqual(expected, actual);
    }

    try testing.expectError(error.EndOfStream, reader.readByte());
    try testing.expectEqualSlices(u8, bytes, fb_writer.getWritten());
}

fn testTrackEvent(bytes: []const u8, results: []const midi.file.TrackEvent) !void {
    var last: ?midi.file.TrackEvent = null;
    var out_buf: [1024]u8 = undefined;
    var fb_writer = io.fixedBufferStream(&out_buf);
    var fb_reader = io.fixedBufferStream(bytes);
    const writer = fb_writer.writer();
    const reader = fb_reader.reader();
    for (results) |expected| {
        const actual = try decode.trackEvent(reader, last);
        try encode.trackEvent(writer, last, actual);
        try testing.expectEqual(expected.delta_time, actual.delta_time);
        switch (expected.kind) {
            .MetaEvent => try testing.expectEqual(expected.kind.MetaEvent, actual.kind.MetaEvent),
            .MidiEvent => try testing.expectEqual(expected.kind.MidiEvent, actual.kind.MidiEvent),
        }
        last = actual;
    }

    try testing.expectError(error.EndOfStream, reader.readByte());
    try testing.expectEqualSlices(u8, bytes, fb_writer.getWritten());
}

fn testChunk(bytes: [8]u8, chunk: midi.file.Chunk) !void {
    const decoded = decode.chunkFromBytes(bytes);
    const encoded = encode.chunkToBytes(chunk);
    try testing.expectEqual(bytes, encoded);
    try testing.expectEqual(chunk, decoded);
}

fn testFileHeader(bytes: [14]u8, header: midi.file.Header) !void {
    const decoded = try decode.fileHeaderFromBytes(bytes);
    const encoded = encode.fileHeaderToBytes(header);
    try testing.expectEqual(bytes, encoded);
    try testing.expectEqual(header, decoded);
}
