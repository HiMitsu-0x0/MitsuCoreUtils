const std = @import("std");

const Timespec = extern struct {
    sec: i64,
    nsec: i64,
};

// Linux x86_64 struct stat. Same layout used in stat.zig and chmod.zig.
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
extern "c" fn access(pathname: [*:0]const u8, mode: c_int) c_int;

const R_OK: c_int = 4;
const W_OK: c_int = 2;
const X_OK: c_int = 1;

const HELP =
    \\Usage: test EXPRESSION
    \\   or: test
    \\   or: [ EXPRESSION ]
    \\Check file types and compare values.
    \\
    \\  -e FILE   file exists
    \\  -f FILE   file is a regular file
    \\  -d FILE   file is a directory
    \\  -b FILE   file is a block device
    \\  -c FILE   file is a character device
    \\  -p FILE   file is a named pipe (FIFO)
    \\  -S FILE   file is a socket
    \\  -s FILE   file has size greater than zero
    \\  -r FILE   file is readable
    \\  -w FILE   file is writable
    \\  -x FILE   file is executable
    \\  -L FILE   file is a symbolic link (also -h)
    \\  -z STR    length of STR is zero
    \\  -n STR    length of STR is non-zero
    \\  STR1 = STR2   strings are equal
    \\  STR1 != STR2  strings are not equal
    \\  N1 -eq N2     integers are equal
    \\  N1 -ne N2     integers are not equal
    \\  N1 -lt N2     N1 is less than N2
    \\  N1 -le N2     N1 is less than or equal to N2
    \\  N1 -gt N2     N1 is greater than N2
    \\  N1 -ge N2     N1 is greater than or equal to N2
    \\  ! EXPR        true if EXPR is false
    \\  EXPR1 -a EXPR2   both true (and)
    \\  EXPR1 -o EXPR2   either true (or)
    \\      --help    display this help and exit
    \\
    \\Exit status: 0 if true, 1 if false, 2 on syntax error.
    \\
;

pub fn main(init: std.process.Init) !u8 {
    const alloc = init.arena.allocator();
    const args = try init.minimal.args.toSlice(alloc);

    // Bracket form: [ EXPRESSION ]
    const start: usize = 1;
    var end: usize = args.len;
    if (std.mem.eql(u8, args[0], "[")) {
        if (args.len < 2 or !std.mem.eql(u8, args[args.len - 1], "]")) {
            var ebuf: [128]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.writeAll("[: missing ']'\n") catch {};
            return 2;
        }
        end -= 1;
    }

    const expr = args[start..end];

    if (expr.len == 1 and std.mem.eql(u8, expr[0], "--help")) {
        showHelp(init.io, HELP);
        return 0;
    }

    if (expr.len == 0) return 1;
    if (expr.len == 1) return if (expr[0].len > 0) 0 else 1;

    var p = Parser{ .args = expr, .pos = 0, .alloc = alloc };
    const result = p.parseOr() catch {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("test: invalid expression\n") catch {};
        return 2;
    };
    if (p.pos != p.args.len) {
        var ebuf: [128]u8 = undefined;
        var ew = std.Io.File.stderr().writer(init.io, &ebuf);
        defer ew.interface.flush() catch {};
        ew.interface.writeAll("test: extra arguments\n") catch {};
        return 2;
    }
    return if (result) 0 else 1;
}

