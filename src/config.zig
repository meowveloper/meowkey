const std = @import("std");
const consts = @import("consts.zig");
const AudioError = consts.AudioError;
const utils = @import("utils.zig");

const KeyEntry = extern struct {
    code: u16,
    padding: [2]u8 = .{ 0, 0 },
    start: u32,
    end: u32,
    padding2: [4]u8 = .{ 0, 0, 0, 0 },
};

pub const Config = struct {
    entries: []const KeyEntry,
    file_contents: []const u8,
    gpa: std.mem.Allocator,

    pub fn load(gpa: std.mem.Allocator, io: std.Io, env_map: std.process.Environ.Map, path: []const u8) !Config {
        const extended_path = try utils.Extended_Path.init(gpa, env_map, path);
        defer extended_path.deinit();
        const contents = try std.Io.Dir.cwd().readFileAlloc(io, extended_path.path, gpa, std.Io.Limit.unlimited);
        errdefer gpa.free(contents);

        const entries = std.mem.bytesAsSlice(KeyEntry, @as([]align(@alignOf(KeyEntry)) u8, @alignCast(contents)));
        return .{ .entries = entries, .file_contents = contents, .gpa = gpa };
    }

    pub fn deinit(self: *const Config) void {
        self.gpa.free(self.file_contents);
    }

    pub fn get_entry(self:Config, code: u16) ?KeyEntry {
        for (self.entries) |ent| {
            if (ent.code == code) return ent;
        }
        return null;
    }

    pub fn pack(gpa: std.mem.Allocator, io: std.Io, env_map: std.process.Environ.Map, paths: struct { config_path: []const u8, bin_path: []const u8 }) !void {
        const config_extended_path = try utils.Extended_Path.init(gpa, env_map, paths.config_path);
        defer config_extended_path.deinit();

        const file_content = std.Io.Dir.cwd().readFileAlloc(io, config_extended_path.path, gpa, std.Io.Limit.unlimited) catch |err| {
            std.log.err("invalid config file at: {s}\n", .{config_extended_path.path});
            return err;
        };
        defer gpa.free(file_content);

        const parsed = try std.json.parseFromSlice(std.json.Value, gpa, file_content, .{});
        defer parsed.deinit();

        const definitions = parsed.value.object.get("definitions") orelse return error.MissingDefinitions;

        var entries = std.ArrayList(KeyEntry).empty;
        defer entries.deinit(gpa);
        var it = definitions.object.iterator();
        while (it.next()) |entry| {
            const name = entry.key_ptr.*;
            const code = utils.map_name_to_code(name) orelse {
                std.debug.print("Skipping unknown key: {s}\n", .{name});
                continue;
            };
            const timing = entry.value_ptr.object.get("timing") orelse continue;
            const press_pair = timing.array.items[0].array;
            const start_ms = press_pair.items[0].float;
            const end_ms = press_pair.items[1].float;

            try entries.append(gpa, .{
                .code = code,
                .start = @intFromFloat(start_ms * 44.1),
                .end = @intFromFloat(end_ms * 44.1)
            });
        }

        const bin_extended_path = try utils.Extended_Path.init(gpa, env_map, paths.bin_path);
        defer bin_extended_path.deinit();

        if(std.fs.path.dirname(bin_extended_path.path)) |path| {
            try std.Io.Dir.cwd().createDirPath(io, path);
        }

        const out_file = try std.Io.Dir.cwd().createFile(io, bin_extended_path.path, .{});
        defer out_file.close(io);

        const bytes = std.mem.sliceAsBytes(entries.items);
        try out_file.writeStreamingAll(io, bytes);

        std.debug.print("Successfully mapped {} keys and wrote to {s}!\n", .{entries.items.len, paths.bin_path});
    }
};

test "Config.pack" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var env_map = try std.testing.environ.createMap(gpa);
    defer env_map.deinit();
    try Config.pack(gpa, io, env_map, .{ .config_path = consts.CONFIG_FILE_PATH, .bin_path = consts.CONFIG_BIN_PATH });
}

test "Config.load" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var env_map = try std.testing.environ.createMap(gpa);
    env_map.deinit();
    const config = try Config.load(gpa, io, env_map, consts.CONFIG_BIN_PATH);
    defer config.deinit();
    for(config.entries) |item| {
        std.debug.print("{}\n", .{item});
    }
}

test "Config.get_entry" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var env_map = try std.testing.environ.createMap(gpa);
    env_map.deinit();
    const config = try Config.load(gpa, io, env_map, consts.CONFIG_BIN_PATH);
    defer config.deinit();
    const entry = config.get_entry(57);
    if(entry) |ent| std.debug.print("entry: {}", .{ent});
}

pub const WavData = struct {
    data: []i16,
    file_contents: []u8,
    gpa: std.mem.Allocator,

    pub fn load_wav(gpa: std.mem.Allocator, io: std.Io, env_map: std.process.Environ.Map, path: []const u8) !WavData {
        const extended_path = try utils.Extended_Path.init(gpa, env_map, path);
        defer extended_path.deinit();

        const file_contents = try std.Io.Dir.cwd().readFileAlloc(io, extended_path.path, gpa, std.Io.Limit.unlimited);
        errdefer gpa.free(file_contents);

        if (file_contents.len < 12) return AudioError.InvalidHeader;

        if (!std.mem.eql(u8, file_contents[0..4], "RIFF")) return AudioError.NotARiffFile;
        if (!std.mem.eql(u8, file_contents[8..12], "WAVE")) return AudioError.NotAWaveFile;

        var offset: usize = 12;
        var fmt_found = false;
        var data_found = false;
        var samples: []i16 = &[_]i16{};

        while (offset + 8 <= file_contents.len) {
            const chunk_id = file_contents[offset .. offset + 4];
            const chunk_size = std.mem.readInt(u32, file_contents[offset + 4 ..][0..4], .little);
            offset += 8;

            if (std.mem.eql(u8, chunk_id, "fmt ")) {
                const audio_format = std.mem.readInt(u16, file_contents[offset..][0..2], .little);
                const bits_per_sample = std.mem.readInt(u16, file_contents[offset + 14 ..][0..2], .little);

                if (audio_format != 1) return AudioError.UnsupportedCompression;
                if (bits_per_sample != 16) return AudioError.Only16BitSupported;
                fmt_found = true;
            } else if (std.mem.eql(u8, chunk_id, "data")) {
                const samples_count = chunk_size / 2;
                const samples_ptr: [*]i16 = @ptrCast(@alignCast(file_contents[offset..].ptr));
                samples = samples_ptr[0..samples_count];
                data_found = true;
            }

            offset += chunk_size;
            if (offset % 2 != 0) offset += 1;
        }

        if (!fmt_found or !data_found) return AudioError.IncompleteData;

        return .{
            .data = samples,
            .file_contents = file_contents,
            .gpa = gpa
        };
    }

    pub fn free(self: *const WavData) void {
        self.gpa.free(self.file_contents);
    }
};

test "WavData" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var env_map = try std.testing.environ.createMap(gpa);
    defer env_map.deinit();

    const wav = try WavData.load_wav(gpa, io, env_map, consts.SOUND_FILE_PATH);
    defer wav.free();

    for(wav.data) |da| {
        std.debug.print("data: {}\n", .{da});
    }
}
