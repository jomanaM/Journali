import SwiftUI

enum JournalPalette {
    static let background = Color.black
    static let surface = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    static let action = Color(red: 127 / 255, green: 129 / 255, blue: 1)
    static let accentText = Color(red: 175 / 255, green: 153 / 255, blue: 253 / 255)
    static let primaryText = Color.white
    static let secondaryText = Color(red: 163 / 255, green: 154 / 255, blue: 154 / 255)
    static let destructive = Color(red: 253 / 255, green: 69 / 255, blue: 60 / 255)
    static let outline = Color.white.opacity(0.13)
}

enum JournalType {
    case display, headingLarge, headingMedium, cardTitle
    case bodyLarge, bodyMedium, supporting, captionMedium, captionSmall

    var spec: (size: CGFloat, weight: Font.Weight, relativeTo: Font.TextStyle) {
        switch self {
        case .display: (42, .black, .largeTitle)
        case .headingLarge: (34, .bold, .largeTitle)
        case .headingMedium: (24, .bold, .title2)
        case .cardTitle: (24, .semibold, .title2)
        case .bodyLarge: (20, .regular, .body)
        case .bodyMedium: (18, .regular, .body)
        case .supporting: (18, .light, .body)
        case .captionMedium: (16, .regular, .subheadline)
        case .captionSmall: (14, .regular, .caption)
        }
    }
}

private struct JournalFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(_ style: JournalType) {
        let spec = style.spec
        _size = ScaledMetric(wrappedValue: spec.size, relativeTo: spec.relativeTo)
        weight = spec.weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

extension View {
    func journalFont(_ style: JournalType) -> some View {
        modifier(JournalFont(style))
    }
}

extension Date {
    var journalDate: String {
        formatted(.verbatim("\(day: .twoDigits)/\(month: .twoDigits)/\(year: .defaultDigits)", locale: Locale(identifier: "en_GB"), timeZone: .current, calendar: Calendar(identifier: .gregorian)))
    }
}
