// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

extern "c" fn chmod(
    pathname: [*:0]const u8,
    mode: c_uint,
) c_int;

const HELP =
    \\Usage: mkdir [OPTION]... DIRECTORY...
    \\Create the DIRECTORY(ies), if they do not already exist.
    \\
    \\  -m MODE   set file mode (octal), as in chmod
    \\  -p        no error if existing, make parent directories as needed
    \\  -v        print a message for each created directory
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

    var parents = false;
    var verbose = false;
    var mode: std.posix.mode_t = 0o777;
    var mode_set = false;
    var paths_start: usize = 1;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a: []const u8 = args[i];
        if (std.mem.eql(u8, a, "--")) {
            paths_start = i + 1;
            break;
        } else if (std.mem.eql(u8, a, "-p")) {
            parents = true;
        } else if (std.mem.eql(u8, a, "-v")) {
            verbose = true;
        } else if (std.mem.eql(u8, a, "-m")) {
            i += 1;
            if (i >= args.len) {
                var ebuf: [128]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.writeAll("mkdir: option requires an argument -- 'm'\n") catch {};
                return 1;
            }
            mode = parseMode(args[i]) orelse {
                var ebuf: [128]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.print("mkdir: invalid mode '{s}'\n", .{args[i]}) catch {};
                return 1;
            };
            mode_set = true;
            paths_start = i + 1;
        } else if (std.mem.startsWith(u8, a, "-m") and a.len > 2) {
            mode = parseMode(a[2..]) orelse {
                var ebuf: [128]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.print("mkdir: invalid mode '{s}'\n", .{a[2..]}) catch {};
                return 1;
            };
            mode_set = true;
            paths_start = i + 1;
        } else if (a.len > 1 and a[0] == '-') {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("mkdir: invalid option '{s}'\n", .{a}) catch {};
            return 1;
        } else {
            paths_start = i;
            break;
        }
    }

    const paths = args[paths_start..];
    if (paths.len == 0) {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("mkdir: missing operand\n") catch {};
        return 1;
    }

    var status: u8 = 0;
    for (paths) |p| {
        makeDir(init.arena.allocator(), init.io, p, parents, mode, mode_set) catch |err| {
            var ebuf: [512]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print(
                "mkdir: cannot create directory '{s}': {s}\n",
                .{ p, @errorName(err) },
            ) catch {};
            status = 1;
            continue;
        };
        if (verbose) {
            var out_buf: [4096]u8 = undefined;
            var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
            defer stdout.interface.flush() catch {};
            stdout.interface.print("mkdir: created directory '{s}'\n", .{p}) catch {};
        }
    }
    return status;
}

fn parseMode(s: []const u8) ?std.posix.mode_t {
    if (s.len == 0) return null;
    var m: std.posix.mode_t = 0;
    for (s) |c| {
        if (c < '0' or c > '7') return null;
        m = m * 8 + (c - '0');
    }
    return m;
}

fn makeDir(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    parents: bool,
    mode: std.posix.mode_t,
    mode_set: bool,
) !void {
    const cwd = std.Io.Dir.cwd();

    if (parents) {
        try cwd.createDirPath(io, path);
    } else {
        try cwd.createDir(io, path, @enumFromInt(mode));
    }

    if (mode_set) {
        const path_z = try allocator.allocSentinel(u8, path.len, 0);
        defer allocator.free(path_z);

        @memcpy(path_z, path);

        if (chmod(path_z, @intCast(mode)) != 0) {
            return error.ChmodFailed;
        }
    }
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
