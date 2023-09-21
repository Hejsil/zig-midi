# 【Zig】乐器数字接口-Midi

MIDI 是“乐器数字接口”的缩写，是一种用于音乐设备之间通信的协议。

```bash
.
├── LICENSE
├── ReadMe.md
├── build.zig
├── example
│   └── midi_file_to_text_stream.zig
├── midi
│   ├── decode.zig
│   ├── encode.zig
│   ├── file.zig
│   └── test.zig
├── midi.zig
```

## 基础

在 MIDI 协议中，`0xFF` 是一个特定的状态字节，用来表示元事件（Meta Event）的开始。元事件是 MIDI 文件结构中的一种特定消息，通常不用于实时音频播放，但它们包含有关 MIDI 序列的元数据，例如序列名称、版权信息、歌词、时间标记、速度（BPM）更改等。

以下是一些常见的元事件类型及其关联的 `0xFF` 后的字节：

- `0x00`: 序列号 (Sequence Number)
- `0x01`: 文本事件 (Text Event)
- `0x02`: 版权通知 (Copyright Notice)
- `0x03`: 序列/曲目名称 (Sequence/Track Name)
- `0x04`: 乐器名称 (Instrument Name)
- `0x05`: 歌词 (Lyric)
- `0x06`: 标记 (Marker)
- `0x07`: 注释 (Cue Point)
- `0x20`: MIDI Channel Prefix
- `0x21`: End of Track (通常跟随值`0x00`，表示轨道的结束)
- `0x2F`: Set Tempo (设定速度，即每分钟的四分音符数)
- `0x51`: SMPTE Offset
- `0x54`: 拍号 (Time Signature)
- `0x58`: 调号 (Key Signature)
- `0x59`: Sequencer-Specific Meta-event

例如，当解析 MIDI 文件时，如果遇到字节 `0xFF 0x03`，那么接下来的字节将表示序列或曲目名称。

在实际的 MIDI 文件中，元事件的具体结构是这样的：

1. `0xFF`: 元事件状态字节。
2. 元事件类型字节，例如上面列出的 `0x00`, `0x01` 等。
3. 长度字节（或一系列字节），表示该事件数据的长度。
4. 事件数据本身。

元事件主要存在于 MIDI 文件中，特别是在标准 MIDI 文件 (SMF) 的上下文中。在实时 MIDI 通信中，元事件通常不会被发送，因为它们通常不会影响音乐的实际播放。

## Midi.zig

本文件主要是处理 MIDI 消息的模块，为处理 MIDI 消息提供了基础结构和函数。

```zig
const std = @import("std");

const mem = std.mem;

const midi = @This();

pub const decode = @import("midi/decode.zig");
pub const encode = @import("midi/encode.zig");
pub const file = @import("midi/file.zig");

pub const File = file.File;

test "midi" {
    _ = @import("midi/test.zig");
    _ = decode;
    _ = file;
}

pub const Message = struct {
    status: u7,
    values: [2]u7,

    pub fn kind(message: Message) Kind {
        const _kind = @as(u3, @truncate(message.status >> 4));
        const _channel = @as(u4, @truncate(message.status));
        return switch (_kind) {
            0x0 => Kind.NoteOff,
            0x1 => Kind.NoteOn,
            0x2 => Kind.PolyphonicKeyPressure,
            0x3 => Kind.ControlChange,
            0x4 => Kind.ProgramChange,
            0x5 => Kind.ChannelPressure,
            0x6 => Kind.PitchBendChange,
            0x7 => switch (_channel) {
                0x0 => Kind.ExclusiveStart,
                0x1 => Kind.MidiTimeCodeQuarterFrame,
                0x2 => Kind.SongPositionPointer,
                0x3 => Kind.SongSelect,
                0x6 => Kind.TuneRequest,
                0x7 => Kind.ExclusiveEnd,
                0x8 => Kind.TimingClock,
                0xA => Kind.Start,
                0xB => Kind.Continue,
                0xC => Kind.Stop,
                0xE => Kind.ActiveSensing,
                0xF => Kind.Reset,

                0x4, 0x5, 0x9, 0xD => Kind.Undefined,
            },
        };
    }

    pub fn channel(message: Message) ?u4 {
        const _kind = message.kind();
        const _channel = @as(u4, @truncate(message.status));
        switch (_kind) {
            // Channel events
            .NoteOff,
            .NoteOn,
            .PolyphonicKeyPressure,
            .ControlChange,
            .ProgramChange,
            .ChannelPressure,
            .PitchBendChange,
            => return _channel,

            // System events
            .ExclusiveStart,
            .MidiTimeCodeQuarterFrame,
            .SongPositionPointer,
            .SongSelect,
            .TuneRequest,
            .ExclusiveEnd,
            .TimingClock,
            .Start,
            .Continue,
            .Stop,
            .ActiveSensing,
            .Reset,
            => return null,

            .Undefined => return null,
        }
    }

    pub fn value(message: Message) u14 {
        // TODO: Is this the right order according to the midi spec?
        return @as(u14, message.values[0]) << 7 | message.values[1];
    }

    pub fn setValue(message: *Message, v: u14) void {
        message.values = .{
            @as(u7, @truncate(v >> 7)),
            @as(u7, @truncate(v)),
        };
    }

    pub const Kind = enum {
        // Channel events
        NoteOff,
        NoteOn,
        PolyphonicKeyPressure,
        ControlChange,
        ProgramChange,
        ChannelPressure,
        PitchBendChange,

        // System events
        ExclusiveStart,
        MidiTimeCodeQuarterFrame,
        SongPositionPointer,
        SongSelect,
        TuneRequest,
        ExclusiveEnd,
        TimingClock,
        Start,
        Continue,
        Stop,
        ActiveSensing,
        Reset,

        Undefined,
    };
};
```

