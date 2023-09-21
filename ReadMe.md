# Zig-midi

MIDI stands for "Musical Instrument Digital Interface" and is a protocol used for communication between musical devices.

> It supports bilingual. So you could read detail in this: [ReadMe Chinese](./ReadMe_cn.md) | [ReadMe En](./ReadMe.md)

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

## Basic

In the `MIDI` protocol, `0xFF` is a specific status byte, used to indicate the start of a Meta Event. Meta Events are a type of specific message in the MIDI file structure. They are generally not used for real-time audio playback, but they contain metadata about the MIDI sequence, such as sequence name, copyright information, lyrics, time markers, changes in beats per minute (BPM), and so on.

Below are some common types of Meta Events and the bytes associated after `0xFF`:

- `0x00`: Sequence Number
- `0x01`: Text Event
- `0x02`: Copyright Notice
- `0x03`: Sequence/Track Name
- `0x04`: Instrument Name
- `0x05`: Lyric
- `0x06`: Marker
- `0x07`: Cue Point
- `0x20`: MIDI Channel Prefix
- `0x21`: End of Track (typically followed by value `0x00`, indicating the end of the track)
- `0x2F`: Set Tempo (setting the speed, namely the number of quarter notes per minute)
- `0x51`: SMPTE Offset
- `0x54`: Time Signature
- `0x58`: Key Signature
- `0x59`: Sequencer-Specific Meta-event

For example, when parsing a MIDI file, if you encounter the bytes `0xFF 0x03`, the following bytes will represent the name of the sequence or track.

In actual MIDI files, the specific structure of a Meta Event is:

1. `0xFF`: Meta Event status byte.
2. Meta Event type byte, like the aforementioned `0x00`, `0x01`, etc.
3. Length byte(s) indicating the length of the event data.
4. The event data itself.

`Meta Events` primarily exist in MIDI files, especially in the context of Standard MIDI Files (SMF). In real-time MIDI communication, Meta Events are typically not sent, as they usually don't affect the actual music playback.

## Midi.zig

This document primarily deals with a module for handling MIDI messages, providing the fundamental structure and functions for processing MIDI messages.

It defines a public structure named "Message" that represents a MIDI message, offering the foundational structure and functions for handling these messages. It consists of three fields: status, value, and several public methods.

- **kind function**: Determines the type of message based on the MIDI message's status code.
- **channel function**: Returns the MIDI channel based on the message type; if the message doesn't contain channel information, it returns null.
- **value and setValue functions**: Used to get and set the value field of the MIDI message.
- **Kind enumeration**: Defines all possible types of MIDI messages, including channel events and system events.

### MIDI Message Structure

First, it's important to understand some background about the MIDI message.

In the MIDI protocol, the values of certain messages can span two 7-bit bytes. This is because the MIDI protocol doesn't use the highest bit of each byte (commonly referred to as the status bit). This means each byte only uses its lower 7 bits to convey data. So, when there's a need to send a value larger than 7 bits (like 14 bits), it's split into two 7-bit bytes.

What the `setValue` function does is it splits a 14-bit value (`u14`) into two 7-bit values and sets them in `message.values`.

Below is a detailed explanation of the steps:

1. **Obtain the higher 7 bits**: `v >> 7` shifts the 14-bit value to the right by 7 places, thus retrieving the higher 7-bit value.
   
2. **Truncate and Convert**: `@truncate(v >> 7)` truncates the higher 7 bits of the value, ensuring it's 7 bits. `@as(u7, @truncate(v >> 7))` guarantees that this value is of `u7` type, i.e., a 7-bit unsigned integer.

3. **Obtain the lower 7 bits**: `@truncate(v)` directly truncates the original value, retaining the lower 7 bits.

4. **Set the values**: `message.values = .{ ... }` sets these two 7-bit values into `message.values`.

### Events

Let take a look on `enum`.

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

This code defines a public enumeration type (`enum`) named `Kind` which describes the possible event types within MIDI. Each enumerated member represents a specific event in the MIDI protocol. These events are categorized into two main types: Channel events and System events.

The `Kind` enumeration offers a structured approach to handling MIDI messages, allowing for clear referencing of specific MIDI events in programming, rather than relying on raw numbers or other encodings.

Below is a brief description of each enumerated member:

#### Channel Events

1. **NoteOff**: This is a note-off event, indicating that a particular note has stopped playing.

2. **NoteOn**: This is a note-on event, indicating the start of a particular note being played.

3. **PolyphonicKeyPressure**: Polyphonic keyboard pressure event, signifying changes in pressure or touch sensitivity on a specific note.

4. **ControlChange**: Control change event, used for sending control signals like volume, balance, etc.

5. **ProgramChange**: Program (timbre) change event, used for changing the instrument's timbre.

6. **ChannelPressure**: Channel pressure event, similar to polyphonic keyboard pressure but applies to the entire channel, not a specific note.

7. **PitchBendChange**: Pitch bend change event, indicating a rise or fall in the pitch of a note.

#### System Events

1. **ExclusiveStart**: Exclusive start event, marking the beginning of an exclusive message sequence.

2. **MidiTimeCodeQuarterFrame**: MIDI time code quarter frame, used for synchronization with other devices.

3. **SongPositionPointer**: Song position pointer, indicating the current playback position of a sequencer.

