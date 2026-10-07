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

const windows = @import("win32");
const CreateCompletionPort = windows.kernel32.CreateIoCompletionPort;
const CreateFile = windows.kernel32.CreateFileW;
const ReadDirectoryChanges = windows.kernel32.ReadDirectoryChangesExW;

const HANDLE = windows.foundation.HANDLE;
const kernel32 = windows.kernel32;

pub fn openCurrentDir() !HANDLE {
    var path_w: [260:0]u16 = undefined;

    const len = kernel32.GetCurrentDirectoryW(path_w.len, &path_w);
    if (len == 0) return error.GetCurrentDirectoryFailed;

    const handle = kernel32.CreateFileW(
        &path_w,
        .{ .FILE_READ_DATA = 1 },
        .{ .DELETE = 1, .READ = 1, .WRITE = 1 },
        null,
        .OPEN_EXISTING,
        .{ .FILE_FLAG_OVERLAPPED = 1, .FILE_FLAG_BACKUP_SEMANTICS = 1 },
        null,
    );

    if (handle == windows.foundation.INVALID_HANDLE_VALUE) {
        return error.CreateFileFailed;
    }

    return handle;
}

pub const Watcher = struct {
    iocp_handle: HANDLE,

    pub fn init() Watcher {
        const result = CreateCompletionPort(windows.foundation.INVALID_HANDLE_VALUE, null, 0, 1);

        return .{ .iocp_handle = result.? };
    }

    pub fn deinit(self: *const Watcher) void {
        _ = windows.kernel32.CloseHandle(self.iocp_handle);
    }

    pub fn bindDir(self: *const Watcher, dir: HANDLE) !void {
        const bound_iocp = kernel32.CreateIoCompletionPort(
            dir,
            self.iocp_handle,
            0,
            0,
        );

        if (bound_iocp == null) {
            _ = kernel32.CloseHandle(dir);
            return error.BindFailed;
        }
    }

    pub fn nextTimeout(self: *const Watcher, timeout: u32) !?*DirectoryChangeAction {
        var bytes_transferred: u32 = 0;
        var completion_key: usize = 0;
        var overlapped_ptr: ?*windows.system.io.OVERLAPPED = null;

        const success = kernel32.GetQueuedCompletionStatus(
            self.iocp_handle,
            &bytes_transferred,
            &completion_key,
            &overlapped_ptr,
            timeout,
        );

        if (success == 0) {
            const err = kernel32.GetLastError();
            if (err == .WAIT_TIMEOUT) return null;

            std.debug.print("kernel32 error name: {any}\n", .{kernel32.GetLastError()});
            return error.OperationFailed;
        }

        if (overlapped_ptr) |overlapepd| {
            const director_change: *DirectoryChangeAction = @fieldParentPtr("overlapped", overlapepd);
            director_change.data = bytes_transferred;
            return director_change;
        }

        return null;
    }
};

pub const DirectoryChangeAction = struct {
    overlapped: windows.system.io.OVERLAPPED,
    data: u32,
    dir: HANDLE,
    buffer: []u8,

    pub fn notify(action: *DirectoryChangeAction) !void {
        const success = kernel32.ReadDirectoryChangesW(
            action.dir,
            action.buffer.ptr,
            @intCast(action.buffer.len),
            windows.foundation.TRUE,
            .{
                .FILE_NAME = 1,
                .CREATION = 1,
                .LAST_WRITE = 1,
            },
            null,
            &action.overlapped,
            null,
        );

        if (success == 0) {
            std.debug.print("kernel32 error name: {any}\n", .{kernel32.GetLastError()});
            return error.ReadDirectoryChangesFailed;
        }
    }
};