这定义了一个名为 Message 的公共结构，表示 MIDI 消息，为处理 MIDI 消息提供了基础结构和函数。它包含三个字段：状态、值和几个公共方法。

- kind 函数：根据 MIDI 消息的状态码确定消息的种类。
- channel 函数：根据消息的种类返回 MIDI 通道，如果消息不包含通道信息则返回 null。
- value 和 setValue 函数：用于获取和设置 MIDI 消息的值字段。
- Kind 枚举：定义了 MIDI 消息的所有可能种类，包括通道事件和系统事件。

### midi消息结构

我们需要先了解 MIDI 消息的一些背景。

在 MIDI 协议中，某些消息的值可以跨越两个7位的字节，这是因为 MIDI 协议不使用每个字节的最高位（这通常被称为状态位）。这意味着每个字节只使用它的低7位来携带数据。因此，当需要发送一个大于7位的值时（比如14位），它会被拆分成两个7位的字节。

`setValue` 这个函数做的事情是将一个14位的值（`u14`）拆分为两个7位的值，并将它们设置到 `message.values` 中。

以下是具体步骤的解释：

1. **获取高7位**：`v >> 7` 把14位的值右移7位，这样我们就得到了高7位的值。
   
2. **截断并转换**：`@truncate(v >> 7)` 截断高7位的值，确保它是7位的。`@as(u7, @truncate(v >> 7))` 确保这个值是 `u7` 类型，即一个7位的无符号整数。

3. **获取低7位**：`@truncate(v)` 直接截断原始值，保留低7位。

4. **设置值**：`message.values = .{ ... }` 将这两个7位的值设置到 `message.values` 中。

### 事件

针对事件，我们看enum。

```zig
    pub const Kind = enum {
        // Channel events
        NoteOff,
        NoteOn,
        PolyphonicKeyPressure,
        ControlChange,
        ProgramChange,
        ChannelPressure,
        PitchBendChange,

        // System events
        ExclusiveStart,
        MidiTimeCodeQuarterFrame,
        SongPositionPointer,
        SongSelect,
        TuneRequest,
        ExclusiveEnd,
        TimingClock,
        Start,
        Continue,
        Stop,
        ActiveSensing,
        Reset,

        Undefined,
    };

```

这段代码定义了一个名为 `Kind` 的公共枚举类型（`enum`），它描述了 MIDI 中可能的事件种类。每个枚举成员都代表 MIDI 协议中的一个特定事件。这些事件分为两大类：频道事件（Channel events）和系统事件（System events）。

这个 `Kind` 枚举为处理 MIDI 消息提供了一个结构化的方法，使得在编程时可以清晰地引用特定的 MIDI 事件，而不是依赖于原始的数字或其他编码。

以下是对每个枚举成员的简要说明：

#### 频道事件 (Channel events)

1. **NoteOff**：这是一个音符结束事件，表示某个音符不再播放。
   
2. **NoteOn**：这是一个音符开始事件，表示开始播放某个音符。
   
