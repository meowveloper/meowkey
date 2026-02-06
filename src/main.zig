const std = @import("std");
const utils = @import("utils.zig");
const device = @import("device.zig");

const InputEvent = extern struct {
    time: TimeVal,
    type: u16,
    code: u16,
    value: i32
};

const TimeVal = extern struct {
    sec: c_long,
    usec: c_long
};


pub fn main(init: std.process.Init) !void {
    const gpa: std.mem.Allocator = init.gpa;
    const arena: std.mem.Allocator = init.arena.allocator();

    const io: std.Io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    try run(gpa, io, stdout_writer);
}

fn run(allocator: std.mem.Allocator, io: std.Io, writer: *std.Io.Writer) !void {
    _ = allocator;
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const device_path = try device.detect_keyboard(io, &path_buffer);

    try utils.print(writer, "file path: {s}\n", .{device_path});
}

