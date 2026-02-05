const std = @import("std");

pub fn main() !void {
    try print("All your {s} are belong to us.\n", .{"codebase"});
}

fn print(comptime fmt: []const u8, args: anytype) !void {
    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(fmt, args);
    try stdout.flush();
}
