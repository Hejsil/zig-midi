const midi = @import("midi");
const std = @import("std");

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();

    const header = try midi.decode.fileHeader(stdin);
    std.debug.warn("file_header:\n", .{});
    std.debug.warn("  chunk_type: {s}\n", .{header.chunk.kind});
    std.debug.warn("  chunk_len:  {}\n", .{header.chunk.len});
    std.debug.warn("  format:     {}\n", .{header.format});
    std.debug.warn("  tracks:     {}\n", .{header.tracks});
    std.debug.warn("  division:   {}\n", .{header.division});

    // The midi standard says that we should respect the headers size, even if it
    // is bigger than nessesary. We therefor need to figure out what to do with the
    // extra bytes in the header. This example will just skip them.
    try stdin.skipBytes(header.chunk.len - midi.file.Header.size, .{});

    while (true) {
        const chunk = midi.decode.chunk(stdin) catch |err| switch (err) {
            error.EndOfStream => break,
            else => |e| return e,
        };

        std.debug.warn("chunk:\n", .{});
        std.debug.warn("  type: {s}\n", .{chunk.kind});
        std.debug.warn("  len:  {}\n", .{chunk.len});

        // If our chunk isn't a track header, we just skip it.
        if (!std.mem.eql(u8, &chunk.kind, midi.file.Chunk.track_header)) {
            try stdin.skipBytes(chunk.len, .{});
            continue;
        }

        // To be decode midi correctly, we have to keep track of the last
        // event. Midi can compress midi event if the same kind of event
        // is repeated.
        var last_event: ?midi.file.TrackEvent = null;
        while (true) {
            const event = try midi.decode.trackEvent(stdin, last_event);
            last_event = event;

            std.debug.warn("  {:>6}", .{event.delta_time});
            switch (event.kind) {
                .MetaEvent => |meta_event| {
                    var buf: [1024]u8 = undefined;
                    const data = buf[0..meta_event.len];
                    try stdin.readNoEof(data);

                    std.debug.warn(" {s:>20} {:>6}", .{ metaEventKindToStr(meta_event.kind()), meta_event.len });
                    switch (meta_event.kind()) {
                        .Luric, .InstrumentName, .TrackName => std.debug.warn(" {s}\n", .{data}),
                        .EndOfTrack => {
                            std.debug.warn("\n", .{});
                            break;
                        },
                        else => std.debug.warn("\n", .{}),
                    }
                },
                .MidiEvent => |midi_event| {
                    std.debug.warn(" {s:>20}", .{midiEventKindToStr(midi_event.kind())});
                    if (midi_event.channel()) |channel|
                        std.debug.warn(" {:>6}", .{channel});
                    std.debug.warn(" {:>3} {:>3}\n", .{ midi_event.values[0], midi_event.values[1] });

                    if (midi_event.kind() == .ExclusiveStart) {
                        while ((try stdin.readByte()) != 0xF7) {}
                    }
                },
            }
        }
    }
}

fn metaEventKindToStr(kind: midi.file.MetaEvent.Kind) []const u8 {
    return switch (kind) {
        .Undefined => "undef",
        .SequenceNumber => "seqnum",
        .TextEvent => "text",
        .CopyrightNotice => "copyright",
        .TrackName => "track_name",
        .InstrumentName => "instr_name",
        .Luric => "luric",
        .Marker => "marker",
        .CuePoint => "cue_point",
        .MidiChannelPrefix => "channel_prefix",
        .EndOfTrack => "eot",
        .SetTempo => "tempo",
        .SmpteOffset => "smpte_offset",
        .TimeSignature => "time_sig",
        .KeySignature => "key_sig",
        .SequencerSpecificMetaEvent => "seq_spec_meta_event",
    };
}

fn midiEventKindToStr(kind: midi.Message.Kind) []const u8 {
    return switch (kind) {
        // Channel events
        .NoteOff => "note_off",
        .NoteOn => "note_on",
        .PolyphonicKeyPressure => "polykey_pressure",
        .ControlChange => "cntrl_change",
        .ProgramChange => "program_change",
        .ChannelPressure => "chnl_pressure",
        .PitchBendChange => "pitch_bend_change",

        // System events
        .ExclusiveStart => "excl_start",
        .MidiTimeCodeQuarterFrame => "midi_timecode_quater_frame",
        .SongPositionPointer => "song_pos_pointer",
        .SongSelect => "song_select",
        .TuneRequest => "tune_request",
        .ExclusiveEnd => "excl_end",
        .TimingClock => "timing_clock",
        .Start => "start",
        .Continue => "continue",
        .Stop => "stop",
        .ActiveSensing => "active_sens",
        .Reset => "reset",

        .Undefined => "undef",
    };
}
