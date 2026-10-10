// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

const HELP =
    \\Usage: seq [OPTION]... LAST
    \\   or: seq [OPTION]... FIRST LAST
    \\   or: seq [OPTION]... FIRST INCREMENT LAST
    \\Print numbers from FIRST to LAST, in steps of INCREMENT.
    \\
    \\  -s, --separator=STRING  use STRING to separate numbers (default: \n)
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

    var sep: []const u8 = "\n";
    var nums_start: usize = 1;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a: []const u8 = args[i];
        if (std.mem.eql(u8, a, "--")) {
            nums_start = i + 1;
            break;
        } else if (std.mem.eql(u8, a, "-s") or std.mem.eql(u8, a, "--separator")) {
            i += 1;
            if (i >= args.len) {
                var ebuf: [128]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.writeAll("seq: option requires an argument -- 's'\n") catch {};
                return 1;
            }
            sep = args[i];
            nums_start = i + 1;
        } else if (std.mem.eql(u8, a, "-w") or std.mem.eql(u8, a, "--equal-width")) {
            nums_start = i + 1; // not yet implemented
        } else if (a.len > 1 and a[0] == '-') {
            if (std.fmt.parseFloat(f64, a)) |_| {
                nums_start = i;
                break;
            } else |_| {
                var ebuf: [256]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.print("seq: invalid option '{s}'\n", .{a}) catch {};
                return 1;
            }
        } else {
            nums_start = i;
            break;
        }
    }

    const nums = args[nums_start..];

    var first: f64 = 1;
    var step: f64 = 1;
    var last: f64 = undefined;

    switch (nums.len) {
        1 => last = parseOr(nums[0]),
        2 => {
            first = parseOr(nums[0]);
            last = parseOr(nums[1]);
        },
        3 => {
            first = parseOr(nums[0]);
            step = parseOr(nums[1]);
            last = parseOr(nums[2]);
        },
        else => {
            var ebuf: [128]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.writeAll("seq: missing operand\n") catch {};
            return 1;
        },
    }

    if (step == 0) {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("seq: invalid zero increment value\n") catch {};
        return 1;
    }

    var out_buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
    const out = &stdout.interface;

    var cur = first;
    var count: usize = 0;
    const eps = @abs(step) * 1e-9;

    if (step > 0) {
        while (cur <= last + eps) : (cur += step) {
            if (count > 0) out.writeAll(sep) catch return 1;
            out.print("{d}", .{cur}) catch return 1;
            count += 1;
            if (count > 1_000_000_000) break;
        }
    } else {
        while (cur >= last - eps) : (cur += step) {
            if (count > 0) out.writeAll(sep) catch return 1;
            out.print("{d}", .{cur}) catch return 1;
            count += 1;
            if (count > 1_000_000_000) break;
        }
    }
    if (count > 0) out.writeAll("\n") catch {};
    return 0;
}

fn parseOr(s: []const u8) f64 {
    return std.fmt.parseFloat(f64, s) catch {
        std.debug.print("seq: invalid floating point argument: '{s}'\n", .{s});
        std.process.exit(1);
    };
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
