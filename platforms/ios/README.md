# NetSpeedLite for iOS & iPadOS

Ultra-lightweight, zero-dependency native SwiftUI + WidgetKit network speed monitor for iOS 16+ and iPadOS 16+.

## Features
- Live download & upload speed via `Darwin.getifaddrs` (`AF_LINK` / `if_data`) with 32-bit counter wrap-around handling
- Adaptive SwiftUI interface for iPhone & iPad with live 60-second dual-line sparkline
- 5 built-in themes: **Midnight**, **Emerald**, **Amber**, **Rose**, and **Frost** (light)
- Toggle between **Bytes/s** (`KB/s`, `MB/s`, `GB/s`) and **Bits/s** (`Kbps`, `Mbps`, `Gbps`)
- **WidgetKit** home screen (`systemSmall`, `systemMedium`) and lock screen (`accessoryRectangular`) widgets synced via App Group `group.com.netspeedlite.ios`

## Build
Requires macOS with Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
cd platforms/ios
chmod +x build_ios.sh
./build_ios.sh
```

Or generate and open in Xcode:

```bash
xcodegen generate
open NetSpeedLite.xcodeproj
```
