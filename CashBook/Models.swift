import SwiftUI
import UIKit

struct Expense: Codable, Identifiable, Hashable {
    var id: String
    var date: Date
    var amount: Double
    var category: String
    var remarks: String
    var address: String
    var lat: Double?
    var lng: Double?

    var hasLocation: Bool { lat != nil && lng != nil }

    var mapsURL: URL? {
        guard let lat, let lng else { return nil }
        return URL(string: "https://maps.apple.com/?ll=\(lat),\(lng)&q=Expense")
    }
}

/// A change made on the phone that still has to reach the Google Sheet.
enum PendingOp: Codable, Hashable {
    case add(Expense)
    case update(Expense)
    case delete(String)
}

struct CategoryDef: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var symbol: String
    var colorHex: String

    var color: Color { Color(hex: colorHex) }

    static let palette: [String] = [
        "#FF9500", "#34C759", "#0A84FF", "#FF2D55", "#AF52DE", "#FF3B30",
        "#5AC8FA", "#FFCC00", "#A2845E", "#5856D6", "#30B0C7", "#8E8E93"
    ]

    static let defaults: [CategoryDef] = [
        CategoryDef(name: "Food", symbol: "fork.knife", colorHex: "#FF9500"),
        CategoryDef(name: "Groceries", symbol: "cart.fill", colorHex: "#34C759"),
        CategoryDef(name: "Transport", symbol: "car.fill", colorHex: "#0A84FF"),
        CategoryDef(name: "Shopping", symbol: "bag.fill", colorHex: "#FF2D55"),
        CategoryDef(name: "Bills", symbol: "doc.text.fill", colorHex: "#AF52DE"),
        CategoryDef(name: "Health", symbol: "cross.case.fill", colorHex: "#FF3B30"),
        CategoryDef(name: "Fun", symbol: "film.fill", colorHex: "#5856D6"),
        CategoryDef(name: "Other", symbol: "ellipsis.circle.fill", colorHex: "#8E8E93")
    ]

    /// Stable colour for category names that aren't in the list (e.g. typed in the Shortcut).
    static func fallback(named name: String) -> CategoryDef {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return CategoryDef(id: "fallback-\(name)", name: name, symbol: "tag.fill",
                           colorHex: palette[sum % palette.count])
    }
}

struct AppSettings: Codable, Equatable {
    var serverURL: String = ""
    var secret: String = ""
    var currency: String = Locale.current.currency?.identifier ?? "USD"
    var categories: [CategoryDef] = CategoryDef.defaults
}

struct CategoryTotal: Identifiable {
    let name: String
    let total: Double
    var id: String { name }
}

struct DayGroup: Identifiable {
    let day: Date
    let items: [Expense]
    var id: Date { day }
    var total: Double { items.reduce(0) { $0 + $1.amount } }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}
