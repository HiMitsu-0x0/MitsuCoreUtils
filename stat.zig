const std = @import("std");

const Timespec = extern struct {
    sec: i64,
    nsec: i64,
};

const Stat = extern struct {
    dev: u64,
    ino: u64,
    nlink: u64,
    mode: u32,
    uid: u32,
    gid: u32,
    __pad0: u32,
    rdev: u64,
    size: i64,
    blksize: i64,
    blocks: i64,
    atim: Timespec,
    mtim: Timespec,
    ctim: Timespec,
    __unused: [3]i64,
};

extern "c" fn stat(pathname: [*:0]const u8, buf: *Stat) c_int;
extern "c" fn lstat(pathname: [*:0]const u8, buf: *Stat) c_int;

const HELP =
    \\Usage: stat [OPTION]... FILE...
    \\Display file or file system status.
    \\
    \\  -L, --dereference     follow links
    \\  -c, --format=FORMAT   use the specified FORMAT instead of the default
    \\      --help            display this help and exit
    \\
    \\Supported FORMAT directives:
    \\  %n  file name
    \\  %s  total size in bytes
    \\  %F  file type
    \\  %a  access rights in octal
    \\  %A  access rights in human-readable form
    \\  %U  user name of owner
    \\  %G  group name of owner
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

    var deref = false;
    var format: ?[]const u8 = null;
    var files_start: usize = 1;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a: []const u8 = args[i];
        if (std.mem.eql(u8, a, "--")) {
            files_start = i + 1;
            break;
        } else if (std.mem.eql(u8, a, "-L") or std.mem.eql(u8, a, "--dereference")) {
            deref = true;
        } else if (std.mem.eql(u8, a, "-c") or std.mem.eql(u8, a, "--format")) {
            i += 1;
            if (i >= args.len) {
                var ebuf: [128]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.writeAll("stat: option requires an argument -- 'c'\n") catch {};
                return 1;
            }
            format = args[i];
            files_start = i + 1;
        } else if (std.mem.startsWith(u8, a, "--format=")) {
            format = a["--format=".len..];
            files_start = i + 1;
        } else if (std.mem.startsWith(u8, a, "-c") and a.len > 2) {
            format = a[2..];
            files_start = i + 1;
        } else if (a.len > 1 and a[0] == '-') {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("stat: invalid option '{s}'\n", .{a}) catch {};
            return 1;
        } else {
            files_start = i;
            break;
        }
    }

    const files = args[files_start..];
    if (files.len == 0) {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("stat: missing operand\n") catch {};
        return 1;
    }

    var out_buf: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
    const out = &stdout.interface;

    var status: u8 = 0;
    for (files) |p| {
        statFile(alloc, out, p, deref, format) catch |err| {
            var ebuf: [512]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("stat: cannot stat '{s}': {s}\n", .{ p, @errorName(err) }) catch {};
            status = 1;
            continue;
        };
    }
    out.flush() catch {};
    return status;
}

fn statFile(
    alloc: std.mem.Allocator,
    out: *std.Io.Writer,
    path: []const u8,
    deref: bool,
    format: ?[]const u8,
) !void {
    const z = try alloc.allocSentinel(u8, path.len, 0);
    @memcpy(z, path);

    var st: Stat = undefined;
    const rc = if (deref) stat(z, &st) else lstat(z, &st);
    if (rc != 0) return error.StatFailed;

    if (format) |f| {
        try formatOut(out, f, path, &st);
    } else {
        try defaultOut(out, path, &st);
    }
}

fn formatOut(
    out: *std.Io.Writer,
    fmt: []const u8,
    path: []const u8,
    st: *const Stat,
) !void {
    var i: usize = 0;
    while (i < fmt.len) {
        const c = fmt[i];
        if (c == '%' and i + 1 < fmt.len) {
            i += 1;
            switch (fmt[i]) {
                'n' => try out.writeAll(path),
                's' => try out.print("{d}", .{st.size}),
                'a' => try out.print("{o}", .{st.mode & 0o7777}),
                'F' => try out.writeAll(fileTypeStr(st.mode)),
                'A' => try out.writeAll(modeString(st.mode)),
                'u' => try out.print("{d}", .{st.uid}),
                'g' => try out.print("{d}", .{st.gid}),
                'U' => {
                    const pw = std.c.getpwuid(st.uid);
                    if (pw) |p| {
                        if (p.name) |n| try out.writeAll(std.mem.span(n))
                        else try out.print("{d}", .{st.uid});
                    } else try out.print("{d}", .{st.uid});
                },
                'G' => {
                    const gr = std.c.getgrgid(st.gid);
                    if (gr) |g| {
                        if (g.name) |n| try out.writeAll(std.mem.span(n))
                        else try out.print("{d}", .{st.gid});
                    } else try out.print("{d}", .{st.gid});
                },
                '%' => try out.writeByte('%'),
                else => {
                    try out.writeByte('%');
                    try out.writeByte(fmt[i]);
                },
            }
            i += 1;
        } else {
            try out.writeByte(c);
            i += 1;
        }
    }
    try out.writeByte('\n');
}

fn defaultOut(out: *std.Io.Writer, path: []const u8, st: *const Stat) !void {
    try out.print("  File: {s}\n", .{path});
    try out.print("  Size: {d}\tBlocks: {d}\tIO Block: {d}\t{s}\n", .{
        st.size, st.blocks, st.blksize, fileTypeStr(st.mode),
    });
    try out.print("Device: {x}h/{d}d\tInode: {d}\tLinks: {d}\n", .{
        st.dev, st.dev, st.ino, st.nlink,
    });
    try out.print("Access: ({o}/{s})\tUid: ({d})\tGid: ({d})\n", .{
        st.mode & 0o7777, modeString(st.mode), st.uid, st.gid,
    });
    try out.print("Access: {d}\n", .{st.atim.sec});
    try out.print("Modify: {d}\n", .{st.mtim.sec});
    try out.print("Change: {d}\n", .{st.ctim.sec});
}

fn fileTypeStr(mode: u32) []const u8 {
    return switch (mode & 0o170000) {
        0o140000 => "socket",
        0o120000 => "symbolic link",
        0o100000 => "regular file",
        0o060000 => "block special file",
        0o040000 => "directory",
        0o020000 => "character special file",
        0o010000 => "fifo",
        else => "unknown",
    };
}

fn modeString(mode: u32) []const u8 {
    const S = struct {
        var bufs: [4][10]u8 = undefined;
        var idx: usize = 0;
    };
    const b = &S.bufs[S.idx];
    S.idx = (S.idx + 1) % S.bufs.len;

    b[0] = switch (mode & 0o170000) {
        0o140000 => 's',
        0o120000 => 'l',
        0o100000 => '-',
        0o060000 => 'b',
        0o040000 => 'd',
        0o020000 => 'c',
        0o010000 => 'p',
        else => '?',
    };
    b[1] = if (mode & 0o400 != 0) 'r' else '-';
    b[2] = if (mode & 0o200 != 0) 'w' else '-';
    b[3] = if (mode & 0o100 != 0) 'x' else '-';
    b[4] = if (mode & 0o040 != 0) 'r' else '-';
    b[5] = if (mode & 0o020 != 0) 'w' else '-';
    b[6] = if (mode & 0o010 != 0) 'x' else '-';
    b[7] = if (mode & 0o004 != 0) 'r' else '-';
    b[8] = if (mode & 0o002 != 0) 'w' else '-';
    b[9] = if (mode & 0o001 != 0) 'x' else '-';
    return b[0..10];
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [2048]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
