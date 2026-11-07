import SwiftUI

struct HabitCalendarView: View {
    @Environment(HabitStore.self) private var store
    enum Mode: String, CaseIterable, Identifiable { case month = "Month", week = "Week"; var id: String { rawValue } }
    @State private var mode: Mode = .month
    @State private var cursor: Date = Date()
    @State private var selected: Date? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 14) {
                        HStack {
                            navButton("chevron.left", -1)
                            Spacer()
                            Text(title).font(.title3.weight(.heavy))
                            Spacer()
                            navButton("chevron.right", 1)
                        }
                        Picker("View", selection: $mode) {
                            ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
                        }
                        .pickerStyle(.segmented)
                        if mode == .month { monthGrid } else { anytimeRows }
                    }
                    .card()

                    if mode == .month {
                        let day = selected ?? Day.sod(store.now)
                        DayRundown(day: day, title: day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .card()
                        symbolKey.card()
                    } else {
                        let ws = Day.weekStart(cursor)
                        ForEach(0..<7, id: \.self) { i in
                            let d = Day.add(ws, i)
                            DayRundown(day: d, title: "\(Day.longNames[i]) · \(d.formatted(.dateTime.month(.abbreviated).day()))")
                                .card()
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Day.diff(d, store.now) == 0 ? Palette.accent : .clear, lineWidth: 2))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(Palette.bg)
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Today") { cursor = store.now; selected = nil }
                }
            }
        }
    }

    private var title: String {
        if mode == .month { return cursor.formatted(.dateTime.month(.wide).year()) }
        let ws = Day.weekStart(cursor), we = Day.add(ws, 6)
        return "\(ws.formatted(.dateTime.month(.abbreviated).day())) – \(we.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func navButton(_ icon: String, _ dir: Int) -> some View {
        Button {
            cursor = mode == .month ? Day.addMonths(cursor, dir) : Day.add(cursor, 7 * dir)
            selected = nil
        } label: {
            Image(systemName: icon).font(.headline).frame(width: 40, height: 40).background(Palette.sunk, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dir < 0 ? "Previous" : "Next")
    }

    // MARK: month

    private var monthGrid: some View {
        let first = Day.monthStart(cursor)
        let start = Day.weekStart(first)
        let last = Day.add(first, Day.daysInMonth(first) - 1)
        let cells = Int((Double(Day.diff(start, last) + 1) / 7).rounded(.up)) * 7
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: cols, spacing: 4) {
            ForEach(0..<7, id: \.self) { i in
                Text(Day.letters[i]).font(.caption.weight(.heavy)).foregroundStyle(Palette.muted)
            }
            ForEach(0..<cells, id: \.self) { i in
                let d = Day.add(start, i)
                dayCell(d, inMonth: Day.cal.isDate(d, equalTo: first, toGranularity: .month))
            }
        }
    }

    private func dayCell(_ d: Date, inMonth: Bool) -> some View {
        let k = Day.key(d)
        let doneHabits = store.sorted.filter { ($0.done[k] ?? 0) > 0 }
        let isToday = Day.diff(d, store.now) == 0
        let isSel = selected.map { Day.diff($0, d) == 0 } ?? false
        let missed = inMonth && Day.sod(d) < Day.sod(store.now)
            && store.habits.contains { $0.isDue(on: d, now: store.now) && $0.count(on: d) < $0.perDayTarget }
        let shown = doneHabits.prefix(6).map(\.symbol).joined()
        return Button {
            selected = d
        } label: {
            VStack(spacing: 2) {
                Text("\(Day.cal.component(.day, from: d))").font(.caption.weight(.heavy)).monospacedDigit()
                Text(shown + (doneHabits.count > 6 ? " +\(doneHabits.count - 6)" : ""))
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4).padding(.horizontal, 2)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(isSel ? Palette.accent.opacity(0.18) : Palette.sunk, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isToday ? Palette.accent : .clear, lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                if missed { Circle().fill(Palette.muted.opacity(0.6)).frame(width: 5, height: 5).padding(5) }
            }
            .opacity(inMonth ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(d.formatted(date: .complete, time: .omitted)), \(doneHabits.count) done")
    }

    private var symbolKey: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Symbols").font(.title3.weight(.heavy))
            Text("Each symbol on the calendar is a habit you finished that day. A small dot means something scheduled was missed. Tap a day to see it, or to log a day you forgot.")
                .font(.footnote).foregroundStyle(Palette.muted)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(store.sorted) { h in
                    Text("\(h.symbol)  \(h.name)").font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    // MARK: week

    @ViewBuilder
    private var anytimeRows: some View {
        let ws = Day.weekStart(cursor)
        let anytime = store.sorted.filter { ($0.freq == .weekly && $0.days.isEmpty) || ($0.freq == .monthly && $0.date == 0) }
        if !anytime.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("ANYTIME THIS WEEK").font(.caption.weight(.heavy)).foregroundStyle(Palette.muted)
                ForEach(anytime) { h in
                    let p = h.periodKind
                    let c = h.periodCounts(p)[Day.periodKey(ws, p)] ?? 0
                    let t = h.effectiveTarget
                    let color = Palette.color(for: h)
                    HStack(spacing: 10) {
                        Text(h.symbol).font(.title3)
                        Text(h.name).font(.subheadline.weight(.semibold)).strikethrough(c >= t, color: color)
                        Spacer()
                        Text("\(c)/\(t) this \(h.freq.periodWord)").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted).monospacedDigit()
                    }
                    .padding(10)
                    .background(c >= t ? color.opacity(0.16) : Palette.sunk, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

/// Everything scheduled or logged on one day, with checkboxes for today and earlier.
struct DayRundown: View {
    @Environment(HabitStore.self) private var store
    let day: Date
    let title: String

    var body: some View {
        let k = Day.key(day)
        let items = store.sorted
            .filter { $0.isDue(on: day, now: store.now) || ($0.done[k] ?? 0) > 0 }
            .sorted { $0.priority.rank < $1.priority.rank }
        let doneCount = items.filter { $0.count(on: day) >= $0.perDayTarget }.count
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline.weight(.heavy))
                Spacer()
                if !items.isEmpty {
                    Text("\(doneCount) of \(items.count)").font(.footnote.weight(.semibold)).foregroundStyle(Palette.muted).monospacedDigit()
                }
            }
            if items.isEmpty {
                Text("Nothing scheduled.").font(.subheadline).foregroundStyle(Palette.muted)
            }
            ForEach(items) { h in
                RundownRow(habit: h, day: day)
            }
        }
    }
}

struct RundownRow: View {
    @Environment(HabitStore.self) private var store
    let habit: Habit
    let day: Date

    var body: some View {
        let n = habit.count(on: day)
        let per = habit.perDayTarget
        let done = n >= per
        let color = Palette.color(for: habit)
        let canTap = Day.sod(day) <= Day.sod(store.now)
        HStack(spacing: 10) {
            Text(habit.symbol).font(.title3)
            Text(habit.name).font(.subheadline.weight(.semibold)).strikethrough(done, color: color)
            PriorityPill(priority: habit.priority)
            if per > 1 { Text("\(n)/\(per)").font(.caption).foregroundStyle(Palette.muted).monospacedDigit() }
            Spacer()
            if canTap {
                Button {
                    store.toggle(habit.id, on: day)
                } label: {
                    ZStack {
                        Circle().stroke(color, lineWidth: 3)
                        if done {
                            Circle().fill(color)
                            Image(systemName: "checkmark").font(.subheadline.weight(.heavy)).foregroundStyle(Palette.onAccent)
                        }
                    }
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: done) { _, new in new }
                .accessibilityLabel(done ? "Uncheck \(habit.name)" : "Check \(habit.name)")
            } else {
                Text("PLANNED").font(.caption2.weight(.bold)).foregroundStyle(Palette.muted)
            }
        }
        .padding(10)
        .background(done ? color.opacity(0.16) : Palette.sunk, in: RoundedRectangle(cornerRadius: 12))
    }
}
