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

fn readDataByte(stream: var) !u7 {
    return math.cast(u7, try stream.readByte()) catch return error.InvalidDataByte;
}

pub fn message(last_message: ?midi.Message, stream: var) !midi.Message {
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
            .values = [2]u8{
                math.cast(u7, first_byte orelse try stream.readByte()) catch return error.InvalidDataByte,
                try readDataByte(stream),
            },
        },
        0x4, 0x5 => return midi.Message{
            .status = status_byte,
            .values = [2]u8{
                math.cast(u7, first_byte orelse try stream.readByte()) catch return error.InvalidDataByte,
                0,
            },
        },
        0x7 => {
            debug.assert(first_byte == null);
            switch (channel) {
                0x0, 0x6, 0x07, 0x8, 0xA, 0xB, 0xC, 0xE, 0xF => return midi.Message{
                    .status = status_byte,
                    .values = [2]u8{ 0, 0 },
                },
                0x1, 0x3 => return midi.Message{
                    .status = status_byte,
                    .values = [2]u8{
                        try readDataByte(stream),
                        0,
                    },
                },
                0x2 => return midi.Message{
                    .status = status_byte,
                    .values = [2]u8{
                        try readDataByte(stream),
                        try readDataByte(stream),
                    },
                },

                // Undefined
                0x4, 0x5, 0x9, 0xD => return midi.Message{
                    .status = status_byte,
                    .values = [2]u8{ 0, 0 },
                },
            }
        },
    }
}

pub fn chunk(bytes: [8]u8) midi.file.Chunk {
    return midi.file.Chunk{
        .kind = @ptrCast(*const [4]u8, bytes[0..4].ptr).*,
        .len = mem.readIntBig(u32, @ptrCast(*const [4]u8, bytes[4..8].ptr)),
    };
}

pub fn fileHeader(bytes: [14]u8) !midi.file.Header {
    const _chunk = decode.chunk(@ptrCast(*const [8]u8, bytes[0..8].ptr).*);
    if (!mem.eql(u8, _chunk.kind, midi.file.Chunk.file_header))
        return error.InvalidFileHeader;
    if (_chunk.len < 6)
        return error.InvalidFileHeader;

    return midi.file.Header{
        .chunk = _chunk,
        .format = mem.readIntBig(u16, @ptrCast(*const [2]u8, bytes[8..10].ptr)),
        .tracks = mem.readIntBig(u16, @ptrCast(*const [2]u8, bytes[10..12].ptr)),
        .division = mem.readIntBig(u16, @ptrCast(*const [2]u8, bytes[12..14].ptr)),
    };
}

pub fn variableLenInt(stream: var) !u28 {
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

pub fn metaEvent(stream: var) !midi.file.MetaEvent {
    return midi.file.MetaEvent{
        .kind_byte = try stream.readByte(),
        .len = try variableLenInt(stream),
    };
}

pub fn trackEvent(last_event: ?midi.file.TrackEvent, stream: var) !midi.file.TrackEvent {
    var ps = io.PeekStream(1, @typeOf(stream.read(undefined)).ErrorSet).init(stream);
    const delta_time = try variableLenInt(&ps.stream);
    const first_byte = try ps.stream.readByte();
    if (first_byte == 0xFF) {
        return midi.file.TrackEvent{
            .delta_time = delta_time,
            .kind = midi.file.TrackEvent.Kind{ .MetaEvent = try metaEvent(&ps.stream) },
        };
    }

    const last_midi_event = if (last_event) |e| switch (e.kind) {
        .MidiEvent => |m| m,
        .MetaEvent => null,
    } else null;

    ps.putBackByte(first_byte);
    return midi.file.TrackEvent{
        .delta_time = delta_time,
        .kind = midi.file.TrackEvent.Kind{ .MidiEvent = try message(last_midi_event, &ps.stream) },
    };
}
