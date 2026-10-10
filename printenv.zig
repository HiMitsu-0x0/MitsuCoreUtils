// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

const HELP =
    \\Usage: printenv [VARIABLE]...
    \\Print the values of the specified environment VARIABLE(s).
    \\With no VARIABLE, print the entire environment.
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

    var out_buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
    const out = &stdout.interface;

    if (args.len == 1) {
        var it = init.environ_map.iterator();
        while (it.next()) |e| {
            out.print("{s}={s}\n", .{ e.key_ptr.*, e.value_ptr.* }) catch return 1;
        }
        return 0;
    }

    var status: u8 = 0;
    for (args[1..]) |name| {
        if (init.environ_map.get(name)) |v| {
            out.print("{s}\n", .{v}) catch return 1;
        } else {
            status = 1;
        }
    }
    return status;
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
