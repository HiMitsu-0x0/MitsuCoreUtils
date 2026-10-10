// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");
const print = std.debug.print;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);

    if (args.len < 2) {
        print("Usage: rm <file>...\n", .{});
        return;
    }
    if (std.mem.eql(u8, args[1], "--version")) {
        print("RM (Mitsu CoreUtils)\n", .{});
        print("Copyright (c) 2026 Mitsu. All Rights Reserved.\n", .{});
        print("Written By HiMitsu\n", .{});
        return;
    }
    if (std.mem.eql(u8, args[1], "--help")) {
        print("Usage: rm <file>...\n", .{});
        print("Remove files.\n", .{});
        print("  --help     display this help and exit\n", .{});
        print("  --version  output version information\n", .{});
        return;
    }
    var failed = false;
    for (args[1..]) |path| {
        std.Io.Dir.cwd().deleteFile(init.io, path) catch |err| {
            print("rm: cannot remove '{s}': {s}\n", .{
                path,
                @errorName(err),
            });
            failed = true;
            continue;
        };

        print("removed '{s}'\n", .{path});
    }

    if (failed) return error.RemoveFailed;
}

