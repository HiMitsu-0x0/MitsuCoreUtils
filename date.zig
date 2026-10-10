const std = @import("std");

extern "c" fn time(tloc: ?*i64) i64;
extern "c" fn localtime_r(timep: *const i64, result: *Tm) ?*Tm;
extern "c" fn gmtime_r(timep: *const i64, result: *Tm) ?*Tm;
extern "c" fn strftime(s: [*]u8, maxsize: usize, format: [*:0]const u8, tm: *const Tm) usize;

const Tm = extern struct {
    tm_sec: c_int,
    tm_min: c_int,
    tm_hour: c_int,
    tm_mday: c_int,
    tm_mon: c_int,
    tm_year: c_int,
    tm_wday: c_int,
    tm_yday: c_int,
    tm_isdst: c_int,
    tm_gmtoff: c_long,
    tm_zone: ?[*:0]const u8,
};

const HELP =
    \\Usage: date [OPTION]... [+FORMAT]
    \\Display the current time.
    \\
    \\  -u, --utc, --universal   print Coordinated Universal Time
    \\  -R, --rfc-email          output RFC 5322 date format
    \\      --help               display this help and exit
    \\
    \\FORMAT is a strftime(3) format string; leading + is required.
    \\Without a format, prints: Sat Oct 10 12:34:56 UTC 2026
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

    var utc = false;
    var rfc_email = false;
    var format: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a: []const u8 = args[i];
        if (std.mem.eql(u8, a, "--")) {
            continue;
        } else if (std.mem.eql(u8, a, "-u") or
            std.mem.eql(u8, a, "--utc") or
            std.mem.eql(u8, a, "--universal"))
        {
            utc = true;
        } else if (std.mem.eql(u8, a, "-R") or std.mem.eql(u8, a, "--rfc-email")) {
            rfc_email = true;
        } else if (a.len > 1 and a[0] == '+') {
            format = a[1..];
        } else if (a.len > 1 and a[0] == '-') {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("date: invalid option '{s}'\n", .{a}) catch {};
            return 1;
        } else {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("date: extra operand '{s}'\n", .{a}) catch {};
            return 1;
        }
    }

    const now = time(null);
    var tm: Tm = undefined;
    const tm_ptr = if (utc) gmtime_r(&now, &tm) else localtime_r(&now, &tm);
    if (tm_ptr == null) {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("date: cannot determine current time\n") catch {};
        return 1;
    }

    var fmt_buf: [256]u8 = undefined;
    const fmt: [:0]const u8 = if (format) |f| blk: {
        const n = @min(f.len, fmt_buf.len - 1);
        @memcpy(fmt_buf[0..n], f[0..n]);
        fmt_buf[n] = 0;
        break :blk fmt_buf[0..n :0];
    } else if (rfc_email)
        "%a, %d %b %Y %H:%M:%S %z"
    else if (utc)
        "%a %b %e %H:%M:%S UTC %Y"
    else
        "%a %b %e %H:%M:%S %Z %Y";

    var out_buf: [512]u8 = undefined;
    const n = strftime(&out_buf, out_buf.len, fmt.ptr, &tm);
    if (n == 0) {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("date: strftime failed\n") catch {};
        return 1;
    }

    var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
    _ = &stdout;
    var w_buf: [512]u8 = undefined;
    var w = std.Io.File.stdout().writer(init.io, &w_buf);
    defer w.interface.flush() catch {};
    w.interface.print("{s}\n", .{out_buf[0..n]}) catch return 1;
    return 0;
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
