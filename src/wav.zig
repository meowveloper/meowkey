const std = @import("std");
const consts = @import("consts.zig");
const AudioError = consts.AudioError;
const utils = @import("utils.zig");

const Environ_Map = std.process.Environ.Map;
const Io = std.Io;
const Gpa = std.mem.Allocator;

pub const WavData = struct {
    data: []i16,
    gpa: std.mem.Allocator,

    pub fn load_wav(gpa: Gpa, io: Io, env_map: Environ_Map, path: []const u8, volume_multiplier: f32) !WavData {
        const extended_path = try utils.Extended_Path.init(gpa, env_map, path);
        defer extended_path.deinit();

        const file_contents:[]const u8 = try std.Io.Dir.cwd().readFileAlloc(io, extended_path.path, gpa, std.Io.Limit.unlimited);
        defer gpa.free(file_contents);

        if (file_contents.len < 12) return AudioError.InvalidHeader;

        if (!std.mem.eql(u8, file_contents[0..4], "RIFF")) return AudioError.NotARiffFile;
        if (!std.mem.eql(u8, file_contents[8..12], "WAVE")) return AudioError.NotAWaveFile;

        const mutable_samples = try parse_wav(gpa, file_contents);

        const wav_data: WavData = .{
            .data = mutable_samples,
            .gpa = gpa
        };
        wav_data.apply_volume(volume_multiplier);
        return wav_data;
    }

    pub fn load_embedded(gpa: Gpa, comptime path: []const u8, volume_multiplier: f32) !WavData {
        const file_contents = @embedFile(path);
        const mutable_samples = try parse_wav(gpa, file_contents);
        const wav_data: WavData = .{
            .data = mutable_samples,
            .gpa = gpa
        };
        wav_data.apply_volume(volume_multiplier);
        return wav_data;
    }

    pub fn free(self: *const WavData) void {
        self.gpa.free(self.data);
    }


    fn apply_volume(self: *const WavData, volume_multiplier: f32) void {
        for (self.data) |*sample| {
            const float_sample = @as(f32, @floatFromInt(sample.*));
            const scaled_sample = float_sample * volume_multiplier;
            const clamped_sample = std.math.clamp(scaled_sample, -32768.0, 32767.0);
            sample.* = @as(i16, @intFromFloat(clamped_sample));
        }
    }

    fn parse_wav(gpa: Gpa, file_contents: []const u8) ![]i16 {
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

    const wav = try WavData.load_wav(gpa, io, env_map, consts.SOUND_FILE_PATH, 2.0);
    defer wav.free();


    for(wav.data) |da| {
        std.debug.print("data: {}\n", .{da});
    }
}

test "WavData.load_embedded" {
    const gpa = std.testing.allocator;
    const wav = try WavData.load_embedded(gpa, consts.EMBEDDED_SOUND_FILE_PATH, 2.0);
    defer wav.free();

    for(wav.data) |da| {
        std.debug.print("data: {}\n", .{da});
    }
}
