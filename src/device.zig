const std = @import("std");

const DeviceError = error{ NoKeyboardFound, AccessDenied };

pub fn detect_keyboard (gpa: std.mem.Allocator, io: std.Io, file: std.Io.File) !std.ArrayList([]u8) {
    var paths: std.ArrayList([]u8) = .empty;
    errdefer {
        for (paths.items) |item| {
            gpa.free(item);
        } 
        paths.deinit(gpa);
    }
    var file_buffer: [1024]u8 = undefined;
    var reader = file.reader(io, &file_buffer);
    
    var event_id_buff: [1024]u8 = undefined;
    var current_event_id: ?[]const u8 = null;

    while(try reader.interface.takeDelimiter('\n')) |raw_line| {
        const line = std.mem.trimEnd(u8, raw_line, &std.ascii.whitespace);
        if(line.len == 0) {
            current_event_id = null;
            continue;
        } 
        if(std.mem.startsWith(u8, line, "H: Handlers=")) {
            var it = std.mem.tokenizeScalar(u8, line, ' ');
            while(it.next()) |token| {
                if(std.mem.startsWith(u8, token, "event")) {
                    const len: usize = @min(token.len, event_id_buff.len);
                    @memcpy(event_id_buff[0..len], token[0..len]);
                    current_event_id = event_id_buff[0..len];
                }
            }
        } else if(std.mem.startsWith(u8, line, "B: EV=")) {
            const ev_hex_str = line[6..];
            const ev_bits = std.fmt.parseInt(u64, ev_hex_str, 16) catch 0;
            if((ev_bits & 0x100000) != 0) {
                if(current_event_id) |event_id| {
                    try paths.append(gpa, try std.fmt.allocPrint(gpa, "/dev/input/{s}", .{event_id}));
                }
            }
        }
    }
    if(paths.items.len < 1) return DeviceError.NoKeyboardFound;
    return paths;
}

test "detect_keyboard" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var devices_file = try std.Io.Dir.openFileAbsolute(io, "/proc/bus/input/devices", .{ .mode = .read_only });
    defer devices_file.close(io);
    var paths = try detect_keyboard(gpa, io, devices_file);
    defer {
        for(paths.items) |item| gpa.free(item);
        paths.deinit(gpa);
    }
    for(paths.items) |path| std.debug.print("path: {s}\n", .{path});
}


