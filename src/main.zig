const std = @import("std");
const utils = @import("utils.zig");
const device = @import("device.zig");
const audio = @import("audio.zig");

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

fn run(gpa: std.mem.Allocator, io: std.Io, writer: *std.Io.Writer) !void {
    var path_buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    var devices_file = try std.Io.Dir.openFileAbsolute(io, "/proc/bus/input/devices", .{ .mode = .read_only });
    defer devices_file.close(io);

    const path = try device.detect_keyboard(io, devices_file, &path_buffer);

    try utils.print(writer, "opening device {s}\n", .{path});
    const fd = try std.posix.openat(std.posix.AT.FDCWD, path, .{ .ACCMODE = .RDONLY }, 0);
    defer std.posix.close(fd);

    var config = try audio.Config.load(gpa, io, "assets/config.bin");
    defer config.deinit(gpa);

    var wav = try audio.load_wav(gpa, io, "assets/sound.wav");
    defer wav.free(gpa);


    var player = try audio.Player.init("default");
    try utils.print(writer, "listening for events..(Ctrl + C to stop)\n", .{});

    while (true) {
        var ev: InputEvent = undefined;
        const bytes_read = try std.posix.read(fd, std.mem.asBytes(&ev));

        if(bytes_read == @sizeOf(InputEvent)) {
            if(ev.type == 1 and ev.value == 1) {
                if(config.get_entry(ev.code)) |entry| {
                    const sound_slice = wav.data[entry.start..entry.end];
                    try player.play(sound_slice);
                }
                try utils.print(writer, "key code: {}\n", .{ev.code});
            }
        }
    }
}

