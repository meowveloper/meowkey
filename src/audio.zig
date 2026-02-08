const std = @import("std");
const alsa = @cImport({
    @cInclude("alsa/asoundlib.h");
});

pub const AudioError = error{ OpenFailed, ParamSetupFailed, InvalidHeader, NotARiffFile, NotAWaveFile, UnsupportedCompression, Only16BitSupported, IncompleteData };

pub const Player = struct {
    handle: ?*alsa.snd_pcm_t,

    pub fn init(device_name: [:0]const u8) !Player {
        var handle: ?*alsa.snd_pcm_t = null;

        const err = alsa.snd_pcm_open(&handle, device_name, alsa.SND_PCM_STREAM_PLAYBACK, 0);

        if (err < 0) {
            const err_msg = alsa.snd_strerror(err);
            std.log.err("ALSA: failed to open the device '{s}' : '{s}'\n", .{ device_name, err_msg });
            return AudioError.OpenFailed;
        }

        std.log.info("ALSA: device '{s}' opened successfully\n", .{device_name});

        try setup_params(handle, 44100);
        return Player{ .handle = handle };
    }

    pub fn deinit(self: *Player) void {
        if (self.handle) |h| {
            _ = alsa.snd_pcm_close(h);
            self.handle = null;
        }
    }

    pub fn play(self: *Player, samples: []const i16) !void {
        if (self.handle) |h| {
            const frames = alsa.snd_pcm_writei(h, samples.ptr, samples.len);
            if (frames < 0) _ = alsa.snd_pcm_prepare(h);
        }
    }

    fn setup_params(handle: ?*alsa.snd_pcm_t, sample_rate: c_uint) !void {
        var params: ?*alsa.snd_pcm_hw_params_t = null;

        _ = alsa.snd_pcm_hw_params_malloc(&params);

        defer alsa.snd_pcm_hw_params_free(params);

        _ = alsa.snd_pcm_hw_params_any(handle, params);

        if (alsa.snd_pcm_hw_params_set_access(handle, params, alsa.SND_PCM_ACCESS_RW_INTERLEAVED) < 0) {
            return AudioError.ParamSetupFailed;
        }

        if (alsa.snd_pcm_hw_params_set_format(handle, params, alsa.SND_PCM_FORMAT_S16_LE) < 0) {
            return AudioError.ParamSetupFailed;
        }

        if (alsa.snd_pcm_hw_params_set_channels(handle, params, 1) < 0) {
            return AudioError.ParamSetupFailed;
        }

        var rate = sample_rate;
        if (alsa.snd_pcm_hw_params_set_rate_near(handle, params, &rate, 0) < 0) {
            return AudioError.ParamSetupFailed;
        }

        if (alsa.snd_pcm_hw_params(handle, params) < 0) {
            return AudioError.ParamSetupFailed;
        }
    }
};

pub fn generate_sine_wave(allocator: std.mem.Allocator, frequency: f32, duration_ms: usize) ![]i16 {
    const sample_rate = 44100;
    const num_samples = (sample_rate * duration_ms) / 1000;

    const buffer = try allocator.alloc(i16, num_samples);

    for (buffer, 0..) |*sample, i| {
        const time = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(sample_rate));
        const value = 10000.0 * std.math.sin(2.0 * std.math.pi * frequency * time);
        sample.* = @as(i16, @intFromFloat(value));
    }

    return buffer;
}

const WavHeader = extern struct {
    // RIFF Header
    chunk_id: [4]u8, // "RIFF"
    chunk_size: u32,
    format: [4]u8, // "WAVE"

    // fmt Sub-chunk
    fmt_id: [4]u8, // "fmt "
    fmt_size: u32,
    audio_format: u16, // 1 for PCM
    num_channels: u16, // 1 for Mono, 2 for Stereo
    sample_rate: u32,
    byte_rate: u32,
    block_align: u16,
    bits_per_sample: u16,

    // data Sub-chunk
    data_id: [4]u8, // "data"
    data_size: u32,
};

const WavData = struct {
    data: []i16,
    file_contents: []u8,

    pub fn free(self: *WavData, gpa: std.mem.Allocator) void {
        gpa.free(self.file_contents);        
    }
};
pub fn load_wav(gpa: std.mem.Allocator, io: std.Io, path: []const u8) !WavData {
    // const max_file_size = 50 * 1024 * 1024; // 50 MB

    const file_contents = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, std.Io.Limit.unlimited);
    errdefer gpa.free(file_contents);

    if (file_contents.len < @sizeOf(WavHeader)) return AudioError.InvalidHeader;

    const header = std.mem.bytesAsValue(WavHeader, file_contents[0..@sizeOf(WavHeader)]);

    if (!std.mem.eql(u8, &header.chunk_id, "RIFF")) return AudioError.NotARiffFile;
    if (!std.mem.eql(u8, &header.format, "WAVE")) return AudioError.NotAWaveFile;
    if (header.audio_format != 1) return AudioError.UnsupportedCompression;
    if (header.bits_per_sample != 16) return AudioError.Only16BitSupported;

    const data_bytes = file_contents[@sizeOf(WavHeader)..];
    if (data_bytes.len < header.data_size) return AudioError.IncompleteData;

    const samples_count = header.data_size / 2;

    const samples_ptr: [*]i16 = @ptrCast(@alignCast(data_bytes.ptr));
    return .{
        .data = samples_ptr[0..samples_count],
        .file_contents = file_contents,
    };
}

test "load_wav" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;
    const path = "assets/click.wav";
    var wav_data = try load_wav(gpa, io, path);
    defer wav_data.free(gpa);
    std.debug.print("data: {any}", .{wav_data.data});
}
