import Foundation
import Darwin

struct NetworkSpeedSample {
    let downloadBytesPerSec: Double
    let uploadBytesPerSec: Double
}

final class NetworkMonitor {
    private var lastInBytes: UInt64 = 0
    private var lastOutBytes: UInt64 = 0
    private var lastTimestamp: UInt64 = 0
    private var isFirstSample = true

    private(set) var sessionDownloadBytes: UInt64 = 0
    private(set) var sessionUploadBytes: UInt64 = 0
    private(set) var peakDownloadBytesPerSec: Double = 0
    private(set) var peakUploadBytesPerSec: Double = 0
    private(set) var activeInterfaceName: String = "No Active Interface"

    let historyCapacity = 60
    private(set) var downloadHistory: [Double]
    private(set) var uploadHistory: [Double]

    private var timebaseInfo = mach_timebase_info_data_t()

    init() {
        mach_timebase_info(&timebaseInfo)
        downloadHistory = Array(repeating: 0, count: historyCapacity)
        uploadHistory = Array(repeating: 0, count: historyCapacity)
    }

    func resetSessionStats() {
        sessionDownloadBytes = 0
        sessionUploadBytes = 0
        peakDownloadBytesPerSec = 0
        peakUploadBytesPerSec = 0
        downloadHistory = Array(repeating: 0, count: historyCapacity)
        uploadHistory = Array(repeating: 0, count: historyCapacity)
    }

    func sample() -> NetworkSpeedSample {
        let (currentIn, currentOut, primaryName) = readInterfaceTotals()
        activeInterfaceName = primaryName

        let now = mach_absolute_time()

        if isFirstSample {
            lastInBytes = currentIn
            lastOutBytes = currentOut
            lastTimestamp = now
            isFirstSample = false
            return NetworkSpeedSample(downloadBytesPerSec: 0, uploadBytesPerSec: 0)
        }

        let elapsedNano = (now - lastTimestamp) * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
        let elapsedSeconds = Double(elapsedNano) / 1_000_000_000.0

        guard elapsedSeconds > 0.05 else {
            return NetworkSpeedSample(downloadBytesPerSec: 0, uploadBytesPerSec: 0)
        }

        let deltaIn = currentIn >= lastInBytes ? (currentIn - lastInBytes) : 0
        let deltaOut = currentOut >= lastOutBytes ? (currentOut - lastOutBytes) : 0

        let downBps = Double(deltaIn) / elapsedSeconds
        let upBps = Double(deltaOut) / elapsedSeconds

        sessionDownloadBytes &+= deltaIn
        sessionUploadBytes &+= deltaOut

        if downBps > peakDownloadBytesPerSec { peakDownloadBytesPerSec = downBps }
        if upBps > peakUploadBytesPerSec { peakUploadBytesPerSec = upBps }

        lastInBytes = currentIn
        lastOutBytes = currentOut
        lastTimestamp = now

        downloadHistory.removeFirst()
        downloadHistory.append(downBps)
        uploadHistory.removeFirst()
        uploadHistory.append(upBps)

        return NetworkSpeedSample(downloadBytesPerSec: downBps, uploadBytesPerSec: upBps)
    }

    private func readInterfaceTotals() -> (UInt64, UInt64, String) {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else {
            return (0, 0, "No Active Interface")
        }
        defer { freeifaddrs(ifaddrPtr) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
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
                // Skip virtual/bridge/awdl interfaces to avoid double counting
                if isPhysicalOrPrimaryInterface(name) {
                    let networkData = dataPtr.assumingMemoryBound(to: if_data.self).pointee
                    let ibytes = UInt64(networkData.ifi_ibytes)
                    let obytes = UInt64(networkData.ifi_obytes)
                    totalIn &+= ibytes
                    totalOut &+= obytes

                    let combined = ibytes &+ obytes
                    if primaryName == nil || combined > bestTraffic {
                        bestTraffic = combined
                        primaryName = "\(name) · \(friendlyType(for: name))"
                    }
                }
            }
            ptr = addr.ifa_next
        }

        return (totalIn, totalOut, primaryName ?? "No Active Interface")
    }

    private func isPhysicalOrPrimaryInterface(_ name: String) -> Bool {
        return name.hasPrefix("en") || name.hasPrefix("utun") || name.hasPrefix("ppp")
    }

    private func friendlyType(for name: String) -> String {
        if name == "en0" { return "Wi-Fi / Primary" }
        if name.hasPrefix("en") { return "Ethernet / Interface" }
        if name.hasPrefix("utun") || name.hasPrefix("ppp") { return "VPN Tunnel" }
        return "Network"
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
