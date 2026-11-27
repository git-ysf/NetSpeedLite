import WidgetKit
import SwiftUI

struct SpeedTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSpeedSnapshot
}

struct SpeedTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpeedTimelineEntry {
        SpeedTimelineEntry(date: Date(), snapshot: .load())
    }

    func getSnapshot(in context: Context, completion: @escaping (SpeedTimelineEntry) -> Void) {
        completion(SpeedTimelineEntry(date: Date(), snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpeedTimelineEntry>) -> Void) {
        let now = Date()
        let entry = SpeedTimelineEntry(date: now, snapshot: .load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now.addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct WidgetSparklinePath: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count >= 2, rect.width > 0, rect.height > 0 else { return path }
        let maxVal = max(1024.0, values.max() ?? 1024.0)
        let stepX = rect.width / CGFloat(values.count - 1)

        for (idx, val) in values.enumerated() {
            let x = rect.minX + CGFloat(idx) * stepX
            let ratio = min(1.0, max(0.0, val / maxVal))
            let y = rect.maxY - CGFloat(ratio) * rect.height
            let pt = CGPoint(x: x, y: y)
            if idx == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        return path
    }
}

struct NetSpeedLiteWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SpeedTimelineEntry

    private var theme: AppTheme {
        AppTheme(rawValue: entry.snapshot.themeRaw) ?? .midnight
    }

    var body: some View {
        let snap = entry.snapshot
        let downStr = NetworkSpeedMonitor.formatSpeed(snap.downloadBps, useBits: snap.useBits)
        let upStr = NetworkSpeedMonitor.formatSpeed(snap.uploadBps, useBits: snap.useBits)

        Group {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("NetSpeedLite · \(snap.interfaceName)")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                    Text("↓ \(downStr)")
                        .font(.caption.monospacedDigit().weight(.bold))
                    Text("↑ \(upStr)")
                        .font(.caption.monospacedDigit().weight(.medium))
                }
            case .systemMedium:
                mediumView(snap: snap, downStr: downStr, upStr: upStr)
            default:
                smallView(snap: snap, downStr: downStr, upStr: upStr)
            }
        }
    }

    private func smallView(snap: WidgetSpeedSnapshot, downStr: String, upStr: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle()
                    .fill(theme.liveDot)
                    .frame(width: 6, height: 6)
                Text(snap.interfaceName)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(theme.mutedText)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("DOWN")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(theme.downloadAccent)
                Text(downStr)
                    .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(theme.primaryText)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("UP")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(theme.uploadAccent)
                Text(upStr)
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundColor(theme.primaryText)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }

            WidgetSparklinePath(values: snap.downloadHistory)
                .stroke(theme.downloadAccent, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(height: 22)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [theme.backgroundTop, theme.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func mediumView(snap: WidgetSpeedSnapshot, downStr: String, upStr: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(theme.liveDot)
                        .frame(width: 6, height: 6)
                    Text(snap.interfaceName)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(theme.primaryText)
                        .lineLimit(1)
                }
                Spacer()
                Text("Session ↓ \(NetworkSpeedMonitor.formatBytes(snap.sessionDownloadBytes))")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(theme.mutedText)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DOWNLOAD")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(theme.downloadAccent)
                    Text(downStr)
                        .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(theme.primaryText)
                        .lineLimit(1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("UPLOAD")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(theme.uploadAccent)
                    Text(upStr)
                        .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(theme.primaryText)
                        .lineLimit(1)
                }
                Spacer()
            }

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.sparklineBackground)
                WidgetSparklinePath(values: snap.uploadHistory)
                    .stroke(theme.uploadAccent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .padding(4)
                WidgetSparklinePath(values: snap.downloadHistory)
                    .stroke(theme.downloadAccent, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .padding(4)
            }
            .frame(height: 38)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [theme.backgroundTop, theme.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

@main
struct NetSpeedLiteWidget: Widget {
    let kind: String = "NetSpeedLiteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpeedTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                NetSpeedLiteWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            } else {
                NetSpeedLiteWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("NetSpeedLite")
        .description("Monitor live download and upload speeds with sparkline history.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
