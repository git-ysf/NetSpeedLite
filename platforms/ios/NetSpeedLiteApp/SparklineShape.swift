import SwiftUI

struct SparklineLine: Shape {
    let values: [Double]
    let maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count >= 2, rect.width > 0, rect.height > 0 else { return path }

        let safeMax = max(1024.0, maxValue)
        let stepX = rect.width / CGFloat(values.count - 1)

        for (index, value) in values.enumerated() {
            let x = rect.minX + CGFloat(index) * stepX
            let ratio = min(1.0, max(0.0, value / safeMax))
            let y = rect.maxY - CGFloat(ratio) * rect.height
            let point = CGPoint(x: x, y: y)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

struct SparklineArea: Shape {
    let values: [Double]
    let maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = SparklineLine(values: values, maxValue: maxValue).path(in: rect)
        guard values.count >= 2, rect.width > 0, rect.height > 0 else { return path }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
