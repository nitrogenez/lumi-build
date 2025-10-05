const std = @import("std");

const Build = std.Build;
const Step = std.Build.Step;

pub const Partition = struct {
    step: *Step.Run,
    offset: usize,
    size: usize,
};

pub fn addEmptyDisk(b: *std.Build, size: usize, path: []const u8) !*Step.Run {
    const dd = try b.findProgram(&.{"dd"}, &.{});
    return b.addSystemCommand(&.{
        dd,
        "if=/dev/zero",
        b.fmt("of={s}", .{path}),
        "bs=512",
        b.fmt("count={d}", .{size / 512}),
    });
}

pub fn addSetDiskLabel(b: *std.Build, disk: []const u8, label: []const u8) !*Step.Run {
    const parted = try b.findProgram(&.{"parted"}, &.{});
    return b.addSystemCommand(&.{ parted, "-s", disk, "mklabel", label });
}

pub fn addPartition(
    b: *std.Build,
    disk: []const u8,
    partnum: usize,
    name: []const u8,
    fstype: []const u8,
    start: usize,
    end: usize,
    flags: ?[]const []const u8,
) !*Step.Run {
    const parted = try b.findProgram(&.{"parted"}, &.{});
    const step = b.addSystemCommand(&.{ parted, "-s", disk });

    step.addArgs(&.{ "mkpart", name, fstype });
    step.addArg(b.fmt("{d}B", start));
    step.addArg(b.fmt("{d}B", end));

    if (flags == null or flags.?.len == 0) {
        return step;
    }
    const n = b.fmt("{d}", .{partnum});
    for (flags.?) |flag| {
        step.addArgs(&.{ "set", n, flag, "on" });
    }
    return step;
}

pub fn addFilesystem(
    b: *Build,
    disk: []const u8,
    fs: enum {
        fat12,
        fat16,
        fat32,
        ext2,
        ext3,
        ext4,
    },
    fs_label: ?[]const u8,
    part_offset: usize,
    size: usize,
) !*Step.Run {
    return switch (fs) {
        .fat12 => try addFatFilesystem(b, 12, disk, fs_label, part_offset, size),
        .fat16 => try addFatFilesystem(b, 16, disk, fs_label, part_offset, size),
        .fat32 => try addFatFilesystem(b, 32, disk, fs_label, part_offset, size),
        .ext2 => try addExtFilesystem(b, 2, disk, fs_label, part_offset, size),
        .ext3 => try addExtFilesystem(b, 3, disk, fs_label, part_offset, size),
        .ext4 => try addExtFilesystem(b, 4, disk, fs_label, part_offset, size),
    };
}

fn addFatFilesystem(
    b: *Build,
    bits: u8,
    disk: []const u8,
    label: []const u8,
    part_offset: usize,
    size: usize,
) !*Step.Run {
    const mkfs = try b.findProgram(&.{ "mkfs.fat", "mkfs.vfat" }, &.{});
    return b.addSystemCommand(&.{
        mkfs,
        b.fmt("-F{d}", .{bits}),
        "-n",
        label,
        b.fmt("--offset={d}", .{part_offset}),
        b.fmt("--size={d}", .{size}),
        disk,
    });
}

fn addExtFilesystem(
    b: *Build,
    version: u8,
    disk: []const u8,
    label: []const u8,
    part_offset: usize,
    size: usize,
) !*Step.Run {
    const mkfs = try b.findProgram(&.{b.fmt("mkfs.ext{d}", .{version})}, &.{});
    return b.addSystemCommand(&.{
        mkfs,
        "-E",
        b.fmt("offset={d}", .{part_offset}),
        "-b",
        "512",
        "-L",
        label,
        disk,
        b.fmt("{d}", .{size / 512}),
    });
}
