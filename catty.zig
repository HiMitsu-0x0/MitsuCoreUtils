// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(allocator);
    const argc = args.len;

    if (argc > 1 and std.mem.eql(u8, args[1], "--version")) {
        std.debug.print("Catty (Mitsu CoreUtils)\n", .{});
        std.debug.print("Copyright (c) 2026 Mitsu. All Rights Reserved.\n\n", .{});
        std.debug.print("Written By HiMitsu\n", .{});
        return;
    }
    
    if (argc > 1) {
        const file_path = args[1];
        
        const file = try std.Io.Dir.cwd().openFile(init.io, file_path, .{});
        defer file.close(init.io);

        var buf: [4096]u8 = undefined;
        var reader = file.reader(init.io, &buf);
        const bytes_read = try reader.interface.readSliceShort(&buf);
        
        std.debug.print("{s}\n", .{buf[0..bytes_read]});
    } else {
        std.debug.print("Command Not Found, Using:\n", .{});
        std.debug.print("catty <file>\n", .{});
    }
}
