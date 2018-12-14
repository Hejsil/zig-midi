const std = @import("std");

const mem = std.mem;

pub const decode = @import("decode.zig");
pub const file = @import("file.zig");

test "midi" {
    _ = @import("test.zig");
    _ = decode;
    _ = file;
}

pub const ChannelMessage = union(enum) {
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

    pub const Kind = @TagType(@This());

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

    pub const AllSoundOff = Channel;

    pub const ResetAllControllers = struct {
        channel: u4,
        value: u7,
    };

    pub const LocalControl = struct {
        channel: u4,
        on: bool,
    };

    pub const AllNotesOff = Channel;
    pub const OmniModeOff = Channel;
    pub const OmniModeOn = Channel;

    pub const MonoModeOn = struct {
        channel: u4,
        value: u7,
    };

    pub const PolyModeOn = Channel;

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

    const Note = struct {
        channel: u4,
        note: u7,
        velocity: u7,
    };

    const Channel = struct {
        channel: u4,
    };

    pub fn equal(a: ChannelMessage, b: ChannelMessage) bool {
        if (Kind(a) != Kind(b))
            return false;

        switch (a) {
            Kind.NoteOff => |av| {
                const bv = b.NoteOff;
                return av.channel == bv.channel and
                    av.note == bv.note and
                    av.velocity == bv.velocity;
            },
            Kind.NoteOn => |av| {
                const bv = b.NoteOn;
                return av.channel == bv.channel and
                    av.note == bv.note and
                    av.velocity == bv.velocity;
            },
            Kind.PolyphonicKeyPressure => |av| {
                const bv = b.PolyphonicKeyPressure;
                return av.channel == bv.channel and
                    av.note == bv.note and
                    av.pressure == bv.pressure;
            },
            Kind.ControlChange => |av| {
                const bv = b.ControlChange;
                return av.channel == bv.channel and
                    av.controller == bv.controller and
                    av.value == bv.value;
            },
            Kind.AllSoundOff => |av| {
                const bv = b.AllSoundOff;
                return av.channel == bv.channel;
            },
            Kind.ResetAllControllers => |av| {
                const bv = b.ResetAllControllers;
                return av.channel == bv.channel and
                    av.value == bv.value;
            },
            Kind.LocalControl => |av| {
                const bv = b.LocalControl;
                return av.channel == bv.channel and
                    av.on == bv.on;
            },
            Kind.AllNotesOff => |av| {
                const bv = b.AllNotesOff;
                return av.channel == bv.channel;
            },
            Kind.OmniModeOff => |av| {
                const bv = b.OmniModeOff;
                return av.channel == bv.channel;
            },
            Kind.OmniModeOn => |av| {
                const bv = b.OmniModeOn;
                return av.channel == bv.channel;
            },
            Kind.MonoModeOn => |av| {
                const bv = b.MonoModeOn;
                return av.channel == bv.channel and
                    av.value == bv.value;
            },
            Kind.PolyModeOn => |av| {
                const bv = b.PolyModeOn;
                return av.channel == bv.channel;
            },
            Kind.ProgramChange => |av| {
                const bv = b.ProgramChange;
                return av.channel == bv.channel and
                    av.program == bv.program;
            },
            Kind.ChannelPressure => |av| {
                const bv = b.ChannelPressure;
                return av.channel == bv.channel and
                    av.pressure == bv.pressure;
            },
            Kind.PitchBendChange => |av| {
                const bv = b.PitchBendChange;
                return av.channel == bv.channel and
                    av.bend == bv.bend;
            },
        }
    }
};

pub const SystemMessage = union(enum) {
    Undefined: Undefined,
    ExclusiveStart: ExclusiveStart,
    ExclusiveEnd: ExclusiveEnd,
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

    pub const Kind = @TagType(@This());

    pub const Undefined = void;

    /// When used with the streaming API, ExclusiveStart is a single
    /// message and contains no data. It is the feeders responsibility
    /// to keep track of the data between an ExclusiveStart and
    /// ExclusiveEnd message.
    /// With the none streaming API, the data field will contain the data
    /// between ExclusiveStart and ExclusiveEnd.
    pub const ExclusiveStart = struct {
        data: []u8,
    };
    pub const ExclusiveEnd = void;

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

    pub fn equal(a: SystemMessage, b: SystemMessage) bool {
        if (Kind(a) != Kind(b))
            return false;

        switch (a) {
            Kind.Undefined => return true,
            Kind.ExclusiveStart => return true,
            Kind.ExclusiveEnd => return true,
            Kind.MidiTimeCodeQuarterFrame => |av| {
                const bv = b.MidiTimeCodeQuarterFrame;
                return av.message_type == bv.message_type and
                    av.values == bv.values;
            },
            Kind.SongPositionPointer => |av| {
                const bv = b.SongPositionPointer;
                return av.beats == bv.beats;
            },
            Kind.SongSelect => |av| {
                const bv = b.SongSelect;
                return av.sequence == bv.sequence;
            },
            Kind.TuneRequest => return true,
            Kind.TimingClock => return true,
            Kind.Start => return true,
            Kind.Continue => return true,
            Kind.Stop => return true,
            Kind.ActiveSensing => return true,
            Kind.Reset => return true,
        }
    }
};

pub const Message = union(enum) {
    System: SystemMessage,
    Channel: ChannelMessage,

    pub const Kind = @TagType(@This());

    pub fn equal(a: Message, b: Message) bool {
        if (Kind(a) != Kind(b))
            return false;

        switch (a) {
            Kind.System => return a.System.equal(b.System),
            Kind.Channel => return a.Channel.equal(b.Channel),
        }
    }
};
