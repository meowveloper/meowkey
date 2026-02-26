pub const SOUND_FILE_PATH = "~/.config/meowkey/sound.wav";
pub const CONFIG_FILE_PATH = "~/.config/meowkey/config.json";
pub const CONFIG_BIN_PATH = "~/.cache/meowkey/config.bin";

pub const AudioError = error{ OpenFailed, ParamSetupFailed, InvalidHeader, NotARiffFile, NotAWaveFile, UnsupportedCompression, Only16BitSupported, IncompleteData };
