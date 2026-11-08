# Contributing to NetSpeedLite

Thank you for your interest in contributing to **NetSpeedLite**! 

NetSpeedLite is built on one core philosophy: **Zero bloat, featherlight footprint (<5 MB RAM, 0% CPU), and flawless Windows 11 taskbar integration.**

---

## 🛠️ Development & Building

NetSpeedLite has **zero external dependencies** and requires no heavy IDE or SDK installations. It compiles using the native C# compiler built into Windows.

### Quick Build
```powershell
# Compile all variants (x64, x86, AnyCpu):
.\build_all.ps1

# Or single quick build:
.\build.ps1
```

---

## 📋 Guidelines for Contributions

1. **Keep it Featherlight:** Pull requests that introduce heavy third-party DLLs, background services, runtime installers, or network telemetry will not be accepted.
2. **Clean Architecture:** Keep UI, taskbar positioning, and network measurement cleanly decoupled.
3. **Continuous Visibility:** Ensure any taskbar UI changes do not cause window dropouts behind maximized apps or explorer restarts.

---

## 🚀 Submitting Pull Requests

1. Fork the repo and create your branch from `main`.
2. Test your changes locally on Windows 11 and/or Windows 10.
3. Submit a Pull Request with a clear explanation of your changes.
