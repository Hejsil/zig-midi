const midi = @import("../midi.zig");
const std = @import("std");

const debug = std.debug;
const io = std.io;
const math = std.math;
const mem = std.mem;

const encode = @This();

test {
    std.testing.refAllDecls(@This());
}

pub fn message(writer: anytype, last_message: ?midi.Message, msg: midi.Message) !void {
    if (msg.channel() == null or last_message == null or msg.status != last_message.?.status) {
        try writer.writeByte((1 << 7) | @as(u8, msg.status));
    }

    switch (msg.kind()) {
        .ExclusiveStart,
        .TuneRequest,
        .ExclusiveEnd,
        .TimingClock,
        .Start,
        .Continue,
        .Stop,
        .ActiveSensing,
        .Reset,
        .Undefined,
        => {},
        .ProgramChange,
        .ChannelPressure,
        .MidiTimeCodeQuarterFrame,
        .SongSelect,
        => {
            try writer.writeByte(msg.values[0]);
        },
        .NoteOff,
        .NoteOn,
        .PolyphonicKeyPressure,
        .ControlChange,
        .PitchBendChange,
        .SongPositionPointer,
        => {
            try writer.writeByte(msg.values[0]);
            try writer.writeByte(msg.values[1]);
        },
    }
}

pub fn chunkToBytes(_chunk: midi.file.Chunk) [8]u8 {
    var res: [8]u8 = undefined;
    mem.copy(u8, res[0..4], &_chunk.kind);
    mem.writeIntBig(u32, res[4..8], _chunk.len);
    return res;
}

pub fn fileHeaderToBytes(header: midi.file.Header) [14]u8 {
    var res: [14]u8 = undefined;
    mem.copy(u8, res[0..8], &chunkToBytes(header.chunk));
    mem.writeIntBig(u16, res[8..10], header.format);
    mem.writeIntBig(u16, res[10..12], header.tracks);
    mem.writeIntBig(u16, res[12..14], header.division);
    return res;
}

pub fn int(writer: anytype, i: u28) !void {
    var tmp = i;
    var is_first = true;
    var buf: [4]u8 = undefined;
    var fbs = io.fixedBufferStream(&buf);
    const w = fbs.writer();

    // TODO: Can we find a way to not encode this in reverse order and then flipping the bytes?
    while (tmp != 0 or is_first) : (is_first = false) {
        w.writeByte(@as(u7, @truncate(tmp)) | (@as(u8, 1 << 7) * @intFromBool(!is_first))) catch
            unreachable;
        tmp >>= 7;
    }
    mem.reverse(u8, fbs.getWritten());
    try writer.writeAll(fbs.getWritten());
}

pub fn metaEvent(writer: anytype, event: midi.file.MetaEvent) !void {
    try writer.writeByte(event.kind_byte);
    try int(writer, event.len);
}

pub fn trackEvent(writer: anytype, last_event: ?midi.file.TrackEvent, event: midi.file.TrackEvent) !void {
    const last_midi_event = if (last_event) |e| switch (e.kind) {
        .MidiEvent => |m| m,
        .MetaEvent => null,
    } else null;

    try int(writer, event.delta_time);
    switch (event.kind) {
        .MetaEvent => |meta| {
            try writer.writeByte(0xFF);
            try metaEvent(writer, meta);
        },
        .MidiEvent => |msg| try message(writer, last_midi_event, msg),
    }
}

pub fn file(writer: anytype, f: midi.File) !void {
    try writer.writeAll(&encode.fileHeaderToBytes(.{
        .chunk = .{
            .kind = midi.file.Chunk.file_header.*,
            .len = @intCast(midi.file.Header.size + f.header_data.len),
        },
        .format = f.format,
        .tracks = @intCast(f.chunks.len),
        .division = f.division,
    }));
    try writer.writeAll(f.header_data);

    for (f.chunks) |c| {
        try writer.writeAll(&encode.chunkToBytes(.{
            .kind = c.kind,
            .len = @intCast(c.bytes.len),
        }));
        try writer.writeAll(c.bytes);
    }
}
