const std = @import("std");
const midi = @import("midi");

pub fn main() !void {
    const stdin_file = try std.io.getStdIn();
    const stdin = &stdin_file.inStream().stream;

    var header_buf: [14]u8 = undefined;
    try stdin.readNoEof(&header_buf);
    const header = try midi.decode.fileHeader(header_buf);
    std.debug.warn("{}\n", header);

    // The midi standard says that we should respect the headers size, even if it
    // is bigger than nessesary. We therefor need to figure out what to do with the
    // extra bytes in the header. This example will just skip them.
    try stdin.skipBytes(header.chunk.len - midi.file.Header.size);

    while (true) {
        var chunk_buf: [8]u8 = undefined;
        stdin.readNoEof(&chunk_buf) catch |err| switch (err) {
            error.EndOfStream => break,
            else => |e| return e,
        };
        const chunk = midi.decode.chunk(chunk_buf);

        std.debug.warn("{}\n", chunk);

        // If our chunk isn't a track header, we just skip it.
        if (!std.mem.eql(u8, chunk.kind, midi.file.Chunk.track_header)) {
            try stdin.skipBytes(chunk.len);
            continue;
        }

        // To be decode midi correctly, we have to keep track of the last
        // event. Midi can compress midi event if the same kind of event
        // is repeated.
        var last_event: ?midi.file.TrackEvent = null;
        while (true) {
            const event = try midi.decode.trackEvent(last_event, stdin);
            last_event = event;

            std.debug.warn("{:>6}", event.delta_time);
            switch (event.kind) {
                .MetaEvent => |meta_event| {
                    std.debug.warn(" {:>6} {:>6}\n", meta_event.kind(), meta_event.len);
                    try stdin.skipBytes(meta_event.len);
                    if (meta_event.kind() == .EndOfTrack)
                        break;
                },
                .MidiEvent => |midi_event| {
                    if (midi_event.channel()) |channel| {
                        std.debug.warn(" {:>6} {:>6} {:>6} {:>6}\n", midi_event.kind(), channel, midi_event.values[0], midi_event.values[1]);
                    } else {
                        std.debug.warn(" {:>6} {:>6} {:>6}\n", midi_event.kind(), midi_event.values[0], midi_event.values[1]);
                    }
                },
            }
        }
    }
}
