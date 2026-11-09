## 📋 Description of Changes
<!-- Provide a clear summary of your changes and why they are needed. -->

## 🎯 Target Area
- [ ] Network Monitoring / Stats (`NetworkMonitor.cs`)
- [ ] Taskbar Positioning / Z-Order (`TaskbarController.cs`)
- [ ] UI / GDI+ Rendering (`MainForm.cs`, `DarkMenuRenderer.cs`)
- [ ] Build Scripts / Tooling (`build.ps1`, `build_all.ps1`, `build.bat`)
- [ ] Documentation / Manifests (`README.md`, `winget/`)

## 🛡️ Featherlight Verification Checklist
- [ ] **Zero Bloat:** No external dependencies, heavy DLLs, or telemetry added.
- [ ] **Compiles cleanly:** Tested with `.\build_all.ps1` across x64, x86, and AnyCpu.
- [ ] **Tested on Windows:** Verified appearance and behavior on Windows 11 and/or Windows 10.
- [ ] **Resource footprint:** Memory usage stays minimal (~5 MB RAM, 0.00% CPU).
- [ ] **Continuous Visibility:** Confirmed no window flickering or dropouts behind maximized windows.
