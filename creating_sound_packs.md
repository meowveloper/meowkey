# Creating Sound Packs for Meowkey

This guide explains how to create custom sound packs for Meowkey. A sound pack consists of two files:
1.  `sound.wav`: A single audio file containing all key sounds.
2.  `config.json`: A mapping file that tells Meowkey where each key sound starts and ends in the `sound.wav` file.

## 1. Preparing the Audio File (`sound.wav`)

Meowkey requires audio in a very specific format for low-latency playback:
-   **Format:** WAV (RIFF)
-   **Codec:** PCM Signed 16-bit Little Endian (`s16le`)
-   **Channels:** Mono (1 channel)
-   **Sample Rate:** 44100 Hz

### Converting Existing Audio
If you have an audio file (MP3, OGG, FLAC, etc.) that you want to use, you must convert it using `ffmpeg`.

```bash
ffmpeg -i input_file.ogg -ac 1 -ar 44100 -acodec pcm_s16le sound.wav
```

-   `-ac 1`: Downmix to Mono.
-   `-ar 44100`: Resample to 44.1kHz.
-   `-acodec pcm_s16le`: Use raw 16-bit PCM codec.

### Recording Your Own Sounds
If you record your own mechanical keyboard:
1.  Record each key press clearly with silence in between.
2.  Normalize the audio to -3dB or -6dB to prevent clipping.
3.  Export as **WAV 16-bit PCM @ 44100Hz Mono**.

---

## 2. Creating the Configuration (`config.json`)

The configuration file maps key names to their corresponding audio timestamps in milliseconds.

### Structure
```json
{
    "base_path": "sound.wav",
    "defines": {
        "key-name-1": [start_ms, end_ms],
        "key-name-2": [start_ms, end_ms],
        ...
    }
}
```

-   **`start_ms`**: The timestamp (in milliseconds) where the sound starts.
-   **`end_ms`**: The timestamp (in milliseconds) where the sound ends.
-   **Precision:** You can use floating-point numbers for high precision (e.g., `1234.56`).

### Finding the Timestamps
You need an audio editor like **Audacity** (free & open source) to find these values.

1.  Open your `sound.wav` in Audacity.
2.  Set the selection format to **milliseconds**.
3.  Select the region of the audio corresponding to a key press (e.g., the "click" of the Q key).
4.  Note the **Start** and **End** times.
5.  Add an entry to `config.json`:
    ```json
    "key-q": [1250.5, 1380.2]
    ```

### Supported Key Names
Meowkey uses standard kebab-case names for keys. Common ones include:

| Category | Key Names |
| :--- | :--- |
| **Letters** | `key-a`, `key-b`, ..., `key-z` |
| **Numbers** | `digit-0` to `digit-9` |
| **Numpad** | `numpad-0` to `numpad-9`, `numpad-enter`, `numpad-add` |
| **Function** | `f1` to `f12` |
| **Modifiers** | `shift-left`, `shift-right`, `control-left`, `alt-left`, `meta-left` |
| **Navigation** | `arrow-up`, `arrow-down`, `arrow-left`, `arrow-right`, `home`, `end`, `page-up`, `page-down` |
| **Special** | `enter`, `space`, `backspace`, `tab`, `escape`, `caps-lock` |
| **Symbols** | `minus`, `equal`, `bracket-left`, `bracket-right`, `semicolon`, `quote`, `backquote`, `comma`, `period`, `slash`, `backslash` |

### Fallback Behavior
If a key is pressed but not defined in `config.json`, Meowkey will currently play nothing (silent). It is recommended to map a generic "click" sound to common keys if you don't want to record every single one individually.

## 3. Installation

Place your generated `sound.wav` and `config.json` in:
`~/.config/meowkey/`

Meowkey will automatically load them on startup.