const Parser = struct {
    args: []const []const u8,
    pos: usize,
    alloc: std.mem.Allocator,

    fn peek(self: *Parser) ?[]const u8 {
        return if (self.pos < self.args.len) self.args[self.pos] else null;
    }

    fn next(self: *Parser) ?[]const u8 {
        if (self.pos >= self.args.len) return null;
        const a = self.args[self.pos];
        self.pos += 1;
        return a;
    }

    fn parseOr(self: *Parser) !bool {
        var left = try self.parseAnd();
        while (self.peek()) |a| {
            if (!std.mem.eql(u8, a, "-o")) break;
            _ = self.next();
            const right = try self.parseAnd();
            left = left or right;
        }
        return left;
    }

    fn parseAnd(self: *Parser) !bool {
        var left = try self.parseNot();
        while (self.peek()) |a| {
            if (!std.mem.eql(u8, a, "-a")) break;
            _ = self.next();
            const right = try self.parseNot();
            left = left and right;
        }
        return left;
    }

    fn parseNot(self: *Parser) !bool {
        if (self.peek()) |a| {
            if (std.mem.eql(u8, a, "!")) {
                _ = self.next();
                return !try self.parseNot();
            }
        }
        return self.parsePrimary();
    }

    fn parsePrimary(self: *Parser) !bool {
        const a = self.next() orelse return error.MissingOperand;
        const at_end = self.pos >= self.args.len;

        // Unary operators only apply if there is a following argument.
        if (!at_end and a.len == 2 and a[0] == '-') {
            switch (a[1]) {
                'e' => return self.fileCheck(.exists),
                'f' => return self.fileCheck(.file),
                'd' => return self.fileCheck(.dir),
                's' => return self.fileCheck(.nonempty),
                'r' => return self.fileCheck(.readable),
                'w' => return self.fileCheck(.writable),
                'x' => return self.fileCheck(.executable),
                'L', 'h' => return self.fileCheck(.symlink),
                'b' => return self.fileCheck(.block),
                'c' => return self.fileCheck(.char),
                'p' => return self.fileCheck(.fifo),
                'S' => return self.fileCheck(.socket),
                'z' => {
                    const s = self.next() orelse return error.MissingOperand;
                    return s.len == 0;
                },
                'n' => {
                    const s = self.next() orelse return error.MissingOperand;
                    return s.len > 0;
                },
                else => {},
            }
        }

        // Binary operator: `a` is LHS, look ahead at next token.
        if (self.peek()) |op| {
            if (isBinaryOp(op)) {
                if (self.pos + 1 >= self.args.len) return error.MissingOperand;
                const rhs = self.args[self.pos + 1];
                _ = self.next(); // consume op
                _ = self.next(); // consume rhs
                return evalBinary(a, op, rhs);
            }
        }

        // Single argument: non-empty string is truthy.
        return a.len > 0;
    }

    const FileTest = enum {
        exists,
        file,
        dir,
        nonempty,
        readable,
        writable,
        executable,
        symlink,
        block,
        char,
        fifo,
        socket,
    };

    fn fileCheck(self: *Parser, kind: FileTest) !bool {
        const path = self.next() orelse return error.MissingOperand;

        const z = try self.alloc.allocSentinel(u8, path.len, 0);
        @memcpy(z, path);

        // Permission checks go through access(2) so effective UID/GID apply.
        if (kind == .readable) return access(z, R_OK) == 0;
        if (kind == .writable) return access(z, W_OK) == 0;
        if (kind == .executable) return access(z, X_OK) == 0;

        var st: Stat = undefined;
        // Symlink check must not follow. Everything else follows, matching GNU.
        const rc = if (kind == .symlink) lstat(z, &st) else stat(z, &st);
        if (rc != 0) return false;

        const mtype: u32 = st.mode & 0o170000;
        return switch (kind) {
            .exists => true,
            .symlink => mtype == 0o120000,
            .file => mtype == 0o100000,
            .dir => mtype == 0o040000,
            .block => mtype == 0o060000,
            .char => mtype == 0o020000,
            .fifo => mtype == 0o010000,
            .socket => mtype == 0o140000,
            .nonempty => st.size > 0,
            else => false,
        };
    }
};

fn isBinaryOp(op: []const u8) bool {
    const ops = [_][]const u8{
        "=", "==", "!=", "-eq", "-ne", "-lt", "-le", "-gt", "-ge",
    };
    for (ops) |o| if (std.mem.eql(u8, op, o)) return true;
    return false;
}

fn evalBinary(lhs: []const u8, op: []const u8, rhs: []const u8) bool {
    if (std.mem.eql(u8, op, "=") or std.mem.eql(u8, op, "==")) {
        return std.mem.eql(u8, lhs, rhs);
    }
    if (std.mem.eql(u8, op, "!=")) return !std.mem.eql(u8, lhs, rhs);

    const l = std.fmt.parseInt(i64, lhs, 10) catch return false;
    const r = std.fmt.parseInt(i64, rhs, 10) catch return false;
    if (std.mem.eql(u8, op, "-eq")) return l == r;
    if (std.mem.eql(u8, op, "-ne")) return l != r;
    if (std.mem.eql(u8, op, "-lt")) return l < r;
    if (std.mem.eql(u8, op, "-le")) return l <= r;
    if (std.mem.eql(u8, op, "-gt")) return l > r;
    if (std.mem.eql(u8, op, "-ge")) return l >= r;
    return false;
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [2048]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
