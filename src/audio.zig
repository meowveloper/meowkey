const std = @import("std");
const alsa = @cImport({
    @cDefine("_FORTIFY_SOURCE", "0");
    @cInclude("alsa/asoundlib.h");
});
const consts = @import("consts.zig");
const AudioError = consts.AudioError;

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

        errdefer _ = alsa.snd_pcm_close(handle);
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

// run witn `zig test src/audio.zig -lc -lasound`
test "Player init, play, and deinit" {
    // Attempt to initialize the player with the "default" ALSA device.
    // In environments without a sound card (like some CI runners), this may fail.
    // We catch `OpenFailed` gracefully so the test suite doesn't fail unnecessarily.
    var player = Player.init("default") catch |err| {
        if (err == AudioError.OpenFailed) {
            std.debug.print("Skipping audio test: 'default' device could not be opened.\n", .{});
            return;
        }
        return err;
    };
    defer player.deinit();

    // Generate ~0.1 seconds of silence (44100 samples/sec / 10 = 4410 samples)
    const silence = try std.testing.allocator.alloc(i16, 4410);
    defer std.testing.allocator.free(silence);
    @memset(silence, 0);

    // Ensure play does not crash
    try player.play(silence);
}

