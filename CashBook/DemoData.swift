import Foundation

/// Sample data used only when the app is launched with "-demo" (for preview screenshots).
enum DemoData {
    static var isOn: Bool { CommandLine.arguments.contains("-demo") }

    private struct Item {
        let daysAgo: Int, hour: Int, minute: Int
        let amount: Double
        let category: String
        let note: String
        let place: String
    }

    private static let items: [Item] = [
        Item(daysAgo: 1, hour: 19, minute: 42, amount: 180, category: "Food", note: "Chai and samosa with team", place: "Connaught Place, New Delhi"),
        Item(daysAgo: 1, hour: 9, minute: 5, amount: 120, category: "Transport", note: "Auto to office", place: "Karol Bagh, New Delhi"),
        Item(daysAgo: 2, hour: 18, minute: 30, amount: 640, category: "Groceries", note: "Vegetables and fruits", place: "INA Market, New Delhi"),
        Item(daysAgo: 3, hour: 13, minute: 15, amount: 250, category: "Food", note: "Lunch thali", place: "Rajouri Garden, New Delhi"),
        Item(daysAgo: 4, hour: 20, minute: 10, amount: 1200, category: "Shopping", note: "T-shirt", place: "Sarojini Nagar, New Delhi"),
        Item(daysAgo: 5, hour: 8, minute: 50, amount: 60, category: "Transport", note: "", place: "Rajiv Chowk, New Delhi"),
        Item(daysAgo: 6, hour: 11, minute: 0, amount: 450, category: "Health", note: "Pharmacy", place: "Patel Nagar, New Delhi"),
        Item(daysAgo: 8, hour: 21, minute: 15, amount: 700, category: "Fun", note: "Movie tickets", place: "Saket, New Delhi"),
        Item(daysAgo: 9, hour: 17, minute: 40, amount: 90, category: "Food", note: "Momos", place: "Lajpat Nagar, New Delhi"),
        Item(daysAgo: 10, hour: 10, minute: 30, amount: 1500, category: "Bills", note: "Maid salary advance", place: "Karol Bagh, New Delhi"),
        Item(daysAgo: 12, hour: 19, minute: 0, amount: 820, category: "Groceries", note: "Monthly kirana", place: "Karol Bagh, New Delhi"),
        Item(daysAgo: 14, hour: 14, minute: 20, amount: 300, category: "Transport", note: "Cab from airport", place: "Aerocity, New Delhi"),
        Item(daysAgo: 16, hour: 13, minute: 45, amount: 220, category: "Food", note: "Biryani", place: "Jama Masjid, New Delhi"),
        Item(daysAgo: 18, hour: 16, minute: 10, amount: 150, category: "Other", note: "Tailor", place: "Karol Bagh, New Delhi"),
        Item(daysAgo: 21, hour: 12, minute: 0, amount: 380, category: "Food", note: "Pizza", place: "Hauz Khas, New Delhi"),
        Item(daysAgo: 24, hour: 9, minute: 30, amount: 100, category: "Transport", note: "Metro card top-up", place: "Rajiv Chowk, New Delhi"),
        Item(daysAgo: 27, hour: 18, minute: 0, amount: 560, category: "Groceries", note: "Dairy and bread", place: "INA Market, New Delhi"),
        Item(daysAgo: 31, hour: 20, minute: 0, amount: 900, category: "Shopping", note: "Shoes repair", place: "Chandni Chowk, New Delhi"),
        Item(daysAgo: 35, hour: 13, minute: 0, amount: 300, category: "Food", note: "Lunch", place: "Connaught Place, New Delhi"),
        Item(daysAgo: 38, hour: 9, minute: 0, amount: 1800, category: "Bills", note: "Cylinder refill", place: "Karol Bagh, New Delhi"),
        Item(daysAgo: 42, hour: 19, minute: 0, amount: 1100, category: "Groceries", note: "Monthly kirana", place: "Karol Bagh, New Delhi"),
        Item(daysAgo: 47, hour: 11, minute: 0, amount: 650, category: "Transport", note: "Train tickets", place: "New Delhi Railway Station")
    ]

    static func make() -> [Expense] {
        let cal = Calendar.current
        let now = Date()
        return items.compactMap { item in
            guard let day = cal.date(byAdding: .day, value: -item.daysAgo, to: now),
                  let date = cal.date(bySettingHour: item.hour, minute: item.minute, second: 0, of: day)
            else { return nil }
            return Expense(id: UUID().uuidString, date: date, amount: item.amount, category: item.category,
                           remarks: item.note, address: item.place, lat: 28.63, lng: 77.21)
        }
        .sorted { $0.date > $1.date }
    }
}