3. **PolyphonicKeyPressure**：多声道键盘压力事件，表示对特定音符的压力或触摸敏感度的变化。
   
4. **ControlChange**：控制变更事件，用于发送如音量、平衡等控制信号。
   
5. **ProgramChange**：程序（音色）变更事件，用于改变乐器的音色。
   
6. **ChannelPressure**：频道压力事件，与多声道键盘压力相似，但它适用于整个频道，而不是特定音符。
   
7. **PitchBendChange**：音高弯曲变更事件，表示音符音高的上升或下降。

#### 系统事件 (System events)

1. **ExclusiveStart**：独占开始事件，标志着一个独占消息序列的开始。
   
2. **MidiTimeCodeQuarterFrame**：MIDI 时间码四分之一帧，用于同步与其他设备。
   
3. **SongPositionPointer**：歌曲位置指针，指示序列器的当前播放位置。
   
4. **SongSelect**：歌曲选择事件，用于选择特定的歌曲或序列。
   
5. **TuneRequest**：调音请求事件，指示设备应进行自我调音。
   
6. **ExclusiveEnd**：独占结束事件，标志着一个独占消息序列的结束。
   
7. **TimingClock**：计时时钟事件，用于节奏的同步。
   
8. **Start**：开始事件，用于启动序列播放。
   
9. **Continue**：继续事件，用于继续暂停的序列播放。
   
10. **Stop**：停止事件，用于停止序列播放。
    
11. **ActiveSensing**：活动感知事件，是一种心跳信号，表示设备仍然在线并工作。
    
12. **Reset**：重置事件，用于将设备重置为其初始状态。

#### 其他

1. **Undefined**：未定义事件，可能表示一个未在此枚举中定义的或无效的 MIDI 事件。

## decode.zig

本文件是对MIDI文件的解码器, 提供了一组工具，可以从不同的输入源解析 MIDI 文件的各个部分。这样可以方便地读取和处理 MIDI 文件。

```zig
const midi = @import("../midi.zig");
const std = @import("std");

const debug = std.debug;
const io = std.io;
const math = std.math;
const mem = std.mem;

const decode = @This();

fn statusByte(b: u8) ?u7 {
    if (@as(u1, @truncate(b >> 7)) != 0)
        return @as(u7, @truncate(b));

    return null;
}

fn readDataByte(reader: anytype) !u7 {
    return math.cast(u7, try reader.readByte()) catch return error.InvalidDataByte;
}

pub fn message(reader: anytype, last_message: ?midi.Message) !midi.Message {
    var first_byte: ?u8 = try reader.readByte();
    const status_byte = if (statusByte(first_byte.?)) |status_byte| blk: {
        first_byte = null;
        break :blk status_byte;
    } else if (last_message) |m| blk: {
        if (m.channel() == null)
            return error.InvalidMessage;

        break :blk m.status;
    } else return error.InvalidMessage;

    const kind = @as(u3, @truncate(status_byte >> 4));
    const channel = @as(u4, @truncate(status_byte));
    switch (kind) {
        0x0, 0x1, 0x2, 0x3, 0x6 => return midi.Message{
            .status = status_byte,
            .values = [2]u7{
                math.cast(u7, first_byte orelse try reader.readByte()) catch return error.InvalidDataByte,
                try readDataByte(reader),
            },
        },
        0x4, 0x5 => return midi.Message{
            .status = status_byte,
            .values = [2]u7{
                math.cast(u7, first_byte orelse try reader.readByte()) catch return error.InvalidDataByte,
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
                        try readDataByte(reader),
                        0,
                    },
                },
                0x2 => return midi.Message{
                    .status = status_byte,
                    .values = [2]u7{
                        try readDataByte(reader),
                        try readDataByte(reader),
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

pub fn chunk(reader: anytype) !midi.file.Chunk {
    var buf: [8]u8 = undefined;
    try reader.readNoEof(&buf);
    return decode.chunkFromBytes(buf);
}

pub fn chunkFromBytes(bytes: [8]u8) midi.file.Chunk {
    return midi.file.Chunk{
        .kind = bytes[0..4].*,
        .len = mem.readIntBig(u32, bytes[4..8]),
    };
}

pub fn fileHeader(reader: anytype) !midi.file.Header {
    var buf: [14]u8 = undefined;
    try reader.readNoEof(&buf);
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

pub fn int(reader: anytype) !u28 {
    var res: u28 = 0;
    while (true) {
        const b = try reader.readByte();
        const is_last = @as(u1, @truncate(b >> 7)) == 0;
        const value = @as(u7, @truncate(b));
        res = try math.mul(u28, res, math.maxInt(u7) + 1);
        res = try math.add(u28, res, value);

        if (is_last)
            return res;
    }
}

pub fn metaEvent(reader: anytype) !midi.file.MetaEvent {
    return midi.file.MetaEvent{
        .kind_byte = try reader.readByte(),
        .len = try decode.int(reader),
    };
}

pub fn trackEvent(reader: anytype, last_event: ?midi.file.TrackEvent) !midi.file.TrackEvent {
    var peek_reader = io.peekStream(1, reader);
    var in_reader = peek_reader.reader();

    const delta_time = try decode.int(&in_reader);
    const first_byte = try in_reader.readByte();
    if (first_byte == 0xFF) {
        return midi.file.TrackEvent{
            .delta_time = delta_time,
            .kind = midi.file.TrackEvent.Kind{ .MetaEvent = try decode.metaEvent(&in_reader) },
        };
    }

    const last_midi_event = if (last_event) |e| switch (e.kind) {
        .MidiEvent => |m| m,
        .MetaEvent => null,
    } else null;

    peek_reader.putBackByte(first_byte) catch unreachable;
    return midi.file.TrackEvent{
        .delta_time = delta_time,
        .kind = midi.file.TrackEvent.Kind{ .MidiEvent = try decode.message(&in_reader, last_midi_event) },
    };
}

/// Decodes a midi file from a reader. Caller owns the returned value
///  (see: `midi.File.deinit`).
pub fn file(reader: anytype, allocator: *mem.Allocator) !midi.File {
    var chunks = std.ArrayList(midi.File.FileChunk).init(allocator);
    errdefer {
        (midi.File{
            .format = 0,
            .division = 0,
            .chunks = chunks.toOwnedSlice(),
        }).deinit(allocator);
    }

    const header = try decode.fileHeader(reader);
    const header_data = try allocator.alloc(u8, header.chunk.len - midi.file.Header.size);
    errdefer allocator.free(header_data);

    try reader.readNoEof(header_data);
    while (true) {
        const c = decode.chunk(reader) catch |err| switch (err) {
            error.EndOfStream => break,
            else => |e| return e,
        };

        const chunk_bytes = try allocator.alloc(u8, c.len);
        errdefer allocator.free(chunk_bytes);
        try reader.readNoEof(chunk_bytes);
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
```

