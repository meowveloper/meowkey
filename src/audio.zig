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
             _ = alsa.snd_pcm_drain(h);
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


pub const KeyEntry = extern struct {
    code: u16,
    padding: [2]u8 = .{ 0, 0 },
    start: u32,
    end: u32,
    padding2: [4]u8 = .{ 0, 0, 0, 0 },
};

pub const Config = struct {
    entries: []const KeyEntry,
    file_contents: []const u8,

    pub fn load(gpa: std.mem.Allocator, io: std.Io, path: []const u8) !Config {
        const contents = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, std.Io.Limit.unlimited);
        errdefer gpa.free(contents);

        const entries = std.mem.bytesAsSlice(KeyEntry, @as([]align(@alignOf(KeyEntry)) u8, @alignCast(contents)));
        return .{
            .entries = entries,
            .file_contents = contents
        };
    }
    pub fn deinit(self: *Config, gpa: std.mem.Allocator) void {
        gpa.free(self.file_contents);
    }
    pub fn get_entry (self: *Config, code: u16) ?KeyEntry {
        for (self.entries) |ent| {
            if(ent.code == code) return ent;
        }
        return null;
    }
};




pub const WavData = struct {
    data: []i16,
    file_contents: []u8,

    pub fn free(self: *WavData, gpa: std.mem.Allocator) void {
        gpa.free(self.file_contents);        
    }
};
pub fn load_wav(gpa: std.mem.Allocator, io: std.Io, path: []const u8) !WavData {
    const file_contents = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, std.Io.Limit.unlimited);
    errdefer gpa.free(file_contents);

    if (file_contents.len < 12) return AudioError.InvalidHeader;


    if (!std.mem.eql(u8, file_contents[0..4], "RIFF")) return AudioError.NotARiffFile;
    if (!std.mem.eql(u8, file_contents[8..12], "WAVE")) return AudioError.NotAWaveFile;

    var offset: usize = 12;
    var fmt_found = false;
    var data_found = false;
    var samples: []i16 = &[_]i16{};

    while(offset + 8 <= file_contents.len) {

        const chunk_id = file_contents[offset .. offset + 4];
        const chunk_size = std.mem.readInt(u32, file_contents[offset + 4 ..][0..4], .little);
        offset += 8;

        if(std.mem.eql(u8, chunk_id, "fmt ")) {
            const audio_format = std.mem.readInt(u16, file_contents[offset ..][0..2], .little);
            const bits_per_sample = std.mem.readInt(u16, file_contents[offset + 14 ..][0..2], .little);

            if(audio_format != 1) return AudioError.UnsupportedCompression;
            if(bits_per_sample != 16) return AudioError.Only16BitSupported;
            fmt_found = true;
        } else if(std.mem.eql(u8, chunk_id, "data")) {
            const samples_count = chunk_size / 2;
            const samples_ptr: [*]i16 = @ptrCast(@alignCast(file_contents[offset..].ptr));
            samples = samples_ptr[0..samples_count];
            data_found = true;
        }

        offset += chunk_size;
        if(offset % 2 != 0) offset += 1;
    }

    if(!fmt_found or !data_found) return AudioError.IncompleteData;

    return .{
        .data = samples,
        .file_contents = file_contents,
    };
}

test "audio system" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;

    // Test WAV loading
    const wav_path = "assets/sound.wav";
    var wav_data = try load_wav(gpa, io, wav_path);
    defer wav_data.free(gpa);
    try std.testing.expect(wav_data.data.len > 0);
    std.debug.print("WAV data length: {d} samples\n", .{wav_data.data.len});

    // Test Config loading
    const config_path = "assets/config.bin";
    var config = try Config.load(gpa, io, config_path);
    defer config.deinit(gpa);
    try std.testing.expect(config.entries.len > 0);
    std.debug.print("Mapped {} keys from config.bin\n", .{config.entries.len});

    // Test specific key lookup (KeyA = 30)
    if (config.get_entry(30)) |entry| {
        try std.testing.expect(entry.code == 30);
        try std.testing.expect(entry.end > entry.start);
        std.debug.print("KeyA (30) range: {} to {}\n", .{ entry.start, entry.end });
    } else {
        return error.TestFailed;
    }
}
