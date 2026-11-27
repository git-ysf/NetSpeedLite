import Foundation
import Combine
import Darwin
import WidgetKit

struct WidgetSpeedSnapshot: Codable {
    let downloadBps: Double
    let uploadBps: Double
    let peakDownloadBps: Double
    let peakUploadBps: Double
    let sessionDownloadBytes: UInt64
    let sessionUploadBytes: UInt64
    let interfaceName: String
    let downloadHistory: [Double]
    let uploadHistory: [Double]
    let useBits: Bool
    let themeRaw: String
    let updatedAt: Date

    static let appGroupID = "group.com.netspeedlite.ios"
    static let storageKey = "NetSpeedLite.WidgetSnapshot"

    static func load() -> WidgetSpeedSnapshot {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(WidgetSpeedSnapshot.self, from: data) {
            return decoded
        }
        return WidgetSpeedSnapshot(
            downloadBps: 0,
            uploadBps: 0,
            peakDownloadBps: 0,
            peakUploadBps: 0,
            sessionDownloadBytes: 0,
            sessionUploadBytes: 0,
            interfaceName: "Wi-Fi",
            downloadHistory: Array(repeating: 0, count: 30),
            uploadHistory: Array(repeating: 0, count: 30),
            useBits: false,
            themeRaw: AppTheme.midnight.rawValue,
            updatedAt: Date()
        )
    }

    func save() {
        let defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        if let encoded = try? JSONEncoder().encode(self) {
            defaults.set(encoded, forKey: Self.storageKey)
        }
    }
}

final class NetworkSpeedMonitor: ObservableObject {
    @Published private(set) var downloadBps: Double = 0
    @Published private(set) var uploadBps: Double = 0
    @Published private(set) var peakDownloadBps: Double = 0
    @Published private(set) var peakUploadBps: Double = 0
    @Published private(set) var sessionDownloadBytes: UInt64 = 0
    @Published private(set) var sessionUploadBytes: UInt64 = 0
    @Published private(set) var interfaceName: String = "No Active Network"
    @Published private(set) var downloadHistory: [Double] = Array(repeating: 0, count: 60)
    @Published private(set) var uploadHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var isPaused: Bool = false

