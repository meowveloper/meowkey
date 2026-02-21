pub const SOUND_FILE_NAME = "~/.config/meowkey/sound.wav";
pub const CONFIG_FILE_PATH = "~/.config/meowkey/config.json";
pub const CONFIG_BIN_PATH = "/tmp/meowkey/config.bin";
pub const SOUND_WAV_PATH = "/tmp/meowkey/sound.wav";

pub const AudioError = error{ OpenFailed, ParamSetupFailed, InvalidHeader, NotARiffFile, NotAWaveFile, UnsupportedCompression, Only16BitSupported, IncompleteData };
