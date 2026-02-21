# Meowkey

**Meowkey** is a lightweight, zero-latency mechanical keyboard sound simulator for Linux. It runs in the background and plays high-quality mechanical switch sounds in real-time as you type, regardless of which application is focused.

Built with **Zig**, it interacts directly with the Linux Input Subsystem (`/dev/input`) and ALSA for maximum performance and minimal resource usage.

## Features
-   **Zero Latency:** Direct ALSA integration ensures instant audio feedback.
-   **Global Capture:** Works system-wide, even in terminals or fullscreen games.
-   **Lightweight:** Written in Zig for high efficiency and low memory footprint.
-   **No Root Required:** Runs with user permissions (if part of the `input` group).

> note that configuration for different sounds is possible, but it doesn't feel right, and I generated the config.json file using AI. The config structure was inspired by the project MechVibes. I will try to find new ways to be able to make sound packs easier.

## Installation
### Prerequisites
-   **Linux** (Kernel 5.x+)
-   **ALSA** (libasound2-dev)
-   **Zig** (0.16.0-dev.2490+fce7878a)

### Build from Source
```bash
git clone https://github.com/meowveloper/meowkey.git
cd meowkey
zig build -Doptimize=ReleaseSafe
```

### Post-Installation Setup
Meowkey needs permission to read input devices. Add your user to the `input` group or run with `sudo`.

```bash
sudo usermod -aG input $USER
newgrp input 
```

## Usage

1.  **Place Sound Pack:**
    Meowkey looks for configuration files in `~/.config/meowkey/`.
    
    Create the directory:
    ```bash
    mkdir -p ~/.config/meowkey
    ```
    
    Copy your [assets/config.json](./assets/config.json) and [assets/sound.wav](./assets/sound.wav) into this folder.
    *(See [creating_sound_packs.md](./creating_sound_packs.md) for details on the format)*

2.  **Run Meowkey:**
    ```bash
    ./zig-out/bin/meowkey
    ```
    Run seamlessly in the background:
    ```bash
    ./zig-out/bin/meowkey & disown
    ```

## Configuration

The `config.json` maps key names to audio timestamps (in milliseconds).

```json
{
    "defines": {
        "key-q": [1250.5, 1380.2],
        "space": [5000.0, 5200.0]
    }
}
```
For a full guide on creating custom sound packs, see [creating_sound_packs.md](./creating_sound_packs.md).