    @Published var useBits: Bool {
        didSet { UserDefaults.standard.set(useBits, forKey: "NetSpeedLite.UseBits") }
    }

    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "NetSpeedLite.Theme") }
    }

    private var timer: Timer?
    private var lastCounters: [String: (inBytes: UInt32, outBytes: UInt32)] = [:]
    private var lastTimestamp: UInt64 = 0
    private var timebaseInfo = mach_timebase_info_data_t()
    private var tickCount = 0

    init() {
        mach_timebase_info(&timebaseInfo)
        self.useBits = UserDefaults.standard.bool(forKey: "NetSpeedLite.UseBits")
        if let raw = UserDefaults.standard.string(forKey: "NetSpeedLite.Theme"),
           let savedTheme = AppTheme(rawValue: raw) {
            self.theme = savedTheme
        } else {
            self.theme = .midnight
        }
    }

    deinit {
        stop()
    }

    func start() {
        guard timer == nil else { return }
        lastTimestamp = 0
        lastCounters.removeAll()
        tick()
        let newTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func resetSession() {
        downloadBps = 0
        uploadBps = 0
        peakDownloadBps = 0
        peakUploadBps = 0
        sessionDownloadBytes = 0
        sessionUploadBytes = 0
        downloadHistory = Array(repeating: 0, count: 60)
        uploadHistory = Array(repeating: 0, count: 60)
        lastCounters.removeAll()
        lastTimestamp = 0
        persistWidgetSnapshot()
    }

    private func tick() {
        guard !isPaused else { return }

        let (currentCounters, primaryName) = readCounters()
        interfaceName = primaryName

        let now = mach_absolute_time()
        if lastTimestamp == 0 {
            lastCounters = currentCounters
            lastTimestamp = now
            return
        }

        let elapsedNano = (now - lastTimestamp) * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
        let elapsedSeconds = Double(elapsedNano) / 1_000_000_000.0
        guard elapsedSeconds > 0.05 else { return }

        var deltaIn: UInt64 = 0
        var deltaOut: UInt64 = 0

        for (name, current) in currentCounters {
            if let prev = lastCounters[name] {
                let dIn: UInt64 = current.inBytes >= prev.inBytes
                    ? UInt64(current.inBytes - prev.inBytes)
                    : UInt64(UInt32.max - prev.inBytes) + UInt64(current.inBytes) + 1
                let dOut: UInt64 = current.outBytes >= prev.outBytes
                    ? UInt64(current.outBytes - prev.outBytes)
                    : UInt64(UInt32.max - prev.outBytes) + UInt64(current.outBytes) + 1
                deltaIn &+= dIn
                deltaOut &+= dOut
            }
        }

        lastCounters = currentCounters
        lastTimestamp = now

        let down = Double(deltaIn) / elapsedSeconds
        let up = Double(deltaOut) / elapsedSeconds

        downloadBps = down
        uploadBps = up
        sessionDownloadBytes &+= deltaIn
        sessionUploadBytes &+= deltaOut

        if down > peakDownloadBps { peakDownloadBps = down }
        if up > peakUploadBps { peakUploadBps = up }

        downloadHistory.removeFirst()
        downloadHistory.append(down)
        uploadHistory.removeFirst()
        uploadHistory.append(up)

        tickCount += 1
        if tickCount % 5 == 0 {
            persistWidgetSnapshot()
        }
    }

    private func persistWidgetSnapshot() {
        let snapshot = WidgetSpeedSnapshot(
            downloadBps: downloadBps,
            uploadBps: uploadBps,
            peakDownloadBps: peakDownloadBps,
            peakUploadBps: peakUploadBps,
            sessionDownloadBytes: sessionDownloadBytes,
            sessionUploadBytes: sessionUploadBytes,
            interfaceName: interfaceName,
            downloadHistory: Array(downloadHistory.suffix(30)),
            uploadHistory: Array(uploadHistory.suffix(30)),
            useBits: useBits,
            themeRaw: theme.rawValue,
            updatedAt: Date()
        )
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func readCounters() -> ([String: (inBytes: UInt32, outBytes: UInt32)], String) {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else {
            return ([:], "No Active Network")
        }
        defer { freeifaddrs(ifaddrPtr) }

        var counters: [String: (inBytes: UInt32, outBytes: UInt32)] = [:]
        var primaryName: String?
        var bestTraffic: UInt64 = 0

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let addr = current.pointee
            let flags = Int32(addr.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if isUp && isRunning && !isLoopback,
               let sa = addr.ifa_addr,
               sa.pointee.sa_family == UInt8(AF_LINK),
               let dataPtr = addr.ifa_data {
                let name = String(cString: addr.ifa_name)
                if name.hasPrefix("en") || name.hasPrefix("pdp_ip") || name.hasPrefix("utun") {
                    let networkData = dataPtr.assumingMemoryBound(to: if_data.self).pointee
                    counters[name] = (networkData.ifi_ibytes, networkData.ifi_obytes)

                    let combined = UInt64(networkData.ifi_ibytes) + UInt64(networkData.ifi_obytes)
                    if primaryName == nil || combined > bestTraffic {
                        bestTraffic = combined
                        primaryName = friendlyName(for: name)
                    }
                }
            }
            ptr = addr.ifa_next
        }

        return (counters, primaryName ?? "No Active Network")
    }

    private func friendlyName(for name: String) -> String {
        if name.hasPrefix("en") { return "\(name) · Wi-Fi" }
        if name.hasPrefix("pdp_ip") { return "\(name) · Cellular" }
        if name.hasPrefix("utun") { return "\(name) · VPN" }
        return name
    }

    static func formatSpeed(_ bytesPerSec: Double, useBits: Bool) -> String {
        if useBits {
            let bits = bytesPerSec * 8.0
            if bits < 1_000_000.0 {
                return String(format: "%.1f Kbps", bits / 1_000.0)
            } else if bits < 1_000_000_000.0 {
                return String(format: "%.2f Mbps", bits / 1_000_000.0)
            } else {
                return String(format: "%.2f Gbps", bits / 1_000_000_000.0)
            }
        }

        if bytesPerSec < 1024.0 * 1024.0 {
            return String(format: "%.1f KB/s", bytesPerSec / 1024.0)
        } else if bytesPerSec < 1024.0 * 1024.0 * 1024.0 {
            return String(format: "%.2f MB/s", bytesPerSec / (1024.0 * 1024.0))
        } else {
            return String(format: "%.2f GB/s", bytesPerSec / (1024.0 * 1024.0 * 1024.0))
        }
    }

    static func formatBytes(_ bytes: UInt64) -> String {
        let value = Double(bytes)
        if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", value / 1024.0)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", value / (1024.0 * 1024.0))
        } else {
            return String(format: "%.2f GB", value / (1024.0 * 1024.0 * 1024.0))
        }
    }
}
