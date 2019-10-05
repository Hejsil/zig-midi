const std = @import("std");
const midi = @import("index.zig");

const testing = std.testing;
const mem = std.mem;
const io = std.io;

const decode = midi.decode;
const file = midi.file;

test "midi.decode.message" {
    try testDecodeMessage("\x80\x00\x00" ++
        "\x7F\x7F" ++
        "\x8F\x7F\x7F", [_]midi.Message{
        midi.Message{
            .status = 0x00,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x00,
            .values = [2]u7 { 0x7F, 0x7F },
        },
        midi.Message{
            .status = 0x0F,
            .values = [2]u7 { 0x7F, 0x7F },
        },
    });
    try testDecodeMessage("\x90\x00\x00" ++
        "\x7F\x7F" ++
        "\x9F\x7F\x7F", [_]midi.Message{
        midi.Message{
            .status = 0x10,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x10,
            .values = [2]u7 { 0x7F, 0x7F },
        },
        midi.Message{
            .status = 0x1F,
            .values = [2]u7 { 0x7F, 0x7F },
        },
    });
    try testDecodeMessage("\xA0\x00\x00" ++
        "\x7F\x7F" ++
        "\xAF\x7F\x7F", [_]midi.Message{
        midi.Message{
            .status = 0x20,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x20,
            .values = [2]u7 { 0x7F, 0x7F },
        },
        midi.Message{
            .status = 0x2F,
            .values = [2]u7 { 0x7F, 0x7F },
        },
    });
    try testDecodeMessage("\xB0\x00\x00" ++
        "\x77\x7F" ++
        "\xBF\x77\x7F", [_]midi.Message{
        midi.Message{
            .status = 0x30,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x30,
            .values = [2]u7 { 0x77, 0x7F },
        },
        midi.Message{
            .status = 0x3F,
            .values = [2]u7 { 0x77, 0x7F },
        },
    });
    try testDecodeMessage("\xC0\x00" ++
        "\x7F" ++
        "\xCF\x7F", [_]midi.Message{
        midi.Message{
            .status = 0x40,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x40,
            .values = [2]u7 { 0x7F, 0x0 },
        },
        midi.Message{
            .status = 0x4F,
            .values = [2]u7 { 0x7F, 0x0 },
        },
    });
    try testDecodeMessage("\xD0\x00" ++
        "\x7F" ++
        "\xDF\x7F", [_]midi.Message{
        midi.Message{
            .status = 0x50,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x50,
            .values = [2]u7 { 0x7F, 0x0 },
        },
        midi.Message{
            .status = 0x5F,
            .values = [2]u7 { 0x7F, 0x0 },
        },
    });
    try testDecodeMessage("\xE0\x00\x00" ++
        "\x7F\x7F" ++
        "\xEF\x7F\x7F", [_]midi.Message{
        midi.Message{
            .status = 0x60,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x60,
            .values = [2]u7 { 0x7F, 0x7F },
        },
        midi.Message{
            .status = 0x6F,
            .values = [2]u7 { 0x7F, 0x7F },
        },
    });
    try testDecodeMessage("\xF0\xF0", [_]midi.Message{
        midi.Message{
            .status = 0x70,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x70,
            .values = [2]u7 { 0x0, 0x0 },
        },
    });
    try testDecodeMessage("\xF1\x00" ++
        "\xF1\x0F" ++
        "\xF1\x70" ++
        "\xF1\x7F", [_]midi.Message{
        midi.Message{
            .status = 0x71,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x71,
            .values = [2]u7 { 0x0F, 0x0 },
        },
        midi.Message{
            .status = 0x71,
            .values = [2]u7 { 0x70, 0x0 },
        },
        midi.Message{
            .status = 0x71,
            .values = [2]u7 { 0x7F, 0x0 },
        },
    });
    try testDecodeMessage("\xF2\x00\x00" ++
        "\xF2\x7F\x7F", [_]midi.Message{
        midi.Message{
            .status = 0x72,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x72,
            .values = [2]u7 { 0x7F, 0x7F },
        },
    });
    try testDecodeMessage("\xF3\x00" ++
        "\xF3\x7F", [_]midi.Message{
        midi.Message{
            .status = 0x73,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x73,
            .values = [2]u7 { 0x7F, 0x0 },
        },
    });
    try testDecodeMessage("\xF6\xF6", [_]midi.Message{
        midi.Message{
            .status = 0x76,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x76,
            .values = [2]u7 { 0x0, 0x0 },
        },
    });
    try testDecodeMessage("\xF7\xF7", [_]midi.Message{
        midi.Message{
            .status = 0x77,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x77,
            .values = [2]u7 { 0x0, 0x0 },
        },
    });
    try testDecodeMessage("\xF8\xF8", [_]midi.Message{
        midi.Message{
            .status = 0x78,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x78,
            .values = [2]u7 { 0x0, 0x0 },
        },
    });
    try testDecodeMessage("\xFA\xFA", [_]midi.Message{
        midi.Message{
            .status = 0x7A,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x7A,
            .values = [2]u7 { 0x0, 0x0 },
        },
    });
    try testDecodeMessage("\xFB\xFB", [_]midi.Message{
        midi.Message{
            .status = 0x7B,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x7B,
            .values = [2]u7 { 0x0, 0x0 },
        },
    });
    try testDecodeMessage("\xFC\xFC", [_]midi.Message{
        midi.Message{
            .status = 0x7C,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x7C,
            .values = [2]u7 { 0x0, 0x0 },
        },
    });
    try testDecodeMessage("\xFE\xFE", [_]midi.Message{
        midi.Message{
            .status = 0x7E,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x7E,
            .values = [2]u7 { 0x0, 0x0 },
        },
    });
    try testDecodeMessage("\xFF\xFF", [_]midi.Message{
        midi.Message{
            .status = 0x7F,
            .values = [2]u7 { 0x0, 0x0 },
        },
        midi.Message{
            .status = 0x7F,
            .values = [2]u7 { 0x0, 0x0 },
        },
    });
}

