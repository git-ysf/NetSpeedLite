import AppKit

final class SparklineView: NSView {
    private var downloadHistory: [Double] = []
    private var uploadHistory: [Double] = []
    private var theme: AppTheme = .midnight

    override var isFlipped: Bool { false }

    func update(downloadHistory: [Double], uploadHistory: [Double], theme: AppTheme) {
        self.downloadHistory = downloadHistory
        self.uploadHistory = uploadHistory
        self.theme = theme
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard bounds.width > 8, bounds.height > 8 else { return }

        let boxPath = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        theme.sparklineBackground.setFill()
        boxPath.fill()

        theme.divider.setStroke()
        boxPath.lineWidth = 1
        boxPath.stroke()

        guard downloadHistory.count >= 2, uploadHistory.count == downloadHistory.count else { return }

        let insetRect = bounds.insetBy(dx: 6, dy: 6)
        let maxVal = max(1024.0, (downloadHistory + uploadHistory).max() ?? 1024.0)

        drawSeries(uploadHistory, maxVal: maxVal, in: insetRect, color: theme.uploadAccent, fillAlpha: 0.14)
        drawSeries(downloadHistory, maxVal: maxVal, in: insetRect, color: theme.downloadAccent, fillAlpha: 0.22)
    }

    private func drawSeries(_ values: [Double], maxVal: Double, in rect: NSRect, color: NSColor, fillAlpha: CGFloat) {
        let count = values.count
        guard count >= 2 else { return }

        let linePath = NSBezierPath()
        let fillPath = NSBezierPath()
        let stepX = rect.width / CGFloat(count - 1)

        for i in 0..<count {
            let x = rect.minX + CGFloat(i) * stepX
            let normalized = min(1.0, max(0.0, values[i] / maxVal))
            let y = rect.minY + CGFloat(normalized) * rect.height
            let pt = NSPoint(x: x, y: y)

            if i == 0 {
                linePath.move(to: pt)
                fillPath.move(to: NSPoint(x: x, y: rect.minY))
                fillPath.line(to: pt)
            } else {
                linePath.line(to: pt)
                fillPath.line(to: pt)
            }
        }

        fillPath.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        fillPath.close()

        let gradient = NSGradient(
            starting: color.withAlphaComponent(fillAlpha),
            ending: color.withAlphaComponent(0.01)
        )
        gradient?.draw(in: fillPath, angle: -90)

        color.setStroke()
        linePath.lineWidth = 1.6
        linePath.lineJoinStyle = .round
        linePath.lineCapStyle = .round
        linePath.stroke()
    }
}
