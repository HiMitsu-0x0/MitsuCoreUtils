// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

const utils = [_][]const u8{
    "catty", "cksum", "cp", "echo", "head", "ll", "lsort",
    "mv", "rm", "rmdir", "tail", "wc",
    "true", "false", "pwd", "whoami", "logname", "nproc",
    "sleep", "yes", "basename", "dirname", "printenv",
    "mkdir", "tee", "truncate", "sync", "seq", "uniq", "cmp",
    "touch", "chmod", "ln", "printf", "cut",
    "env", "base64", "date", "stat", "test",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });

    for (utils) |name| {
        const exe = b.addExecutable(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("{s}.zig", .{name})),
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        b.installArtifact(exe);
    }
}
