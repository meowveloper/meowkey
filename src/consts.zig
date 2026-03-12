pub const SOUND_FILE_PATH = "~/.config/meowkey/sound.wav";
pub const CONFIG_FILE_PATH = "~/.config/meowkey/config.json";
pub const CONFIG_BIN_PATH = "~/.cache/meowkey/config.bin";

pub const EMBEDDED_CONFIG_FILE_PATH = "assets/config.json";
pub const EMBEDDED_SOUND_FILE_PATH = "assets/sound.wav";

pub const AudioError = error{ OpenFailed, ParamSetupFailed, InvalidHeader, NotARiffFile, NotAWaveFile, UnsupportedCompression, Only16BitSupported, IncompleteData };
