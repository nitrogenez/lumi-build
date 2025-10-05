const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("lumi-build", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/root.zig"),
        .link_libc = true,
    });
    const lib = b.addLibrary(.{
        .name = "lumi-build",
        .root_module = mod,
    });
    lib.linkSystemLibrary("libparted");
    b.installArtifact(lib);
}
