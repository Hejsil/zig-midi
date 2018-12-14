const std = @import("std");
const midi = @import("index.zig");

const debug = std.debug;
const math = std.math;
const mem = std.mem;

const decode = @This();

fn statusByte(b: u8) ?u7 {
    if (@truncate(u1, b >> 7) != 0)
        return @truncate(u7, b);

    return null;
}

/// Accepts input one byte at a time and returns midi channel messages as they are decoded.
///
/// For a non-byte based wrapper, consider using ChannelMessageDecoder instead.
pub const StreamingChannelMessageDecoder = struct {
    const State = union(enum) {
        Status: void,
        Running: ChannelMessage(0),

        ChannelValue1: ChannelMessage(0),
        ChannelValue2: ChannelMessage(1),

        fn ChannelMessage(comptime count: usize) type {
            return struct {
                kind: midi.ChannelMessage.Kind,
                channel: u4,
                values: [count]u7,
            };
        }
    };

    state: State,

    pub fn init() StreamingChannelMessageDecoder {
        return StreamingChannelMessageDecoder{ .state = State.Status };
    }

    fn feed(stream: *StreamingChannelMessageDecoder, b: u8) !?midi.ChannelMessage {
        repeat: while (true) {
            switch (stream.state) {
                State.Status => {
                    const statut_byte = statusByte(b) orelse return error.ExpectedStatusByte;
                    const upper = @truncate(u3, b >> 4);
                    const lower = @truncate(u4, b);
                    const kind = channel_message_table[upper] orelse return error.InvalidChannelMessage;

                    stream.state = State{
                        .ChannelValue1 = State.ChannelMessage(0){
                            .kind = kind,
                            .channel = lower,
                            .values = []u7{},
                        },
                    };
                    return null;
                },
                State.Running => |msg| {
                    stream.state = if (statusByte(b)) |_| State{ .Status = {} } else State{ .ChannelValue1 = msg };
                    continue :repeat;
                },

                State.ChannelValue1 => |msg| {
                    const value = math.cast(u7, b) catch return error.InvalidChannelMessage;

                    stream.state = State{ .Running = msg };
                    switch (msg.kind) {
                        midi.ChannelMessage.Kind.NoteOff,
                        midi.ChannelMessage.Kind.NoteOn,
                        midi.ChannelMessage.Kind.PolyphonicKeyPressure,
                        midi.ChannelMessage.Kind.PitchBendChange,
                        midi.ChannelMessage.Kind.ControlChange,
                        => {
                            stream.state = State{
                                .ChannelValue2 = State.ChannelMessage(1){
                                    .kind = msg.kind,
                                    .channel = msg.channel,
                                    .values = []u7{value},
                                },
                            };
                            return null;
                        },
                        midi.ChannelMessage.Kind.ProgramChange => return midi.ChannelMessage{
                            .ProgramChange = midi.ChannelMessage.ProgramChange{
                                .channel = msg.channel,
                                .program = value,
                            },
                        },
                        midi.ChannelMessage.Kind.ChannelPressure => return midi.ChannelMessage{
                            .ChannelPressure = midi.ChannelMessage.ChannelPressure{
                                .channel = msg.channel,
                                .pressure = value,
                            },
                        },
                        else => unreachable,
                    }
                },
                State.ChannelValue2 => |msg| {
                    const value = math.cast(u7, b) catch return error.InvalidChannelMessage;

                    stream.state = State{
                        .Running = State.ChannelMessage(0){
                            .channel = msg.channel,
                            .kind = msg.kind,
                            .values = []u7{},
                        },
                    };
                    switch (msg.kind) {
                        midi.ChannelMessage.Kind.ControlChange => switch (msg.values[0]) {
                            120 => return midi.ChannelMessage{
                                .AllSoundOff = midi.ChannelMessage.AllSoundOff{ .channel = msg.channel },
                            },
                            121 => return midi.ChannelMessage{
                                .ResetAllControllers = midi.ChannelMessage.ResetAllControllers{
                                    .channel = msg.channel,
                                    .value = value,
                                },
                            },
                            122 => return midi.ChannelMessage{
                                .LocalControl = midi.ChannelMessage.LocalControl{
                                    .channel = msg.channel,
                                    .on = switch (value) {
                                        0 => false,
                                        127 => true,
                                        else => return error.InvalidChannelMessage,
                                    },
                                },
                            },
                            123 => return midi.ChannelMessage{
                                .AllNotesOff = midi.ChannelMessage.AllNotesOff{ .channel = msg.channel },
                            },
                            124 => return midi.ChannelMessage{
                                .OmniModeOff = midi.ChannelMessage.OmniModeOff{ .channel = msg.channel },
                            },
                            125 => return midi.ChannelMessage{
                                .OmniModeOn = midi.ChannelMessage.OmniModeOn{ .channel = msg.channel },
                            },
                            126 => return midi.ChannelMessage{
                                .MonoModeOn = midi.ChannelMessage.MonoModeOn{
                                    .channel = msg.channel,
                                    .value = value,
                                },
                            },
                            127 => return midi.ChannelMessage{
                                .PolyModeOn = midi.ChannelMessage.PolyModeOn{ .channel = msg.channel },
                            },
                            else => return midi.ChannelMessage{
                                .ControlChange = midi.ChannelMessage.ControlChange{
                                    .channel = msg.channel,
                                    .controller = msg.values[0],
                                    .value = value,
                                },
                            },
                        },
                        midi.ChannelMessage.Kind.NoteOff => return midi.ChannelMessage{
                            .NoteOff = midi.ChannelMessage.NoteOff{
                                .channel = msg.channel,
                                .note = msg.values[0],
                                .velocity = value,
                            },
                        },
                        midi.ChannelMessage.Kind.NoteOn => return midi.ChannelMessage{
                            .NoteOn = midi.ChannelMessage.NoteOn{
                                .channel = msg.channel,
                                .note = msg.values[0],
                                .velocity = value,
                            },
                        },
                        midi.ChannelMessage.Kind.PolyphonicKeyPressure => return midi.ChannelMessage{
                            .PolyphonicKeyPressure = midi.ChannelMessage.PolyphonicKeyPressure{
                                .channel = msg.channel,
                                .note = msg.values[0],
                                .pressure = value,
                            },
                        },
                        midi.ChannelMessage.Kind.PitchBendChange => return midi.ChannelMessage{
                            .PitchBendChange = midi.ChannelMessage.PitchBendChange{
                                .channel = msg.channel,
                                .bend = u14(msg.values[0]) | u14(value) << 7,
                            },
                        },
                        else => unreachable,
                    }
                },
            }
        }
    }

    pub fn reset(stream: *StreamingChannelMessageDecoder) void {
        stream.state = State{ .Status = void{} };
    }

    pub fn done(stream: *StreamingChannelMessageDecoder) !void {
        switch (stream.state) {
            State.Status, State.Running => {
                stream.reset();
                return;
            },
            else => return error.InvalidChannelMessage,
        }
    }

    const channel_message_table = blk: {
        var res = []?midi.ChannelMessage.Kind{null} ** (math.maxInt(u3) + 1);
        res[0x0] = midi.ChannelMessage.Kind.NoteOff;
        res[0x1] = midi.ChannelMessage.Kind.NoteOn;
        res[0x2] = midi.ChannelMessage.Kind.PolyphonicKeyPressure;
        res[0x3] = midi.ChannelMessage.Kind.ControlChange;
        res[0x4] = midi.ChannelMessage.Kind.ProgramChange;
        res[0x5] = midi.ChannelMessage.Kind.ChannelPressure;
        res[0x6] = midi.ChannelMessage.Kind.PitchBendChange;
        break :blk res;
    };
};

