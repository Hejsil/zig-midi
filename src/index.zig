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
};

pub const Chunk = struct {
    kind: [4]u8,
    len: u32,
};
