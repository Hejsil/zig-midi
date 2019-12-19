const std = @import("std");
const midi = @import("../midi.zig");

const debug = std.debug;
const math = std.math;
const mem = std.mem;
const io = std.io;

const decode = @This();

pub fn message(stream: var, last_message: ?midi.Message, message: midi.Message) !midi.Message {
    if (last_message == null or message.status != last_message.?.status) {
        try stream.write([_]u8{(1 << 8) | u8(message.status)});
    }

    switch (message.kind()) {
        .ExclusiveStart, .TuneRequest, .ExclusiveEnd, .TimingClock, .Start, .Continue, .Stop, .ActiveSensing, .Reset, .Undefined => {},
        .ProgramChange,
        .ChannelPressure,
        .MidiTimeCodeQuarterFrame,
        .SongSelect,
        => {
            try stream.write([_]u8{message.values[0]});
        },
        .NoteOff,
        .NoteOn,
        .PolyphonicKeyPressure,
        .ControlChange,
        .PitchBendChange,
        .SongPositionPointer,
        => {
            try stream.write([_]u8{message.values[0]});
            try stream.write([_]u8{message.values[1]});
        },
    }
}

pub fn chunkToBytes(_chunk: midi.file.Chunk) [8]u8 {
    var res: [8]u8 = undefined;
    mem.copy(u8, res[0..4], _chunk.kind);
    mem.writeIntBig(u32, @ptrCast(*[4]u8, res[4..8].ptr), _chunk.len);
    return res;
}

pub fn fileHeaderToBytes(header: midi.file.Header) [14]u8 {
    var res: [14]u8 = undefined;
    mem.copy(u8, res[0..8], chunkToBytes(header.chunk));
    mem.writeIntBig(u16, @ptrCast(*[2]u8, res[8..10].ptr), header.format);
    mem.writeIntBig(u16, @ptrCast(*[2]u8, res[10..12].ptr), header.tracks);
    mem.writeIntBig(u16, @ptrCast(*[2]u8, res[12..14].ptr), header.division);
    return res;
}

pub fn int(stream: var, i: u28) !void {
    var tmp: u28 = i;
    while (tmp > math.maxInt(u7)) {
        try stream.write([_]u8{@truncate(u8, tmp) | 1 << 8});
        tmp >>= 7;
    }

    try stream.write([_]u8{@intCast(u7, tmp)});
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