/// A wrapper for the StreamingChannelMessageDecoder. Accepts a slice of bytes which can be iterated
/// to get all midi channel messages in these bytes.
pub const ChannelMessageDecoder = struct {
    stream: StreamingChannelMessageDecoder,
    bytes: []const u8,
    i: usize,

    pub fn init(bytes: []const u8) ChannelMessageDecoder {
        return ChannelMessageDecoder{
            .stream = StreamingChannelMessageDecoder.init(),
            .bytes = bytes,
            .i = 0,
        };
    }

    pub fn next(iter: *ChannelMessageDecoder) !?midi.ChannelMessage {
        while (iter.i < iter.bytes.len) {
            defer iter.i += 1;
            if (try iter.stream.feed(iter.bytes[iter.i])) |message|
                return message;
        }

        try iter.stream.done();
        return null;
    }
};

/// Accepts input one byte at a time and returns midi system messages as they are decoded.
///
/// For a non-byte based wrapper, consider using SystemMessageDecoder instead.
pub const StreamingSystemMessageDecoder = struct {
    const State = union(enum) {
        Status: void,

        SystemValue1: SystemMessage(0),
        SystemValue2: SystemMessage(1),

        SystemExclusive: void,

        fn SystemMessage(comptime count: usize) type {
            return struct {
                kind: midi.SystemMessage.Kind,
                values: [count]u7,
            };
        }
    };

    state: State,

    pub fn init() StreamingSystemMessageDecoder {
        return StreamingSystemMessageDecoder{ .state = State.Status };
    }

    fn feed(stream: *StreamingSystemMessageDecoder, b: u8) !?midi.SystemMessage {
        switch (stream.state) {
            State.Status => {
                const status_byte = statusByte(b) orelse return error.ExpectedStatusByte;
                const upper = @truncate(u3, b >> 4);
                const lower = @truncate(u4, b);

                if (upper != 0b111)
                    return error.InvalidSystemMessage;

                const kind = system_message_table[lower];
                switch (kind) {
                    midi.SystemMessage.Kind.ExclusiveStart => {
                        stream.state = State.SystemExclusive;
                        return midi.SystemMessage{ .ExclusiveStart = midi.SystemMessage.ExclusiveStart{ .data = "" } };
                    },
                    midi.SystemMessage.Kind.MidiTimeCodeQuarterFrame,
                    midi.SystemMessage.Kind.SongPositionPointer,
                    midi.SystemMessage.Kind.SongSelect,
                    => {
                        stream.state = State{
                            .SystemValue1 = State.SystemMessage(0){
                                .kind = kind,
                                .values = []u7{},
                            },
                        };
                        return null;
                    },

                    midi.SystemMessage.Kind.Undefined => return midi.SystemMessage{ .Undefined = {} },
                    midi.SystemMessage.Kind.TuneRequest => return midi.SystemMessage{ .TuneRequest = {} },
                    midi.SystemMessage.Kind.TimingClock => return midi.SystemMessage{ .TimingClock = {} },
                    midi.SystemMessage.Kind.Start => return midi.SystemMessage{ .Start = {} },
                    midi.SystemMessage.Kind.Continue => return midi.SystemMessage{ .Continue = {} },
                    midi.SystemMessage.Kind.Stop => return midi.SystemMessage{ .Stop = {} },
                    midi.SystemMessage.Kind.ActiveSensing => return midi.SystemMessage{ .ActiveSensing = {} },
                    midi.SystemMessage.Kind.Reset => return midi.SystemMessage{ .Reset = {} },

                    midi.SystemMessage.Kind.ExclusiveEnd => return error.DanglingExclusiveEnd,
                }
            },

            State.SystemValue1 => |msg| {
                const value = math.cast(u7, b) catch return error.InvalidSystemMessage;

                stream.state = State.Status;
                switch (msg.kind) {
                    midi.SystemMessage.Kind.SongPositionPointer => {
                        stream.state = State{
                            .SystemValue2 = State.SystemMessage(1){
                                .kind = msg.kind,
                                .values = []u7{value},
                            },
                        };
                        return null;
                    },
                    midi.SystemMessage.Kind.MidiTimeCodeQuarterFrame => return midi.SystemMessage{
                        .MidiTimeCodeQuarterFrame = midi.SystemMessage.MidiTimeCodeQuarterFrame{
                            .message_type = @intCast(u3, value >> 4),
                            .values = @truncate(u4, value),
                        },
                    },
                    midi.SystemMessage.Kind.SongSelect => return midi.SystemMessage{
                        .SongSelect = midi.SystemMessage.SongSelect{ .sequence = value },
                    },
                    else => unreachable,
                }
            },
            State.SystemValue2 => |msg| {
                const value = math.cast(u7, b) catch return error.InvalidSystemMessage;

                stream.state = State.Status;
                switch (msg.kind) {
                    midi.SystemMessage.Kind.SongPositionPointer => return midi.SystemMessage{
                        .SongPositionPointer = midi.SystemMessage.SongPositionPointer{ .beats = u14(msg.values[0]) | u14(value) << 7 },
                    },
                    else => unreachable,
                }
            },

            State.SystemExclusive => |msg| {
                const status_byte = statusByte(b) orelse return null;
                const upper = @truncate(u3, b >> 4);
                const lower = @truncate(u4, b);

                if (upper != 0b111)
                    return error.InvalidSystemMessage;
                if (system_message_table[lower] != midi.SystemMessage.Kind.ExclusiveEnd)
                    return error.DanglingExclusiveStart;

                stream.state = State.Status;
                return midi.SystemMessage{ .ExclusiveEnd = {} };
            },
        }
    }

    pub fn reset(stream: *StreamingSystemMessageDecoder) void {
        stream.state = State{ .Status = void{} };
    }

    pub fn done(stream: *StreamingSystemMessageDecoder) !void {
        switch (stream.state) {
            State.Status => {
                stream.reset();
                return;
            },
            else => return error.InvalidSystemMessage,
        }
    }

    const system_message_table = blk: {
        var res = []midi.SystemMessage.Kind{midi.SystemMessage.Kind.Undefined} ** (math.maxInt(u4) + 1);
        res[0x0] = midi.SystemMessage.Kind.ExclusiveStart;
        res[0x1] = midi.SystemMessage.Kind.MidiTimeCodeQuarterFrame;
        res[0x2] = midi.SystemMessage.Kind.SongPositionPointer;
        res[0x3] = midi.SystemMessage.Kind.SongSelect;
        res[0x6] = midi.SystemMessage.Kind.TuneRequest;
        res[0x7] = midi.SystemMessage.Kind.ExclusiveEnd;
        res[0x8] = midi.SystemMessage.Kind.TimingClock;
        res[0xA] = midi.SystemMessage.Kind.Start;
        res[0xB] = midi.SystemMessage.Kind.Continue;
        res[0xC] = midi.SystemMessage.Kind.Stop;
        res[0xE] = midi.SystemMessage.Kind.ActiveSensing;
        res[0xF] = midi.SystemMessage.Kind.Reset;
        break :blk res;
    };
};

