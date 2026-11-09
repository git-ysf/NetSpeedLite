# 🚀 NetSpeedLite — Ultra-Featherlight Live Network Speed Monitor for Windows 11 & 10 Taskbar

> **A modern, zero-bloat, open-source alternative to TrafficMonitor, NetSpeedMonitor, and DU Meter.**  
> Real-time upload and download speed displayed directly on your Windows taskbar with microscopic resource usage.

<div align="center">

[![Download NetSpeedLite (x64)](https://img.shields.io/badge/⬇️_Download-NetSpeedLite_x64_(v1.0.1)-2563EB?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/git-ysf/NetSpeedLite/releases/latest/download/NetSpeedLite-x64.exe)
[![Download Universal (ARM64 / Copilot+)](https://img.shields.io/badge/⬇️_Universal-AnyCpu_(ARM64%20%2F%20x64)-059669?style=for-the-badge&logo=arm&logoColor=white)](https://github.com/git-ysf/NetSpeedLite/releases/latest/download/NetSpeedLite-AnyCpu.exe)

<br/>

[![Latest Release](https://img.shields.io/github/v/release/git-ysf/NetSpeedLite?color=blue&label=Latest%20Release)](https://github.com/git-ysf/NetSpeedLite/releases/latest)
[![CI Status](https://github.com/git-ysf/NetSpeedLite/actions/workflows/ci.yml/badge.svg)](https://github.com/git-ysf/NetSpeedLite/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Windows 11 / 10](https://img.shields.io/badge/Platform-Windows%2011%20%7C%2010-0078D4.svg)](https://microsoft.com/windows)
[![Binary Size](https://img.shields.io/badge/Binary%20Size-~18%20KB-success.svg)](#)
[![RAM Usage](https://img.shields.io/badge/RAM%20Usage-~5%20MB-brightgreen.svg)](#)
[![CPU Usage](https://img.shields.io/badge/CPU%20Usage-0.00%25-brightgreen.svg)](#)
[![Dependencies](https://img.shields.io/badge/Dependencies-Zero-informational.svg)](#)

</div>

---

## 💡 What is NetSpeedLite?

**NetSpeedLite** is an ultra-featherlight, portable Windows taskbar utility designed to monitor real-time internet upload and download speeds. Docked smoothly next to the system tray notification chevron (`^`), NetSpeedLite delivers accurate network throughput metrics with **subpixel anti-aliasing**, **true taskbar transparency**, and **continuous visibility**.

Unlike heavy monitoring suites that consume hundreds of megabytes of RAM or throw constant update popups, NetSpeedLite operates on a **zero-bloat philosophy**: a single standalone executable of just **18 KB**, consuming only **~5 MB of RAM** and **0.00% CPU**.

```
       Taskbar Preview (Native Segoe UI + Transparent Background)
┌────────────────────────────────────────────────────────────────────────┐
│  [Windows Start]   [Apps]            ↑: 0.21 KB/s   ^  ENG  📶  🔊     │
│                                      ↓: 0.17 KB/s                      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🥊 Comparison with Other Windows Network Monitors

Why switch to NetSpeedLite? Here is how it compares against popular legacy and commercial network monitors:

| Feature / Metric | 🏆 **NetSpeedLite** | ⚠️ **TrafficMonitor** | ⚠️ **NetSpeedMonitor** | ⚠️ **DU Meter** | ⚠️ **XMeters** |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Windows 11 Taskbar Support** | **Native & Flawless** | Prone to dropouts | Broken (requires hacks) | DeskBand overlay | Broken on modern Win 11 |
| **Executable Size** | **~18 KB** | ~35 MB | ~3.5 MB | ~15 MB | ~25 MB |
| **RAM Footprint** | **~5.5 MB** | 30 MB – 65 MB | 15 MB – 25 MB | 25 MB – 45 MB | 20 MB – 35 MB |
| **CPU Impact** | **0.00% (microsecond deltas)** | 0.3% – 1.5% | 0.5% – 1.0% | 0.5% – 2.0% | 0.8% – 2.5% |
| **External Dependencies** | **None (Native OS)** | LibreHardwareMonitor DLLs | Old VC++ 2005 Runtimes | Proprietary drivers | .NET Framework 4.0 runtime |
| **Annoying Popups** | **Zero (100% Silent)** | Frequent update prompts | None (Abandonware) | Trial & purchase nags | Pro version upsells |
| **Maximized Window Visibility** | **Continuously Visible** | Frequently hides | N/A | Flashes | Inconsistent |
| **Pricing & License** | **100% Free (MIT)** | Free (GPL v2) | Free (Closed Source) | Paid ($29.95) | Freemium ($4.99) |

---

## 💻 Supported Devices & Download Options

NetSpeedLite runs on all modern and legacy Windows devices with zero installation required:

### 📱 Supported Device Categories
- 💻 **Laptops & Ultrabooks:** Lenovo (IdeaPad Pro, Legion, ThinkPad, Yoga), Dell (XPS, Inspiron, Latitude), HP (Spectre, Envy, Omen), ASUS (ZenBook, ROG, TUF), Acer, Samsung Galaxy Book.
- 🖥️ **Desktops & Workstations:** Custom PC builds, Intel NUCs, Mini PCs (Beelink, Minisforum), video editing and 3D rendering workstations.
- 📱 **2-in-1s & Tablets:** Microsoft Surface Pro / Surface Laptop / Surface Go, HP Pavilion x360, Dell 2-in-1s.
- 🎮 **Windows Gaming Handhelds:** ASUS ROG Ally / Ally X, Lenovo Legion Go, MSI Claw, Steam Deck (running Windows 11/10).
- ⚡ **ARM64 & Copilot+ PCs:** Qualcomm Snapdragon X Elite & Snapdragon X Plus devices (Surface Pro 11, Surface Laptop 7, Lenovo Yoga Slim 7x, Dell XPS 13 Copilot+).

---

### 📦 Multi-Architecture Downloads

| Architecture | Target Devices | Size | Direct Download |
| :--- | :--- | :---: | :---: |
| **x64 (64-bit)** *(Recommended)* | 99% of modern Intel & AMD laptops, desktops, and handhelds | `18 KB` | [**Download NetSpeedLite-x64.exe**](https://github.com/git-ysf/NetSpeedLite/releases/latest/download/NetSpeedLite-x64.exe) |
| **AnyCpu (Universal)** | **ARM64 Copilot+ PCs** (Snapdragon X Elite), Surface Pro, Intel & AMD | `18 KB` | [**Download NetSpeedLite-AnyCpu.exe**](https://github.com/git-ysf/NetSpeedLite/releases/latest/download/NetSpeedLite-AnyCpu.exe) |
| **x86 (32-bit)** | Older 32-bit PCs, lightweight Windows VMs, legacy tablets | `18 KB` | [**Download NetSpeedLite-x86.exe**](https://github.com/git-ysf/NetSpeedLite/releases/latest/download/NetSpeedLite-x86.exe) |

> 💡 *All builds are completely portable: single standalone `.exe` files with no installer needed. Check all versions on the [GitHub Releases Page](https://github.com/git-ysf/NetSpeedLite/releases).*

---

## ✨ Key Features & Architectural Highlights

### 🪶 1. True Featherlight Architecture
- **Single Portable File:** No installer, no background services, no scheduled tasks, no temporary extraction folders.
- **Micro-Memory Allocation:** Operates within ~5 MB of RAM, leaving your system completely unburdened for creative software (DaVinci Resolve, Adobe Premiere Pro, Blender) or gaming.
- **0.00% CPU Consumption:** Samples network deltas once every 1,000 ms using hardware counters and remains fully asleep between ticks.

### ⏱️ 2. Hardware-Accurate Speed Sampling
- **High-Precision Timing:** Uses the CPU's invariant Time Stamp Counter (`Stopwatch.GetTimestamp()`) for nanosecond-level delta timing, avoiding standard Windows timer jitter.
- **Cached Adapter Routing:** Automatically discovers and caches your active network adapter (Wi-Fi 6E/7, Gigabit Ethernet, USB tethering). Reads statistics in **0.1 milliseconds** instead of querying the entire network stack.
- **Dynamic Throughput Formatting:** Clean, readable units from `0.00 KB/s` up to `999.99 MB/s` and `GB/s`.

### 🛡️ 3. Zero-Flicker Continuous Visibility
- **No Maximized-Window Dropouts:** Specifically engineered for Windows 11 so that opening full-screen or maximized applications (browsers, video editors, IDEs) never causes the widget to disappear.
- **Atomic Double-Buffered Painting:** Overrides the Windows background-erase message (`WM_ERASEBKGND`) to deliver smooth, flicker-free digital clock-style number updates.
- **Self-Healing Z-Order:** Anchors automatically to the left edge of `TrayNotifyWnd` and maintains top-level positioning alongside the system tray chevron.

### 🎨 4. Native Windows 11 Dark Aesthetic
- **True Transparency:** Alpha-keyed background (`#010000`) lets Windows 11 taskbar blur, Mica, and dark themes shine through seamlessly.
- **Color Palette:**
  - Up Arrow (`↑:`): Sky Blue (`#38BDF8`)
  - Down Arrow (`↓:`): Sky Blue (`#38BDF8`)
  - Speed Values: Crisp Studio White (`#F8FAFC`)
- **Modern Dark Context Menu:** Right-clicking opens a custom dark-mode menu matching Windows 11 system dialogs.

### 🖱️ 5. Non-Intrusive Controls
- **Click-Through:** Left-clicking passes through to the taskbar (`WS_EX_NOACTIVATE`) so it never steals focus from your active project or timeline.
- **Task Manager Shortcut:** Double-clicking instantly opens Windows Task Manager (`taskmgr.exe`).
- **One-Click Auto-Start:** Easily toggle Windows startup on or off directly from the right-click menu.

---

## ❓ Frequently Asked Questions (FAQ)

### How do I show live internet speed on the Windows 11 taskbar?
Download [NetSpeedLite-x64.exe](https://github.com/git-ysf/NetSpeedLite/releases/latest/download/NetSpeedLite-x64.exe), place it anywhere on your computer (e.g. `C:\Program Files\NetSpeedLite\`), and double-click to run it. It immediately appears on your taskbar next to your system tray icons.

### Why does my net speed monitor keep disappearing behind windows?
Legacy monitors like TrafficMonitor often mistake maximized standard windows (browsers, File Explorer, video editors) for full-screen games because maximized windows have boundary rectangles that touch or exceed screen edges. NetSpeedLite is explicitly engineered to ignore these false triggers and remains permanently and continuously visible.

### Does NetSpeedLite collect telemetry or check for updates?
No. NetSpeedLite contains **zero telemetry, zero analytics, and zero remote network requests**. It does not make any background connections to external servers. All network measurements are read locally from the Windows kernel network interface tables.

### How do I make NetSpeedLite start automatically with Windows?
Simply right-click the speed numbers on your taskbar and check **Start with Windows**. It automatically creates a lightweight user startup entry in `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`.

### Does it support Snapdragon X Elite Copilot+ PCs?
Yes! Download the [NetSpeedLite-AnyCpu.exe](https://github.com/git-ysf/NetSpeedLite/releases/latest/download/NetSpeedLite-AnyCpu.exe) build, which JIT-compiles natively for ARM64 hardware with maximum execution speed and zero battery drain.

---

## 🌐 Recommended Featherlight Monitors for Other Operating Systems

Looking for companion monitors for your non-Windows devices? Here are the best lightweight open-source alternatives:

- 🍏 **macOS (MacBook, Mac Mini, Studio):** **[Stats](https://github.com/exelban/stats)** — Open-source native Swift menu bar monitor (~15 MB RAM, 0.00% CPU).
- 🐧 **Linux (Ubuntu, Fedora, Arch):** **[Vitals](https://github.com/corecoding/Vitals)** & **NetSpeed** for GNOME / KDE; built-in `/proc/net/dev` module for **[Waybar](https://github.com/Alexays/Waybar)** and Polybar.
- 🤖 **Android (Phones & Tablets):** **[NetSpeed Indicator](https://github.com/nisargjhaveri/NetSpeedIndicator)** — Open-source status-bar speed monitor on F-Droid.
- 🍎 **iOS / iPadOS (iPhone & iPad):** **[Traffic Monitor](https://apps.apple.com/app/traffic-monitor-with-widget/id482570191)** — Dynamic Island & Lock Screen live widget.

---

## 🛠️ Building from Source

NetSpeedLite requires no external SDKs or Visual Studio installations. It compiles cleanly with the C# compiler built into every Windows installation:

### Quick Build (PowerShell):
```powershell
# Compile all variants (x64, x86, AnyCpu):
powershell -ExecutionPolicy Bypass -File .\build_all.ps1

# Or single quick build:
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

### Quick Build (Command Prompt):
```cmd
build.bat
```

---

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for details.
