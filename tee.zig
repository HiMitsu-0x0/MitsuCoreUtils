// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

const HELP =
    \\Usage: tee [OPTION]... [FILE]...
    \\Copy standard input to each FILE, and also to standard output.
    \\
    \\  -a, --append             append to the given FILEs, do not overwrite
    \\  -i, --ignore-interrupts  ignore interrupt signals
    \\      --help               display this help and exit
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

    var append = false;
    var files_start: usize = 1;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a: []const u8 = args[i];
        if (std.mem.eql(u8, a, "--")) {
            files_start = i + 1;
            break;
        } else if (std.mem.eql(u8, a, "-a") or std.mem.eql(u8, a, "--append")) {
            append = true;
        } else if (std.mem.eql(u8, a, "-i") or std.mem.eql(u8, a, "--ignore-interrupts")) {
            // accepted, no-op
        } else if (a.len > 1 and a[0] == '-') {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("tee: invalid option '{s}'\n", .{a}) catch {};
            return 1;
        } else {
            files_start = i;
            break;
        }
    }

    const files = args[files_start..];

    var handles: std.ArrayList(std.Io.File) = .empty;
    defer {
        for (handles.items) |h| h.close(init.io);
        handles.deinit(init.gpa);
    }

    const flags: std.Io.Dir.CreateFileOptions = if (append)
        .{ .truncate = false }
    else
        .{ .truncate = true };

    var status: u8 = 0;
    for (files) |p| {
        const h = std.Io.Dir.cwd().createFile(init.io, p, flags) catch |e| {
            var ebuf: [512]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("tee: {s}: {s}\n", .{ p, @errorName(e) }) catch {};
            status = 1;
            continue;
        };
        handles.append(init.gpa, h) catch {
            h.close(init.io);
            continue;
        };
    }

    var in_buf: [4096]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(init.io, &in_buf);
    const reader = &stdin_reader.interface;

    var out_buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
    const out = &stdout.interface;

    var data_buf: [64 * 1024]u8 = undefined;

    while (true) {
        const n = reader.readSliceShort(&data_buf) catch break;
        if (n == 0) break;

        out.writeAll(data_buf[0..n]) catch {};

        for (handles.items) |h| {
            var fb: [4096]u8 = undefined;
            var fw: std.Io.File.Writer = .init(h, init.io, &fb);

            if (append) {
                const end = h.length(init.io) catch 0;
                fw.seekTo(end) catch |e| {
                    var ebuf: [256]u8 = undefined;
                    var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                    defer ew.interface.flush() catch {};
                    ew.interface.print("tee: seek error: {s}\n", .{@errorName(e)}) catch {};
                    status = 1;
                    continue;
                };
            }

            fw.interface.writeAll(data_buf[0..n]) catch |e| {
                var ebuf: [256]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.print("tee: write error: {s}\n", .{@errorName(e)}) catch {};
                status = 1;
                continue;
            };
            fw.interface.flush() catch {};
        }
    }
    out.flush() catch {};
    return status;
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
