// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

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

extern "c" fn chmod(pathname: [*:0]const u8, mode: c_uint) c_int;
extern "c" fn lstat(pathname: [*:0]const u8, buf: *Stat) c_int;

const HELP =
    \\Usage: chmod [OPTION]... MODE FILE...
    \\Change the mode of each FILE to MODE.
    \\
    \\  -c, --changes      like -v but report only when a change is made
    \\  -f, --silent       suppress most error messages
    \\  -v, --verbose      output a diagnostic for every file processed
    \\      --help         display this help and exit
    \\
    \\MODE may be:
    \\  - an octal number, e.g. 755 or 0644
    \\  - a symbolic expression, e.g. u+rwx, go-w, a=rw, +x
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

    var verbose = false;
    var changes_only = false;
    var silent = false;
    var recursive = false;
    var operands_start: usize = 1;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a: []const u8 = args[i];
        if (std.mem.eql(u8, a, "--")) {
            operands_start = i + 1;
            break;
        } else if (std.mem.eql(u8, a, "-v") or std.mem.eql(u8, a, "--verbose")) {
            verbose = true;
        } else if (std.mem.eql(u8, a, "-c") or std.mem.eql(u8, a, "--changes")) {
            changes_only = true;
        } else if (std.mem.eql(u8, a, "-f") or
            std.mem.eql(u8, a, "--silent") or
            std.mem.eql(u8, a, "--quiet"))
        {
            silent = true;
        } else if (std.mem.eql(u8, a, "-R") or std.mem.eql(u8, a, "--recursive")) {
            recursive = true;
        } else if (a.len > 1 and a[0] == '-') {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("chmod: invalid option '{s}'\n", .{a}) catch {};
            return 1;
        } else {
            operands_start = i;
            break;
        }
    }

    const operands = args[operands_start..];
    if (operands.len < 2) {
        if (!silent) {
            var ebuf: [128]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.writeAll("chmod: missing operand\n") catch {};
        }
        return 1;
    }

    if (recursive) {
        if (!silent) {
            var ebuf: [128]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.writeAll("chmod: -R is not implemented\n") catch {};
        }
        return 1;
    }

    const mode_str = operands[0];

    var numeric_mode: ?u32 = null;
    if (mode_str.len > 0) {
        var all_octal = true;
        for (mode_str) |c| {
            if (c < '0' or c > '7') {
                all_octal = false;
                break;
            }
        }
        if (all_octal) {
            numeric_mode = std.fmt.parseInt(u32, mode_str, 8) catch null;
        }
    }

    if (numeric_mode == null) {
        if (applySym(0, mode_str, false) == null) {
            if (!silent) {
                var ebuf: [256]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.print("chmod: invalid mode '{s}'\n", .{mode_str}) catch {};
            }
            return 1;
        }
    }

    var status: u8 = 0;
    for (operands[1..]) |p| {
        applyTo(init.io, alloc, p, mode_str, numeric_mode, verbose, changes_only, silent) catch |err| {
            if (!silent) {
                var ebuf: [512]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.print("chmod: cannot access '{s}': {s}\n", .{ p, @errorName(err) }) catch {};
            }
            status = 1;
        };
    }
    return status;
}

fn applyTo(
    io: std.Io,
    alloc: std.mem.Allocator,
    path: []const u8,
    mode_str: []const u8,
    numeric_mode: ?u32,
    verbose: bool,
    changes_only: bool,
    silent: bool,
) !void {
    const z = try alloc.allocSentinel(u8, path.len, 0);
    @memcpy(z, path);

    var st: Stat = undefined;
    if (lstat(z, &st) != 0) return error.LstatFailed;
    const old_mode: u32 = @intCast(st.mode & 0o7777);

    const new_mode: u32 = if (numeric_mode) |m|
        m & 0o7777
    else
        applySym(old_mode, mode_str, (st.mode & 0o170000) == 0o040000) orelse
            return error.InvalidMode;

    if (chmod(z, @intCast(new_mode)) != 0) return error.ChmodFailed;

    if ((verbose or changes_only) and (verbose or new_mode != old_mode)) {
        var out_buf: [512]u8 = undefined;
        var stdout = std.Io.File.stdout().writer(io, &out_buf);
        defer stdout.interface.flush() catch {};
        var msbuf: [10]u8 = undefined;
        stdout.interface.print(
            "mode of '{s}' changed to {o:0>4} ({s})\n",
            .{ path, new_mode, modeStr(new_mode, &msbuf) },
        ) catch {};
    }
    _ = silent;
}

