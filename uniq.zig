// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

const HELP =
    \\Usage: uniq [OPTION]... [INPUT [OUTPUT]]
    \\Filter adjacent matching lines from INPUT (or standard input).
    \\
    \\  -c, --count     prefix lines by the number of occurrences
    \\  -d, --repeated  only print duplicate lines
    \\  -u, --unique    only print unique lines
    \\      --help      display this help and exit
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

    var count = false;
    var repeated = false;
    var unique = false;
    var files_start: usize = 1;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a: []const u8 = args[i];
        if (std.mem.eql(u8, a, "--")) {
            files_start = i + 1;
            break;
        } else if (std.mem.eql(u8, a, "-c") or std.mem.eql(u8, a, "--count")) {
            count = true;
        } else if (std.mem.eql(u8, a, "-d") or std.mem.eql(u8, a, "--repeated")) {
            repeated = true;
        } else if (std.mem.eql(u8, a, "-u") or std.mem.eql(u8, a, "--unique")) {
            unique = true;
        } else if (a.len > 1 and a[0] == '-') {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("uniq: invalid option '{s}'\n", .{a}) catch {};
            return 1;
        } else {
            files_start = i;
            break;
        }
    }

    const files = args[files_start..];

    var input: std.ArrayList(u8) = .empty;
    defer input.deinit(init.gpa);

    if (files.len == 0) {
        var in_buf: [4096]u8 = undefined;
        var stdin_reader = std.Io.File.stdin().reader(init.io, &in_buf);
        const reader = &stdin_reader.interface;
        var tmp: [4096]u8 = undefined;
        while (true) {
            const n = reader.readSliceShort(&tmp) catch break;
            if (n == 0) break;
            input.appendSlice(init.gpa, tmp[0..n]) catch break;
        }
    } else {
        const f = std.Io.Dir.cwd().openFile(init.io, files[0], .{}) catch |e| {
            var ebuf: [512]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("uniq: {s}: {s}\n", .{ files[0], @errorName(e) }) catch {};
            return 1;
        };
        defer f.close(init.io);

        var r_buf: [4096]u8 = undefined;
        var fr = f.reader(init.io, &r_buf);
        var tmp: [4096]u8 = undefined;
        while (true) {
            const n = fr.interface.readSliceShort(&tmp) catch break;
            if (n == 0) break;
            input.appendSlice(init.gpa, tmp[0..n]) catch break;
        }
    }

    var lines: std.ArrayList([]const u8) = .empty;
    defer lines.deinit(init.gpa);
    var it = std.mem.splitScalar(u8, input.items, '\n');
    while (it.next()) |line| lines.append(init.gpa, line) catch {};
    if (lines.items.len > 0 and lines.items[lines.items.len - 1].len == 0) _ = lines.pop();

    var out_buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
    const out = &stdout.interface;

    var prev: ?[]const u8 = null;
    var n: usize = 0;

    for (lines.items) |line| {
        if (prev) |p| {
            if (std.mem.eql(u8, p, line)) {
                n += 1;
                continue;
            }
            emit(out, p, n, count, repeated, unique) catch return 1;
        }
        prev = line;
        n = 1;
    }
    if (prev) |p| emit(out, p, n, count, repeated, unique) catch return 1;
    return 0;
}

fn emit(w: *std.Io.Writer, line: []const u8, n: usize, count: bool, repeated: bool, unique: bool) !void {
    const is_rep = n > 1;
    if (repeated and !is_rep) return;
    if (unique and is_rep) return;
    if (count) try w.print("{d: >7} {s}\n", .{ n, line })
    else try w.print("{s}\n", .{line});
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
