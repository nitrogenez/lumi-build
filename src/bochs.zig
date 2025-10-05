const std = @import("std");

pub const Options = std.StringHashMapUnmanaged(?[]const u8);
pub const Rc = struct {
    plugin_ctrl: ?Options = null,
    config_interface: ?Options = null,
    display_library: ?Options = null,
    cpu: ?Options = null,
    cpuid: ?Options = null,
    memory: ?Options = null,
    megs: ?Options = null,
    romimage: ?Options = null,
    vgaromimage: ?Options = null,
    optromimage1: ?Options = null,
    optromimage2: ?Options = null,
    optromimage3: ?Options = null,
    optromimage4: ?Options = null,
    vga: ?Options = null,
    voodoo: ?Options = null,
    keyboard: ?Options = null,
    mouse: ?Options = null,
    pci: ?Options = null,
    clock: ?Options = null,
    cmosimage: ?Options = null,
    private_colormap: ?Options = null,
    floppya: ?Options = null,
    floppyb: ?Options = null,
    ata0: ?Options = null,
    ata1: ?Options = null,
    ata2: ?Options = null,
    ata3: ?Options = null,
    @"ata0-master": ?Options = null,
    @"ata1-master": ?Options = null,
    @"ata2-master": ?Options = null,
    @"ata3-master": ?Options = null,
    @"ata0-slave": ?Options = null,
    @"ata1-slave": ?Options = null,
    @"ata2-slave": ?Options = null,
    @"ata3-slave": ?Options = null,
    boot: ?Options = null,
    floppy_bootsig_check: ?Options = null,
    log: ?Options = null,
    logprefix: ?Options = null,
    panic: ?Options = null,
    @"error": ?Options = null,
    info: ?Options = null,
    debug: ?Options = null,
    debugger_log: ?Options = null,
    com1: ?Options = null,
    com2: ?Options = null,
    com3: ?Options = null,
    com4: ?Options = null,
    parport1: ?Options = null,
    parport2: ?Options = null,
    sound: ?Options = null,
    speaker: ?Options = null,
    sb16: ?Options = null,
    es1370: ?Options = null,
    ne2k: ?Options = null,
    pcipnic: ?Options = null,
    e1000: ?Options = null,
    usb_uhci: ?Options = null,
    usb_ohci: ?Options = null,
    usb_ehci: ?Options = null,
    usb_xhci: ?Options = null,
    pcidev: ?Options = null,

    pub fn set(
        self: *@This(),
        gpa: std.mem.Allocator,
        comptime field: []const u8,
        key: []const u8,
        value: ?[]const u8,
    ) !void {
        if (@field(self, field) == null)
            @field(self, field) = .{};
        try @field(self, field).?.put(gpa, key, value);
    }

    pub fn stringifyEntry(name: []const u8, opts: Options, writer: anytype) !void {
        try writer.writeAll(name);
        try writer.writeAll(": ");

        var iter = opts.iterator();
        var i: usize = 0;
        while (iter.next()) |entry| : (i += 1) {
            if (i != 0) try writer.writeAll(", ");

            try writer.writeAll(entry.key_ptr.*);
            if (entry.value_ptr.*) |value| {
                try writer.writeAll("=");
                try writer.writeAll(value);
            }
        }
    }

    pub fn stringify(self: @This(), writer: anytype) !void {
        inline for (@typeInfo(@This()).@"struct".fields) |field| {
            if (@field(self, field.name) != null) {
                try stringifyEntry(
                    field.name,
                    @field(self, field.name).?,
                    writer,
                );
            }
        }
    }

    pub fn stringifyAlloc(self: @This(), gpa: std.mem.Allocator) ![]const u8 {
        var arr = std.ArrayListUnmanaged(u8){};
        try self.stringify(arr.writer(gpa));
        return try arr.toOwnedSlice(gpa);
    }

    pub fn asArgv(self: @This(), gpa: std.mem.Allocator, program: []const u8) ![]const []const u8 {
        var arr = std.ArrayListUnmanaged([]const u8){};
        try arr.append(gpa, program);
        try arr.append(gpa, "-q");
        inline for (@typeInfo(@This()).@"struct".fields) |field| {
            if (@field(self, field.name) != null) {
                var str = std.ArrayListUnmanaged(u8){};
                try stringifyEntry(
                    field.name,
                    @field(self, field.name).?,
                    str.writer(gpa),
                );
                try arr.append(gpa, try str.toOwnedSlice(gpa));
            }
        }
        return arr.toOwnedSlice(gpa);
    }
};
