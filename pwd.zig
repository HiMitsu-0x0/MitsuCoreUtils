// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

const HELP =
    \\Usage: pwd
    \\Print the full filename of the current working directory.
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

    const cwd = std.process.currentPathAlloc(init.io, init.gpa) catch {
        var ebuf: [256]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("pwd: cannot determine current directory\n") catch {};
        return 1;
    };
    defer init.gpa.free(cwd);

    var buf: [std.fs.max_path_bytes + 1]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &buf);
    defer stdout.interface.flush() catch {};
    stdout.interface.print("{s}\n", .{cwd}) catch return 1;
    return 0;
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
