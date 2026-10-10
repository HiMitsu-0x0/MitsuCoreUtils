// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");
const linux = std.os.linux;

const HELP =
    \\Usage: whoami
    \\Print the user name associated with the current effective user ID.
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

    const uid: u32 = @intCast(linux.getuid());

    const pw = std.c.getpwuid(uid) orelse {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.print("whoami: cannot find name for user ID {d}\n", .{uid}) catch {};
        return 1;
    };

    const name = std.mem.span(pw.name orelse {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.print("whoami: cannot find name for user ID {d}\n", .{uid}) catch {};
        return 1;
    });

    var buf: [256]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &buf);
    defer stdout.interface.flush() catch {};
    stdout.interface.print("{s}\n", .{name}) catch return 1;
    return 0;
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
