# Meowkey

**Meowkey** is a lightweight, zero-latency mechanical keyboard sound simulator for Linux. It runs in the background and plays high-quality mechanical switch sounds in real-time as you type, regardless of which application is focused.

Built with **Zig**, it interacts directly with the Linux Input Subsystem (`/dev/input`) and ALSA for maximum performance and minimal resource usage.

# Preview


https://github.com/user-attachments/assets/d163c566-8a7c-496d-a539-45eefa7714f0



## Features
-   **Zero Latency:** Direct ALSA integration ensures instant audio feedback.
-   **Global Capture:** Works system-wide, even in terminals or fullscreen games.
-   **Lightweight:** Written in Zig for high efficiency and low memory footprint **(below 30MB while typing)**.
-   **No Root Required:** Runs with user permissions (if part of the `input` group).
-   **Embedded Sounds:** Works out of the box with an embedded CherryMX Red PBT sound pack—no configuration required.
-   **Customizable:** Support for custom `.wav` sound packs and independent volume control.

> note that configuration for different sounds is possible, but it doesn't feel right, and I generated the config.json file using AI. The config structure was inspired by the project MechVibes. I will try to find new ways to be able to make sound packs easier.

## Installation

### Download Prebuilt Binaries (Recommended)
You can download the latest prebuilt binaries for `x86_64` and `aarch64` Linux directly from the [GitHub Releases](https://github.com/meowveloper/meowkey/releases) page.

1.  Download the binary for your architecture.
2.  Make it executable: `chmod +x meowkey`
3.  Run it: `./meowkey` or Run seamlessly in the background: `./meowkey & disown`

### System Prerequisites
-   **Linux** (Kernel 5.x+)
-   **ALSA** (`libasound2` on Debian/Ubuntu, `alsa-lib` on Arch/Fedora)

### Post-Installation Setup
Meowkey needs permission to read input devices. Add your user to the `input` group:

```bash
sudo usermod -aG input $USER
newgrp input 
```

---

## Development (Building from Source)

If you wish to contribute or build the latest version yourself, you will need the **Zig** compiler (version: **0.16.0-dev.2821+3edaef9e0**).

```bash
git clone https://github.com/meowveloper/meowkey.git
cd meowkey
zig build -Doptimize=ReleaseSafe
```

---

## Usage


### Basic Usage
By default, Meowkey comes with an embedded **CherryMX Red (PBT)** sound pack. You can run it immediately without any setup:

```bash
./zig-out/bin/meowkey
```

Run seamlessly in the background:
```bash
./zig-out/bin/meowkey & disown
```

### Volume Control
You can adjust the playback volume using the `--volume` or `-vl` flag. The default is `1.0`.

```bash
# Play at half volume
./zig-out/bin/meowkey --volume=0.5

# Play at 150% volume
./zig-out/bin/meowkey -vl=1.5
```

## Custom Sound Packs

Meowkey looks for custom configuration files in `~/.config/meowkey/`. If both files are found, they will override the embedded sound pack.
    
Create the directory:
```bash
mkdir -p ~/.config/meowkey
```
    
Copy your `config.json` and `sound.wav` into this folder.

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

----
# Future Plans
- [ ] supporting multiple sound packs without having to change the `~/.config/meokey` folder everytime
- [ ] hot reload for adding/remove input devices(keyboards)
- [ ] support for MacOs
- [ ] support for Windows(not sure)
- [ ] Frontend GUI for convnience instead of typing command line arguments (not sure)
