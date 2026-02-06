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
    var paths: std.ArrayList([]u8) = .empty;
    defer {
        for(paths.items) |item| {
            allocator.free(item);
        }
        paths.deinit(allocator);
    }

    var devices_file = try std.Io.Dir.openFileAbsolute(io, "/proc/bus/input/devices", .{ .mode = .read_only });
    defer devices_file.close(io);

    try device.detect_keyboard(allocator, io,devices_file, &paths);
    for(paths.items) |path| {
        try utils.print(writer, "path: {s}\n", .{path});
    }
}

