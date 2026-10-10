// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");
const print = std.debug.print;

const Mode = enum { md5, sha1, sha256, sha512, sha3, blake2, crc32, base64 };

const usage =
    \\Usage: cksum --mode <algo> <file>
    \\
    \\Algorithms:
    \\  md5      - MD5 (128-bit)
    \\  sha1     - SHA-1 (160-bit)
    \\  sha256   - SHA-256 (256-bit)
    \\  sha512   - SHA-512 (512-bit)
    \\  sha3     - SHA3-256 (256-bit)
    \\  blake2   - BLAKE2b-512 (512-bit)
    \\  crc32    - CRC-32 (32-bit)
    \\  base64   - Base64 encode (not hash, just encoding)
    \\
    \\Options:
    \\  --mode <algo>   Choose an algorithm
    \\  --version       Show Version
    \\  --help          Show Help
    \\
;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    const argc = args.len;

    if (argc > 1 and std.mem.eql(u8, args[1], "--version")) {
        print("Cksum (Mitsu CoreUtils)\n", .{});
        print("Copyright (c) 2026 Mitsu. All Rights Reserved.\n", .{});
        print("Written By HiMitsu\n", .{});
        return;
    }

    var mode_str: ?[]const u8 = null;
    var file_path: ?[]const u8 = null;

    var i: usize = 1;
    while (i < argc) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--mode")) {
            i += 1;
            if (i >= argc) {
                print("Error: --mode Need an argument\n", .{});
                print("{s}", .{usage});
                return;
            }
            mode_str = args[i];
        } else if (std.mem.eql(u8, args[i], "--help") or std.mem.eql(u8, args[i], "-h")) {
            print("{s}", .{usage});
            return;
        } else {
            if (file_path == null) file_path = args[i];
        }
    }

    if (mode_str == null or file_path == null) {
        print("{s}", .{usage});
        return;
    }

    const mode = parseMode(mode_str.?) catch {
        print("Error: unknown mode '{s}'\n", .{mode_str.?});
        print("{s}", .{usage});
        return;
    };

    computeAndPrint(init.io, allocator, mode, file_path.?) catch |err| {
        print("Error: {s} (file: {s})\n", .{ @errorName(err), file_path.? });
        return err;
    };
}

fn parseMode(s: []const u8) !Mode {
    if (std.mem.eql(u8, s, "md5")) return .md5;
    if (std.mem.eql(u8, s, "sha1")) return .sha1;
    if (std.mem.eql(u8, s, "sha256")) return .sha256;
    if (std.mem.eql(u8, s, "sha512")) return .sha512;
    if (std.mem.eql(u8, s, "sha3")) return .sha3;
    if (std.mem.eql(u8, s, "blake2")) return .blake2;
    if (std.mem.eql(u8, s, "crc32")) return .crc32;
    if (std.mem.eql(u8, s, "base64")) return .base64;
    return error.UnknownMode;
}

fn computeAndPrint(io: std.Io, allocator: std.mem.Allocator, mode: Mode, path: []const u8) !void {
    const data = try std.Io.Dir.cwd().readFileAlloc(
        io,
        path,
        allocator,
        std.Io.Limit.limited(64 * 1024 * 1024),
    );
    defer allocator.free(data);

    switch (mode) {
        .md5 => try hashGeneric(std.crypto.hash.Md5, data, path),
        .sha1 => try hashGeneric(std.crypto.hash.Sha1, data, path),
        .sha256 => try hashGeneric(std.crypto.hash.sha2.Sha256, data, path),
        .sha512 => try hashGeneric(std.crypto.hash.sha2.Sha512, data, path),
        .sha3 => try hashGeneric(std.crypto.hash.sha3.Sha3_256, data, path),
        .blake2 => try hashGeneric(std.crypto.hash.blake2.Blake2b512, data, path),
        .crc32 => try crc32Handler(data, path),
        .base64 => try base64Handler(allocator, data),
    }
}

fn hashGeneric(comptime H: type, data: []const u8, path: []const u8) !void {
    var hasher = H.init(.{});
    hasher.update(data);

    var digest: [H.digest_length]u8 = undefined;
    hasher.final(&digest);

    var hex: [H.digest_length * 2]u8 = undefined;
    for (digest, 0..) |b, j| {
        _ = std.fmt.bufPrint(hex[j * 2 ..][0..2], "{x:0>2}", .{b}) catch unreachable;
    }
    print("{s}  {s}\n", .{ hex, path });
}

fn crc32Handler(data: []const u8, path: []const u8) !void {
    var hasher = std.hash.Crc32.init();
    hasher.update(data);
    const crc = hasher.final();
    print("{x:0>8}  {s}\n", .{ crc, path });
}

fn base64Handler(allocator: std.mem.Allocator, data: []const u8) !void {
    const enc_len = std.base64.standard.Encoder.calcSize(data.len);
    const buf = try allocator.alloc(u8, enc_len);
    defer allocator.free(buf);
    const encoded = std.base64.standard.Encoder.encode(buf, data);
    print("{s}\n", .{encoded});
}
