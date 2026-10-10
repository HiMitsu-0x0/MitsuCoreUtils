// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

const HELP =
    \\Usage: printf FORMAT [ARGUMENT]...
    \\Print ARGUMENT(s) according to FORMAT.
    \\
    \\Supported conversions: %%s %%d %%i %%u %%x %%X %%o %%c %%b %%%%
    \\      --help   display this help and exit
    \\
;

pub fn main(init: std.process.Init) !u8 {
    const alloc = init.arena.allocator();
    const args = try init.minimal.args.toSlice(alloc);

    for (args[1..]) |a| {
        if (std.mem.eql(u8, a, "--help")) {
            showHelp(init.io, HELP);
            return 0;
        }
    }

    if (args.len < 2) {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("printf: missing operand\n") catch {};
        return 1;
    }

    const format = args[1];
    const rest = args[2..];

    var out_buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
    const out = &stdout.interface;

    var arg_idx: usize = 0;
    var iter_count: usize = 0;
    var first_iter = true;

    while (first_iter or arg_idx < rest.len) {
        first_iter = false;
        var i: usize = 0;
        while (i < format.len) {
            const c = format[i];
            if (c == '\\') {
                i += 1;
                if (i >= format.len) { out.writeByte('\\') catch return 1; break; }
                switch (format[i]) {
                    'n' => out.writeByte('\n') catch return 1,
                    't' => out.writeByte('\t') catch return 1,
                    'r' => out.writeByte('\r') catch return 1,
                    '\\' => out.writeByte('\\') catch return 1,
                    '0'...'7' => {
                        var val: u8 = 0;
                        var n: usize = 0;
                        while (i < format.len and n < 3 and format[i] >= '0' and format[i] <= '7') : (n += 1) {
                            val = val * 8 + (format[i] - '0');
                            i += 1;
                        }
                        i -= 1;
                        out.writeByte(val) catch return 1;
                    },
                    else => {
                        out.writeByte('\\') catch return 1;
                        out.writeByte(format[i]) catch return 1;
                    },
                }
                i += 1;
                continue;
            }
            if (c != '%') {
                out.writeByte(c) catch return 1;
                i += 1;
                continue;
            }
            i += 1;
            if (i >= format.len) { out.writeByte('%') catch return 1; break; }
            const conv = format[i];
            switch (conv) {
                '%' => out.writeByte('%') catch return 1,
                's' => {
                    const s = if (arg_idx < rest.len) rest[arg_idx] else "";
                    arg_idx += 1;
                    out.writeAll(s) catch return 1;
                },
                'c' => {
                    const s = if (arg_idx < rest.len) rest[arg_idx] else "";
                    arg_idx += 1;
                    if (s.len > 0) out.writeByte(s[0]) catch return 1;
                },
                'b' => {
                    const s = if (arg_idx < rest.len) rest[arg_idx] else "";
                    arg_idx += 1;
                    var j: usize = 0;
                    while (j < s.len) {
                        if (s[j] == '\\' and j + 1 < s.len) {
                            j += 1;
                            switch (s[j]) {
                                'n' => out.writeByte('\n') catch return 1,
                                't' => out.writeByte('\t') catch return 1,
                                'r' => out.writeByte('\r') catch return 1,
                                '\\' => out.writeByte('\\') catch return 1,
                                else => {
                                    out.writeByte('\\') catch return 1;
                                    out.writeByte(s[j]) catch return 1;
                                },
                            }
                        } else {
                            out.writeByte(s[j]) catch return 1;
                        }
                        j += 1;
                    }
                },
                'd', 'i', 'u', 'x', 'X', 'o' => {
                    const s = if (arg_idx < rest.len) rest[arg_idx] else "0";
                    arg_idx += 1;
                    const n = std.fmt.parseInt(i64, s, 0) catch 0;
                    switch (conv) {
                        'd', 'i' => out.print("{d}", .{n}) catch return 1,
                        'u' => out.print("{d}", .{@as(u64, @bitCast(n))}) catch return 1,
                        'x' => out.print("{x}", .{@as(u64, @bitCast(n))}) catch return 1,
                        'X' => out.print("{X}", .{@as(u64, @bitCast(n))}) catch return 1,
                        'o' => out.print("{o}", .{@as(u64, @bitCast(n))}) catch return 1,
                        else => unreachable,
                    }
                },
                else => {
                    out.writeByte('%') catch return 1;
                    out.writeByte(conv) catch return 1;
                },
            }
            i += 1;
        }

        iter_count += 1;
        if (iter_count > 1_000_000) break;
        if (arg_idx >= rest.len) break;
    }
    out.flush() catch {};
    return 0;
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
