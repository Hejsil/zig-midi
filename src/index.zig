const std = @import("std");

const mem = std.mem;

pub const decode = @import("decode.zig");

test "midi" {
    _ = decode;
}

pub const Message = union(enum) {
    NoteOff: NoteOff,
    NoteOn: NoteOn,
    PolyphonicKeyPressure: PolyphonicKeyPressure,
    ControlChange: ControlChange,
    AllSoundOff: AllSoundOff,
    ResetAllControllers: ResetAllControllers,
    LocalControl: LocalControl,
    AllNotesOff: AllNotesOff,
    OmniModeOff: OmniModeOff,
    OmniModeOn: OmniModeOn,
    MonoModeOn: MonoModeOn,
    PolyModeOn: PolyModeOn,
    ProgramChange: ProgramChange,
    ChannelPressure: ChannelPressure,
    PitchBendChange: PitchBendChange,

    SystemExclusive: SystemExclusive,
    SystemExclusiveStart: SystemExclusiveStart,
    SystemExclusiveEnd: SystemExclusiveEnd,
    MidiTimeCodeQuarterFrame: MidiTimeCodeQuarterFrame,
    SongPositionPointer: SongPositionPointer,
    SongSelect: SongSelect,
    TuneRequest: TuneRequest,
    TimingClock: TimingClock,
    Start: Start,
    Continue: Continue,
    Stop: Stop,
    ActiveSensing: ActiveSensing,
    Reset: Reset,

    pub const Kind = @TagType(Message);

    pub const NoteOff = Note;
    pub const NoteOn = Note;

    pub const PolyphonicKeyPressure = struct {
        channel: u4,
        note: u7,
        pressure: u7,
    };

    pub const ControlChange = struct {
        channel: u4,
        controller: u7,
        value: u7,
    };

    pub const AllSoundOff = ChannelMessage;

    pub const ResetAllControllers = struct {
        channel: u4,
        value: u7,
    };

    pub const LocalControl = struct {
        channel: u4,
        on: bool,
    };

    pub const AllNotesOff = ChannelMessage;
    pub const OmniModeOff = ChannelMessage;
    pub const OmniModeOn = ChannelMessage;

    pub const MonoModeOn = struct {
        channel: u4,
        value: u7,
    };

    pub const PolyModeOn = ChannelMessage;

    pub const ProgramChange = struct {
        channel: u4,
        program: u7,
    };

    pub const ChannelPressure = struct {
        channel: u4,
        pressure: u7,
    };

    pub const PitchBendChange = struct {
        channel: u4,
        bend: u14,
    };

    pub const SystemExclusive = struct {
        id: []u7,
        message: []u7,
    };

    pub const SystemExclusiveStart = void;
    pub const SystemExclusiveEnd = void;

    pub const MidiTimeCodeQuarterFrame = struct {
        message_type: u3,
        values: u4,
    };

    pub const SongPositionPointer = struct {
        beats: u14,
    };

    pub const SongSelect = struct {
        sequence: u7,
    };

    pub const TuneRequest = void;
    pub const TimingClock = void;
    pub const Start = void;
    pub const Continue = void;
    pub const Stop = void;
    pub const ActiveSensing = void;
    pub const Reset = void;

    const Note = struct {
        channel: u4,
        note: u7,
        velocity: u7,
    };

    const ChannelMessage = struct {
        channel: u4,
    };

    pub fn equal(a: Message, b: Message) bool {
        if (Message.Kind(a) != Message.Kind(b))
            return false;

        switch (a) {
            Message.Kind.NoteOff => |av| {
                const bv = b.NoteOff;
                return av.channel == bv.channel and
                    av.note == bv.note and
                    av.velocity == bv.velocity;
            },
            Message.Kind.NoteOn => |av| {
                const bv = b.NoteOn;
                return av.channel == bv.channel and
                    av.note == bv.note and
                    av.velocity == bv.velocity;
            },
            Message.Kind.PolyphonicKeyPressure => |av| {
                const bv = b.PolyphonicKeyPressure;
                return av.channel == bv.channel and
                    av.note == bv.note and
                    av.pressure == bv.pressure;
            },
            Message.Kind.ControlChange => |av| {
                const bv = b.ControlChange;
                return av.channel == bv.channel and
                    av.controller == bv.controller and
                    av.value == bv.value;
            },
            Message.Kind.AllSoundOff => |av| {
                const bv = b.AllSoundOff;
                return av.channel == bv.channel;
            },
            Message.Kind.ResetAllControllers => |av| {
                const bv = b.ResetAllControllers;
                return av.channel == bv.channel and
                    av.value == bv.value;
            },
            Message.Kind.LocalControl => |av| {
                const bv = b.LocalControl;
                return av.channel == bv.channel and
                    av.on == bv.on;
            },
            Message.Kind.AllNotesOff => |av| {
                const bv = b.AllNotesOff;
                return av.channel == bv.channel;
            },
            Message.Kind.OmniModeOff => |av| {
                const bv = b.OmniModeOff;
                return av.channel == bv.channel;
            },
            Message.Kind.OmniModeOn => |av| {
                const bv = b.OmniModeOn;
                return av.channel == bv.channel;
            },
            Message.Kind.MonoModeOn => |av| {
                const bv = b.MonoModeOn;
                return av.channel == bv.channel and
                    av.value == bv.value;
            },
            Message.Kind.PolyModeOn => |av| {
                const bv = b.PolyModeOn;
                return av.channel == bv.channel;
            },
            Message.Kind.ProgramChange => |av| {
                const bv = b.ProgramChange;
                return av.channel == bv.channel and
                    av.program == bv.program;
            },
            Message.Kind.ChannelPressure => |av| {
                const bv = b.ChannelPressure;
                return av.channel == bv.channel and
                    av.pressure == bv.pressure;
            },
            Message.Kind.PitchBendChange => |av| {
                const bv = b.PitchBendChange;
                return av.channel == bv.channel and
                    av.bend == bv.bend;
            },

            Message.Kind.SystemExclusive => |av| {
                const bv = b.SystemExclusive;
                return std.mem.eql(u7, av.id, bv.id) and
                    std.mem.eql(u7, av.message, bv.message);
            },
            Message.Kind.SystemExclusiveStart => return true,
            Message.Kind.SystemExclusiveEnd => return true,
            Message.Kind.MidiTimeCodeQuarterFrame => |av| {
                const bv = b.MidiTimeCodeQuarterFrame;
                return av.message_type == bv.message_type and
                    av.values == bv.values;
            },
            Message.Kind.SongPositionPointer => |av| {
                const bv = b.SongPositionPointer;
                return av.beats == bv.beats;
            },
            Message.Kind.SongSelect => |av| {
                const bv = b.SongSelect;
                return av.sequence == bv.sequence;
            },
            Message.Kind.TuneRequest => return true,
            Message.Kind.TimingClock => return true,
            Message.Kind.Start => return true,
            Message.Kind.Continue => return true,
            Message.Kind.Stop => return true,
            Message.Kind.ActiveSensing => return true,
            Message.Kind.Reset => return true,
        }
    }
};

pub const ChunkHeader = struct {
    kind: [4]u8,
    len: u32,

    fn equal(a: ChunkHeader, b: ChunkHeader) bool {
        if (!mem.eql(u8, a.kind, b.kind))
            return false;
        return a.len == b.len;
    }
};

pub const Chunk = struct {
    header: ChunkHeader,
    data: []const u8,

    fn equal(a: Chunk, b: Chunk) bool {
        if (!mem.eql(u8, a.data, b.data))
            return false;
        return a.header.equal(b.header);
    }
};
