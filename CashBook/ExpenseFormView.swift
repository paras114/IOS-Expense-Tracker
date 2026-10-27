import SwiftUI
import UIKit

struct ExpenseFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let editing: Expense?

    @State private var amountText = ""
    @State private var category = ""
    @State private var remarks = ""
    @State private var date = Date()
    @State private var lat: Double?
    @State private var lng: Double?
    @State private var address = ""
    @State private var locState: LocState = .idle
    @State private var confirmDelete = false
    @FocusState private var amountFocused: Bool

    enum LocState { case idle, finding, found, unavailable }

    init(editing: Expense? = nil) {
        self.editing = editing
        if let e = editing {
            _amountText = State(initialValue: e.amount.formatted(.number.grouping(.never).precision(.fractionLength(0...2))))
            _category = State(initialValue: e.category)
            _remarks = State(initialValue: e.remarks)
            _date = State(initialValue: e.date)
            _lat = State(initialValue: e.lat)
            _lng = State(initialValue: e.lng)
            _address = State(initialValue: e.address)
            _locState = State(initialValue: (e.hasLocation || !e.address.isEmpty) ? .found : .idle)
        }
    }

    private var parsedAmount: Double? {
        let cleaned = amountText
            .replacingOccurrences(of: ",", with: ".")
            .filter { "0123456789.".contains($0) }
        return Double(cleaned)
    }

    private var canSave: Bool { (parsedAmount ?? 0) > 0 && !category.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    amountSection
                    categorySection
                    noteSection
                    detailsSection
                    if editing != nil { deleteButton }
                }
                .padding()
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(editing == nil ? "New Expense" : "Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: save) {
                    Text(editing == nil ? "Save Expense" : "Save Changes")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .disabled(!canSave)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .task {
                if editing == nil {
                    amountFocused = true
                    await findLocation()
                }
            }
            .confirmationDialog("Delete this expense?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let e = editing { store.delete(e) }
                    dismiss()
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: Sections

    private var amountSection: some View {
        VStack(spacing: 6) {
            Text("Amount")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(store.currencySymbol)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("0", text: $amountText)
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { amountFocused = true }
        }
        .padding(.top, 8)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Category").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 16) {
                ForEach(store.settings.categories) { cat in
                    let selected = cat.name == category
                    Button {
                        withAnimation(.snappy) { category = cat.name }
                    } label: {
                        VStack(spacing: 6) {
                            CategoryIcon(cat: cat, size: 54, filled: selected)
                                .scaleEffect(selected ? 1.06 : 1)
                            Text(cat.name)
                                .font(.caption.weight(selected ? .semibold : .regular))
                                .foregroundStyle(selected ? Color.primary : Color.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .sensoryFeedback(.selection, trigger: category)
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Note").font(.headline)
            TextField("What was it for? (optional)", text: $remarks, axis: .vertical)
                .lineLimit(1...4)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var detailsSection: some View {
        VStack(spacing: 0) {
            DatePicker(selection: $date) {
                Label("When", systemImage: "clock")
            }
            .padding(14)

            Divider().padding(.leading, 14)

            HStack(spacing: 10) {
                Label {
                    Text(locationText)
                        .lineLimit(2)
                        .foregroundStyle(locState == .found ? Color.primary : Color.secondary)
                } icon: {
                    Image(systemName: locState == .found ? "location.fill" : "location.slash")
                }
                Spacer()
                switch locState {
                case .finding:
                    ProgressView()
                case .idle, .unavailable:
                    Button(locState == .idle ? "Add" : "Retry") {
                        Task { await findLocation() }
                    }
                    .font(.subheadline.weight(.semibold))
                case .found:
                    Button {
                        lat = nil; lng = nil; address = ""; locState = .idle
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .accessibilityLabel("Remove location")
                }
            }
            .padding(14)
        }
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmDelete = true
        } label: {
            Label("Delete Expense", systemImage: "trash")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var locationText: String {
        switch locState {
        case .idle: return "No location"
        case .finding: return "Finding location…"
        case .unavailable: return "Location unavailable"
        case .found: return address.isEmpty ? "Location attached" : address
        }
    }

    // MARK: Actions

    private func findLocation() async {
        locState = .finding
        guard let loc = await LocationService.shared.current() else {
            locState = .unavailable
            return
        }
        lat = loc.coordinate.latitude
        lng = loc.coordinate.longitude
        locState = .found
        address = await LocationService.shared.placeName(for: loc)
    }

    private func save() {
        guard let amount = parsedAmount, amount > 0, !category.isEmpty else { return }
        let expense = Expense(
            id: editing?.id ?? UUID().uuidString,
            date: date,
            amount: amount,
            category: category,
            remarks: remarks.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address,
            lat: lat,
            lng: lng
        )
        if editing == nil { store.add(expense) } else { store.update(expense) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
