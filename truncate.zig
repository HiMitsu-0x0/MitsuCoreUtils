// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

const HELP =
    \\Usage: truncate [OPTION]... FILE...
    \\Shrink or extend the size of each FILE to the specified size.
    \\
    \\  -s, --size=SIZE  set or adjust the file size
    \\  -c, --no-create  do not create any files
    \\      --help       display this help and exit
    \\
    \\SIZE may be followed by K, M, or G for KiB, MiB, GiB.
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

    var size: ?i64 = null;
    var no_create = false;
    var paths_start: usize = 1;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a: []const u8 = args[i];
        if (std.mem.eql(u8, a, "--")) {
            paths_start = i + 1;
            break;
        } else if (std.mem.eql(u8, a, "-c") or std.mem.eql(u8, a, "--no-create")) {
            no_create = true;
        } else if (std.mem.eql(u8, a, "-s") or std.mem.eql(u8, a, "--size")) {
            i += 1;
            if (i >= args.len) {
                var ebuf: [128]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.writeAll("truncate: option requires an argument -- 's'\n") catch {};
                return 1;
            }
            size = parseSize(args[i]) orelse {
                var ebuf: [128]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.print("truncate: invalid size '{s}'\n", .{args[i]}) catch {};
                return 1;
            };
            paths_start = i + 1;
        } else if (std.mem.startsWith(u8, a, "-s") and a.len > 2) {
            size = parseSize(a[2..]) orelse {
                var ebuf: [128]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.print("truncate: invalid size '{s}'\n", .{a[2..]}) catch {};
                return 1;
            };
            paths_start = i + 1;
        } else if (a.len > 1 and a[0] == '-') {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("truncate: invalid option '{s}'\n", .{a}) catch {};
            return 1;
        } else {
            paths_start = i;
            break;
        }
    }

    const paths = args[paths_start..];

    if (size == null) {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("truncate: you must specify '--size'\n") catch {};
        return 1;
    }
    if (paths.len == 0) {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("truncate: missing file operand\n") catch {};
        return 1;
    }

    var status: u8 = 0;
    for (paths) |p| {
        truncateFile(init.io, p, size.?, no_create) catch |err| {
            var ebuf: [512]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print(
                "truncate: cannot open '{s}' for writing: {s}\n",
                .{ p, @errorName(err) },
            ) catch {};
            status = 1;
        };
    }
    return status;
}

fn parseSize(s: []const u8) ?i64 {
    if (s.len == 0) return null;
    var mult: i64 = 1;
    var end = s.len;
    switch (s[s.len - 1]) {
        'K', 'k' => {
            mult = 1024;
            end -= 1;
        },
        'M', 'm' => {
            mult = 1024 * 1024;
            end -= 1;
        },
        'G', 'g' => {
            mult = 1024 * 1024 * 1024;
            end -= 1;
        },
        else => {},
    }
    if (end == 0) return null;
    const n = std.fmt.parseInt(i64, s[0..end], 10) catch return null;
    if (n < 0) return null;
    return n * mult;
}

fn truncateFile(io: std.Io, path: []const u8, size: i64, no_create: bool) !void {
    const cwd = std.Io.Dir.cwd();
    const f = cwd.openFile(io, path, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => {
            if (no_create) return;
            const nf = try cwd.createFile(io, path, .{});
            nf.close(io);
            return;
        },
        else => return err,
    };
    defer f.close(io);
    try f.setLength(io, @intCast(size));
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
