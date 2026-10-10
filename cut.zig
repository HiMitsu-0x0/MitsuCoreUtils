// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

const HELP =
    \\Usage: cut OPTION... [FILE]...
    \\Print selected parts of lines from each FILE to standard output.
    \\
    \\  -b LIST    select only these bytes
    \\  -c LIST    select only these characters
    \\  -d DELIM   use DELIM instead of TAB for field delimiter
    \\  -f LIST    select only these fields
    \\  -s         do not print lines not containing delimiters
    \\      --help display this help and exit
    \\
    \\LIST is a comma-separated list of N, N-, -M, or N-M ranges.
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

    var mode: enum { none, bytes, chars, fields } = .none;
    var list_str: []const u8 = "";
    var delim: u8 = '\t';
    var suppress = false;
    var files_start: usize = 1;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a: []const u8 = args[i];
        if (std.mem.eql(u8, a, "--")) {
            files_start = i + 1;
            break;
        } else if (std.mem.eql(u8, a, "-b") or std.mem.eql(u8, a, "-c") or std.mem.eql(u8, a, "-f")) {
            i += 1;
            if (i >= args.len) return errMissing(init.io, a);
            list_str = args[i];
            mode = if (std.mem.eql(u8, a, "-b")) .bytes else if (std.mem.eql(u8, a, "-c")) .chars else .fields;
            files_start = i + 1;
        } else if (std.mem.startsWith(u8, a, "-b") and a.len > 2) {
            list_str = a[2..]; mode = .bytes; files_start = i + 1;
        } else if (std.mem.startsWith(u8, a, "-c") and a.len > 2) {
            list_str = a[2..]; mode = .chars; files_start = i + 1;
        } else if (std.mem.startsWith(u8, a, "-f") and a.len > 2) {
            list_str = a[2..]; mode = .fields; files_start = i + 1;
        } else if (std.mem.eql(u8, a, "-d")) {
            i += 1;
            if (i >= args.len) return errMissing(init.io, a);
            if (args[i].len != 1) {
                var ebuf: [128]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.writeAll("cut: delimiter must be a single character\n") catch {};
                return 1;
            }
            delim = args[i][0];
            files_start = i + 1;
        } else if (std.mem.startsWith(u8, a, "-d") and a.len > 2) {
            if (a.len != 3) {
                var ebuf: [128]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.writeAll("cut: delimiter must be a single character\n") catch {};
                return 1;
            }
            delim = a[2];
            files_start = i + 1;
        } else if (std.mem.eql(u8, a, "-s")) {
            suppress = true;
        } else if (a.len > 1 and a[0] == '-') {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("cut: invalid option '{s}'\n", .{a}) catch {};
            return 1;
        } else {
            files_start = i;
            break;
        }
    }

    if (mode == .none) {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("cut: you must specify a list of bytes, characters, or fields\n") catch {};
        return 1;
    }

    var ranges = std.ArrayList(Range).empty;
    defer ranges.deinit(alloc);
    parseList(alloc, list_str, &ranges) catch {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("cut: invalid list\n") catch {};
        return 1;
    };

    const files = args[files_start..];

    var out_buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
    const out = &stdout.interface;

    if (files.len == 0) {
        processStream(init.io, alloc, std.Io.File.stdin(), mode, ranges.items, delim, suppress, out) catch |e| {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("cut: read error: {s}\n", .{@errorName(e)}) catch {};
            return 1;
        };
    } else {
        for (files) |p| {
            const f = std.Io.Dir.cwd().openFile(init.io, p, .{}) catch |e| {
                var ebuf: [512]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.print("cut: {s}: {s}\n", .{ p, @errorName(e) }) catch {};
                continue;
            };
            defer f.close(init.io);
            processStream(init.io, alloc, f, mode, ranges.items, delim, suppress, out) catch {};
        }
    }
    out.flush() catch {};
    return 0;
}

const Range = struct { lo: usize, hi: ?usize };

