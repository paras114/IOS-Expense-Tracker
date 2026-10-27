import SwiftUI

struct HistoryView: View {
    @Environment(Store.self) private var store
    @State private var search = ""
    @State private var filter: String?
    @State private var editing: Expense?

    private var filtered: [Expense] {
        store.expenses.filter { e in
            (filter == nil || e.category.caseInsensitiveCompare(filter ?? "") == .orderedSame) &&
            (search.isEmpty
             || e.remarks.localizedCaseInsensitiveContains(search)
             || e.category.localizedCaseInsensitiveContains(search)
             || e.address.localizedCaseInsensitiveContains(search))
        }
    }

    private var days: [DayGroup] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.date) }
            .map { DayGroup(day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        search.isEmpty && filter == nil ? "No expenses yet" : "No matches",
                        systemImage: "banknote",
                        description: Text(search.isEmpty && filter == nil
                                          ? "Tap + to log your first cash expense."
                                          : "Try a different search or category.")
                    )
                } else {
                    List {
                        ForEach(days) { group in
                            Section {
                                ForEach(group.items) { e in
                                    Button { editing = e } label: { ExpenseRow(expense: e) }
                                        .buttonStyle(.plain)
                                        .swipeActions {
                                            Button(role: .destructive) {
                                                store.delete(e)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            } header: {
                                HStack {
                                    Text(group.day, format: .dateTime.weekday(.wide).day().month(.wide))
                                    Spacer()
                                    Text(store.format(group.total))
                                }
                                .font(.footnote.weight(.semibold))
                                .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
            .searchable(text: $search, prompt: "Search notes, places, categories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Category", selection: $filter) {
                            Text("All categories").tag(String?.none)
                            ForEach(store.allCategoryNames, id: \.self) { name in
                                Text(name).tag(String?.some(name))
                            }
                        }
                    } label: {
                        Image(systemName: filter == nil
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .refreshable { await store.sync() }
            .overlay(alignment: .bottomTrailing) { AddExpenseButton() }
            .sheet(item: $editing) { ExpenseFormView(editing: $0) }
        }
    }
}
