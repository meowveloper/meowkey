const std = @import("std");
const Gpa = std.mem.Allocator;
const Io = std.Io;
const Environ_Map = std.process.Environ.Map;


pub fn print(writer: *Io.Writer, comptime fmt: []const u8, args: anytype) Io.Writer.Error!void {
    try writer.print(fmt, args);
    try writer.flush();
}

test "print" {
    const io = std.testing.io;
    var buffer: [1024 * 20]u8 = undefined;
    var file_writer = std.Io.File.Writer.init(.stdout(), io, &buffer); 
    try print(&file_writer.interface, "hello\n" , .{});
}



pub fn map_name_to_code(name: []const u8) ?u16 {
    const Map = std.StaticStringMap(u16).initComptime(.{
        .{ "alt-left", 56 },        .{ "arrow-down", 108 },     .{ "arrow-left", 105 },
        .{ "arrow-right", 106 },    .{ "arrow-up", 103 },       .{ "backquote", 41 },
        .{ "backslash", 43 },       .{ "backspace", 14 },       .{ "bracket-left", 26 },
        .{ "bracket-right", 27 },   .{ "caps-lock", 58 },       .{ "comma", 51 },
        .{ "control-left", 29 },    .{ "delete", 111 },         .{ "digit-0", 11 },
        .{ "digit-1", 2 },          .{ "digit-2", 3 },          .{ "digit-3", 4 },
        .{ "digit-4", 5 },          .{ "digit-5", 6 },          .{ "digit-6", 7 },
        .{ "digit-7", 8 },          .{ "digit-8", 9 },          .{ "digit-9", 10 },
        .{ "end", 107 },            .{ "enter", 28 },           .{ "equal", 13 },
        .{ "escape", 1 },           .{ "f1", 59 },              .{ "f10", 68 },
        .{ "f11", 87 },             .{ "f12", 88 },             .{ "f2", 60 },
        .{ "f3", 61 },              .{ "f4", 62 },              .{ "f5", 63 },
        .{ "f6", 64 },              .{ "f7", 65 },              .{ "f8", 66 },
        .{ "f9", 67 },              .{ "home", 102 },           .{ "insert", 110 },
        .{ "key-a", 30 },           .{ "key-b", 48 },           .{ "key-c", 46 },
        .{ "key-d", 32 },           .{ "key-e", 18 },           .{ "key-f", 33 },
        .{ "key-g", 34 },           .{ "key-h", 35 },           .{ "key-i", 23 },
        .{ "key-j", 36 },           .{ "key-k", 37 },           .{ "key-l", 38 },
        .{ "key-m", 50 },           .{ "key-n", 49 },           .{ "key-o", 24 },
        .{ "key-p", 25 },           .{ "key-q", 16 },           .{ "key-r", 19 },
        .{ "key-s", 31 },           .{ "key-t", 20 },           .{ "key-u", 22 },
        .{ "key-v", 47 },           .{ "key-w", 17 },           .{ "key-x", 45 },
        .{ "key-y", 21 },           .{ "key-z", 44 },           .{ "minus", 12 },
        .{ "num-lock", 69 },        .{ "numpad-0", 82 },        .{ "numpad-1", 79 },
        .{ "numpad-2", 80 },        .{ "numpad-3", 81 },        .{ "numpad-4", 75 },
        .{ "numpad-5", 76 },        .{ "numpad-6", 77 },        .{ "numpad-7", 71 },
        .{ "numpad-8", 72 },        .{ "numpad-9", 73 },        .{ "numpad-add", 78 },
        .{ "numpad-decimal", 83 },  .{ "numpad-divide", 98 },   .{ "numpad-enter", 96 },
        .{ "numpad-multiply", 55 }, .{ "numpad-subtract", 74 }, .{ "page-down", 109 },
        .{ "page-up", 104 },        .{ "pause", 119 },          .{ "period", 52 },
        .{ "print-screen", 99 },    .{ "quote", 40 },           .{ "scroll-lock", 70 },
        .{ "semicolon", 39 },       .{ "shift-left", 42 },      .{ "shift-right", 54 },
        .{ "slash", 53 },           .{ "space", 57 },           .{ "tab", 15 },
    });
    return Map.get(name);
}

test "map_name_to_code" {
    const result = map_name_to_code("space");
    try std.testing.expect(result == 57);
}

pub const Extended_Path = struct {
    path: []u8,
    gpa: Gpa,

    pub fn init(gpa: Gpa, env_map: Environ_Map, path: []const u8) !Extended_Path {
        var resulted_path: []u8 = undefined;
        if(std.mem.startsWith(u8, path, "~")) {
            const home = env_map.get("HOME");
            if(home) |h| {
                resulted_path = try std.fmt.allocPrint(gpa, "{s}/{s}", .{h, path[2..]});
            } else return error.No_Home;
        } else {
            resulted_path = try gpa.dupe(u8, path);
        }
        return Extended_Path{
            .path = resulted_path,
            .gpa = gpa
        };
    }

    pub fn deinit(self: *const Extended_Path) void {
        self.gpa.free(self.path);
    }
};


test "get_extended_path" {
    const gpa = std.testing.allocator;
    var env_map = try std.testing.environ.createMap(gpa);
    defer env_map.deinit();
    const extended_path = try Extended_Path.init(gpa, env_map, "~/.config/meowkey/config.json"); 
    defer extended_path.deinit();
    std.debug.print("path: {s}\n", .{ extended_path.path });
}


pub fn check_file_existance (gpa: Gpa, io: Io, env_map: Environ_Map, path: []const u8) bool {
    const extended_path = Extended_Path.init(gpa, env_map, path) catch {
        std.log.err("cannot extend file path '{s}'\n", .{path});
        return false;
    };
    defer extended_path.deinit();
    const contents = Io.Dir.cwd().readFileAlloc(io, extended_path.path, gpa, Io.Limit.unlimited) catch {
        std.log.err("cannot read file at {s}\n", .{extended_path.path});
        return false;
    };
    defer gpa.free(contents);
    return true;
}

test "check_file_existance" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var env_map = try std.testing.environ.createMap(gpa);
    defer env_map.deinit();
    const yes = check_file_existance(gpa, io, env_map, "src/utils.zig");
    try std.testing.expect(yes);
}
