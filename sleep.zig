// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

const HELP =
    \\Usage: sleep NUMBER[SUFFIX]...
    \\Pause for NUMBER seconds. SUFFIX may be 's', 'm', 'h', or 'd'.
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

    if (args.len < 2) {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("sleep: missing operand\n") catch {};
        return 1;
    }

    var total: f64 = 0;
    for (args[1..]) |a| {
        const v = std.fmt.parseFloat(f64, a) catch {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("sleep: invalid time interval '{s}'\n", .{a}) catch {};
            return 1;
        };
        if (v < 0) {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("sleep: invalid time interval '{s}'\n", .{a}) catch {};
            return 1;
        }
        total += v;
    }

    if (total <= 0) return 0;
    const ns_f = total * @as(f64, @floatFromInt(std.time.ns_per_s));
    const max_ns: f64 = @floatFromInt(std.math.maxInt(u64));
    const ns: u64 = if (ns_f >= max_ns) std.math.maxInt(u64) else @intFromFloat(ns_f);

    try std.Io.sleep(init.io, std.Io.Duration.fromNanoseconds(ns), .awake);
    return 0;
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
