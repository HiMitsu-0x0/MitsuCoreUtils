// Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
// SPDX-License-Identifier: MIT

const std = @import("std");

pub fn main() !u8 {
    std.posix.sync();
    return 0;
}