/// A wrapper for the StreamingSystemMessageDecoder. Accepts a slice of bytes which can be iterated
/// to get all midi system messages in these bytes.
pub const SystemMessageDecoder = struct {
    stream: StreamingSystemMessageDecoder,
    bytes: []const u8,
    i: usize,

    pub fn init(bytes: []const u8) SystemMessageDecoder {
        return SystemMessageDecoder{
            .stream = StreamingSystemMessageDecoder.init(),
            .bytes = bytes,
            .i = 0,
        };
    }

    pub fn next(iter: *SystemMessageDecoder) !?midi.SystemMessage {
        while (iter.i < iter.bytes.len) {
            defer iter.i += 1;
            if (try iter.stream.feed(iter.bytes[iter.i])) |message|
                return message;
        }

        try iter.stream.done();
        return null;
    }
};

/// Accepts input one byte at a time and returns midi messages as they are decoded.
///
/// For a non-byte based wrapper, consider using MessageDecoder instead.
pub const StreamingMessageDecoder = struct {
    const State = union(enum) {
        Status: void,
        Channel: StreamingChannelMessageDecoder,
        System: StreamingSystemMessageDecoder,
    };

    state: State,

    pub fn init() StreamingMessageDecoder {
        return StreamingMessageDecoder{ .state = State.Status };
    }

    fn feed(stream: *StreamingMessageDecoder, b: u8) !?midi.Message {
        repeat: while (true) switch (stream.state) {
            State.Status => {
                const statut_byte = statusByte(b) orelse return error.ExpectedStatusByte;

                var channel_decoder = StreamingChannelMessageDecoder.init();
                if (channel_decoder.feed(b)) |m_message| {
                    stream.state = State{ .Channel = channel_decoder };
                    if (m_message) |message|
                        return midi.Message{ .Channel = message };

                    return null;
                } else |_| {}

                var system_decoder = StreamingSystemMessageDecoder.init();
                if (system_decoder.feed(b)) |m_message| {
                    stream.state = State{ .System = system_decoder };
                    if (m_message) |message|
                        return midi.Message{ .System = message };

                    return null;
                } else |_| {}

                return error.InvalidMessage;
            },
            State.Channel => |*decoder| {
                const m_message = decoder.feed(b) catch {
                    try decoder.done();
                    stream.state = State.Status;
                    continue :repeat;
                };
                if (m_message) |message|
                    return midi.Message{ .Channel = message };

                return null;
            },
            State.System => |*decoder| {
                const m_message = decoder.feed(b) catch {
                    try decoder.done();
                    stream.state = State.Status;
                    continue :repeat;
                };
                if (m_message) |message|
                    return midi.Message{ .System = message };

                return null;
            },
        };
    }

    pub fn reset(stream: *StreamingMessageDecoder) void {
        stream.state = State{ .Status = void{} };
    }

    pub fn done(stream: *StreamingMessageDecoder) !void {
        switch (stream.state) {
            State.Status => stream.reset(),
            State.Channel => |*decoder| {
                try decoder.done();
                stream.reset();
            },
            State.System => |*decoder| {
                try decoder.done();
                stream.reset();
            },
        }
    }
};

