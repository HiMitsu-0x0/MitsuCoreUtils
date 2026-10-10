// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");
const print = std.debug.print;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    const argc = args.len;

    if (argc > 1 and std.mem.eql(u8, args[1], "--version")) {
        print("Mv (Mitsu CoreUtils)\n", .{});
        print("Copyright (c) 2026 Mitsu. All Rights Reserved.\n", .{});
        print("Written By HiMitsu\n", .{});
        return;
    }

    if (argc < 3) {
        print("Usage: mv <source> <dest>\n", .{});
        print("       mv --version\n", .{});
        return;
    }

    const source_path = args[1];
    const dest_path = args[2];

    try movePath(init.io, allocator, source_path, dest_path);
    print("Moved '{s}' -> '{s}'\n", .{ source_path, dest_path });
}

fn movePath(io: std.Io, allocator: std.mem.Allocator, src_path: []const u8, dest_path: []const u8) !void {
    const basename = std.fs.path.basename(src_path);

    var dest_is_dir = false;
    if (std.Io.Dir.cwd().openDir(io, dest_path, .{})) |d| {
        var dir = d;
        dir.close(io);
        dest_is_dir = true;
    } else |_| {}

    const final_dest = if (dest_is_dir)
        try std.fs.path.join(allocator, &.{ dest_path, basename })
    else
        dest_path;
    defer if (dest_is_dir) allocator.free(final_dest);

    if (std.fs.path.dirname(final_dest)) |parent| {
        try std.Io.Dir.cwd().createDirPath(io, parent);
    }

    if (std.Io.Dir.cwd().rename(src_path, std.Io.Dir.cwd(), final_dest, io)) |_| {
        return;
    } else |rename_err| switch (rename_err) {
        error.CrossDevice => {
            try copyAndDelete(io, allocator, src_path, final_dest);
        },
        else => return rename_err,
    }
}

fn copyAndDelete(io: std.Io, allocator: std.mem.Allocator, src_path: []const u8, dest_path: []const u8) !void {
    if (std.Io.Dir.cwd().openDir(io, src_path, .{ .iterate = true })) |d| {
        var src_dir = d;
        defer src_dir.close(io);

        try copyDirRecursive(io, allocator, src_dir, dest_path);
        try std.Io.Dir.cwd().deleteTree(io, src_path);
    } else |err| switch (err) {
        error.NotDir => {
            try std.Io.Dir.cwd().copyFile(src_path, std.Io.Dir.cwd(), dest_path, io, .{});
            try std.Io.Dir.cwd().deleteFile(io, src_path);
        },
        else => return err,
    }
}

fn copyDirRecursive(io: std.Io, allocator: std.mem.Allocator, src_dir: std.Io.Dir, dest_path: []const u8) !void {
    try std.Io.Dir.cwd().createDirPath(io, dest_path);

    var dest_dir = try std.Io.Dir.cwd().openDir(io, dest_path, .{});
    defer dest_dir.close(io);

    var walker = try src_dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        const dest_entry_path = try std.fs.path.join(allocator, &.{ dest_path, entry.path });
        defer allocator.free(dest_entry_path);

        switch (entry.kind) {
            .file => {
                if (std.fs.path.dirname(dest_entry_path)) |parent| {
                    try std.Io.Dir.cwd().createDirPath(io, parent);
                }
                try src_dir.copyFile(entry.path, dest_dir, entry.path, io, .{});
            },
            .directory => {
                try std.Io.Dir.cwd().createDirPath(io, dest_entry_path);
            },
            .sym_link => {
                var buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
                const link_target = buf[0..try src_dir.readLink(io, entry.path, &buf)];
                if (std.fs.path.dirname(dest_entry_path)) |parent| {
                    try std.Io.Dir.cwd().createDirPath(io, parent);
                }
                try dest_dir.symLink(io, link_target, entry.path, .{});
            },
            else => print("Skipping: {s}\n", .{entry.path}),
        }
    }
}
