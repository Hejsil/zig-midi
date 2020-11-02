const std = @import("std");
const midi = @import("../midi.zig");

const debug = std.debug;
const math = std.math;
const mem = std.mem;
const io = std.io;

const encode = @This();

pub fn message(stream: anytype, last_message: ?midi.Message, msg: midi.Message) !void {
    if (msg.channel() == null or last_message == null or msg.status != last_message.?.status) {
        try stream.writeByte((1 << 7) | @as(u8, msg.status));
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
            try stream.writeByte(msg.values[0]);
        },
        .NoteOff,
        .NoteOn,
        .PolyphonicKeyPressure,
        .ControlChange,
        .PitchBendChange,
        .SongPositionPointer,
        => {
            try stream.writeByte(msg.values[0]);
            try stream.writeByte(msg.values[1]);
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

pub fn int(stream: anytype, i: u28) !void {
    var tmp = i;
    var is_first = true;
    var buf: [4]u8 = undefined;
    var fbs = io.fixedBufferStream(&buf);
    const fbstream = fbs.outStream();

    // TODO: Can we find a way to not encode this in reverse order and then flipping the bytes?
    while (tmp != 0 or is_first) : (is_first = false) {
        fbstream.writeByte(@truncate(u7, tmp) | (@as(u8, 1 << 7) * @boolToInt(!is_first))) catch unreachable;
        tmp >>= 7;
    }
    mem.reverse(u8, fbs.getWritten());
    try stream.writeAll(fbs.getWritten());
}

pub fn metaEvent(stream: anytype, event: midi.file.MetaEvent) !void {
    try stream.writeByte(event.kind_byte);
    try int(stream, event.len);
}

pub fn trackEvent(stream: anytype, last_event: ?midi.file.TrackEvent, event: midi.file.TrackEvent) !void {
    const last_midi_event = if (last_event) |e| switch (e.kind) {
        .MidiEvent => |m| m,
        .MetaEvent => null,
    } else null;

    try int(stream, event.delta_time);
    switch (event.kind) {
        .MetaEvent => |meta| {
            try stream.writeByte(0xFF);
            try metaEvent(stream, meta);
        },
        .MidiEvent => |msg| try message(stream, last_midi_event, msg),
    }
}

pub fn file(stream: anytype, f: midi.File) !void {
    try stream.writeAll(&encode.fileHeaderToBytes(.{
        .chunk = .{
            .kind = midi.file.Chunk.file_header.*,
            .len = @intCast(u32, midi.file.Header.size + f.header_data.len),
        },
        .format = f.format,
        .tracks = @intCast(u16, f.chunks.len),
        .division = f.division,
    }));
    try stream.writeAll(f.header_data);

    for (f.chunks) |c| {
        try stream.writeAll(&encode.chunkToBytes(.{
            .kind = c.kind,
            .len = @intCast(u32, c.bytes.len),
        }));
        try stream.writeAll(c.bytes);
    }
}