1. statusByte: 解析 MIDI 消息的首个字节，来确定是否这是一个状态字节，还是一个数据字节。将一个字节 b 解码为一个 u7 类型的 MIDI 状态字节，如果字节 b 不是一个状态字节，则返回 null。换句话说，midi的消息是14位，如果高7位不为空，则是midi消息的状态字节。在 MIDI 协议中，消息的首个字节通常是状态字节，但也可能用之前的状态字节（这称为“运行状态”）来解释接下来的字节。因此，这段代码需要确定它是否读取了一个新的状态字节，或者它是否应该使用前一个消息的状态字节。
2. readDataByte: 从 reader 中读取并返回一个数据字节。如果读取的字节不符合数据字节的规定，则抛出 InvalidDataByte 错误。
3. message: 从 reader 读取并解码一个 MIDI 消息。如果读取的字节不能形成一个有效的 MIDI 消息，则抛出 InvalidMessage 错误。这是一个复杂的函数，涉及到解析 MIDI 消息的不同种类。
4. chunk，chunkFromBytes: 这两个函数从 reader 或直接从字节数组 bytes 中解析一个 MIDI 文件块头。
5. fileHeader, fileHeaderFromBytes: 这两个函数从 reader 或直接从字节数组 bytes 中解析一个 MIDI 文件头。
6. int: 从 reader 中解码一个可变长度的整数。
7. metaEvent: 从 reader 中解析一个 MIDI 元事件。
8. trackEvent: 从 reader 中解析一个 MIDI 轨道事件。它可以是 MIDI 消息或元事件。
9. file: 用于从 reader 解码一个完整的 MIDI 文件。它首先解码文件头，然后解码所有的文件块。这个函数会返回一个表示 MIDI 文件的结构体。

### message解析
```zig
const status_byte = if (statusByte(first_byte.?)) |status_byte| blk: {
    first_byte = null;
    break :blk status_byte;
} else if (last_message) |m| blk: {
    if (m.channel() == null)
        return error.InvalidMessage;

    break :blk m.status;
} else return error.InvalidMessage;
```

