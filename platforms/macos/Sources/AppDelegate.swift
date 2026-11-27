import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = NetworkMonitor()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let popoverVC = PopoverViewController()
    private var timer: Timer?

    private let defaults = UserDefaults.standard
    private let unitKey = "NetSpeedLite.UseBits"
    private let themeKey = "NetSpeedLite.Theme"

    private var useBits: Bool {
        get { defaults.bool(forKey: unitKey) }
        set { defaults.set(newValue, forKey: unitKey) }
    }

    private var currentTheme: AppTheme {
        get {
            guard let raw = defaults.string(forKey: themeKey),
                  let t = AppTheme(rawValue: raw) else {
                return .midnight
            }
            return t
        }
        set { defaults.set(newValue.rawValue, forKey: themeKey) }
    }

    private var latestDownBps: Double = 0
    private var latestUpBps: Double = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusBarClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
            button.title = "↓ 0.0 KB/s  ↑ 0.0 KB/s"
        }

        popover.contentViewController = popoverVC
        popover.behavior = .transient
        popover.animates = true

        popoverVC.onToggleUnit = { [weak self] in
            guard let self = self else { return }
            self.useBits.toggle()
            self.refreshUI()
        }
        popoverVC.onSelectTheme = { [weak self] theme in
            guard let self = self else { return }
            self.currentTheme = theme
            self.refreshUI()
        }
        popoverVC.onResetSession = { [weak self] in
            guard let self = self else { return }
            self.monitor.resetSessionStats()
            self.refreshUI()
        }
        popoverVC.onQuit = {
            NSApp.terminate(nil)
        }

        let newTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
        tick()
    }

    private func tick() {
        let sample = monitor.sample()
        latestDownBps = sample.downloadBytesPerSec
        latestUpBps = sample.uploadBytesPerSec
        refreshUI()
    }

    private func refreshUI() {
        let downStr = NetworkMonitor.formatSpeed(latestDownBps, useBits: useBits)
        let upStr = NetworkMonitor.formatSpeed(latestUpBps, useBits: useBits)
        statusItem.button?.title = "↓ \(downStr)  ↑ \(upStr)"

        if popover.isShown || popoverVC.isViewLoaded {
            popoverVC.update(
                theme: currentTheme,
                useBits: useBits,
                interfaceName: monitor.activeInterfaceName,
                downBps: latestDownBps,
                upBps: latestUpBps,
                peakDownBps: monitor.peakDownloadBytesPerSec,
                peakUpBps: monitor.peakUploadBytesPerSec,
                sessionDown: monitor.sessionDownloadBytes,
                sessionUp: monitor.sessionUploadBytes,
                downHistory: monitor.downloadHistory,
                upHistory: monitor.uploadHistory
            )
        }
    }

    @objc private func handleStatusBarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover(sender)
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu(sender)
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            refreshUI()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        let unitTitle = useBits ? "Switch to Bytes/s (KB/s, MB/s)" : "Switch to Bits/s (Kbps, Mbps)"
        let unitItem = NSMenuItem(title: unitTitle, action: #selector(menuToggleUnit), keyEquivalent: "u")
        unitItem.target = self
        menu.addItem(unitItem)

        let themeMenu = NSMenu()
        for t in AppTheme.allCases {
            let item = NSMenuItem(title: t.rawValue, action: #selector(menuSelectTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = t.rawValue
            item.state = (t == currentTheme) ? .on : .off
            themeMenu.addItem(item)
        }
        let themeRoot = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeRoot.submenu = themeMenu
        menu.addItem(themeRoot)

        let resetItem = NSMenuItem(title: "Reset Session Stats", action: #selector(menuResetSession), keyEquivalent: "r")
        resetItem.target = self
        menu.addItem(resetItem)

        if #available(macOS 13.0, *) {
            let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(menuToggleLaunchAtLogin), keyEquivalent: "")
            loginItem.target = self
            loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
            menu.addItem(loginItem)
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit NetSpeedLite", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        sender.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuToggleUnit() {
        useBits.toggle()
        refreshUI()
    }

    @objc private func menuSelectTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let theme = AppTheme(rawValue: raw) else { return }
        currentTheme = theme
        refreshUI()
    }

    @objc private func menuResetSession() {
        monitor.resetSessionStats()
        refreshUI()
    }

    @objc private func menuToggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
            } catch {
                NSLog("NetSpeedLite: Launch at Login toggle failed: \(error.localizedDescription)")
            }
        }
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }
}
