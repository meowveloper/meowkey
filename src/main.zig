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


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    try run(allocator);
}

fn run(allocator: std.mem.Allocator) !void {

    const device_path = try device.detect_keyboard(allocator);
    var file = try std.fs.cwd().openFile(device_path, .{ .mode = .read_only });
    defer file.close();

    try utils.print("listening on {s}...\n", .{device_path});

    while (true) {
        var event: InputEvent = undefined;
        const bytes_read = try file.read(std.mem.asBytes(&event));
        if(bytes_read == 0) break;

        if(event.type == 1 and event.value == 1) try utils.print("key pressed! code: {d}\n", .{event.code});
    }
}