/// A wrapper for the StreamingMessageDecoder. Accepts a slice of bytes which can be iterated
/// to get all midi system messages in these bytes.
pub const MessageDecoder = struct {
    stream: StreamingMessageDecoder,
    bytes: []const u8,
    i: usize,

    pub fn init(bytes: []const u8) MessageDecoder {
        return MessageDecoder{
            .stream = StreamingMessageDecoder.init(),
            .bytes = bytes,
            .i = 0,
        };
    }

    pub fn next(iter: *MessageDecoder) !?midi.Message {
        while (iter.i < iter.bytes.len) {
            defer iter.i += 1;
            if (try iter.stream.feed(iter.bytes[iter.i])) |message|
                return message;
        }

        try iter.stream.done();
        return null;
    }
};

/// Accepts a slice of bytes which can be iterated to get all midi chunks and their data in these
/// bytes.
pub const ChunkIterator = struct {
    bytes: []const u8,
    i: usize,

    pub fn init(bytes: []const u8) ChunkIterator {
        return ChunkIterator{
            .bytes = bytes,
            .i = 0,
        };
    }

    pub fn next(iter: *ChunkIterator) !?midi.file.Chunk {
        if (iter.i == iter.bytes.len)
            return null;
        if (iter.bytes.len - iter.i < 8)
            return error.OutOfBounds;

        const info_bytes = @ptrCast(*const [8]u8, iter.bytes[iter.i..][0..8].ptr).*;
        const info = decode.chunkInfo(info_bytes);
        iter.i += info_bytes.len;

        return midi.file.Chunk{
            .info = info,
            .data = try iter.chunkData(info),
        };
    }

    fn chunkData(iter: *ChunkIterator, header: midi.file.Chunk.Info) ![]const u8 {
        const start = iter.i;
        const end = iter.i + header.len;
        if (iter.bytes.len < end)
            return error.OutOfBounds;

        defer iter.i += header.len;
        return iter.bytes[start..end];
    }
};

