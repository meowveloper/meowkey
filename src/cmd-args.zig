const std = @import("std");

pub const Cmd_Args = struct {
    volume: f32 = 1.0,

    pub fn parse_args(raw_args: []const [:0]const u8) Cmd_Args {
        var args = Cmd_Args{};
        for(raw_args) |arg| {
            if(std.mem.startsWith(u8, arg, "--volume") or std.mem.startsWith(u8, arg, "-vl")) {
                const vol = parse_vol(arg);
                if(vol) |v| args.volume = v;
            }
        }
        return args;
    }

    fn parse_vol(arg : [:0]const u8) ?f32 {
        var it = std.mem.tokenizeAny(u8, arg, "=");
        while(it.next()) |tok| {
            const n = std.fmt.parseFloat(f32, tok) catch {
                continue;
            };
            return n;
        }
        return null;
    }
};

test "parse" {
    const args = Cmd_Args.parse_args(&.{
        "--vl=23",
        "--volume=20"
    });
    std.debug.print("{}\n", .{args});
    try std.testing.expect(args.volume == @as(f32, 20));
}