这段代码的目的是确定 MIDI 消息的状态字节。它可以是从 `reader` 读取的当前字节，或者是从前一个 MIDI 消息中获取的。这样做是为了支持 MIDI 协议中的“运行状态”，在该协议中，连续的 MIDI 消息可能不会重复状态字节。

1. `const status_byte = ...;`: 这是一个常量声明。`status_byte` 将保存 MIDI 消息的状态字节。

2. `if (statusByte(first_byte.?)) |status_byte| blk: { ... }`:
- `statusByte(first_byte.?)`: 这是一个函数调用，它检查 `first_byte` 是否是一个有效的状态字节。`.?` 是可选值的语法，它用于解包 `first_byte` 的值（它是一个可选的 `u8`，可以是 `u8` 或 `null`）。
- `|status_byte|`: 如果 `statusByte` 函数返回一个有效的状态字节，则这个值会被捕获并赋给这里的 `status_byte` 变量。
- `blk:`: 这是一个匿名代码块的标签。Zig 允许你给代码块命名，这样你可以从该代码块中跳出。
- `{ ... }`: 这是一个代码块。在这里，`first_byte` 被设置为 `null`，然后使用 `break :blk status_byte;` 来结束此代码块，并将 `status_byte` 的值赋给外部的 `status_byte` 常量。

3. `else if (last_message) |m| blk: { ... }`:
- 如果 `first_byte` 不是一个状态字节，代码会检查是否存在一个名为 `last_message` 的前一个 MIDI 消息。
- `|m|`: 如果 `last_message` 存在（即它不是 `null`），它的值将被捕获并赋给 `m`。
- `{ ... }`: 这是另一个代码块。在这里，它检查 `m` 是否有一个通道。如果没有，则返回一个 `InvalidMessage` 错误。否则，使用 `break :blk m.status;` 结束此代码块，并将 `m.status` 的值赋给外部的 `status_byte` 常量。

4. `else return error.InvalidMessage;`: 如果 `first_byte` 不是状态字节，并且不存在前一个消息，那么返回一个 `InvalidMessage` 错误。


## encode.zig

本文件用于将 MIDI 数据结构编码为其对应的二进制形式。具体来说，它是将内存中的 MIDI 数据结构转换为 MIDI 文件格式的二进制数据。

```zig
const midi = @import("../midi.zig");
const std = @import("std");

const debug = std.debug;
const io = std.io;
const math = std.math;
const mem = std.mem;

const encode = @This();

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
    var fbs = io.fixedBufferStream(&buf).writer();

    // TODO: Can we find a way to not encode this in reverse order and then flipping the bytes?
    while (tmp != 0 or is_first) : (is_first = false) {
        fbs.writeByte(@as(u7, @truncate(tmp)) | (@as(u8, 1 << 7) * @intFromBool(!is_first))) catch
            unreachable;
        tmp >>= 7;
    }
    mem.reverse(u8, fbs.context.getWritten());
    try writer.writeAll(fbs.context.getWritten());
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
            .len = @as(u32, @intCast(midi.file.Header.size + f.header_data.len)),
        },
        .format = f.format,
        .tracks = @as(u16, @intCast(f.chunks.len)),
        .division = f.division,
    }));
    try writer.writeAll(f.header_data);

    for (f.chunks) |c| {
        try writer.writeAll(&encode.chunkToBytes(.{
            .kind = c.kind,
            .len = @as(u32, @intCast(c.bytes.len)),
        }));
        try writer.writeAll(c.bytes);
    }
}
```

- message 函数：这是将 MIDI 消息编码为字节序列的函数, 将单个 MIDI 消息编码为其二进制形式。根据消息类型，这会向提供的 writer 写入一个或多个字节。若消息需要状态字节，并且不同于前一个消息的状态，函数会写入状态字节。接着，根据消息的种类，函数会写入所需的数据字节。

- chunkToBytes 函数：将 MIDI 文件的块（Chunk）信息转换为 8 字节的二进制数据。这 8 字节中包括 4 字节的块类型和 4 字节的块长度。它复制块类型到前 4 个字节，然后写入块的长度到后 4 个字节，并返回结果。

- fileHeaderToBytes 函数：编码 MIDI 文件的头部为 14 字节的二进制数据。这 14 字节包括块信息、文件格式、轨道数量和时间划分信息。

