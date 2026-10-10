// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

const HELP =
    \\Usage: yes [STRING]...
    \\Repeatedly output a line with all specified STRING(s), or 'y'.
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

    var line_buf: [4096]u8 = undefined;
    var line_len: usize = 0;

    if (args.len > 1) {
        for (args[1..], 0..) |a, idx| {
            if (idx > 0 and line_len < line_buf.len) {
                line_buf[line_len] = ' ';
                line_len += 1;
            }
            for (a) |c| {
                if (line_len >= line_buf.len) break;
                line_buf[line_len] = c;
                line_len += 1;
            }
        }
    } else {
        line_buf[0] = 'y';
        line_len = 1;
    }
    if (line_len < line_buf.len) {
        line_buf[line_len] = '\n';
        line_len += 1;
    }

    const line = line_buf[0..line_len];

    var out_buf: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
    const out = &stdout.interface;

    while (true) {
        out.writeAll(line) catch return 0;
    }
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
