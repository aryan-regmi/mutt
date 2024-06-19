const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // const version = std.SemanticVersion{.major = 0, .minor = 1, .patch = 0};

    // Lib
    const lib = b.addStaticLibrary(.{
        .name = "mutt",
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);
    _ = b.addModule("mutt", .{ .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/lib.zig" } } });

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

// TODO: Add step that uses `git archive` to create archive for package manager
//  https://github.com/zigzap/zap/blob/master/create-archive.sh
fn gitArchive(b: *std.Build, lib_name: []const u8) !void {
    const git = b.findProgram(&.{"git"}, &.{ "/usr/bin/", "/usr/local/bin/" }) catch {
        std.log.err("Unable to find `git`", .{});
    };

    const version = "0.1.0";

    const archive = b.run(&.{
        git,
        "archive",
        "--format=tar.gz",
        "-o",
        version ++ ".tar.gz",
        "--prefix=" ++ lib_name ++ "-" ++ version ++ "/",
        "HEAD",
    });
    _ = archive; // autofix
}