4. **SongSelect**: Song select event, used to choose a specific song or sequence.

5. **TuneRequest**: Tune request event, signaling that a device should undergo self-tuning.

6. **ExclusiveEnd**: Exclusive end event, marking the end of an exclusive message sequence.

7. **TimingClock**: Timing clock event, used for rhythmic synchronization.

8. **Start**: Start event, used to initiate sequence playback.

9. **Continue**: Continue event, used to resume paused sequence playback.

10. **Stop**: Stop event, used to halt sequence playback.

11. **ActiveSensing**: Active sensing event, a type of heartbeat signal, indicating that the device is still online and functioning.

12. **Reset**: Reset event, used to reset the device to its initial state.

#### Others

1. **Undefined**: Undefined event, which may represent a MIDI event that is either not defined in this enumeration or is invalid.

## decode.zig

This document is a decoder for MIDI files, offering a set of tools that can parse various parts of MIDI files from different input sources. This facilitates easy reading and processing of MIDI files.

1. **statusByte**: Parses the first byte of a MIDI message to determine if it's a status byte or a data byte. It decodes a byte b into a u7 type MIDI status byte; if byte b is not a status byte, it returns null. In other words, if a MIDI message is 14 bits and the top 7 bits are not empty, it is the status byte of the MIDI message. In the MIDI protocol, the first byte of a message is usually the status byte, but subsequent bytes might be interpreted using the previous status byte (known as "running status"). Therefore, this code needs to ascertain whether it has read a new status byte or if it should use the status byte from the previous message.
2. **readDataByte**: Reads and returns a data byte from the reader. If the byte read does not comply with the data byte specifications, it throws an InvalidDataByte error.
3. **message**: Reads and decodes a MIDI message from the reader. If the bytes read cannot form a valid MIDI message, it throws an InvalidMessage error. This is a complex function that involves parsing various types of MIDI messages.
4. **chunk**, **chunkFromBytes**: These two functions parse a MIDI file chunk header either from the reader or directly from a byte array bytes.
5. **fileHeader**, **fileHeaderFromBytes**: These two functions parse a MIDI file header either from the reader or directly from a byte array bytes.
6. **int**: Decodes a variable-length integer from the reader.
7. **metaEvent**: Parses a MIDI meta event from the reader.
8. **trackEvent**: Parses a MIDI track event from the reader. It could be either a MIDI message or a meta event.
9. **file**: Used to decode an entire MIDI file from the reader. It first decodes the file header and then decodes all the file chunks. This function returns a structure representing the MIDI file.

## encode.zig

This document is used for encoding MIDI data structures into their corresponding binary format. Specifically, it converts MIDI data structures in memory into the binary data of the MIDI file format.

- **message function**: This function encodes MIDI messages into a byte sequence, translating a single MIDI message into its binary form. Depending on the message type, it writes one or more bytes to the provided writer. If the message requires a status byte and it's different from the status of the previous message, the function writes the status byte. Then, based on the type of the message, the function writes the required data bytes.

- **chunkToBytes function**: This function converts MIDI file chunk information into 8 bytes of binary data. These 8 bytes include 4 bytes for the chunk type and 4 bytes for the chunk length. It copies the chunk type into the first 4 bytes, then writes the length of the chunk into the last 4 bytes and returns the result.

- **fileHeaderToBytes function**: This function encodes the MIDI file header into 14 bytes of binary data. These 14 bytes comprise the chunk information, file format, the number of tracks, and the time division information.

- **int function**: Encodes an integer into the variable-length integer format used in MIDI files. In MIDI files, some integer values use a special encoding format that can vary in length based on the size of the integer.

- **metaEvent function**: Encodes a MIDI meta event (Meta Event) into binary data, which includes the type and length of the event. Specifically, it encodes a meta event by first writing its type byte followed by its length.

- **trackEvent function**: Encodes a track event. Track events can be either meta events or MIDI messages. The function starts by writing the time difference between events (delta time) and then encodes the event content based on the event type (MetaEvent or MidiEvent).

- **file function**: This is the main function, used to encode the entire MIDI file data structure into its binary form. It first encodes the file header and then loops through encoding each chunk and the events within each chunk.


## file.zig

The primary purpose is to represent and process different parts of a MIDI file and also provides an iterator to traverse events in a MIDI track.

1. **Header Structure**:
- Represents the header of a MIDI file.
- Contains a chunk, format, number of tracks, and a division.

2. **Chunk Structure**:
- Represents a chunk in a MIDI file, where each chunk has a type and length.
- Defines constants for the file header and track header.

3. **MetaEvent Structure**:
- Represents a MIDI meta event.
- It has a type byte and length.
- Features a function that returns the type of the event based on its type byte.
- Defines all the possible meta event types.

4. **TrackEvent Structure**:
- Represents an event in a MIDI track.
- It has a delta time and a type.
- The event type can be either a MIDI event or a meta event.

5. **File Structure**:
- Represents the entire MIDI file.
- It has a format, division, header data, and a series of chunks.
- Defines a sub-structure, FileChunk, to represent the type and byte data of a file chunk.
- Offers a cleanup method to release resources of the file.

6. **TrackIterator Structure**:
- Is an iterator designed for traversing events in a MIDI track.
- It uses a FixedBufferStream to read events.
- Defines a Result structure to return the event and associated data.
- Provides a `next` method to read the subsequent event.
