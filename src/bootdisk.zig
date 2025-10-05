const std = @import("std");

const Build = std.Build;
const Step = Build.Step;

pub const Disk = struct {
    step: *Step.Run,
    path: []const u8,
    fstab: PartList,
};

pub const Part = struct {
    label: []const u8,
    fstype: enum {
        ext4,
        fat32,
        fat16,
    },
    size: usize,
    flags: ?[]const []const u8 = null,
    offset: usize,
};

pub const PartQuery = struct {
    label: []const u8,
    fstype: enum {
        ext4,
        fat32,
        fat16,
    },
    size: usize,
    flags: ?[]const []const u8 = null,
};

pub const PartList = struct {
    pub const start_offset = 1024 * 1024;

    list: std.ArrayListUnmanaged(Part) = .empty,
    offset: usize = start_offset,

    pub fn initBuffer(gpa: std.mem.Allocator, buffer: []const PartQuery) !PartList {
        var pl: PartList = .{};
        for (buffer) |part| {
            try pl.add(gpa, part.label, part.size, part.flags);
        }
        return pl;
    }

    pub fn add(self: *PartList, gpa: std.mem.Allocator, label: []const u8, size: usize, flags: ?[]const []const u8) !void {
        try self.list.append(gpa, Part{
            .label = label,
            .size = size,
            .flags = flags,
            .offset = self.offset,
        });
        self.offset += size;
    }

    pub fn getPartedScript(self: *PartList, gpa: std.mem.Allocator, parted: []const u8, dev: []const u8) ![]const []const u8 {
        var script: std.ArrayListUnmanaged([]const u8) = .empty;
        try script.appendSlice(gpa, &.{ parted, "-s", dev, "mklabel", "gpt" });

        for (self.list.items, 0..) |part, i| {
            try script.append(gpa, "mkpart");
            try script.append(gpa, part.label);
            try script.append(gpa, @tagName(part.fstype));
            try script.append(gpa, try std.fmt.allocPrint(gpa, "{d}B", .{part.offset}));
            try script.append(gpa, try std.fmt.allocPrint(gpa, "{d}B", .{part.offset + part.size}));

            if (part.flags) |flags| {
                for (flags) |flag| {
                    try script.append(gpa, "set");
                    try script.append(gpa, try std.fmt.allocPrint(gpa, "{d}", .{i + 1}));
                    try script.append(gpa, flag);
                    try script.append(gpa, "on");
                }
            }
        }
        return script.toOwnedSlice(gpa);
    }
};

pub fn addMkfsFat(b: *Build, bits: u8, offset: usize, label: []const u8, disk: []const u8) !*Step.Run {
    const mkfs = try b.findProgram(&.{"mkfs.vfat"}, &.{});
    return b.addSystemCommand(&.{ mkfs, "-F", b.fmt("{d}", .{bits}), "-n", label, "--offset", b.fmt("{d}", .{offset}), disk });
}

pub fn addMkfsExt4(b: *Build, offset: usize, label: []const u8, disk: []const u8) !*Step.Run {
    const mkfs = try b.findProgram(&.{"mkfs.ext4"}, &.{});
    return b.addSystemCommand(&.{ mkfs, "--offset", b.fmt("{d}", .{offset}), "-L", label, disk });
}

pub fn addEmptyDisk(b: *Build, size: usize, disk: []const u8) !*Step.Run {
    const dd = try b.findProgram(&.{"dd"}, &.{});
    return b.addSystemCommand(&.{ dd, "if=/dev/zero", b.fmt("of={s}", .{disk}), "bs=512", b.fmt("count={d}", .{size / 512}) });
}

pub fn addParted(b: *Build, table: *PartList, disk: []const u8) !*Step.Run {
    const parted = try b.findProgram(&.{"parted"}, &.{});
    return b.addSystemCommand(try table.getPartedScript(b.allocator, parted, disk));
}

pub fn addMkdirFat(b: *Build, offset: usize, disk: []const u8, subpath: []const u8) !*Step.Run {
    const mmd = try b.findProgram(&.{"mmd"}, &.{});
    return b.addSystemCommand(&.{
        mmd,
        "-i",
        b.fmt("{s}@@{d}", .{ disk, offset }),
        b.fmt("::{s}", .{subpath}),
    });
}

pub fn addCopyFileFat(b: *Build, offset: usize, disk: []const u8, source: []const u8, dest_dir: []const u8) !*Step.Run {
    const mcopy = try b.findProgram(&.{"mcopy"}, &.{});
    return b.addSystemCommand(&.{
        mcopy,
        "-i",
        b.fmt("{s}@@{d}", .{ disk, offset }),
        source,
        b.fmt("::{s}", .{dest_dir}),
    });
}

pub fn addDisk(
    b: *Build,
    name: []const u8,
    parttable: []const PartQuery,
    dirs: []const []const u8,
) !*Step.Run {
    if (parttable.len == 0)
        return error.EmptyPartitionTable;

    const disk_size = blk: {
        var i: usize = 1024 * 1024;
        for (parttable) |part| {
            i += part.size;
        }
        break :blk i;
    };
    const resolved_parts = try PartList.initBuffer(b.allocator, parttable);
    const disk_path = b.getInstallPath(.bin, name);
    const empty_disk = try addEmptyDisk(b, disk_size, disk_path);
    const partition_disk = try addParted(b, resolved_parts, disk_path);
    partition_disk.dependOn(&empty_disk.step);

    var mkfs: ?*Step.Run = null;
    for (resolved_parts.list.items) |part| {
        const mkfs_last = switch (part.fstype) {
            .fat16 => try addMkfsFat(b, 16, part.offset, part.label, disk_path),
            .fat32 => try addMkfsFat(b, 32, part.offset, part.label, disk_path),
            .ext4 => try addMkfsExt4(b, part.offset, part.label, disk_path),
        };
        if (mkfs) |prev| mkfs_last.step.dependOn(&prev.step);
        mkfs = mkfs_last;
    }
    if (mkfs) |step| step.step.dependOn(&partition_disk.step);

    return Disk{
        .step = mkfs orelse partition_disk,
        .path = disk_path,
        .fstab = resolved_parts,
    };
}
