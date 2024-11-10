const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .root_source_file = b.path("src/main.zig"),
        .name = "wizard101-file-extractor",
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const cmd = b.addRunArtifact(exe);
    if (b.args) |args| cmd.addArgs(args);

    const step = b.step("run", "Run program");
    step.dependOn(&cmd.step);
}
