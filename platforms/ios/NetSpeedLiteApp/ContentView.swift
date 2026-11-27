import SwiftUI

struct ContentView: View {
    @ObservedObject var monitor: NetworkSpeedMonitor

    private var theme: AppTheme { monitor.theme }

    private var maxSparklineValue: Double {
        max(1024.0, (monitor.downloadHistory + monitor.uploadHistory).max() ?? 1024.0)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundTop, theme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    headerBar
                    speedCards
                    sparklineCard
                    themePickerCard
                    actionBar
                }
                .padding()
                .frame(maxWidth: 680)
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(monitor.isPaused ? theme.mutedText : theme.liveDot)
                    .frame(width: 8, height: 8)
                Text(monitor.interfaceName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.primaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(theme.cardBackground)
            .overlay(
                Capsule().stroke(theme.cardBorder, lineWidth: 1)
            )
            .clipShape(Capsule())

            Spacer()

            Button {
                monitor.useBits.toggle()
            } label: {
                Text(monitor.useBits ? "Bits/s (bps)" : "Bytes/s (B/s)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(theme.cardBackground)
                    .overlay(
                        Capsule().stroke(theme.cardBorder, lineWidth: 1)
                    )
                    .clipShape(Capsule())
            }
        }
    }

    private var speedCards: some View {
        HStack(spacing: 12) {
            metricCard(
                title: "DOWNLOAD",
                speed: NetworkSpeedMonitor.formatSpeed(monitor.downloadBps, useBits: monitor.useBits),
                peak: NetworkSpeedMonitor.formatSpeed(monitor.peakDownloadBps, useBits: monitor.useBits),
                total: NetworkSpeedMonitor.formatBytes(monitor.sessionDownloadBytes),
                accent: theme.downloadAccent
            )
            metricCard(
                title: "UPLOAD",
                speed: NetworkSpeedMonitor.formatSpeed(monitor.uploadBps, useBits: monitor.useBits),
                peak: NetworkSpeedMonitor.formatSpeed(monitor.peakUploadBps, useBits: monitor.useBits),
                total: NetworkSpeedMonitor.formatBytes(monitor.sessionUploadBytes),
                accent: theme.uploadAccent
            )
        }
    }

    private func metricCard(title: String, speed: String, peak: String, total: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundColor(accent)
                .tracking(0.8)

            Text(speed)
                .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(theme.primaryText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Divider()
                .background(theme.cardBorder)

            VStack(alignment: .leading, spacing: 2) {
                Text("Peak \(peak)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(theme.mutedText)
                Text("Session \(total)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(theme.mutedText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var sparklineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LIVE THROUGHPUT (60s)")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(theme.mutedText)
                    .tracking(0.8)
                Spacer()
                HStack(spacing: 12) {
                    legendDot(label: "Down", color: theme.downloadAccent)
                    legendDot(label: "Up", color: theme.uploadAccent)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.sparklineBackground)

                SparklineArea(values: monitor.uploadHistory, maxValue: maxSparklineValue)
                    .fill(
                        LinearGradient(
                            colors: [theme.uploadAccent.opacity(0.20), theme.uploadAccent.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(8)

                SparklineLine(values: monitor.uploadHistory, maxValue: maxSparklineValue)
                    .stroke(theme.uploadAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .padding(8)

                SparklineArea(values: monitor.downloadHistory, maxValue: maxSparklineValue)
                    .fill(
                        LinearGradient(
                            colors: [theme.downloadAccent.opacity(0.28), theme.downloadAccent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(8)

                SparklineLine(values: monitor.downloadHistory, maxValue: maxSparklineValue)
                    .stroke(theme.downloadAccent, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .padding(8)
            }
            .frame(height: 150)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.cardBorder.opacity(0.7), lineWidth: 1)
            )
        }
        .padding(14)
        .background(theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func legendDot(label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(theme.mutedText)
        }
    }

    private var themePickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THEME")
                .font(.caption2.weight(.bold))
                .foregroundColor(theme.mutedText)
                .tracking(0.8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AppTheme.allCases) { item in
                        Button {
                            monitor.theme = item
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(item.downloadAccent)
                                    .frame(width: 8, height: 8)
                                Text(item.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(theme.primaryText)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(monitor.theme == item ? item.downloadAccent.opacity(0.22) : theme.sparklineBackground)
                            .overlay(
                                Capsule().stroke(
                                    monitor.theme == item ? item.downloadAccent : theme.cardBorder,
                                    lineWidth: 1
                                )
                            )
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                monitor.isPaused.toggle()
            } label: {
                Label(monitor.isPaused ? "Resume" : "Pause", systemImage: monitor.isPaused ? "play.fill" : "pause.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.cardBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                monitor.resetSession()
            } label: {
                Label("Reset Session", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.cardBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
