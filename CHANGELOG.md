# Changelog

## [0.1.0] - 2026-03-13
### Added
- Real-time zero latency keypress sound generation using Zig.
- Robust multi-device detection using `EV_REP` scanning.
- Flawless background input capture via `/dev/input`.
- ALSA integration for native, highly performant audio playback.
- Custom MechVibes-compatible soundpack loading (WAV + JSON).
- Embedded asset fallback for a seamless out-of-the-box experience.
- Cross-architecture portability (x86_64, aarch64).

### Fixed
- Static linking issues on glibc and NixOS systems.
- OOM leaks during input listener loop.
- Non-blocking audio playback using spawned threads.
