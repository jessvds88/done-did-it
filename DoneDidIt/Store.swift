import Foundation
import Observation

/// Keeps habits in a JSON file in the app's Documents folder.
@Observable
final class HabitStore {
    private(set) var habits: [Habit] = []
    /// "Now", refreshed whenever the app comes to the front, so the day rolls over.
    var now: Date = Date()
    /// Most recent change that can be undone from the toast.
    var undo: UndoAction? = nil
    /// Bumps when everything due today gets finished, to trigger confetti.
    var celebrate: Int = 0

    struct UndoAction: Identifiable {
        let id = UUID()
        let message: String
        let canUndo: Bool
        let revert: () -> Void
    }

    private let url: URL = URL.documentsDirectory.appending(path: "habits.json")

    init() { load() }

    // MARK: persistence

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        habits = (try? dec.decode([Habit].self, from: data)) ?? []
    }

    private func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(habits) {
            try? data.write(to: url, options: [.atomic])
        }
    }

    // MARK: queries

    var sorted: [Habit] { habits.sorted { $0.created < $1.created } }

    func habit(_ id: UUID) -> Habit? { habits.first { $0.id == id } }

    func has(name: String) -> Bool {
        let n = name.trimmingCharacters(in: .whitespaces).lowercased()
        return habits.contains { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == n }
    }

    var startersLeft: [Habit] { Starters.list.filter { !has(name: $0.name) } }

    var nextSymbol: String { Starters.symbols.first { s in !habits.contains { $0.symbol == s } } ?? "⭐" }

    var nextColor: Int { habits.count % Palette.habitColors.count }

    // MARK: edits

    func add(_ h: Habit) {
        var h = h
        h.id = UUID()
        h.created = Date()
        h.done = [:]
        habits.append(h)
        save()
    }

    func addStarters(_ list: [Habit]) {
        for s in list where !has(name: s.name) {
            var h = s
            h.colorIndex = nextColor
            add(h)
        }
        undo = UndoAction(message: list.count == 1 ? "Added \(list[0].name)" : "Added \(list.count) habits", canUndo: false, revert: {})
    }

    func update(_ h: Habit) {
        guard let i = habits.firstIndex(where: { $0.id == h.id }) else { return }
        var h = h
        h.done = habits[i].done
        h.created = habits[i].created
        habits[i] = h
        save()
    }

    func delete(_ id: UUID) {
        habits.removeAll { $0.id == id }
        save()
    }

    private func setCount(_ id: UUID, key: String, _ value: Int) {
        guard let i = habits.firstIndex(where: { $0.id == id }) else { return }
        if value <= 0 { habits[i].done.removeValue(forKey: key) } else { habits[i].done[key] = value }
        save()
    }

    /// The big check button: adds a check-in for today, or takes the latest one back if already done.
    func tap(_ id: UUID) {
        now = Date()
        guard let h = habit(id) else { return }
        let k = Day.key(now)
        let st = h.status(now: now)
        if st.met {
            var last: String? = (h.done[k] ?? 0) > 0 ? k : nil
            if last == nil {
                let pk = Day.periodKey(now, h.periodKind)
                last = h.doneKeys.filter { Day.periodKey(Day.parse($0), h.periodKind) == pk }.last
            }
            guard let lk = last else { return }
            setCount(id, key: lk, (h.done[lk] ?? 0) - 1)
            undo = UndoAction(message: "Unchecked \(h.name)", canUndo: false, revert: {})
            return
        }
        let before = h.done[k] ?? 0
        setCount(id, key: k, before + 1)
        guard let after = habit(id)?.status(now: now) else { return }
        undo = UndoAction(message: after.met ? "\(h.name) done" : "\(h.name): \(after.count) of \(after.target)", canUndo: true) { [weak self] in
            self?.setCount(id, key: k, before)
        }
        checkAllDone()
    }

    /// Calendar rows: toggle a specific day (lets you fill in a day you forgot to log).
    func toggle(_ id: UUID, on day: Date) {
        guard let h = habit(id) else { return }
        let k = Day.key(day)
        let cur = h.done[k] ?? 0
        setCount(id, key: k, cur >= h.perDayTarget ? 0 : cur + 1)
        checkAllDone()
    }

    private func checkAllDone() {
        let due = habits.map { $0.status(now: now) }.filter { $0.section == .today }
        if !due.isEmpty && due.allSatisfy(\.met) { celebrate += 1 }
    }
}