- int 函数：将一个整数编码为 MIDI 文件中的可变长度整数格式。在 MIDI 文件中，某些整数值使用一种特殊的编码格式，可以根据整数的大小变化长度。

- metaEvent 函数：将 MIDI 元事件（Meta Event）编码为二进制数据, 这包括事件的类型和长度。具体则是编码一个元事件，首先写入其种类字节，然后是其长度。

- trackEvent 函数：编码轨道事件。轨道事件可以是元事件或 MIDI 事件，函数首先写入事件之间的时间差（delta 时间），然后根据事件类型（MetaEvent 或 MidiEvent）编码事件内容。

- file 函数：这是主函数，用于将整个 MIDI 文件数据结构编码为其二进制形式。它首先编码文件头，然后循环编码每个块和块中的事件。


### int函数

```zig

pub fn int(writer: anytype, i: u28) !void {
    var tmp = i;
    var is_first = true;
    var buf: [4]u8 = undefined;
    var fbs = io.fixedBufferStream(&buf).writer();

    // TODO: Can we find a way to not encode this in reverse order and then flipping the bytes?
    while (tmp != 0 or is_first) : (is_first = false) {
        fbs.writeByte(@as(u7, @truncate(tmp)) | (@as(u8, 1 << 7) * @intFromBool(!is_first))) catch
            unreachable;
        tmp >>= 7;
    }
    mem.reverse(u8, fbs.context.getWritten());
    try writer.writeAll(fbs.context.getWritten());
}
```

这个函数`int`用于编码一个整数为MIDI文件中的可变长度整数格式。在MIDI文件中，许多值（如delta时间）使用这种可变长度编码。

详细地解析这个函数的每一步：

1. **参数定义**:
- `writer`: 任意类型的写入对象，通常是一种流或缓冲区，可以向其写入数据。
- `i`: 一个最多28位的无符号整数（`u28`），即要编码的值。

1. **局部变量初始化**:
- `tmp`：作为输入整数的临时副本。
- `is_first`：一个布尔值，用于指示当前处理的是否是整数的第一个字节。
- `buf`: 定义一个4字节的缓冲区。因为最大的`u28`值需要4个字节的可变长度编码。
- `fbs`：使用`io.fixedBufferStream`创建一个固定缓冲区的流，并获取它的写入器。

1. **循环进行可变长度编码**:
- 循环条件是：直到`tmp`为0并且不是第一个字节。
- `: (is_first = false)` 是一个后置条件，每次循环结束后都会执行。
- `(@as(u8, 1 << 7) * @intFromBool(!is_first))`
  - `1 << 7`: 这个操作是左移操作。数字1在二进制中表示为`0000 0001`。当你将它左移7位时，你得到`1000 0000`，这在十进制中等于 `128`。
  - `@intFromBool(!is_first)`: 这是将上一步得到的布尔值转换为整数。在许多编程语言中，true通常被视为1，false被视为0。在Zig中，这种转换不是隐式的，所以需要用`@intFromBool()`函数来进行转换
  - `@as(u8, 1 << 7)`: 这里是将数字128（从1 << 7得到）显式地转换为一个8位无符号整数。
  - `(@as(u8, 1 << 7) * @intFromBool(!is_first))`: 将转换后的数字128与从布尔转换得到的整数（0或1）相乘。如果`is_first`为`true`（即这是第一个字节），那么整个表达式的值为0。如果`is_first为false`（即这不是第一个字节），那么整个表达式的值为128（`1000 0000` in 二进制）。
  - 这种结构在MIDI变长值的编码中很常见。MIDI变长值的每个字节的最高位被用作“继续”位，指示是否有更多的字节跟随。如果最高位是1，那么表示还有更多的字节；如果是0，表示这是最后一个字节。
- 在每次迭代中，它提取`tmp`的最后7位并将其编码为一个字节，最高位根据是否是第一个字节来设置（如果是第一个字节，则为0，否则为1）。
- 然后，整数右移7位，以处理下一个字节。
- 请注意，这种编码方式实际上是从低字节到高字节的反向方式，所以接下来需要翻转这些字节。

1. **翻转字节**:
- 使用`mem.reverse`翻转在固定缓冲区流中编码的字节。这是因为我们是以反序编码它们的，现在我们要将它们放在正确的顺序。

1. **写入结果**:
- 使用提供的`writer`将翻转后的字节写入到目标位置。


