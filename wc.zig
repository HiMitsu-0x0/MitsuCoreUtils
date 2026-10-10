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
        const file_path = args[1];

        const file = try std.Io.Dir.cwd().openFile(init.io, file_path, .{});
        defer file.close(init.io);

        var in_buf: [4096]u8 = undefined;
        var file_reader = file.reader(init.io, &in_buf);
        const input = &file_reader.interface;

        var lines: usize = 0;
        var words: usize = 0;
        var chars: usize = 0;
        var in_word = false;

        while (try input.takeDelimiter('\n')) |line| {
            lines += 1;
            chars += line.len + 1;

            for (line) |c| {
                if (c == ' ' or c == '\t' or c == '\r') {
                    in_word = false;
                } else if (!in_word) {
                    in_word = true;
                    words += 1;
                }
            }
            in_word = false;
        }
        print("Lines: {d}, Words: {d}, Characters: {d}\n", .{lines, words, chars});
    } else {
        print("Command Not Found, Using:\n", .{});
        print("wc <file>\n", .{});
    }
}
