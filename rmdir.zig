// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");
const print = std.debug.print;

const usage =
    \\Usage: rmdir [options] <dir>...
    \\
    \\Remove empty directories.
    \\
    \\Options:
    \\  -p, --parents   Also delete the parent if it becomes empty
    \\  --version       Show Version
    \\  --help          Show Help
    \\
;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    const argc = args.len;

    if (argc > 1 and std.mem.eql(u8, args[1], "--version")) {
        print("Rmdir (Mitsu CoreUtils)\n", .{});
        print("Copyright (c) 2026 Mitsu. All Rights Reserved.\n", .{});
        print("Written By HiMitsu\n", .{});
        return;
    }

    var parents = false;
    var dirs: std.ArrayList([]const u8) = .empty;
    defer dirs.deinit(allocator);

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            print("{s}", .{usage});
            return;
        } else if (std.mem.eql(u8, arg, "--parents") or
            std.mem.eql(u8, arg, "-p"))
        {
            parents = true;
        } else if (arg.len > 1 and arg[0] == '-') {
            for (arg[1..]) |c| switch (c) {
                'p' => parents = true,
                else => {
                    print("Error: unknown option '-{c}'\n", .{c});
                    print("{s}", .{usage});
                    return;
                },
            };
        } else {
            try dirs.append(allocator, arg);
        }
    }

    if (dirs.items.len == 0) {
        print("Error: butuh Requires at least one directory\n", .{});
        print("{s}", .{usage});
        return;
    }

    var had_error = false;
    for (dirs.items) |dir| {
        removeDir(init.io, allocator, dir, parents) catch |err| {
            print("rmdir: {s}: {s}\n", .{ dir, @errorName(err) });
            had_error = true;
        };
    }

    if (had_error) std.process.exit(1);
}

fn removeDir(io: std.Io, allocator: std.mem.Allocator, path: []const u8, parents: bool) !void {
    try std.Io.Dir.cwd().deleteDir(io, path);

    if (!parents) return;

    var current = try allocator.dupe(u8, path);
    defer allocator.free(current);

    while (std.fs.path.dirname(current)) |parent| {
        if (parent.len == 0 or std.mem.eql(u8, parent, ".")) break;
        if (parent.len == 1 and parent[0] == '/') break;

        const parent_slice = parent;

        std.Io.Dir.cwd().deleteDir(io, parent_slice) catch break;

        const new_len = parent_slice.len;
        @memcpy(current[0..new_len], parent_slice);
        current = current[0..new_len];
    }
}
