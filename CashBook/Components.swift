import SwiftUI

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

struct CategoryIcon: View {
    let cat: CategoryDef
    var size: CGFloat = 40
    var filled = false

    var body: some View {
        Image(systemName: cat.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(filled ? Color.white : cat.color)
            .frame(width: size, height: size)
            .background(filled ? cat.color : cat.color.opacity(0.16), in: Circle())
    }
}

struct AddExpenseButton: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            router.showAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(Color.accentColor.gradient, in: Circle())
                .shadow(color: .black.opacity(0.22), radius: 10, y: 5)
        }
        .accessibilityLabel("Add expense")
        .padding(20)
    }
}

struct SyncStatusButton: View {
    @Environment(Store.self) private var store

    var body: some View {
        Button {
            Task { await store.sync() }
        } label: {
            if store.isSyncing {
                ProgressView()
            } else if store.syncError != nil {
                Image(systemName: "exclamationmark.icloud.fill").foregroundStyle(.orange)
            } else if !store.pending.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "icloud.and.arrow.up")
                    Text("\(store.pending.count)").font(.caption.weight(.semibold))
                }
            } else {
                Image(systemName: store.isConfigured ? "checkmark.icloud" : "icloud.slash")
            }
        }
        .disabled(!store.isConfigured || store.isSyncing)
    }
}

struct ExpenseRow: View {
    @Environment(Store.self) private var store
    let expense: Expense
    var showDate = false

    var body: some View {
        let cat = store.category(named: expense.category)
        HStack(spacing: 12) {
            CategoryIcon(cat: cat, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.remarks.isEmpty ? expense.category : expense.remarks)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(store.format(expense.amount))
                .font(.body.weight(.semibold).monospacedDigit())
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts: [String] = []
        if !expense.remarks.isEmpty { parts.append(expense.category) }
        parts.append(showDate
            ? expense.date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
            : expense.date.formatted(date: .omitted, time: .shortened))
        if let place = expense.address.split(separator: ",").first {
            parts.append(String(place))
        }
        return parts.joined(separator: " · ")
    }
}
