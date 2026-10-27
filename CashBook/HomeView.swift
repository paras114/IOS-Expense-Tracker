import SwiftUI
import Charts

struct HomeView: View {
    @Environment(Store.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var month = Calendar.current.startOfMonth(for: .now)
    @State private var editing: Expense?

    private var cal: Calendar { Calendar.current }
    private var monthExpenses: [Expense] { store.expenses(inMonthOf: month) }
    private var total: Double { monthExpenses.reduce(0) { $0 + $1.amount } }

    private var previousTotal: Double {
        guard let prev = cal.date(byAdding: .month, value: -1, to: month) else { return 0 }
        return store.expenses(inMonthOf: prev).reduce(0) { $0 + $1.amount }
    }

    private var isCurrentMonth: Bool { cal.isDate(month, equalTo: .now, toGranularity: .month) }

    private var daysCounted: Int {
        if isCurrentMonth { return cal.component(.day, from: .now) }
        return cal.range(of: .day, in: .month, for: month)?.count ?? 30
    }

    private var categoryTotals: [CategoryTotal] {
        Dictionary(grouping: monthExpenses, by: \.category)
            .map { CategoryTotal(name: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    private var dayTotals: [DayGroup] {
        Dictionary(grouping: monthExpenses) { cal.startOfDay(for: $0.date) }
            .map { DayGroup(day: $0.key, items: $0.value) }
            .sorted { $0.day < $1.day }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !store.isConfigured { connectBanner }
                    monthPicker
                    summaryCard
                    if !categoryTotals.isEmpty {
                        categoryCard
                        dailyCard
                    }
                    recentCard
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Cash Book")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SyncStatusButton() }
            }
            .refreshable { await store.sync() }
            .overlay(alignment: .bottomTrailing) { AddExpenseButton() }
            .sheet(item: $editing) { ExpenseFormView(editing: $0) }
        }
    }

    // MARK: Sections

    private var connectBanner: some View {
        Button {
            router.tab = .settings
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "tablecells.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect your Google Sheet").font(.subheadline.weight(.semibold))
                    Text("Expenses stay on this iPhone until you add your web app URL in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var monthPicker: some View {
        HStack {
            monthButton("chevron.left") { shift(-1) }
            Spacer()
            Text(month, format: .dateTime.month(.wide).year())
                .font(.headline)
            Spacer()
            monthButton("chevron.right") { shift(1) }
                .disabled(isCurrentMonth)
                .opacity(isCurrentMonth ? 0.3 : 1)
        }
        .padding(.top, 4)
    }

    private func monthButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 38, height: 38)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
        }
    }

    private func shift(_ by: Int) {
        if let m = cal.date(byAdding: .month, value: by, to: month) {
            withAnimation(.snappy) { month = m }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isCurrentMonth ? "Spent this month" : "Spent in \(month.formatted(.dateTime.month(.wide)))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(store.format(total))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
            Text("\(monthExpenses.count) expense\(monthExpenses.count == 1 ? "" : "s") · \(store.format(monthExpenses.isEmpty ? 0 : total / Double(max(daysCounted, 1)))) per day")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if previousTotal > 0 {
                changeChip.padding(.top, 4)
            }
        }
        .card()
    }

    private var changeChip: some View {
        let pct = (total - previousTotal) / previousTotal * 100
        let up = pct > 0
        let tint: Color = up ? .red : .green
        return Label("\(Int(abs(pct).rounded()))% vs last month",
                     systemImage: up ? "arrow.up.right" : "arrow.down.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("By category").font(.headline)
            HStack {
                Spacer()
                ZStack {
                    Chart(categoryTotals) { item in
                        SectorMark(angle: .value("Amount", item.total),
                                   innerRadius: .ratio(0.62),
                                   angularInset: 1.5)
                            .cornerRadius(5)
                            .foregroundStyle(store.category(named: item.name).color)
                    }
                    VStack(spacing: 0) {
                        Text("\(categoryTotals.count)")
                            .font(.title2.weight(.bold))
                        Text(categoryTotals.count == 1 ? "category" : "categories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 170, height: 170)
                Spacer()
            }
            VStack(spacing: 12) {
                ForEach(categoryTotals) { item in
                    categoryRow(item)
                }
            }
        }
        .card()
    }

    private func categoryRow(_ item: CategoryTotal) -> some View {
        let cat = store.category(named: item.name)
        let share = total > 0 ? item.total / total : 0
        let maxShare = (categoryTotals.first?.total ?? 1) / max(total, 1)
        return HStack(spacing: 12) {
            CategoryIcon(cat: cat, size: 34)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.name).font(.subheadline.weight(.medium))
                    Spacer()
                    Text(store.format(item.total)).font(.subheadline.weight(.semibold).monospacedDigit())
                    Text("\(Int((share * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.tertiarySystemFill))
                        Capsule().fill(cat.color)
                            .frame(width: geo.size.width * (maxShare > 0 ? share / maxShare : 0))
                    }
                }
                .frame(height: 6)
            }
        }
    }

    private var dailyCard: some View {
        let start = month
        let end = cal.date(byAdding: .month, value: 1, to: month) ?? month
        return VStack(alignment: .leading, spacing: 12) {
            Text("Daily spending").font(.headline)
            Chart(dayTotals) { d in
                BarMark(x: .value("Day", d.day, unit: .day),
                        y: .value("Spent", d.total))
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(3)
            }
            .chartXScale(domain: start...end)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v, format: .number.notation(.compactName))
                        }
                    }
                }
            }
            .frame(height: 170)
        }
        .card()
    }

    private var recentCard: some View {
        let recent = Array(monthExpenses.prefix(6))
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Recent").font(.headline)
                Spacer()
                if !monthExpenses.isEmpty {
                    Button("See all") { router.tab = .history }
                        .font(.subheadline)
                }
            }
            .padding(.bottom, 4)
            if recent.isEmpty {
                Text("Nothing logged \(isCurrentMonth ? "this month yet" : "in this month"). Tap + to add an expense.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(recent) { e in
                    Button { editing = e } label: { ExpenseRow(expense: e, showDate: true) }
                        .buttonStyle(.plain)
                    if e.id != recent.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
        }
        .card()
    }
}
