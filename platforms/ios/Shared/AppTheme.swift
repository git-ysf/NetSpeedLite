import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case midnight = "Midnight"
    case emerald = "Emerald"
    case amber = "Amber"
    case rose = "Rose"
    case frost = "Frost"

    var id: String { rawValue }

    var isLight: Bool {
        self == .frost
    }

    var colorScheme: ColorScheme {
        isLight ? .light : .dark
    }

    var backgroundTop: Color {
        switch self {
        case .frost:
            return Color(red: 248/255, green: 250/255, blue: 252/255)
        default:
            return Color(red: 15/255, green: 19/255, blue: 29/255)
        }
    }

    var backgroundBottom: Color {
        switch self {
        case .frost:
            return Color(red: 226/255, green: 232/255, blue: 240/255)
        default:
            return Color(red: 9/255, green: 12/255, blue: 20/255)
        }
    }

    var cardBackground: Color {
        switch self {
        case .frost:
            return Color.white.opacity(0.92)
        default:
            return Color(red: 22/255, green: 27/255, blue: 38/255)
        }
    }

    var cardBorder: Color {
        switch self {
        case .frost:
            return Color(red: 203/255, green: 213/255, blue: 225/255)
        default:
            return Color(red: 42/255, green: 50/255, blue: 68/255)
        }
    }

    var sparklineBackground: Color {
        switch self {
        case .frost:
            return Color(red: 238/255, green: 242/255, blue: 248/255)
        default:
            return Color(red: 10/255, green: 13/255, blue: 20/255)
        }
    }

    var primaryText: Color {
        switch self {
        case .frost:
            return Color(red: 15/255, green: 23/255, blue: 42/255)
        default:
            return Color(red: 248/255, green: 250/255, blue: 252/255)
        }
    }

    var mutedText: Color {
        switch self {
        case .frost:
            return Color(red: 71/255, green: 85/255, blue: 105/255)
        default:
            return Color(red: 148/255, green: 163/255, blue: 184/255)
        }
    }

    var downloadAccent: Color {
        switch self {
        case .midnight:
            return Color(red: 56/255, green: 189/255, blue: 248/255)
        case .emerald:
            return Color(red: 52/255, green: 211/255, blue: 153/255)
        case .amber:
            return Color(red: 251/255, green: 191/255, blue: 36/255)
        case .rose:
            return Color(red: 251/255, green: 113/255, blue: 133/255)
        case .frost:
            return Color(red: 2/255, green: 132/255, blue: 199/255)
        }
    }

    var uploadAccent: Color {
        switch self {
        case .midnight:
            return Color(red: 167/255, green: 139/255, blue: 250/255)
        case .emerald:
            return Color(red: 56/255, green: 189/255, blue: 248/255)
        case .amber:
            return Color(red: 249/255, green: 115/255, blue: 22/255)
        case .rose:
            return Color(red: 192/255, green: 132/255, blue: 252/255)
        case .frost:
            return Color(red: 124/255, green: 58/255, blue: 237/255)
        }
    }

    var liveDot: Color {
        Color(red: 52/255, green: 211/255, blue: 153/255)
    }
}