test "decode.chunk" {
    testing.expectEqual(midi.file.Chunk{
        .kind = "abcd",
        .len = 0x04,
    }, decode.chunk("abcd\x00\x00\x00\x04"));
    testing.expectEqual(midi.file.Chunk{
        .kind = "efgh",
        .len = 0x0400,
    }, decode.chunk("efgh\x00\x00\x04\x00"));
    testing.expectEqual(midi.file.Chunk{
        .kind = "ijkl",
        .len = 0x040000,
    }, decode.chunk("ijkl\x00\x04\x00\x00"));
    testing.expectEqual(midi.file.Chunk{
        .kind = "mnop",
        .len = 0x04000000,
    }, decode.chunk("mnop\x04\x00\x00\x00"));
}

test "decode.fileHeader" {
    testing.expectEqual(midi.file.Header{
        .format = 0,
        .tracks = 0x0001,
        .division = 0x0110,
    }, try decode.fileHeader("MThd\x00\x00\x00\x06\x00\x00\x00\x01\x01\x10"));
    testing.expectEqual(midi.file.Header{
        .format = 1,
        .tracks = 0x0101,
        .division = 0x0110,
    }, try decode.fileHeader("MThd\x00\x00\x00\x06\x00\x01\x01\x01\x01\x10"));
    testing.expectEqual(midi.file.Header{
        .format = 2,
        .tracks = 0x0101,
        .division = 0x0110,
    }, try decode.fileHeader("MThd\x00\x00\x00\x06\x00\x02\x01\x01\x01\x10"));
    testing.expectEqual(midi.file.Header{
        .format = 0,
        .tracks = 0x0001,
        .division = 0xFF10,
    }, try decode.fileHeader("MThd\x00\x00\x00\x06\x00\x00\x00\x01\xFF\x10"));
    testing.expectEqual(midi.file.Header{
        .format = 1,
        .tracks = 0x0101,
        .division = 0xFF10,
    }, try decode.fileHeader("MThd\x00\x00\x00\x06\x00\x01\x01\x01\xFF\x10"));
    testing.expectEqual(midi.file.Header{
        .format = 2,
        .tracks = 0x0101,
        .division = 0xFF10,
    }, try decode.fileHeader("MThd\x00\x00\x00\x06\x00\x02\x01\x01\xFF\x10"));

    testing.expectError(error.InvalidFileHeader, decode.fileHeader("MThd\x00\x00\x00\x05\x00\x00\x00\x01\x01\x10"));
}

