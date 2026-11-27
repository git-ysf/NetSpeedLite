import AppKit

enum AppTheme: String, CaseIterable {
    case midnight = "Midnight"
    case emerald = "Emerald"
    case amber = "Amber"
    case rose = "Rose"
    case frost = "Frost"

    var isLight: Bool {
        self == .frost
    }

    var cardTop: NSColor {
        switch self {
        case .frost:
            return NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        default:
            return NSColor(srgbRed: 22/255, green: 27/255, blue: 38/255, alpha: 1.0)
        }
    }

    var cardBottom: NSColor {
        switch self {
        case .frost:
            return NSColor(srgbRed: 241/255, green: 245/255, blue: 249/255, alpha: 1.0)
        default:
            return NSColor(srgbRed: 14/255, green: 18/255, blue: 28/255, alpha: 1.0)
        }
    }

    var cardBorder: NSColor {
        switch self {
        case .frost:
            return NSColor(srgbRed: 203/255, green: 213/255, blue: 225/255, alpha: 1.0)
        default:
            return NSColor(srgbRed: 42/255, green: 50/255, blue: 68/255, alpha: 1.0)
        }
    }

    var primaryText: NSColor {
        switch self {
        case .frost:
            return NSColor(srgbRed: 15/255, green: 23/255, blue: 42/255, alpha: 1.0)
        default:
            return NSColor(srgbRed: 248/255, green: 250/255, blue: 252/255, alpha: 1.0)
        }
    }

    var mutedText: NSColor {
        switch self {
        case .frost:
            return NSColor(srgbRed: 71/255, green: 85/255, blue: 105/255, alpha: 1.0)
        default:
            return NSColor(srgbRed: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)
        }
    }

    var divider: NSColor {
        switch self {
        case .frost:
            return NSColor(srgbRed: 15/255, green: 23/255, blue: 42/255, alpha: 0.09)
        default:
            return NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.10)
        }
    }

    var sparklineBackground: NSColor {
        switch self {
        case .frost:
            return NSColor(srgbRed: 232/255, green: 238/255, blue: 246/255, alpha: 1.0)
        default:
            return NSColor(srgbRed: 10/255, green: 13/255, blue: 20/255, alpha: 1.0)
        }
    }

    var downloadAccent: NSColor {
        switch self {
        case .midnight:
            return NSColor(srgbRed: 56/255, green: 189/255, blue: 248/255, alpha: 1.0)
        case .emerald:
            return NSColor(srgbRed: 52/255, green: 211/255, blue: 153/255, alpha: 1.0)
        case .amber:
            return NSColor(srgbRed: 251/255, green: 191/255, blue: 36/255, alpha: 1.0)
        case .rose:
            return NSColor(srgbRed: 251/255, green: 113/255, blue: 133/255, alpha: 1.0)
        case .frost:
            return NSColor(srgbRed: 2/255, green: 132/255, blue: 199/255, alpha: 1.0)
        }
    }

    var uploadAccent: NSColor {
        switch self {
        case .midnight:
            return NSColor(srgbRed: 167/255, green: 139/255, blue: 250/255, alpha: 1.0)
        case .emerald:
            return NSColor(srgbRed: 56/255, green: 189/255, blue: 248/255, alpha: 1.0)
        case .amber:
            return NSColor(srgbRed: 249/255, green: 115/255, blue: 22/255, alpha: 1.0)
        case .rose:
            return NSColor(srgbRed: 192/255, green: 132/255, blue: 252/255, alpha: 1.0)
        case .frost:
            return NSColor(srgbRed: 124/255, green: 58/255, blue: 237/255, alpha: 1.0)
        }
    }

    var liveDot: NSColor {
        NSColor(srgbRed: 52/255, green: 211/255, blue: 153/255, alpha: 1.0)
    }
}
