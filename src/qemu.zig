const std = @import("std");

pub fn findProgram(b: *std.Build, target: std.Build.ResolvedTarget) ![]const u8 {
    const program = switch (target.result.cpu.arch) {
        .x86 => "qemu-system-i386",
        else => "qemu-system-" ++ @tagName(target.result.cpu.arch),
    };
    return b.findProgram(&.{program}, &.{});
}

pub fn addQemuRun(b: *std.Build, target: std.Build.ResolvedTarget, disk: []const u8) !*std.Build.Step.Run {
    return b.addSystemCommand(&.{ findProgram(b, target), "-drive", b.fmt("format=raw,file={s}", .{disk}) });
}
