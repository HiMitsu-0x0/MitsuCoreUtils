// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

extern "c" fn symlink(target: [*:0]const u8, linkpath: [*:0]const u8) c_int;
extern "c" fn link(oldpath: [*:0]const u8, newpath: [*:0]const u8) c_int;
extern "c" fn unlink(pathname: [*:0]const u8) c_int;

const HELP =
    \\Usage: ln [OPTION]... TARGET [LINK_NAME]
    \\   or: ln [OPTION]... TARGET... DIRECTORY
    \\Create a link to TARGET.
    \\
    \\  -s, --symbolic   make symbolic links instead of hard links
    \\  -f, --force      remove existing destination files
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

    var symbolic = false;
    var force = false;
    var operands_start: usize = 1;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a: []const u8 = args[i];
        if (std.mem.eql(u8, a, "--")) {
            operands_start = i + 1;
            break;
        } else if (std.mem.eql(u8, a, "-s") or std.mem.eql(u8, a, "--symbolic")) {
            symbolic = true;
        } else if (std.mem.eql(u8, a, "-f") or std.mem.eql(u8, a, "--force")) {
            force = true;
        } else if (a.len > 1 and a[0] == '-') {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("ln: invalid option '{s}'\n", .{a}) catch {};
            return 1;
        } else {
            operands_start = i;
            break;
        }
    }

    const operands = args[operands_start..];
    if (operands.len == 0) {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("ln: missing file operand\n") catch {};
        return 1;
    }
    if (operands.len > 2) {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("ln: linking to multiple targets is not implemented\n") catch {};
        return 1;
    }

    const target = operands[0];
    const link_name: []const u8 = if (operands.len == 2) operands[1] else baseName(target);

    const tz = try alloc.allocSentinel(u8, target.len, 0);
    @memcpy(tz, target);

    const lz = try alloc.allocSentinel(u8, link_name.len, 0);
    @memcpy(lz, link_name);

    if (force) {
        _ = unlink(lz);
    }

    const rc = if (symbolic) symlink(tz, lz) else link(tz, lz);
    if (rc != 0) {
        var ebuf: [512]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.print("ln: failed to create link '{s}' -> '{s}'\n", .{ link_name, target }) catch {};
        return 1;
    }
    return 0;
}

fn baseName(path: []const u8) []const u8 {
    var i = path.len;
    while (i > 0) : (i -= 1) if (path[i - 1] == '/') break;
    return path[i..];
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
