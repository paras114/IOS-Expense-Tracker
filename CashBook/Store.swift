import Foundation
import Observation

/// Holds all expenses. Saves instantly on the phone, then syncs with the Google Sheet.
@MainActor
@Observable
final class Store {
    var expenses: [Expense] = []
    var pending: [PendingOp] = []
    var settings = AppSettings()
    var lastSynced: Date?
    var syncError: String?
    var isSyncing = false

    @ObservationIgnored private var syncAgain = false

    private struct Saved: Codable {
        var expenses: [Expense]
        var pending: [PendingOp]
        var lastSynced: Date?
    }

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("expenses.json")
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "settings"),
           let s = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = s
        }
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            expenses = saved.expenses
            pending = saved.pending
            lastSynced = saved.lastSynced
        }
    }

    // MARK: Saving on the phone

    func persist() {
        let saved = Saved(expenses: expenses, pending: pending, lastSynced: lastSynced)
        if let data = try? JSONEncoder().encode(saved) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "settings")
        }
    }

    // MARK: Changes

    func add(_ e: Expense) {
        expenses.append(e)
        sortExpenses()
        pending.append(.add(e))
        persist()
        Task { await sync() }
    }

    func update(_ e: Expense) {
        if let i = expenses.firstIndex(where: { $0.id == e.id }) { expenses[i] = e }
        sortExpenses()
        pending.append(.update(e))
        persist()
        Task { await sync() }
    }

    func delete(_ e: Expense) {
        expenses.removeAll { $0.id == e.id }
        pending.append(.delete(e.id))
        persist()
        Task { await sync() }
    }

    private func sortExpenses() {
        expenses.sort { $0.date > $1.date }
    }

    // MARK: Sync

    var isConfigured: Bool { api != nil }

    private var api: API? {
        let s = settings.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = settings.secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("https://"), !key.isEmpty, let url = URL(string: s) else { return nil }
        return API(endpoint: url, secret: key)
    }

    func sync() async {
        guard let api else { return }
        if isSyncing { syncAgain = true; return }
        isSyncing = true
        defer { isSyncing = false }

        repeat {
            syncAgain = false
            var skipped: String?
            do {
                while let op = pending.first {
                    do {
                        try await api.send(op)
                    } catch API.APIError.rejected(let message) {
                        skipped = "One entry was skipped: \(message)"
                    }
                    if !pending.isEmpty { pending.removeFirst() }
                    persist()
                }
                let remote = try await api.fetchAll()
                expenses = applyPending(to: remote)
                sortExpenses()
                lastSynced = Date()
                syncError = skipped
                persist()
            } catch {
                syncError = error.localizedDescription
                break
            }
        } while syncAgain
    }

    /// Re-applies changes that haven't reached the sheet yet on top of the sheet's data.
    private func applyPending(to remote: [Expense]) -> [Expense] {
        var list = remote
        for op in pending {
            switch op {
            case .add(let e), .update(let e):
                if let i = list.firstIndex(where: { $0.id == e.id }) { list[i] = e } else { list.append(e) }
            case .delete(let id):
                list.removeAll { $0.id == id }
            }
        }
        return list
    }

    // MARK: Helpers for the screens

    func category(named name: String) -> CategoryDef {
        settings.categories.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            ?? CategoryDef.fallback(named: name)
    }

    func expenses(inMonthOf month: Date) -> [Expense] {
        let cal = Calendar.current
        return expenses.filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    func format(_ amount: Double) -> String {
        amount.formatted(.currency(code: settings.currency).precision(.fractionLength(0...2)))
    }

    var currencySymbol: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = settings.currency
        return f.currencySymbol ?? settings.currency
    }

    /// Category names from settings plus any others that appear in the data.
    var allCategoryNames: [String] {
        var names = settings.categories.map(\.name)
        for e in expenses where !names.contains(where: { $0.caseInsensitiveCompare(e.category) == .orderedSame }) {
            names.append(e.category)
        }
        return names
    }
}
