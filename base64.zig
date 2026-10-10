const std = @import("std");

const HELP =
    \\Usage: base64 [OPTION]... [FILE]
    \\Base64 encode or decode FILE, or standard input, to standard output.
    \\
    \\  -d, --decode          decode data
    \\  -w, --wrap=COLS       wrap encoded lines after COLS characters (default 76)
    \\                        use 0 to disable line wrapping
    \\      --help            display this help and exit
    \\
;

const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

pub fn main(init: std.process.Init) !u8 {
    const alloc = init.arena.allocator();
    const args = try init.minimal.args.toSlice(alloc);

    for (args[1..]) |a| {
        if (std.mem.eql(u8, a, "--help")) {
            showHelp(init.io, HELP);
            return 0;
        }
    }

    var decode = false;
    var wrap: usize = 76;
    var files_start: usize = 1;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a: []const u8 = args[i];
        if (std.mem.eql(u8, a, "--")) {
            files_start = i + 1;
            break;
        } else if (std.mem.eql(u8, a, "-d") or std.mem.eql(u8, a, "--decode")) {
            decode = true;
        } else if (std.mem.eql(u8, a, "-w") or std.mem.eql(u8, a, "--wrap")) {
            i += 1;
            if (i >= args.len) return usageErr(init.io, "base64: option requires an argument -- 'w'");
            wrap = std.fmt.parseInt(usize, args[i], 10) catch 76;
            files_start = i + 1;
        } else if (std.mem.startsWith(u8, a, "-w") and a.len > 2) {
            wrap = std.fmt.parseInt(usize, a[2..], 10) catch 76;
            files_start = i + 1;
        } else if (a.len > 1 and a[0] == '-') {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("base64: invalid option '{s}'\n", .{a}) catch {};
            return 1;
        } else {
            files_start = i;
            break;
        }
    }

    const files = args[files_start..];
    var input = std.ArrayList(u8).empty;
    defer input.deinit(alloc);

    if (files.len == 0) {
        try readAll(init.io, alloc, std.Io.File.stdin(), &input);
    } else {
        for (files) |p| {
            const f = std.Io.Dir.cwd().openFile(init.io, p, .{}) catch |e| {
                var ebuf: [512]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.print("base64: {s}: {s}\n", .{ p, @errorName(e) }) catch {};
                return 1;
            };
            defer f.close(init.io);
            try readAll(init.io, alloc, f, &input);
        }
    }

    var out_buf: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
    const out = &stdout.interface;

    if (decode) {
        try decodeTo(input.items, out);
    } else {
        try encodeTo(alloc, input.items, wrap, out);
    }
    out.flush() catch {};
    return 0;
}

fn readAll(io: std.Io, alloc: std.mem.Allocator, f: std.Io.File, buf: *std.ArrayList(u8)) !void {
    var r_buf: [8192]u8 = undefined;
    var r = f.reader(io, &r_buf);
    var chunk: [8192]u8 = undefined;
    while (true) {
        const n = r.interface.readSliceShort(&chunk) catch break;
        if (n == 0) break;
        try buf.appendSlice(alloc, chunk[0..n]);
    }
}

fn encodeTo(alloc: std.mem.Allocator, data: []const u8, wrap: usize, out: *std.Io.Writer) !void {
    _ = alloc;
    var col: usize = 0;
    var i: usize = 0;
    while (i + 2 < data.len) : (i += 3) {
        const b0 = data[i];
        const b1 = data[i + 1];
        const b2 = data[i + 2];
        const triple = (@as(u32, b0) << 16) | (@as(u32, b1) << 8) | b2;
        const c0 = ALPHABET[(triple >> 18) & 0x3f];
        const c1 = ALPHABET[(triple >> 12) & 0x3f];
        const c2 = ALPHABET[(triple >> 6) & 0x3f];
        const c3 = ALPHABET[triple & 0x3f];
        try emitChar(out, c0, wrap, &col);
        try emitChar(out, c1, wrap, &col);
        try emitChar(out, c2, wrap, &col);
        try emitChar(out, c3, wrap, &col);
    }
    const rem = data.len - i;
    if (rem == 1) {
        const b0 = data[i];
        const triple = @as(u32, b0) << 16;
        try emitChar(out, ALPHABET[(triple >> 18) & 0x3f], wrap, &col);
        try emitChar(out, ALPHABET[(triple >> 12) & 0x3f], wrap, &col);
        try emitChar(out, '=', wrap, &col);
        try emitChar(out, '=', wrap, &col);
    } else if (rem == 2) {
        const b0 = data[i];
        const b1 = data[i + 1];
        const triple = (@as(u32, b0) << 16) | (@as(u32, b1) << 8);
        try emitChar(out, ALPHABET[(triple >> 18) & 0x3f], wrap, &col);
        try emitChar(out, ALPHABET[(triple >> 12) & 0x3f], wrap, &col);
        try emitChar(out, ALPHABET[(triple >> 6) & 0x3f], wrap, &col);
        try emitChar(out, '=', wrap, &col);
    }
    if (col != 0) try out.writeByte('\n');
}

fn emitChar(out: *std.Io.Writer, c: u8, wrap: usize, col: *usize) !void {
    if (wrap > 0 and col.* == wrap) {
        try out.writeByte('\n');
        col.* = 0;
    }
    try out.writeByte(c);
    col.* += 1;
}

fn decodeTo(data: []const u8, out: *std.Io.Writer) !void {
    var quad: [4]u8 = undefined;
    var qn: usize = 0;
    for (data) |c| {
        if (c == '\n' or c == '\r' or c == ' ' or c == '\t') continue;
        quad[qn] = c;
        qn += 1;
        if (qn == 4) {
            const vals = decodeQuad(quad) orelse return error.InvalidBase64;
            const triple = (@as(u32, vals[0]) << 18) |
                (@as(u32, vals[1]) << 12) |
                (@as(u32, vals[2]) << 6) |
                @as(u32, vals[3]);
            try out.writeByte(@intCast((triple >> 16) & 0xff));
            if (quad[2] != '=') try out.writeByte(@intCast((triple >> 8) & 0xff));
            if (quad[3] != '=') try out.writeByte(@intCast(triple & 0xff));
            qn = 0;
        }
    }
}

fn decodeQuad(q: [4]u8) ?[4]u8 {
    var out: [4]u8 = undefined;
    for (q, 0..) |c, i| {
        out[i] = if (c == '=') 0 else decodeChar(c) orelse return null;
    }
    return out;
}

fn decodeChar(c: u8) ?u8 {
    if (c >= 'A' and c <= 'Z') return c - 'A';
    if (c >= 'a' and c <= 'z') return c - 'a' + 26;
    if (c >= '0' and c <= '9') return c - '0' + 52;
    if (c == '+') return 62;
    if (c == '/') return 63;
    return null;
}

fn usageErr(io: std.Io, msg: []const u8) u8 {
    var ebuf: [256]u8 = undefined;
    var ew = std.Io.File.stderr().writer(io, &ebuf);
    defer ew.interface.flush() catch {};
    ew.interface.writeAll(msg) catch {};
    ew.interface.writeByte('\n') catch {};
    return 1;
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
