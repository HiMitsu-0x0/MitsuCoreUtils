const std = @import("std");

extern "c" fn clearenv() c_int;
extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;
extern "c" fn unsetenv(name: [*:0]const u8) c_int;
extern "c" fn execvp(file: [*:0]const u8, argv: [*:null]const ?[*:0]const u8) c_int;

const HELP =
    \\Usage: env [OPTION]... [-] [NAME=VALUE]... [COMMAND [ARG]...]
    \\Set each NAME to VALUE in the environment and run COMMAND.
    \\
    \\  -i, --ignore-environment  start with an empty environment
    \\  -u, --unset=NAME           remove variable NAME from the environment
    \\      --help                 display this help and exit
    \\
    \\With no COMMAND, print the resulting environment.
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

    var ignore_env = false;
    var unset_vars = std.ArrayList([]const u8).empty;
    defer unset_vars.deinit(alloc);
    var assignments = std.ArrayList([]const u8).empty;
    defer assignments.deinit(alloc);
    var command_idx: ?usize = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a: []const u8 = args[i];
        if (std.mem.eql(u8, a, "--")) {
            if (i + 1 < args.len) command_idx = i + 1;
            break;
        } else if (std.mem.eql(u8, a, "-i") or std.mem.eql(u8, a, "--ignore-environment")) {
            ignore_env = true;
        } else if (std.mem.eql(u8, a, "-u") or std.mem.eql(u8, a, "--unset")) {
            i += 1;
            if (i >= args.len) {
                var ebuf: [128]u8 = undefined;
                var ew = std.Io.File.stderr().writer(init.io, &ebuf);
                defer ew.interface.flush() catch {};
                ew.interface.writeAll("env: option requires an argument -- 'u'\n") catch {};
                return 1;
            }
            unset_vars.append(alloc, args[i]) catch {};
        } else if (std.mem.startsWith(u8, a, "-u") and a.len > 2) {
            unset_vars.append(alloc, a[2..]) catch {};
        } else if (std.mem.indexOfScalar(u8, a, '=')) |eq| {
            if (eq > 0) assignments.append(alloc, a) catch {};
        } else if (a.len > 1 and a[0] == '-') {
            var ebuf: [256]u8 = undefined;
            var ew = std.Io.File.stderr().writer(init.io, &ebuf);
            defer ew.interface.flush() catch {};
            ew.interface.print("env: invalid option '{s}'\n", .{a}) catch {};
            return 1;
        } else {
            command_idx = i;
            break;
        }
    }

    if (ignore_env) _ = clearenv();

    for (unset_vars.items) |v| {
        const vz = try alloc.allocSentinel(u8, v.len, 0);
        @memcpy(vz, v);
        _ = unsetenv(vz);
    }

    for (assignments.items) |a| {
        const eq = std.mem.indexOfScalar(u8, a, '=').?;
        const nz = try alloc.allocSentinel(u8, eq, 0);
        @memcpy(nz, a[0..eq]);
        const vz = try alloc.allocSentinel(u8, a.len - eq - 1, 0);
        @memcpy(vz, a[eq + 1 ..]);
        _ = setenv(nz, vz, 1);
    }

    if (command_idx == null) {
        var out_buf: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
        const out = &stdout.interface;
        const envp = std.c.environ;
        var j: usize = 0;
        while (envp[j]) |e| : (j += 1) {
            out.print("{s}\n", .{std.mem.span(e)}) catch return 1;
        }
        out.flush() catch {};
        return 0;
    }

    const cmd_args = args[command_idx.?..];
    const argv = try alloc.alloc(?[*:0]const u8, cmd_args.len + 1);
    for (cmd_args, 0..) |arg, k| {
        const az = try alloc.allocSentinel(u8, arg.len, 0);
        @memcpy(az, arg);
        argv[k] = az.ptr;
    }
    argv[cmd_args.len] = null;

    _ = execvp(argv[0].?, @ptrCast(argv.ptr));

    var ebuf: [512]u8 = undefined;
    var ew = std.Io.File.stderr().writer(init.io, &ebuf);
    defer ew.interface.flush() catch {};
    ew.interface.print("env: '{s}': No such file or directory\n", .{cmd_args[0]}) catch {};
    return 127;
}

fn showHelp(io: std.Io, text: []const u8) void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    w.interface.writeAll(text) catch {};
    w.interface.flush() catch {};
}
