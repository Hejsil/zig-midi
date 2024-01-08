const builtin = @import("builtin");
const std = @import("std");

const Mode = builtin.Mode;

pub fn build(b: *std.Build) void {
    const midi_mod = b.addModule("midi", .{ .root_source_file = .{ .path = "midi.zig" } });

    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const test_step = b.step("test", "Run all tests in all modes.");
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "midi.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);

    const example_step = b.step("examples", "Build examples");
    for ([_][]const u8{
        "midi_file_to_text_stream",
    }) |example_name| {
        const example = b.addExecutable(.{
            .name = example_name,
            .root_source_file = .{ .path = b.fmt("example/{s}.zig", .{example_name}) },
            .target = target,
            .optimize = optimize,
        });
        const install_example = b.addInstallArtifact(example, .{});
        example.root_module.addImport("midi", midi_mod);
        example_step.dependOn(&example.step);
        example_step.dependOn(&install_example.step);
    }

    const all_step = b.step("all", "Build everything and runs all tests");
    all_step.dependOn(test_step);
    all_step.dependOn(example_step);
}
