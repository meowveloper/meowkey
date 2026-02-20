pub const CONFIG_DIR = "~/meowkey";
pub const SOUND_FILE_NAME = "sound.wav";
pub const CONFIG_FILE_NAME = "config.json";
pub const CONFIG_BIN_PATH = "/tmp/meowkey/config.bin";

pub const AudioError = error{ OpenFailed, ParamSetupFailed, InvalidHeader, NotARiffFile, NotAWaveFile, UnsupportedCompression, Only16BitSupported, IncompleteData };
