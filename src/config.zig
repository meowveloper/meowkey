const std = @import("std");
const consts = @import("consts.zig");
const utils = @import("utils.zig");

const Environ_Map = std.process.Environ.Map;
const Io = std.Io;
const Gpa = std.mem.Allocator;
const Config_Paths = struct {config_path: []const u8, bin_path: []const u8};
const Config_Paths_Comptime = struct{comptime embed_path:[]const u8 = consts.EMBEDDED_CONFIG_FILE_PATH, bin_path: []const u8};

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

    pub fn load_file(gpa: Gpa, io: Io, env_map: Environ_Map, paths: Config_Paths) !Config {
        try pack_config(gpa, io, env_map, paths);
        return try load(gpa, io, env_map, paths.bin_path);
    }
    pub fn load_embedded(gpa: Gpa, io: Io, env_map: Environ_Map, paths: Config_Paths_Comptime) !Config {
        try pack_embedded(gpa, io, env_map, paths);
        return try load(gpa, io, env_map, paths.bin_path);
    }

    fn load(gpa: Gpa, io: Io, env_map: Environ_Map, path: []const u8) !Config {
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

    pub fn get_entry(self: Config, code: u16) ?KeyEntry {
        for (self.entries) |ent| {
            if (ent.code == code) return ent;
        }
        return null;
    }
    pub fn pack_config(gpa: Gpa, io: Io, env_map: Environ_Map, paths: Config_Paths) !void {
        const extended_path = try utils.Extended_Path.init(gpa, env_map, paths.config_path);
        defer extended_path.deinit();
        const file_contents = try std.Io.Dir.cwd().readFileAlloc(io, extended_path.path, gpa, std.Io.Limit.unlimited);
        defer gpa.free(file_contents);
        try pack(gpa, io, env_map, file_contents, paths.bin_path);
    }
    pub fn pack_embedded(gpa: Gpa, io: Io, env_map: Environ_Map, paths: Config_Paths_Comptime) !void {
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


test "Config.load_file" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var env_map = try std.testing.environ.createMap(gpa);
    defer env_map.deinit();
    const config = try Config.load_file(gpa, io, env_map, .{ .config_path = consts.CONFIG_FILE_PATH, .bin_path = consts.CONFIG_BIN_PATH });
    defer config.deinit();
    for(config.entries) |item| {
        std.debug.print("{}\n", .{item});
    }
}
test "Config.load_embedded" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var env_map = try std.testing.environ.createMap(gpa);
    defer env_map.deinit();
    const config = try Config.load_embedded(gpa, io, env_map, .{ .embed_path = consts.EMBEDDED_CONFIG_FILE_PATH, .bin_path = consts.CONFIG_BIN_PATH });
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

