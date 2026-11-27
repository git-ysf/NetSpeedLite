# NetSpeedLite for macOS

Ultra-lightweight, zero-dependency native Swift menu bar network speed monitor for macOS 12+ (Universal Apple Silicon `arm64` + Intel `x86_64`).

## Features
- Live download & upload speed in the macOS menu bar (`NSStatusBar`) using `getifaddrs` (`AF_LINK` / `if_data`)
- Dark-first popover (`NSPopover`) with live 60-second dual-line sparkline, peak speed, and session totals
- 5 built-in themes: **Midnight**, **Emerald**, **Amber**, **Rose**, and **Frost** (light)
- Toggle between **Bytes/s** (`KB/s`, `MB/s`, `GB/s`) and **Bits/s** (`Kbps`, `Mbps`, `Gbps`)
- Right-click context menu with **Launch at Login** (macOS 13+ `SMAppService`), theme switcher, and session reset

## Build
Requires macOS with Xcode Command Line Tools (`swiftc`, `lipo`, `xcrun`).

```bash
cd platforms/macos
chmod +x build_macos.sh
./build_macos.sh
```

Outputs:
- `platforms/macos/build/NetSpeedLite.app` (Universal `arm64` + `x86_64`)
- `platforms/macos/build/NetSpeedLite-macOS.zip`
