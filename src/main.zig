const std = @import("std");
const utils = @import("utils.zig");
const device = @import("device.zig");
const audio = @import("audio.zig");
const config_t = @import("config.zig");
const consts = @import("consts.zig");
const Cmd_Args = @import("cmd-args.zig").Cmd_Args;
const Wav = @import("wav.zig");

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
    const env_map = init.environ_map;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    const args = try init.minimal.args.toSlice(arena);
    const cmd_args = Cmd_Args.parse_args(args);

    try run(gpa, io, stdout_writer, cmd_args, env_map.*);
}

fn run(gpa: std.mem.Allocator, io: std.Io, writer: *std.Io.Writer, args: Cmd_Args, env_map: std.process.Environ.Map) !void {
    try utils.print(writer, "starting meowkey\n", .{});
    var devices_file = try std.Io.Dir.openFileAbsolute(io, "/proc/bus/input/devices", .{ .mode = .read_only });
    defer devices_file.close(io);

    var paths = try device.detect_keyboard(gpa, io, devices_file);
    defer {
        for (paths.items) |it| gpa.free(it);
        paths.deinit(gpa);
    }

    // init config and wav structs
    var config: config_t.Config = undefined;
    defer config.deinit();
    var wav: Wav.WavData = undefined;
    defer wav.free();

    // check if config files exists
    const is_config_json_exist = utils.check_file_existance(gpa, io, env_map, consts.CONFIG_FILE_PATH);
    const is_config_wav_exist = utils.check_file_existance(gpa, io, env_map, consts.SOUND_FILE_PATH);


    // use if exists, if not use embedded
    if(is_config_json_exist and is_config_wav_exist) {
        std.log.info("both {s} and {s} are found and will be used instead of embedded assets.\n", .{consts.CONFIG_FILE_PATH, consts.SOUND_FILE_PATH});
        config = try config_t.Config.load_file(gpa, io, env_map, .{ .config_path = consts.CONFIG_FILE_PATH, .bin_path = consts.CONFIG_BIN_PATH });
        wav = try Wav.WavData.load_wav(gpa, io, env_map, consts.SOUND_FILE_PATH, args.volume);
    } else {
        std.log.info("both files {s} and {s} cannot be found. falling back to embedded assets.\n", .{consts.CONFIG_FILE_PATH, consts.SOUND_FILE_PATH});
        config = try config_t.Config.load_embedded(gpa, io, env_map, .{ .embed_path = consts.EMBEDDED_CONFIG_FILE_PATH, .bin_path = consts.CONFIG_BIN_PATH });
        wav = try Wav.WavData.load_embedded(gpa, consts.EMBEDDED_SOUND_FILE_PATH, args.volume);
    }



    for (paths.items) |path| {
        const t = try std.Thread.spawn(.{}, read_thread, .{ path, &config, &wav });
        t.detach();
    }
    try io.sleep(.fromSeconds(std.math.maxInt(i64)), .awake);
}

fn play_thread(data: []const i16, device_name: [:0]const u8) void {
    var player = audio.Player.init(device_name) catch return;
    defer player.deinit();
    player.play(data) catch {
        std.log.err("failed to play sound", .{});
    };
}

fn read_thread(path: []const u8, config: *const config_t.Config, wav: *const Wav.WavData) void {
    const fd = std.posix.openat(std.posix.AT.FDCWD, path, .{ .ACCMODE = .RDONLY }, 0) catch |err| {
        std.log.err("failed to open device {s}: {}\n", .{path, err});
        return;
    };
    defer std.posix.close(fd);
    while (true) {
        var ev: InputEvent = undefined;
        const bytes_read = std.posix.read(fd, std.mem.asBytes(&ev)) catch return;

        if(bytes_read == @sizeOf(InputEvent)) {
            if(ev.type == 1 and ev.value == 1) {
                if(config.get_entry(ev.code)) |entry| {
                    if (entry.end <= wav.data.len and entry.start < entry.end) {
                        const sound_slice = wav.data[entry.start..entry.end];
                        const t = std.Thread.spawn(.{}, play_thread, .{sound_slice, "default"}) catch return;
                        t.detach(); 
                    }
                }
            }
        }
    }
}
