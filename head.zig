// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");
const print = std.debug.print;

const usage =
    \\Usage: head [options] <file>...
    \\
    \\Print the first 10 lines of each FILE to standard output.
    \\
    \\Options:
    \\  -n, --lines <N>   Print first N lines (default: 10)
    \\  --version         Show version
    \\  --help            Show this help
    \\
;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    const argc = args.len;

    if (argc > 1 and std.mem.eql(u8, args[1], "--version")) {
        print("Head (Mitsu CoreUtils)\n", .{});
        print("Copyright (c) 2026 Mitsu. All Rights Reserved.\n", .{});
        print("Written By HiMitsu\n", .{});
        return;
    }

    var n_lines: usize = 10;
    var files: std.ArrayList([]const u8) = .empty;
    defer files.deinit(allocator);

    var i: usize = 1;
    while (i < argc) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            print("{s}", .{usage});
            return;
        } else if (std.mem.eql(u8, arg, "-n") or std.mem.eql(u8, arg, "--lines")) {
            i += 1;
            if (i >= argc) {
                print("Error: -n requires an argument\n", .{});
                return;
            }
            n_lines = std.fmt.parseInt(usize, args[i], 10) catch {
                print("Error: invalid line count '{s}'\n", .{args[i]});
                return;
            };
        } else if (arg.len > 2 and std.mem.startsWith(u8, arg, "-n")) {
            n_lines = std.fmt.parseInt(usize, arg[2..], 10) catch {
                print("Error: invalid line count '{s}'\n", .{arg[2..]});
                return;
            };
        } else {
            try files.append(allocator, arg);
        }
    }

    if (files.items.len == 0) {
        print("{s}", .{usage});
        return;
    }

    const multi = files.items.len > 1;

    for (files.items, 0..) |file, idx| {
        if (multi) {
            if (idx > 0) print("\n", .{});
            print("==> {s} <==\n", .{file});
        }
        headFile(init.io, allocator, file, n_lines) catch |err| {
            print("head: {s}: {s}\n", .{ file, @errorName(err) });
        };
    }
}

fn headFile(io: std.Io, allocator: std.mem.Allocator, path: []const u8, n_lines: usize) !void {
    if (n_lines == 0) return;

    const data = try std.Io.Dir.cwd().readFileAlloc(
        io,
        path,
        allocator,
        std.Io.Limit.limited(64 * 1024 * 1024),
    );
    defer allocator.free(data);

    var count: usize = 0;
    var start: usize = 0;
    for (data, 0..) |c, j| {
        if (c == '\n') {
            print("{s}\n", .{data[start..j]});
            count += 1;
            if (count >= n_lines) return;
            start = j + 1;
        }
    }
    if (start < data.len) {
        print("{s}\n", .{data[start..]});
    }
}
