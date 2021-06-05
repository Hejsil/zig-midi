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
