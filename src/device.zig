const std = @import("std");

const DeviceError = error{ NoKeyboardFound, AccessDenied };

pub fn detect_keyboard (buffer: []u8) ![]const u8 {
    var file = try std.fs.openFileAbsolute("/proc/bus/input/devices", .{ .mode = .read_only });
    defer file.close();

    var file_buffer: [1024]u8 = undefined;
    var reader = file.reader(&file_buffer);
    
    var event_id_buff: [1024]u8 = undefined;
    var current_event_id: ?[]const u8 = null;

    while(try reader.interface.takeDelimiter('\n')) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, &std.ascii.whitespace);
        if(line.len == 0) {
            current_event_id = null;
            continue;
        } 
        if(std.mem.startsWith(u8, line, "H: Handlers=")) {
            var it = std.mem.tokenizeScalar(u8, line, ' ');
            while(it.next()) |token| {
                if(std.mem.startsWith(u8, token, "event")) {
                    const len: usize = @min(token.len, buffer.len);
                    @memcpy(event_id_buff[0..len], token[0..len]);
                    current_event_id = event_id_buff[0..len];
                }
            }
        } else if(std.mem.startsWith(u8, line, "B: EV=")) {
            const ev_hex_str = line[6..];
            const ev_bits = std.fmt.parseInt(u64, ev_hex_str, 16) catch 0;
            if((ev_bits & 0x100000) != 0) {
                if(current_event_id) |event_id| {
                    return try std.fmt.bufPrint(buffer, "/dev/input/{s}", .{event_id});
                }
            }
        }
    }
    
    return DeviceError.NoKeyboardFound;
}

test "detect_keyboard" {
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const result = try detect_keyboard(&buffer);
    std.debug.print("result: {s}\n", .{result});
}