fn parseList(alloc: std.mem.Allocator, s: []const u8, out: *std.ArrayList(Range)) !void {
    var it = std.mem.splitScalar(u8, s, ',');
    while (it.next()) |part| {
        if (part.len == 0) continue;
        if (std.mem.indexOfScalar(u8, part, '-')) |dash| {
            if (dash == 0) {
                const hi = try std.fmt.parseInt(usize, part[1..], 10);
                try out.append(alloc, .{ .lo = 1, .hi = hi });
            } else if (dash == part.len - 1) {
                const lo = try std.fmt.parseInt(usize, part[0..dash], 10);
                try out.append(alloc, .{ .lo = lo, .hi = null });
            } else {
                const lo = try std.fmt.parseInt(usize, part[0..dash], 10);
                const hi = try std.fmt.parseInt(usize, part[dash + 1 ..], 10);
                try out.append(alloc, .{ .lo = lo, .hi = hi });
            }
        } else {
            const n = try std.fmt.parseInt(usize, part, 10);
            try out.append(alloc, .{ .lo = n, .hi = n });
        }
    }
}

fn inRanges(idx: usize, ranges: []const Range) bool {
    for (ranges) |r| {
        if (idx >= r.lo and (r.hi == null or idx <= r.hi.?)) return true;
    }
    return false;
}

fn processStream(
    io: std.Io,
    alloc: std.mem.Allocator,
    input: std.Io.File,
    mode: anytype,
    ranges: []const Range,
    delim: u8,
    suppress: bool,
    out: *std.Io.Writer,
) !void {
    var r_buf: [4096]u8 = undefined;
    var reader = input.reader(io, &r_buf);
    var line_buf: std.ArrayList(u8) = .empty;
    defer line_buf.deinit(alloc);

    var chunk: [4096]u8 = undefined;
    while (true) {
        const n = reader.interface.readSliceShort(&chunk) catch break;
        if (n == 0) break;
        for (chunk[0..n]) |c| {
            if (c == '\n') {
                try processLine(line_buf.items, mode, ranges, delim, suppress, out);
                line_buf.clearRetainingCapacity();
            } else {
                try line_buf.append(alloc, c);
            }
        }
    }
    if (line_buf.items.len > 0) {
        try processLine(line_buf.items, mode, ranges, delim, suppress, out);
    }
}

fn processLine(
    line: []const u8,
    mode: anytype,
    ranges: []const Range,
    delim: u8,
    suppress: bool,
    out: *std.Io.Writer,
) !void {
    switch (mode) {
        .bytes, .chars => {
            for (line, 0..) |c, idx| {
                if (inRanges(idx + 1, ranges)) try out.writeByte(c);
            }
            try out.writeByte('\n');
        },
        .fields => {
            var n_delim: usize = 0;
            for (line) |c| if (c == delim) { n_delim += 1; };
            if (n_delim == 0) {
                if (suppress) return;
                try out.writeAll(line);
                try out.writeByte('\n');
                return;
            }
            var field_idx: usize = 1;
            var field_start: usize = 0;
            var first = true;
            var i: usize = 0;
            while (i <= line.len) : (i += 1) {
                const at_end = i == line.len;
                const at_delim = !at_end and line[i] == delim;
                if (at_end or at_delim) {
                    if (inRanges(field_idx, ranges)) {
                        if (!first) try out.writeByte(delim);
                        try out.writeAll(line[field_start..i]);
                        first = false;
                    }
                    field_idx += 1;
                    field_start = i + 1;
                }
            }
            try out.writeByte('\n');
        },
        else => {},
    }
}

fn errMissing(io: std.Io, opt: []const u8) u8 {
    var ebuf: [256]u8 = undefined;
    var ew = std.Io.File.stderr().writer(io, &ebuf);
    defer ew.interface.flush() catch {};
    ew.interface.print("cut: option requires an argument -- '{s}'\n", .{opt}) catch {};
    return 1;
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