test "decode.variableLenInt" {
    try testDecodeVariableLenInt("\x00" ++
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
        "\xFF\xFF\xFF\x7F", [_]u28{
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

    testing.expectEqual(u28(0x00000000), try decode.variableLenInt(&io.SliceInStream.init("\x00\xFF\xFF\xFF\xFF").stream));
    testing.expectEqual(u28(0x00000040), try decode.variableLenInt(&io.SliceInStream.init("\x40\xFF\xFF\xFF\xFF").stream));
    testing.expectEqual(u28(0x0000007F), try decode.variableLenInt(&io.SliceInStream.init("\x7F\xFF\xFF\xFF\xFF").stream));
    testing.expectEqual(u28(0x00000080), try decode.variableLenInt(&io.SliceInStream.init("\x81\x00\xFF\xFF\xFF").stream));
    testing.expectEqual(u28(0x00002000), try decode.variableLenInt(&io.SliceInStream.init("\xC0\x00\xFF\xFF\xFF").stream));
    testing.expectEqual(u28(0x00003FFF), try decode.variableLenInt(&io.SliceInStream.init("\xFF\x7F\xFF\xFF\xFF").stream));
    testing.expectEqual(u28(0x00004000), try decode.variableLenInt(&io.SliceInStream.init("\x81\x80\x00\xFF\xFF").stream));
    testing.expectEqual(u28(0x00100000), try decode.variableLenInt(&io.SliceInStream.init("\xC0\x80\x00\xFF\xFF").stream));
    testing.expectEqual(u28(0x001FFFFF), try decode.variableLenInt(&io.SliceInStream.init("\xFF\xFF\x7F\xFF\xFF").stream));
    testing.expectEqual(u28(0x00200000), try decode.variableLenInt(&io.SliceInStream.init("\x81\x80\x80\x00\xFF").stream));
    testing.expectEqual(u28(0x08000000), try decode.variableLenInt(&io.SliceInStream.init("\xC0\x80\x80\x00\xFF").stream));
    testing.expectEqual(u28(0x0FFFFFFF), try decode.variableLenInt(&io.SliceInStream.init("\xFF\xFF\xFF\x7F\xFF").stream));
}

test "decode.metaEvent" {
    try testDecodeMetaEvent("\xFF\x00\x00" ++
        "\xFF\x00\x02", [_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 0,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 0,
            .len = 2,
        },
    });
    try testDecodeMetaEvent("\xFF\x01\x00" ++
        "\xFF\x01\x02", [_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 1,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 1,
            .len = 2,
        },
    });
    try testDecodeMetaEvent("\xFF\x02\x00" ++
        "\xFF\x02\x02", [_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 2,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 2,
            .len = 2,
        },
    });
    try testDecodeMetaEvent("\xFF\x03\x00" ++
        "\xFF\x03\x02", [_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 3,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 3,
            .len = 2,
        },
    });
    try testDecodeMetaEvent("\xFF\x04\x00" ++
        "\xFF\x04\x02", [_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 4,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 4,
            .len = 2,
        },
    });
    try testDecodeMetaEvent("\xFF\x05\x00" ++
        "\xFF\x05\x02", [_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 5,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 5,
            .len = 2,
        },
    });
    try testDecodeMetaEvent("\xFF\x06\x00" ++
        "\xFF\x06\x02", [_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 6,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 6,
            .len = 2,
        },
    });
    try testDecodeMetaEvent("\xFF\x20\x00" ++
        "\xFF\x20\x02", [_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 0x20,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 0x20,
            .len = 2,
        },
    });
    try testDecodeMetaEvent("\xFF\x2F\x00" ++
        "\xFF\x2F\x02", [_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 0x2F,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 0x2F,
            .len = 2,
        },
    });
    try testDecodeMetaEvent("\xFF\x51\x00" ++
        "\xFF\x51\x02", [_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 0x51,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 0x51,
            .len = 2,
        },
    });
    try testDecodeMetaEvent("\xFF\x54\x00" ++
        "\xFF\x54\x02", [_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 0x54,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 0x54,
            .len = 2,
        },
    });
    try testDecodeMetaEvent("\xFF\x58\x00" ++
        "\xFF\x58\x02", [_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 0x58,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 0x58,
            .len = 2,
        },
    });
    try testDecodeMetaEvent("\xFF\x59\x00" ++
        "\xFF\x59\x02", [_]midi.file.MetaEvent{
        midi.file.MetaEvent{
            .kind_byte = 0x59,
            .len = 0,
        },
        midi.file.MetaEvent{
            .kind_byte = 0x59,
            .len = 2,
        },
    });
    try testDecodeMetaEvent("\xFF\x7F\x00" ++
        "\xFF\x7F\x02", [_]midi.file.MetaEvent{
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

fn testDecodeMessage(bytes: []const u8, results: []const midi.Message) !void {
    var last: ?midi.Message = null;
    var stream = io.SliceInStream.init(bytes);
    for (results) |expected| {
        const actual = try decode.message(last, &stream.stream);
        testing.expectEqual(expected, actual);
        last = actual;
    }

    testing.expectError(error.EndOfStream, stream.stream.readByte());
}

fn testDecodeVariableLenInt(bytes: []const u8, results: []const u28) !void {
    var stream = io.SliceInStream.init(bytes);
    for (results) |expected| {
        const actual = try decode.variableLenInt(&stream.stream);
        testing.expectEqual(expected, actual);
    }

    testing.expectError(error.EndOfStream, stream.stream.readByte());
}

fn testDecodeMetaEvent(bytes: []const u8, results: []const midi.file.MetaEvent) !void {
    var stream = io.SliceInStream.init(bytes);
    for (results) |expected| {
        const actual = try decode.metaEvent(&stream.stream);
        testing.expectEqual(expected, actual);
    }

    testing.expectError(error.EndOfStream, stream.stream.readByte());
}
