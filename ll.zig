// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");
const print = std.debug.print;

const EntryInfo = struct {
    name: []const u8,
    kind: std.Io.File.Kind,
    size: u64,
    mtime: std.Io.Timestamp,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);

    if (args.len > 1 and std.mem.eql(u8, args[1], "--version")) {
        print("Ll (Mitsu CoreUtils)\n", .{});
        print("Copyright (c) 2026 Mitsu. All Rights Reserved.\n", .{});
        print("Written By HiMitsu\n", .{});
        return;
    }

    var show_all = false;
    var human = false;
    var path: ?[]const u8 = null;

    for (args[1..]) |arg| {
        if (arg.len > 1 and arg[0] == '-') {
            for (arg[1..]) |c| switch (c) {
                'a' => show_all = true,
                'h' => human = true,
                'l' => {},
                else => {},
            };
        } else if (path == null) {
            path = arg;
        }
    }

    try listDir(init.io, allocator, path orelse ".", show_all, human);
}

fn listDir(io: std.Io, allocator: std.mem.Allocator, path: []const u8, show_all: bool, human: bool) !void {
    var dir = try std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
    defer dir.close(io);

    var entries: std.ArrayList(EntryInfo) = .empty;
    defer entries.deinit(allocator);

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (!show_all and entry.name.len > 0 and entry.name[0] == '.') continue;

        const st = dir.statFile(io, entry.name, .{ .follow_symlinks = false }) catch continue;

        try entries.append(allocator, .{
            .name = try allocator.dupe(u8, entry.name),
            .kind = entry.kind,
            .size = st.size,
            .mtime = st.mtime,
        });
    }

    std.mem.sort(EntryInfo, entries.items, {}, struct {
        fn lt(_: void, a: EntryInfo, b: EntryInfo) bool {
            return std.mem.lessThan(u8, a.name, b.name);
        }
    }.lt);

    print("total {d} entries\n", .{entries.items.len});

    for (entries.items) |e| {
        var size_buf: [32]u8 = undefined;
        const size_str = if (human)
            humanSize(&size_buf, e.size)
        else
            std.fmt.bufPrint(&size_buf, "{d}", .{e.size}) catch "?";

        var date_buf: [32]u8 = undefined;
        const date_str = formatDate(&date_buf, e.mtime.toSeconds());

        print("{c}  {s:>8}  {s}  {s}", .{
            kindChar(e.kind),
            size_str,
            date_str,
            e.name,
        });

        if (e.kind == .sym_link) {
            var lbuf: [std.Io.Dir.max_path_bytes]u8 = undefined;
            const n = dir.readLink(io, e.name, &lbuf) catch 0;
            if (n > 0) print(" -> {s}", .{lbuf[0..n]});
        }

        print("\n", .{});
    }
}

fn kindChar(kind: std.Io.File.Kind) u8 {
    return switch (kind) {
        .directory => 'd',
        .sym_link => 'l',
        .character_device => 'c',
        .block_device => 'b',
        .named_pipe => 'p',
        .unix_domain_socket => 's',
        else => '-',
    };
}

fn humanSize(buf: []u8, size: u64) []const u8 {
    const units = [_][]const u8{ "B", "K", "M", "G", "T", "P" };
    var s: f64 = @floatFromInt(size);
    var i: usize = 0;
    while (s >= 1024.0 and i < units.len - 1) : (i += 1) s /= 1024.0;
    if (i == 0) return std.fmt.bufPrint(buf, "{d}{s}", .{ size, units[i] }) catch "?";
    return std.fmt.bufPrint(buf, "{d:.1}{s}", .{ s, units[i] }) catch "?";
}

fn formatDate(buf: []u8, secs_signed: i64) []const u8 {
    if (secs_signed < 0) return "???";
    const secs: u64 = @intCast(secs_signed);
    const epoch = std.time.epoch.EpochSeconds{ .secs = secs };
    const day = epoch.getEpochDay();
    const yd = day.calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = epoch.getDaySeconds();
    const months = [_][]const u8{
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    };
    return std.fmt.bufPrint(buf, "{s} {d:>2} {d:0>2}:{d:0>2}", .{
        months[md.month.numeric() - 1],
        md.day_index + 1,
        ds.getHoursIntoDay(),
        ds.getMinutesIntoHour(),
    }) catch "?";
}
