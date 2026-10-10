// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

extern "c" fn getlogin() ?[*:0]u8;

const HELP =
    \\Usage: logname
    \\Print the user's login name.
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

    const name = getlogin() orelse {
        var ebuf: [64]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("logname: no login name\n") catch {};
        return 1;
    };

    var buf: [256]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &buf);
    defer stdout.interface.flush() catch {};
    stdout.interface.print("{s}\n", .{std.mem.span(name)}) catch return 1;
    return 0;
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
