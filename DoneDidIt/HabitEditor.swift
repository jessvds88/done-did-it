import SwiftUI

struct HabitEditor: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let original: Habit?
    @State private var draft: Habit
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    init(original: Habit?) {
        self.original = original
        _draft = State(initialValue: original ?? Habit(name: ""))
    }

    private var isNew: Bool { original == nil }

    var body: some View {
        NavigationStack {
            Form {
                if isNew && !store.startersLeft.isEmpty {
                    Section("From your list") {
                        StarterChips(onPick: { dismiss() })
                            .padding(.vertical, 4)
                    }
                }

                Section("What is it?") {
                    TextField("e.g. Unload the dishwasher", text: $draft.name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                }

                Section("How often") {
                    Picker("How often", selection: $draft.freq) {
                        ForEach(Frequency.allCases) { f in Text(f.label).tag(f) }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                    frequencyDetail
                }

                Section("Priority") {
                    Picker("Priority", selection: $draft.priority) {
                        ForEach(Priority.allCases) { p in Text(p.label).tag(p) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Symbol") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                        ForEach(Starters.symbols, id: \.self) { sym in
                            let usedBy = store.habits.first { $0.symbol == sym && $0.id != draft.id }
                            Button {
                                draft.symbol = sym
                            } label: {
                                Text(sym).font(.title3)
                                    .frame(maxWidth: .infinity, minHeight: 38)
                                    .background(draft.symbol == sym ? Palette.accent.opacity(0.18) : Palette.sunk,
                                                in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(draft.symbol == sym ? Palette.accent : .clear, lineWidth: 2))
                                    .opacity(usedBy != nil && draft.symbol != sym ? 0.4 : 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(usedBy.map { "\(sym), also used by \($0.name)" } ?? sym)
                        }
                    }
                    .padding(.vertical, 4)
                    Text("Faded symbols are already used by another habit.").font(.footnote).foregroundStyle(Palette.muted)
                }

                Section("Color") {
                    HStack(spacing: 12) {
                        ForEach(Palette.habitColors.indices, id: \.self) { i in
                            Button {
                                draft.colorIndex = i
                            } label: {
                                Circle().fill(Palette.habitColors[i])
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().stroke(Color.primary, lineWidth: draft.colorIndex == i ? 3 : 0).padding(-4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if !isNew {
                    Section {
                        Button("Delete habit", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(isNew ? "New habit or chore" : "Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save") { save() }
                        .fontWeight(.bold)
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete \(draft.name) and all its check-ins?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let o = original { store.delete(o.id) }
                    dismiss()
                }
            } message: {
                Text("This can't be undone.")
            }
            .onAppear {
                if isNew {
                    draft.symbol = store.nextSymbol
                    draft.colorIndex = store.nextColor
                }
            }
        }
    }

    @ViewBuilder
    private var frequencyDetail: some View {
        switch draft.freq {
        case .daily:
            Stepper("\(draft.target) time\(draft.target > 1 ? "s" : "") a day", value: $draft.target, in: 1...31)
        case .weekly:
            VStack(alignment: .leading, spacing: 10) {
                Text("On set days? (optional)").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.muted)
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        let on = draft.days.contains(i)
                        Button {
                            if on { draft.days.removeAll { $0 == i } } else { draft.days.append(i); draft.days.sort() }
                        } label: {
                            Text(Day.letters[i]).font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .foregroundStyle(on ? Palette.onAccent : Color.primary)
                                .background(on ? Palette.accent : Palette.sunk, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Day.longNames[i])
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            .padding(.vertical, 4)
            if draft.days.isEmpty {
                Stepper("\(draft.target) time\(draft.target > 1 ? "s" : "") a week, any days", value: $draft.target, in: 1...7)
            } else {
                Text("Due on \(draft.describe).").foregroundStyle(Palette.muted)
            }
        case .monthly:
            Picker("On a set date?", selection: $draft.date) {
                Text("Any day").tag(0)
                ForEach(1...31, id: \.self) { d in Text("The \(Day.ordinal(d))").tag(d) }
            }
            if draft.date == 0 {
                Stepper("\(draft.target) time\(draft.target > 1 ? "s" : "") a month", value: $draft.target, in: 1...31)
            } else {
                Text("In shorter months it moves to the last day.").font(.footnote).foregroundStyle(Palette.muted)
            }
        case .every:
            Stepper("Every \(draft.every) \(draft.unit == .weeks ? "week" : "day")\(draft.every > 1 ? "s" : "")", value: $draft.every, in: 1...60)
            Picker("Unit", selection: $draft.unit) {
                Text("Days").tag(IntervalUnit.days)
                Text("Weeks").tag(IntervalUnit.weeks)
            }
            .pickerStyle(.segmented)
            Text("Comes due again that long after the last time you did it.").font(.footnote).foregroundStyle(Palette.muted)
        }
    }

    private func save() {
        var h = draft
        h.name = h.name.trimmingCharacters(in: .whitespaces)
        if h.freq != .weekly { h.days = [] }
        if h.freq != .monthly { h.date = 0 }
        if isNew { store.add(h) } else { store.update(h) }
        dismiss()
    }
}
