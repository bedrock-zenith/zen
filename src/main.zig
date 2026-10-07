//  SPDX-License-Identifier: LGPL-3.0-or-later
//  ============================================================================
//   Zen - Minecraft Bedrock Addon Utility Tool
//   Copyright (C) 2026 Bedrock Zenith
//   https://github.com/bedrock-zenith/zen
//  ============================================================================
//  
//  This file is part of Zen.
//  
//  Zen is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//  
//  Zen is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU Lesser General Public License for more details.
//  
//  You should have received a copy of the GNU Lesser General Public License
//  along with Zen. If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");
const Io = std.Io;

const windows = @import("win32");

const manager = @import("manager/windows.zig");

pub fn main(_: std.process.Init.Minimal) !void {
    var watcher: manager.Watcher = .init();
    defer watcher.deinit();

    const cwd = try manager.openCurrentDir();
    defer _ = windows.kernel32.CloseHandle(cwd);

    try watcher.bindDir(cwd);

    var buffer: [1024]u8 align(2) = undefined;

    var action: manager.DirectoryChangeAction = .{
        .overlapped = std.mem.zeroes(windows.system.io.OVERLAPPED),
        .buffer = &buffer,
        .dir = cwd,
        .data = 0,
    };

    for (0..16) |_| {
        try action.notify();

        const result = try watcher.nextTimeout(60_000);
        if (result) |a| {
            const filename = fromUTF16ToUTF8(a.buffer[0..a.data]);
            std.debug.print("FileChanged: {s} ({d})\n", .{ filename, filename.len });
        }
    }
    std.debug.print("end", .{});
}

// https://github.com/marlersoft/zigwin32

pub fn fromUTF16ToUTF8(in: []u8) []u8 {
    const len: usize = @divFloor(in.len, 2);
    const buffer: []u16 = @as([*]u16, @ptrCast(@alignCast(in.ptr)))[0..len];
    for (0..len) |i| {
        const value = buffer[i];
        in[i] = @intCast(value);
    }

    return in[0..len];
}