## file.zig

主要目的是为了表示和处理MIDI文件的不同部分，以及提供了一个迭代器来遍历MIDI轨道的事件。

```zig
const midi = @import("../midi.zig");
const std = @import("std");
const decode = @import("./decode.zig");

const io = std.io;
const mem = std.mem;

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

    pub fn deinit(file: File, allocator: *mem.Allocator) void {
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
        var event = decode.trackEvent(s, it.last_event) catch return null;
        it.last_event = event;

        const start = it.stream.pos;

        var end: usize = switch (event.kind) {
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
```

1. **Header 结构**:
  - 表示MIDI文件的头部。
  - 包含一个块、格式、轨道数以及除法。

2. **Chunk 结构**:
  - 表示MIDI文件中的块，每个块有一个种类和长度。
  - 定义了文件头和轨道头的常量。

3. **MetaEvent 结构**:
  - 表示MIDI的元事件。
  - 它有一个种类字节和长度。
  - 有一个函数，根据种类字节返回事件的种类。
  - 定义了所有可能的元事件种类。

4. **TrackEvent 结构**:
  - 表示MIDI轨道中的事件。
  - 它有一个delta时间和种类。
  - 事件种类可以是MIDI事件或元事件。

5. **File 结构**:
  - 表示整个MIDI文件。
  - 它有格式、除法、头部数据和一系列块。
  - 定义了一个子结构FileChunk，用于表示文件块的种类和字节数据。
  - 提供了一个清除方法来释放文件的资源。

6. **TrackIterator 结构**:
  - 是一个迭代器，用于遍历MIDI轨道的事件。
  - 它使用一个FixedBufferStream来读取事件。
  - 定义了一个Result结构来返回事件和关联的数据。
  - 提供了一个`next`方法来读取下一个事件。

## Build.zig

buid.zig是一个Zig构建脚本（build.zig），用于配置和驱动Zig的构建过程。

```zig
const builtin = @import("builtin");
const std = @import("std");

const Builder = std.build.Builder;
const Mode = builtin.Mode;

pub fn build(b: *Builder) void {
    const test_all_step = b.step("test", "Run all tests in all modes.");
    inline for (@typeInfo(std.builtin.Mode).Enum.fields) |field| {
        const test_mode = @field(std.builtin.Mode, field.name);
        const mode_str = @tagName(test_mode);

        const tests = b.addTest("midi.zig");
        tests.setBuildMode(test_mode);
        tests.setNamePrefix(mode_str ++ " ");

        const test_step = b.step("test-" ++ mode_str, "Run all tests in " ++ mode_str ++ ".");
        test_step.dependOn(&tests.step);
        test_all_step.dependOn(test_step);
    }

    const example_step = b.step("examples", "Build examples");
    inline for ([_][]const u8{
        "midi_file_to_text_stream",
    }) |example_name| {
        const example = b.addExecutable(example_name, "example/" ++ example_name ++ ".zig");
        example.addPackagePath("midi", "midi.zig");
        example.install();
        example_step.dependOn(&example.step);
    }

    const all_step = b.step("all", "Build everything and runs all tests");
    all_step.dependOn(test_all_step);
    all_step.dependOn(example_step);

    b.default_step.dependOn(all_step);
}
```

这个build比较复杂，我们逐行来解析:

```zig
const test_all_step = b.step("test", "Run all tests in all modes.");
```
- 使用b.step()方法定义了一个名为test的步骤。描述是“在所有模式下运行所有测试”。
  
```zig
inline for (@typeInfo(std.builtin.Mode).Enum.fields) |field| {}
```
- Zig有几种构建模式，例如Debug、ReleaseSafe等, 上面则是为每种构建模式生成测试.
  - 这里，@typeInfo()函数获取了一个类型的元信息。std.builtin.Mode是Zig中定义的构建模式的枚举。Enum.fields获取了这个枚举的所有字段。

```zig
const example_step = b.step("examples", "Build examples");
```
- 配置示例构建,为所有示例创建的构建步骤.

```zig
const all_step = b.step("all", "Build everything and runs all tests");
all_step.dependOn(test_all_step);
all_step.dependOn(example_step);

b.default_step.dependOn(all_step);
```
- all_step是一个汇总步骤，它依赖于之前定义的所有其他步骤。最后，b.default_step.dependOn(all_step);确保当你仅仅执行zig build（没有指定步骤）时，all_step会被执行。