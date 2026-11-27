# Changelog

All notable changes to **NetSpeedLite** are documented in this file.

---

## [v1.2.0] — 2026-11-28

### 🌐 Cross-Platform Edition
- **Android (`platforms/android`)**: Native Java APK (`NetSpeedLite-Android.apk`) with live status-bar/notification speed monitor, foreground service, and `TrafficStats` sampling.
- **macOS (`platforms/macos`)**: Universal (`arm64` + `x86_64`) native Swift/AppKit menu bar app (`NetSpeedLite-macOS.zip`) with popover telemetry card, live sparkline, and adaptive themes.
- **Linux (`platforms/linux`)**: Zero-dependency C99 binary (`netspeedlite-linux-x86_64`) reading `/proc/net/dev` with `--waybar`, `--polybar`, `--tui`, `--once`, and `--json` output modes.
- **iOS / iPadOS (`platforms/ios`)**: Native SwiftUI + WidgetKit app (`NetSpeedLite-iOS-unsigned.ipa` / XcodeGen project) with live throughput dashboard and widgets.
- **Multi-Platform CI**: Added parallel GitHub Actions jobs (`build-linux`, `build-macos`, `build-ios`, `build-android`) in `.github/workflows/ci.yml` and updated `.gitignore` for platform build artifacts.

---

## [v1.1.0] — 2026-11-28

### ✨ Highlights
- **Per-Pixel Alpha Transparent UI (`UpdateLayeredWindow`)**: Replaced color-key transparency with a cached 32-bit `Format32bppPArgb` backbuffer for crisp anti-aliasing, zero color-key fringes, and zero per-tick bitmap allocations.
- **Borderless Transparent Glass Pill & Minimal Mode**: Subtle translucent taskbar pill that adapts automatically to Windows 11/10 Light & Dark taskbars (`SystemUsesLightTheme`), plus a pure floating-text **Minimal** toggle.
- **Opaque Hover Telemetry Flyout**: Hovering over the taskbar widget for 180 ms reveals an opaque, high-contrast telemetry card showing the active network adapter, live & peak speeds, session data transferred, and a smooth Catmull-Rom dual-channel sparkline. Lazy-initialized with zero idle resource cost.
- **10 Adaptive Color Themes**: **Ocean**, **Cyber Neon**, **Amber Dusk**, **Monochrome**, **Aurora**, **Crimson**, **Lavender**, **Matrix**, **Nordic**, and **Sunset** — persisted in `HKCU\Software\NetSpeedLite`.
- **Live Mini Sparkline**: Zero-allocation 16-sample ring buffer plotting real-time download/upload activity right on the taskbar (auto-hides when idle, toggleable).
- **Bits / Bytes Unit Toggle & Session Reset**: Switch between `KB/s`/`MB/s`/`GB/s` and `Kbps`/`Mbps`/`Gbps`, and reset session peaks/totals via middle-click or the right-click menu.
- **Modernized Context Menu**: Rounded hover highlights and custom vector checkmarks in `DarkMenuRenderer`.

---

## [v1.0.2] — 2026-11-15
- Dynamic High-DPI scaling across multi-monitor and 125%–200% display setups.
- Zero-spike network adapter refresh and interactive desktop STA thread attachment.

## [v1.0.1] — 2026-11-09
- IPv6 interface support, multi-architecture builds (`x64`, `x86`, `AnyCpu`), CI workflow, and improved UI spacing.

## [v1.0.0] — 2026-11-08
- Initial portable release: ~18 KB executable, `Stopwatch` microsecond delta sampling, and Windows 11/10 taskbar docking.
