// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

extern "c" fn utimensat(
    dirfd: c_int,
    pathname: [*:0]const u8,
    times: ?*const [2]Timespec,
    flags: c_int,
) c_int;

const Timespec = extern struct {
    tv_sec: isize,
    tv_nsec: isize,
};

const AT_FDCWD: c_int = -100;
const UTIME_NOW: isize = (1 << 30) - 1;
const UTIME_OMIT: isize = (1 << 30) - 2;

const HELP =
    \\Usage: touch [OPTION]... FILE...
    \\Update the access and modification times of each FILE to the current time.
    \\
    \\  -a             change only the access time
    \\  -m             change only the modification time
    \\  -c, --no-create  do not create any files
    \\      --help       display this help and exit
    \\
;

pub fn main(init: std.process.Init) !u8 {
    const alloc = init.arena.allocator();
    const args = try init.minimal.args.toSlice(alloc);

    for (args[1..]) |a| {
        if (std.mem.eql(u8, a, "--help")) {
            showHelp(init.io, HELP);
            return 0;
        }
    }

    var only_access = false;
    var only_modify = false;
    var no_create = false;
    var files_start: usize = 1;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a: []const u8 = args[i];
        if (std.mem.eql(u8, a, "--")) {
            files_start = i + 1;
            break;
        } else if (std.mem.eql(u8, a, "-a")) {
            only_access = true;
        } else if (std.mem.eql(u8, a, "-m")) {
            only_modify = true;
        } else if (std.mem.eql(u8, a, "-c") or std.mem.eql(u8, a, "--no-create")) {
            no_create = true;
        } else if (a.len > 1 and a[0] == '-') {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("touch: invalid option '{s}'\n", .{a}) catch {};
            return 1;
        } else {
            files_start = i;
            break;
        }
    }

    const files = args[files_start..];
    if (files.len == 0) {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("touch: missing file operand\n") catch {};
        return 1;
    }

    var status: u8 = 0;
    for (files) |p| {
        touchFile(init.io, alloc, p, only_access, only_modify, no_create) catch |err| {
            var ebuf: [512]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("touch: cannot touch '{s}': {s}\n", .{ p, @errorName(err) }) catch {};
            status = 1;
        };
    }
    return status;
}

fn touchFile(
    io: std.Io,
    alloc: std.mem.Allocator,
    path: []const u8,
    only_access: bool,
    only_modify: bool,
    no_create: bool,
) !void {
    const cwd = std.Io.Dir.cwd();
    if (!no_create) {
        const f = cwd.createFile(io, path, .{ .truncate = false }) catch |err| switch (err) {
            error.PathAlreadyExists => null,
            else => return err,
        };
        if (f) |fh| fh.close(io);
    } else {
        const f = cwd.openFile(io, path, .{}) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return err,
        };
        f.close(io);
    }

    const z = try alloc.allocSentinel(u8, path.len, 0);
    @memcpy(z, path);

    var times: [2]Timespec = undefined;
    const atime_nsec: isize = if (only_modify) UTIME_OMIT else UTIME_NOW;
    const mtime_nsec: isize = if (only_access) UTIME_OMIT else UTIME_NOW;
    times = .{
        .{ .tv_sec = 0, .tv_nsec = atime_nsec },
        .{ .tv_sec = 0, .tv_nsec = mtime_nsec },
    };

    if (utimensat(AT_FDCWD, z, &times, 0) != 0) {
        return error.UtimensatFailed;
    }
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
