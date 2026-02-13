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
     std.debug.print("Successfully mapped {any} keys!\n", .{entries.items});
}

fn mapNameToCode(name: []const u8) ?u16 {
    if (std.mem.eql(u8, name, "KeyA")) return 30;
    if (std.mem.eql(u8, name, "KeyB")) return 48;
    if (std.mem.eql(u8, name, "Space")) return 57;
    if (std.mem.eql(u8, name, "Enter")) return 28;
    return null;
}
