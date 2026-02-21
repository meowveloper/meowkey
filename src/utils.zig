const std = @import("std");


pub fn print(writer: *std.Io.Writer, comptime fmt: []const u8, args: anytype) std.Io.Writer.Error!void {
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
        .{ "AltLeft", 56 },        .{ "ArrowDown", 108 },     .{ "ArrowLeft", 105 },
        .{ "ArrowRight", 106 },    .{ "ArrowUp", 103 },       .{ "Backquote", 41 },
        .{ "Backslash", 43 },      .{ "Backspace", 14 },      .{ "BracketLeft", 26 },
        .{ "BracketRight", 27 },   .{ "CapsLock", 58 },       .{ "Comma", 51 },
        .{ "ControlLeft", 29 },    .{ "Delete", 111 },        .{ "Digit0", 11 },
        .{ "Digit1", 2 },          .{ "Digit2", 3 },          .{ "Digit3", 4 },
        .{ "Digit4", 5 },          .{ "Digit5", 6 },          .{ "Digit6", 7 },
        .{ "Digit7", 8 },          .{ "Digit8", 9 },          .{ "Digit9", 10 },
        .{ "End", 107 },           .{ "Enter", 28 },          .{ "Equal", 13 },
        .{ "Escape", 1 },          .{ "F1", 59 },             .{ "F10", 68 },
        .{ "F11", 87 },            .{ "F12", 88 },            .{ "F2", 60 },
        .{ "F3", 61 },             .{ "F4", 62 },             .{ "F5", 63 },
        .{ "F6", 64 },             .{ "F7", 65 },             .{ "F8", 66 },
        .{ "F9", 67 },             .{ "Home", 102 },          .{ "Insert", 110 },
        .{ "KeyA", 30 },           .{ "KeyB", 48 },           .{ "KeyC", 46 },
        .{ "KeyD", 32 },           .{ "KeyE", 18 },           .{ "KeyF", 33 },
        .{ "KeyG", 34 },           .{ "KeyH", 35 },           .{ "KeyI", 23 },
        .{ "KeyJ", 36 },           .{ "KeyK", 37 },           .{ "KeyL", 38 },
        .{ "KeyM", 50 },           .{ "KeyN", 49 },           .{ "KeyO", 24 },
        .{ "KeyP", 25 },           .{ "KeyQ", 16 },           .{ "KeyR", 19 },
        .{ "KeyS", 31 },           .{ "KeyT", 20 },           .{ "KeyU", 22 },
        .{ "KeyV", 47 },           .{ "KeyW", 17 },           .{ "KeyX", 45 },
        .{ "KeyY", 21 },           .{ "KeyZ", 44 },           .{ "Minus", 12 },
        .{ "NumLock", 69 },        .{ "Numpad0", 82 },        .{ "Numpad1", 79 },
        .{ "Numpad2", 80 },        .{ "Numpad3", 81 },        .{ "Numpad4", 75 },
        .{ "Numpad5", 76 },        .{ "Numpad6", 77 },        .{ "Numpad7", 71 },
        .{ "Numpad8", 72 },        .{ "Numpad9", 73 },        .{ "NumpadAdd", 78 },
        .{ "NumpadDecimal", 83 },  .{ "NumpadDivide", 98 },   .{ "NumpadEnter", 96 },
        .{ "NumpadMultiply", 55 }, .{ "NumpadSubtract", 74 }, .{ "PageDown", 109 },
        .{ "PageUp", 104 },        .{ "Pause", 119 },         .{ "Period", 52 },
        .{ "PrintScreen", 99 },    .{ "Quote", 40 },          .{ "ScrollLock", 70 },
        .{ "Semicolon", 39 },      .{ "ShiftLeft", 42 },      .{ "ShiftRight", 54 },
        .{ "Slash", 53 },          .{ "Space", 57 },          .{ "Tab", 15 },
    });
    return Map.get(name);
}

test "map_name_to_code" {
    const result = map_name_to_code("Space");
    try std.testing.expect(result == 57);
}

pub const Extended_Path = struct {
    path: []u8,
    gpa: std.mem.Allocator,

    pub fn init(gpa: std.mem.Allocator, env_map: std.process.Environ.Map, path: []const u8) !Extended_Path {
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
