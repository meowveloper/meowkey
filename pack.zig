const std = @import("std");

const KeyEntry = extern struct {
    code: u16,
    padding: [2]u8 = .{ 0, 0 },
    start: u32,
    end: u32,
    padding2: [4]u8 = .{ 0, 0, 0, 0 },
};

pub fn main(init: std.process.Init) !void {
    const gpa: std.mem.Allocator = init.gpa;
    const io: std.Io = init.io;

    const file_content = try std.Io.Dir.cwd().readFileAlloc(io, "./assets/config.json", gpa, std.Io.Limit.unlimited);
    defer gpa.free(file_content);
    const parsed = try std.json.parseFromSlice(std.json.Value, gpa, file_content, .{});
    defer parsed.deinit();
    const definitions = parsed.value.object.get("definitions") orelse return error.MissingDefinitions;

    var entries = std.ArrayList(KeyEntry).empty;
    defer entries.deinit(gpa);

    var it = definitions.object.iterator();
    while (it.next()) |entry| {
        const name = entry.key_ptr.*;
        const code = mapNameToCode(name) orelse {
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
    const out_file = try std.Io.Dir.cwd().createFile(io, "assets/config.bin", .{});
    defer out_file.close(io);

    const bytes = std.mem.sliceAsBytes(entries.items);
    try out_file.writeStreamingAll(io, bytes);

    std.debug.print("Successfully mapped {} keys and wrote to assets/config.bin!\n", .{entries.items.len});
}

fn mapNameToCode(name: []const u8) ?u16 {
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
