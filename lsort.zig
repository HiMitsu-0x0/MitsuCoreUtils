// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");
const print = std.debug.print;

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(allocator);
    const argc = args.len;

    if (argc > 1 and std.mem.eql(u8, args[1], "--version")) {
        print("LSort (Mitsu CoreUtils)\n", .{});
        print("Copyright (c) 2026 Mitsu. All Rights Reserved.\n\n", .{});
        print("Written By HiMitsu\n", .{});
        return;
    }

    if (argc > 1) {
        const file_path = args[1];

        const file = try std.Io.Dir.cwd().openFile(init.io, file_path, .{});
        defer file.close(init.io);

        const stdout = std.Io.File.stdout();
        var out_buf: [4096]u8 = undefined;
        var file_writer = std.Io.File.writer(stdout, init.io, &out_buf);
        const output = &file_writer.interface; 

        var in_buf: [4096]u8 = undefined;
        var file_reader = file.reader(init.io, &in_buf);
        const input = &file_reader.interface;

        var lines: std.ArrayList([]const u8) = .empty;
        defer {
            for (lines.items) |line| {
                init.gpa.free(line);
            }
            lines.deinit(init.gpa);
        }
        
        while (try input.takeDelimiter('\n')) |line| {
            const owned = try init.gpa.dupe(u8, line);
            try lines.append(init.gpa, owned);
        }
        std.mem.sort([]const u8, lines.items, {}, lessThan);
        for (lines.items) |line| {
            try output.print("{s}\n", .{line});
        }
        try output.flush();
    } else {
        print("Command Not Found, Using:\n", .{});
        print("lsort <file>\n", .{});
    }
}