/// Decodes 8 bytes into a midi.file.Chunk.Info.
pub fn chunkInfo(bytes: [8]u8) midi.file.Chunk.Info {
    return midi.file.Chunk.Info{
        .kind = @ptrCast(*const [4]u8, bytes[0..4].ptr).*,
        .len = mem.readIntBig(u32, @ptrCast(*const [4]u8, bytes[4..8].ptr)),
    };
}

/// Decodes 14 bytes into a midi.file.Header. This wraps decode.chunkInfo and validates that the
/// file header is correct.
///
/// TODO: "We may decide to define other format IDs to support other structures. A program encountering
///        an unknown format ID may still read other MTrk chunks it finds from the file, as format 1 or
///        2, if its user can make sense of them and arrange them into some other structure if
///        appropriate. Also, more parameters may be added to the MThd chunk in the future: it is
///        important to read and honor the length, even if it is longer than 6." -The Midi Spec
pub fn fileHeader(bytes: [14]u8) !midi.file.Header {
    const info = decode.chunkInfo(@ptrCast(*const [8]u8, bytes[0..8].ptr).*);
    const format = mem.readIntBig(u16, @ptrCast(*const [2]u8, bytes[8..10].ptr));
    const ntrks = mem.readIntBig(u16, @ptrCast(*const [2]u8, bytes[10..12].ptr));
    const division = mem.readIntBig(u16, @ptrCast(*const [2]u8, bytes[12..14].ptr));

    if (!mem.eql(u8, info.kind, "MThd"))
        return error.InvalidHeaderKind;
    if (info.len != 6)
        return error.InvalidHeaderLength;
    if (format > 2)
        return error.InvalidHeaderFormat;

    return midi.file.Header{
        .format = @intToEnum(midi.file.Header.Format, @intCast(u2, format)),
        .tracks = switch (@intToEnum(midi.file.Header.Format, @intCast(u2, format))) {
            midi.file.Header.Format.SingleMultiChannelTrack => blk: {
                if (ntrks != 1)
                    return error.InvalidHeaderNumberOfTracks;
                break :blk ntrks;
            },
            midi.file.Header.Format.ManySimultaneousTracks => ntrks,
            midi.file.Header.Format.ManyIndependentTracks => ntrks,
        },
        .division = switch (@truncate(u1, division >> 15)) {
            0 => midi.file.Header.Division{ .TicksPerQuarterNote = @truncate(u15, division) },
            1 => midi.file.Header.Division{
                .SubdivisionsOfSecond = midi.file.Header.Division.SubdivisionsOfSecond{
                    .smpte_format = @bitCast(i8, @truncate(u8, division >> 8)),
                    .ticks_per_frame = @truncate(u8, division),
                },
            },
        },
    };
}

