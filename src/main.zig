const std = @import("std");
const Io = std.Io;
const windows = std.os.windows;

const zen = @import("zen");

pub fn main(minimal: std.process.Init) !void {

    //const runtime: *zio.Runtime = try .init(std.heap.smp_allocator, .{});
    const io = minimal.io;

    var buffer: [2048]u8 = undefined;
    var file_writer = std.Io.File.stdout().writer(
        io,
        &buffer,
    );
    var output = &file_writer.interface;

    const project: std.Io.Dir = try .openDir(.cwd(), io, "C:/Users/jeanh/Documents/MCPE/servers/zenith/zen/src", .{ .iterate = true });
    var iterator = project.iterate();
    while (try iterator.next(io)) |entry| {
        try output.print("{any}\n", .{entry});
    }

    //windows.ntdll.NtNotifyChangeDirectoryFileEx();

    try output.flush();
}
