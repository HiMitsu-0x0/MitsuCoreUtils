// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");
const print = std.debug.print;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    const argc = args.len;

    if (argc > 1 and std.mem.eql(u8, args[1], "--version")) {
        print("Echo (Mitsu CoreUtils)\n", .{});
        print("Copyright (c) 2026 Mitsu. All Rights Reserved.\n", .{});
        print("Written By HiMitsu\n", .{});
        return;
    }
    if (argc > 1) {
        const file_path = std.Io.File.stdout();
        var buffer: [4096]u8 = undefined;
        var file_writer = std.Io.File.writer(file_path, init.io, &buffer);
        const output = &file_writer.interface;

        for (args[1..], 0..) |arg, i| {
            if (i  != 0) try output.writeByte(' ');
            try output.writeAll(arg);
        }
        try output.writeByte('\n');
        try output.flush();
    } else {
        print("Command Not Found, Using:\n", .{});
        print("echo <word>\n", .{});
        print("echo <word> > <file>\n", .{});
    }
}
