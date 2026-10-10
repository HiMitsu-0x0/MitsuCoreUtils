// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

const HELP =
    \\Usage: cmp [OPTION]... FILE1 [FILE2]
    \\Compare two files byte by byte.
    \\If FILE2 is omitted or is '-', read standard input.
    \\
    \\  -s, --silent, --quiet   suppress all normal output
    \\      --help              display this help and exit
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

    var silent = false;
    var files_start: usize = 1;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a: []const u8 = args[i];
        if (std.mem.eql(u8, a, "--")) {
            files_start = i + 1;
            break;
        } else if (std.mem.eql(u8, a, "-s") or
            std.mem.eql(u8, a, "--silent") or
            std.mem.eql(u8, a, "--quiet"))
        {
            silent = true;
        } else if (a.len > 1 and a[0] == '-') {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("cmp: invalid option '{s}'\n", .{a}) catch {};
            return 2;
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
        ew.interface.writeAll("cmp: missing operand\n") catch {};
        return 2;
    }

    const p1 = files[0];
    const p2: []const u8 = if (files.len >= 2) files[1] else "-";

    const f1_is_stdin = std.mem.eql(u8, p1, "-");
    const f2_is_stdin = std.mem.eql(u8, p2, "-");

    const f1 = if (f1_is_stdin) std.Io.File.stdin() else openIn(init.io, p1) catch |e| {
        var ebuf: [512]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.print("cmp: {s}: {s}\n", .{ p1, @errorName(e) }) catch {};
        return 2;
    };
    defer if (!f1_is_stdin) f1.close(init.io);

    const f2 = if (f2_is_stdin) std.Io.File.stdin() else openIn(init.io, p2) catch |e| {
        var ebuf: [512]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.print("cmp: {s}: {s}\n", .{ p2, @errorName(e) }) catch {};
        return 2;
    };
    defer if (!f2_is_stdin) f2.close(init.io);

    var r1_buf: [64 * 1024]u8 = undefined;
    var r1 = f1.reader(init.io, &r1_buf);
    var r2_buf: [64 * 1024]u8 = undefined;
    var r2 = f2.reader(init.io, &r2_buf);

    var b1: [64 * 1024]u8 = undefined;
    var b2: [64 * 1024]u8 = undefined;
    var offset: u64 = 0;
    var line: u64 = 1;

    while (true) {
        const n1 = r1.interface.readSliceShort(&b1) catch 0;
        const n2 = r2.interface.readSliceShort(&b2) catch 0;
        const nm = @min(n1, n2);

        var j: usize = 0;
        while (j < nm) : (j += 1) {
            if (b1[j] != b2[j]) {
                if (!silent) {
                    var out_buf: [4096]u8 = undefined;
                    var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
                    defer stdout.interface.flush() catch {};
                    stdout.interface.print(
                        "{s} {s} differ: byte {d}, line {d}\n",
                        .{ p1, p2, offset + j + 1, line },
                    ) catch {};
                }
                return 1;
            }
            if (b1[j] == '\n') line += 1;
        }
        offset += nm;

        if (n1 != n2) {
            if (!silent) {
                const shorter = if (n1 < n2) p1 else p2;
                var out_buf: [4096]u8 = undefined;
                var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
                defer stdout.interface.flush() catch {};
                stdout.interface.print(
                    "cmp: EOF on {s} after byte {d}, line {d}\n",
                    .{ shorter, offset, line },
                ) catch {};
            }
            return 1;
        }
        if (n1 == 0) return 0;
    }
}

fn openIn(io: std.Io, p: []const u8) !std.Io.File {
    return std.Io.Dir.cwd().openFile(io, p, .{});
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