/// Accepts input one byte at a time and returns variable-length integers as they are decoded.
pub const StreamingVariableLengthIntDecoder = struct {
    res: u28,

    pub fn init() StreamingVariableLengthIntDecoder {
        return StreamingVariableLengthIntDecoder{ .res = 0 };
    }

    pub fn feed(decoder: *StreamingVariableLengthIntDecoder, b: u8) !?u28 {
        const is_last = @truncate(u1, b >> 7) == 0;
        const value = @truncate(u7, b);
        decoder.res = try math.mul(u28, decoder.res, math.maxInt(u7) + 1);
        decoder.res = try math.add(u28, decoder.res, value);

        if (!is_last)
            return null;

        defer decoder.res = 0;
        return decoder.res;
    }
};

/// Decodes a variable-length integer and returns it, and its the length in bytes.
pub fn variableLengthInt(bytes: []const u8) !struct {
    res: u28,
    len: usize,
} {
    const Result = @typeOf(variableLengthInt).ReturnType.Payload;
    var decoder = StreamingVariableLengthIntDecoder.init();
    for (bytes) |b, i| {
        if (try decoder.feed(b)) |res| {
            return Result{
                .res = res,
                .len = i + 1,
            };
        }
    }

    return error.InputTooSmall;
}

/// Accepts input one byte at a time and returns midi meta events as they are decoded.
///
/// For a non-byte based wrapper, consider using MetaEventDecoder instead.
pub const StreamingMetaEventDecoder = struct {
    const State = union(enum) {
        Status: void,
        Kind: void,
        Length: Length,
        Rest: u28,

        const Length = struct {
            kind: u8,
            decoder: StreamingVariableLengthIntDecoder,
        };
    };

    state: State,

    pub fn init() StreamingMetaEventDecoder {
        return StreamingMetaEventDecoder{ .state = State.Status };
    }

    fn feed(stream: *StreamingMetaEventDecoder, b: u8) !?midi.file.MetaEvent {
        repeat: while (true) switch (stream.state) {
            State.Status => {
                if (b != 0xFF)
                    return error.InvalidMetaEvent;

                stream.state = State.Kind;
                return null;
            },
            State.Kind => {
                stream.state = State{
                    .Length = State.Length{
                        .kind = b,
                        .decoder = StreamingVariableLengthIntDecoder.init(),
                    },
                };
                return null;
            },
            @TagType(State).Length => |*ctx| {
                const length = (try ctx.decoder.feed(b)) orelse return null;
                const kind = ctx.kind;
                stream.state = State{ .Rest = length };
                return midi.file.MetaEvent{
                    .data = null,
                    .len = length,
                    .kind = meta_event_table[kind],
                };
            },
            State.Rest => |rest| {
                if (rest == 0) {
                    stream.state = State.Status;
                    continue :repeat;
                }

                stream.state = State{ .Rest = rest - 1 };
                return null;
            },
        };
    }

    pub fn reset(stream: *StreamingMetaEventDecoder) void {
        stream.state = State{ .Status = void{} };
    }

    pub fn done(stream: *StreamingMetaEventDecoder) !void {
        switch (stream.state) {
            State.Status => stream.reset(),
            State.Rest => |rest| {
                if (rest != 0)
                    return error.InvalidMetaEvent;

                stream.reset();
            },
            else => return error.InvalidMetaEvent,
        }
    }

    const meta_event_table = blk: {
        var res = []midi.file.MetaEvent.Kind{midi.file.MetaEvent.Kind.Undefined} ** (math.maxInt(u7) + 1);
        res[0x00] = midi.file.MetaEvent.Kind.SequenceNumber;
        res[0x01] = midi.file.MetaEvent.Kind.TextEvent;
        res[0x02] = midi.file.MetaEvent.Kind.CopyrightNotice;
        res[0x03] = midi.file.MetaEvent.Kind.TrackName;
        res[0x04] = midi.file.MetaEvent.Kind.InstrumentName;
        res[0x05] = midi.file.MetaEvent.Kind.Luric;
        res[0x06] = midi.file.MetaEvent.Kind.Marker;
        res[0x20] = midi.file.MetaEvent.Kind.MidiChannelPrefix;
        res[0x2F] = midi.file.MetaEvent.Kind.EndOfTrack;
        res[0x51] = midi.file.MetaEvent.Kind.SetTempo;
        res[0x54] = midi.file.MetaEvent.Kind.SmpteOffset;
        res[0x58] = midi.file.MetaEvent.Kind.TimeSignature;
        res[0x59] = midi.file.MetaEvent.Kind.KeySignature;
        res[0x7F] = midi.file.MetaEvent.Kind.SequencerSpecificMetaEvent;
        break :blk res;
    };
};

/// A wrapper for the StreamingMetaEventDecoder. Accepts a slice of bytes which can be iterated
/// to get all midi meta events in these bytes.
pub const MetaEventDecoder = struct {
    stream: StreamingMetaEventDecoder,
    bytes: []const u8,
    i: usize,

    pub fn init(bytes: []const u8) MetaEventDecoder {
        return MetaEventDecoder{
            .stream = StreamingMetaEventDecoder.init(),
            .bytes = bytes,
            .i = 0,
        };
    }

    pub fn next(iter: *MetaEventDecoder) !?midi.file.MetaEvent {
        var event = while (iter.i < iter.bytes.len) {
            defer iter.i += 1;
            if (try iter.stream.feed(iter.bytes[iter.i])) |event|
                break event;
        } else {
            try iter.stream.done();
            return null;
        };

        const start = iter.i;
        if (iter.bytes.len < start + event.len)
            return error.InvalidMetaEvent;

        while (iter.i < start + event.len) : (iter.i += 1) {
            // Should never error, and never return a value while we iterate over the data
            // of the event;
            if (iter.stream.feed(iter.bytes[iter.i]) catch unreachable) |_|
                unreachable;
        }

        event.data = iter.bytes[start..].ptr;
        return event;
    }
};