fn applySym(cur: u32, expr: []const u8, is_dir: bool) ?u32 {
    if (expr.len == 0) return null;
    var result = cur;
    var it = std.mem.splitScalar(u8, expr, ',');
    while (it.next()) |clause| {
        if (clause.len == 0) return null;
        result = applyClause(result, clause, is_dir) orelse return null;
    }
    return result;
}

fn applyClause(cur: u32, clause: []const u8, is_dir: bool) ?u32 {
    var i: usize = 0;

    var who_u = false;
    var who_g = false;
    var who_o = false;
    while (i < clause.len) {
        switch (clause[i]) {
            'u' => {
                who_u = true;
                i += 1;
            },
            'g' => {
                who_g = true;
                i += 1;
            },
            'o' => {
                who_o = true;
                i += 1;
            },
            'a' => {
                who_u = true;
                who_g = true;
                who_o = true;
                i += 1;
            },
            else => break,
        }
    }
    const who_given = who_u or who_g or who_o;
    if (!who_given) {
        who_u = true;
        who_g = true;
        who_o = true;
    }

    if (i >= clause.len) return null;
    const op = clause[i];
    if (op != '+' and op != '-' and op != '=') return null;
    i += 1;

    var bits: u32 = 0;
    var cap_x = false;
    var want_suid = false;
    var want_sgid = false;
    var want_sticky = false;
    var copy_u = false;
    var copy_g = false;
    var copy_o = false;

    while (i < clause.len) : (i += 1) {
        switch (clause[i]) {
            'r' => bits |= 0o444,
            'w' => bits |= 0o222,
            'x' => bits |= 0o111,
            'X' => cap_x = true,
            's' => {
                want_suid = true;
                want_sgid = true;
            },
            't' => want_sticky = true,
            'u' => copy_u = true,
            'g' => copy_g = true,
            'o' => copy_o = true,
            else => return null,
        }
    }

    if (cap_x and (is_dir or (cur & 0o111) != 0)) {
        bits |= 0o111;
    }

    var perms_to_apply: u32 = 0;

    if (copy_u or copy_g or copy_o) {
        if (copy_u) {
            const um = (cur >> 6) & 7;
            if (who_u) perms_to_apply |= um << 6;
            if (who_g) perms_to_apply |= um << 3;
            if (who_o) perms_to_apply |= um;
        }
        if (copy_g) {
            const gm = (cur >> 3) & 7;
            if (who_u) perms_to_apply |= gm << 6;
            if (who_g) perms_to_apply |= gm << 3;
            if (who_o) perms_to_apply |= gm;
        }
        if (copy_o) {
            const om = cur & 7;
            if (who_u) perms_to_apply |= om << 6;
            if (who_g) perms_to_apply |= om << 3;
            if (who_o) perms_to_apply |= om;
        }
    } else {
        if (who_u) perms_to_apply |= bits & 0o700;
        if (who_g) perms_to_apply |= bits & 0o070;
        if (who_o) perms_to_apply |= bits & 0o007;
    }

    var special_to_apply: u32 = 0;
    if (want_suid and who_u) special_to_apply |= 0o4000;
    if (want_sgid and who_g) special_to_apply |= 0o2000;
    if (want_sticky) special_to_apply |= 0o1000;

    var new_mode = cur;
    switch (op) {
        '+' => {
            new_mode |= perms_to_apply | special_to_apply;
        },
        '-' => {
            new_mode &= ~(perms_to_apply | special_to_apply);
        },
        '=' => {
            if (who_u) new_mode &= ~@as(u32, 0o4700);
            if (who_g) new_mode &= ~@as(u32, 0o2070);
            if (who_o) new_mode &= ~@as(u32, 0o1007);
            new_mode |= perms_to_apply | special_to_apply;
        },
        else => return null,
    }
    return new_mode;
}

fn modeStr(mode: u32, buf: *[10]u8) []const u8 {
    buf[0] = '-';
    buf[1] = if (mode & 0o400 != 0) 'r' else '-';
    buf[2] = if (mode & 0o200 != 0) 'w' else '-';
    buf[3] = if (mode & 0o100 != 0) 'x' else '-';
    buf[4] = if (mode & 0o040 != 0) 'r' else '-';
    buf[5] = if (mode & 0o020 != 0) 'w' else '-';
    buf[6] = if (mode & 0o010 != 0) 'x' else '-';
    buf[7] = if (mode & 0o004 != 0) 'r' else '-';
    buf[8] = if (mode & 0o002 != 0) 'w' else '-';
    buf[9] = if (mode & 0o001 != 0) 'x' else '-';
    return buf[0..10];
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
