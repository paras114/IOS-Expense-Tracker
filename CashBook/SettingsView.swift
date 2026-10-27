import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var newCategory = ""
    @State private var showAddCategory = false

    private var currencyCodes: [String] {
        var codes = Locale.commonISOCurrencyCodes
        if !codes.contains(store.settings.currency) { codes.insert(store.settings.currency, at: 0) }
        return codes
    }

    private var statusText: String {
        if !store.isConfigured {
            return "Paste the Web app URL from Apps Script (ends in /exec) and the SECRET from Code.gs."
        }
        if let err = store.syncError { return "⚠️ \(err)" }
        if let d = store.lastSynced {
            return "Last synced \(d.formatted(.relative(presentation: .named)))."
        }
        return "Not synced yet."
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    TextField("https://script.google.com/macros/s/…/exec",
                              text: $store.settings.serverURL, axis: .vertical)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.footnote.monospaced())
                    SecureField("Secret key", text: $store.settings.secret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task { await store.sync() }
                    } label: {
                        HStack {
                            Text("Sync now")
                            Spacer()
                            if store.isSyncing { ProgressView() }
                        }
                    }
                    .disabled(!store.isConfigured || store.isSyncing)
                } header: {
                    Text("Google Sheet")
                } footer: {
                    Text(statusText)
                }

                Section("Currency") {
                    Picker("Currency", selection: $store.settings.currency) {
                        ForEach(currencyCodes, id: \.self) { code in
                            Text("\(code) – \(Locale.current.localizedString(forCurrencyCode: code) ?? code)")
                                .tag(code)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    ForEach($store.settings.categories) { $cat in
                        NavigationLink {
                            CategoryEditView(category: $cat)
                        } label: {
                            HStack(spacing: 12) {
                                CategoryIcon(cat: cat, size: 32)
                                Text(cat.name)
                            }
                        }
                    }
                    .onDelete { store.settings.categories.remove(atOffsets: $0) }
                    .onMove { store.settings.categories.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        newCategory = ""
                        showAddCategory = true
                    } label: {
                        Label("Add Category", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Categories")
                } footer: {
                    Text("Tap to change icon and colour. Swipe to delete, or tap Edit to reorder. Past expenses keep their category name.")
                }

                Section("On this iPhone") {
                    LabeledContent("Expenses", value: "\(store.expenses.count)")
                    LabeledContent("Waiting to sync", value: "\(store.pending.count)")
                }
            }
            .navigationTitle("Settings")
            .toolbar { EditButton() }
            .alert("New Category", isPresented: $showAddCategory) {
                TextField("Name", text: $newCategory)
                Button("Add") { addCategory() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func addCategory() {
        let name = newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              !store.settings.categories.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
        else { return }
        let color = CategoryDef.palette[store.settings.categories.count % CategoryDef.palette.count]
        store.settings.categories.append(CategoryDef(name: name, symbol: "tag.fill", colorHex: color))
    }
}

struct CategoryEditView: View {
    @Binding var category: CategoryDef

    private static let symbols = [
        "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill", "cart.fill", "basket.fill",
        "car.fill", "fuelpump.fill", "bus.fill", "tram.fill", "bicycle", "airplane", "bag.fill",
        "tshirt.fill", "house.fill", "bolt.fill", "drop.fill", "wifi", "phone.fill",
        "doc.text.fill", "cross.case.fill", "pills.fill", "heart.fill", "gift.fill", "gamecontroller.fill",
        "film.fill", "ticket.fill", "book.fill", "graduationcap.fill", "pawprint.fill", "dumbbell.fill",
        "scissors", "wrench.and.screwdriver.fill", "banknote.fill", "creditcard.fill", "person.2.fill", "leaf.fill",
        "tag.fill", "star.fill", "hands.sparkles.fill", "building.columns.fill", "sparkles", "ellipsis.circle.fill"
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    CategoryIcon(cat: category, size: 76, filled: true)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Name") {
                TextField("Name", text: $category.name)
            }

            Section("Colour") {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(CategoryDef.palette, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 36, height: 36)
                            .overlay {
                                if hex == category.colorHex {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .onTapGesture { category.colorHex = hex }
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Icon") {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Self.symbols, id: \.self) { s in
                        let selected = s == category.symbol
                        Image(systemName: s)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .foregroundStyle(selected ? category.color : Color.primary)
                            .background(selected ? category.color.opacity(0.18) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .onTapGesture { category.symbol = s }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle(category.name.isEmpty ? "Category" : category.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
