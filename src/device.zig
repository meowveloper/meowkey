const std = @import("std");

const DeviceError = error{ NoKeyboardFound, AccessDenied };

pub fn detect_keyboard (allocator: std.mem.Allocator) ![]u8 {
    const search_dir = "/dev/input/by-id"; 
    var dir = try std.fs.openDirAbsolute(search_dir, .{ .iterate = true });
    defer dir.close();
    
    var iterator = dir.iterate();

    while(try iterator.next()) |entry| {
        if(std.mem.endsWith(u8, entry.name, "-event-kbd")) {
            return try std.fs.path.join(allocator, &[_][]const u8{ search_dir, entry.name });
        }
    }

    return DeviceError.NoKeyboardFound;
}
