// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

const HELP =
    \\Usage: dirname NAME...
    \\Strip the last component from NAME.
    \\
    \\      --help  display this help and exit
    \\
;

pub fn main(init: std.process.Init) !u8 {
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    for (args[1..]) |a| {
        if (std.mem.eql(u8, a, "--help")) {
            showHelp(init.io, HELP);
            return 0;
        }
    }

    var names_start: usize = 1;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a: []const u8 = args[i];
        if (std.mem.eql(u8, a, "--")) {
            names_start = i + 1;
            break;
        } else if (a.len > 1 and a[0] == '-') {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("dirname: invalid option '{s}'\n", .{a}) catch {};
            return 1;
        } else {
            names_start = i;
            break;
        }
    }

    const names = args[names_start..];
    if (names.len == 0) {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("dirname: missing operand\n") catch {};
        return 1;
    }

    var out_buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
    const out = &stdout.interface;

    for (names) |name| {
        out.print("{s}\n", .{dirName(name)}) catch return 1;
    }
    return 0;
}

fn dirName(path: []const u8) []const u8 {
    if (path.len == 0) return ".";
    var end = path.len;
    while (end > 1 and path[end - 1] == '/') end -= 1;

    var all_slash = true;
    for (path[0..end]) |c| if (c != '/') {
        all_slash = false;
        break;
    };
    if (all_slash) return "/";

    var i = end;
    while (i > 0) : (i -= 1) if (path[i - 1] == '/') break;
    if (i == 0) return ".";

    var dend = i;
    while (dend > 1 and path[dend - 1] == '/') dend -= 1;
    return path[0..dend];
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
