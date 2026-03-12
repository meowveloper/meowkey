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
        const contents = std.Io.Dir.cwd().readFileAlloc(io, extended_path.path, gpa, std.Io.Limit.unlimited) catch |err| {
            std.log.err("Error loading config file {}\n", .{err});
            return err;
        };
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
    pub fn pack_config(gpa: std.mem.Allocator, io: std.Io, env_map: std.process.Environ.Map, paths: struct {config_path: []const u8, bin_path: []const u8}) !void {
        const extended_path = try utils.Extended_Path.init(gpa, env_map, paths.config_path);
        defer extended_path.deinit();
        const file_contents = try std.Io.Dir.cwd().readFileAlloc(io, extended_path.path, gpa, std.Io.Limit.unlimited);
        defer gpa.free(file_contents);
        try pack(gpa, io, env_map, file_contents, paths.bin_path);
    }
    pub fn pack_embedded(gpa: std.mem.Allocator, io: std.Io, env_map: std.process.Environ.Map, paths: struct {
        comptime embed_path:[]const u8 = consts.EMBEDDED_CONFIG_FILE_PATH,
        bin_path: []const u8
    }) !void {
        const file_contents = @embedFile(paths.embed_path);
        try pack(gpa, io, env_map, file_contents, paths.bin_path);
    }

   fn pack(gpa: std.mem.Allocator, io: std.Io, env_map: std.process.Environ.Map, file_content: []const u8, bin_path: []const u8 ) !void {
        const parsed = try std.json.parseFromSlice(std.json.Value, gpa, file_content, .{});
        defer parsed.deinit();

        const defines = parsed.value.object.get("defines") orelse return error.MissingDefines;

        var entries = std.ArrayList(KeyEntry).empty;
        defer entries.deinit(gpa);
        var it = defines.object.iterator();
        while (it.next()) |entry| {
            const name = entry.key_ptr.*;
            const code = utils.map_name_to_code(name) orelse {
                std.debug.print("Skipping unknown key: {s}\n", .{name});
                continue;
            };

            const timing_array = entry.value_ptr.array;
            if (timing_array.items.len != 2) continue;

            // Handle both integer and float values in the JSON array
            const start_ms = switch (timing_array.items[0]) {
                .integer => |i| @as(f64, @floatFromInt(i)),
                .float => |f| f,
                else => continue,
            };
            const end_ms = switch (timing_array.items[1]) {
                .integer => |i| @as(f64, @floatFromInt(i)),
                .float => |f| f,
                else => continue,
            };

            try entries.append(gpa, .{
                .code = code,
                .start = @intFromFloat(start_ms * 44.1),
                .end = @intFromFloat(end_ms * 44.1)
            });
        }

        const bin_extended_path = try utils.Extended_Path.init(gpa, env_map, bin_path);
        defer bin_extended_path.deinit();

        if(std.fs.path.dirname(bin_extended_path.path)) |path| {
            try std.Io.Dir.cwd().createDirPath(io, path);
        }

        const out_file = try std.Io.Dir.cwd().createFile(io, bin_extended_path.path, .{});
        defer out_file.close(io);

        const bytes = std.mem.sliceAsBytes(entries.items);
        try out_file.writeStreamingAll(io, bytes);

        std.debug.print("Successfully mapped {} keys and wrote to {s}!\n", .{entries.items.len, bin_path});
    }
};

test "Config.pack_config" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var env_map = try std.testing.environ.createMap(gpa);
    defer env_map.deinit();
    try Config.pack_config(gpa, io, env_map, .{ .config_path = consts.CONFIG_FILE_PATH, .bin_path = consts.CONFIG_BIN_PATH });
}

test "Config.pack_embedded" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var env_map = try std.testing.environ.createMap(gpa);
    defer env_map.deinit();
    try Config.pack_embedded(gpa, io, env_map, .{ .embed_path = consts.EMBEDDED_CONFIG_FILE_PATH, .bin_path = consts.CONFIG_BIN_PATH });
}


test "Config.load" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var env_map = try std.testing.environ.createMap(gpa);
    defer env_map.deinit();
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
    defer env_map.deinit();
    const config = try Config.load(gpa, io, env_map, consts.CONFIG_BIN_PATH);
    defer config.deinit();
    const entry = config.get_entry(57);
    if(entry) |ent| std.debug.print("entry: {}", .{ent});
}

pub const WavData = struct {
    data: []i16,
    gpa: std.mem.Allocator,

    pub fn load_wav(gpa: std.mem.Allocator, io: std.Io, env_map: std.process.Environ.Map, path: []const u8) !WavData {
        const extended_path = try utils.Extended_Path.init(gpa, env_map, path);
        defer extended_path.deinit();

        const file_contents:[]const u8 = try std.Io.Dir.cwd().readFileAlloc(io, extended_path.path, gpa, std.Io.Limit.unlimited);
        errdefer gpa.free(file_contents);
        defer gpa.free(file_contents);

        if (file_contents.len < 12) return AudioError.InvalidHeader;

        if (!std.mem.eql(u8, file_contents[0..4], "RIFF")) return AudioError.NotARiffFile;
        if (!std.mem.eql(u8, file_contents[8..12], "WAVE")) return AudioError.NotAWaveFile;

        const mutable_samples = try parse_wav(gpa, file_contents);

        return .{
            .data = mutable_samples,
            .gpa = gpa
        };
    }

    pub fn load_embedded(gpa: std.mem.Allocator, comptime path: []const u8) !WavData {
        const file_contents = @embedFile(path);
        const mutable_samples = try parse_wav(gpa, file_contents);
        return .{
            .data = mutable_samples,
            .gpa = gpa
        };
    }

    pub fn free(self: *const WavData) void {
        self.gpa.free(self.data);
    }


    pub fn apply_volume(self: *const WavData, volume_multiplier: f32) void {
        for (self.data) |*sample| {
            const float_sample = @as(f32, @floatFromInt(sample.*));
            const scaled_sample = float_sample * volume_multiplier;
            const clamped_sample = std.math.clamp(scaled_sample, -32768.0, 32767.0);
            sample.* = @as(i16, @intFromFloat(clamped_sample));
        }
    }

    fn parse_wav(gpa: std.mem.Allocator, file_contents: []const u8) ![]i16 {
        var offset: usize = 12;
        var fmt_found = false;
        var data_found = false;
        var data_offset: usize = 0;
        var data_size: usize = 0;
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
                data_offset = offset;
                data_size = chunk_size;
                data_found = true;
            }

            offset += chunk_size;
            if (offset % 2 != 0) offset += 1;
        }
        if (!fmt_found or !data_found) return AudioError.IncompleteData;
        
        const samples_count = data_size / 2;
        const mutable_samples = try gpa.alloc(i16, samples_count);
        @memcpy(std.mem.sliceAsBytes(mutable_samples), file_contents[data_offset .. data_offset + data_size]);
        return mutable_samples;
    }
};

test "WavData" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var env_map = try std.testing.environ.createMap(gpa);
    defer env_map.deinit();

    const wav = try WavData.load_wav(gpa, io, env_map, consts.SOUND_FILE_PATH);
    defer wav.free();

    wav.apply_volume(2.0);

    for(wav.data) |da| {
        std.debug.print("data: {}\n", .{da});
    }
}

test "WavData.load_embedded" {
    const gpa = std.testing.allocator;
    const wav = try WavData.load_embedded(gpa, consts.EMBEDDED_SOUND_FILE_PATH);
    defer wav.free();
    wav.apply_volume(2.0);

    for(wav.data) |da| {
        std.debug.print("data: {}\n", .{da});
    }
}
