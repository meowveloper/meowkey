const std = @import("std");


pub fn print(writer: *std.Io.Writer, comptime fmt: []const u8, args: anytype) std.Io.Writer.Error!void {
    try writer.print(fmt, args);
    try writer.flush();
}
