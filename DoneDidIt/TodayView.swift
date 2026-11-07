import SwiftUI

struct TodayView: View {
    @Environment(HabitStore.self) private var store
    @State private var adding = false
    @State private var editing: Habit? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if store.habits.isEmpty {
                        StarterCard()
                    } else {
                        SummaryCard()
                        ForEach(HabitSection.allCases, id: \.self) { section in
                            let rows = rows(in: section)
                            if !rows.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(section.title).font(.title3.weight(.heavy))
                                        Spacer()
                                        Text(hint(for: section)).font(.footnote.weight(.semibold)).foregroundStyle(Palette.muted)
                                    }
                                    ForEach(rows) { row in
                                        HabitCard(habit: row.habit, status: row.status) { editing = row.habit }
                                    }
                                }
                            }
                        }
                        if !store.startersLeft.isEmpty { StillOnListCard() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
            }
            .background(Palette.bg)
            .navigationTitle("Done Did It")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: { Label("Add", systemImage: "plus.circle.fill").font(.title2) }
                }
            }
            .overlay(alignment: .bottom) { UndoToast() }
            .sheet(isPresented: $adding) { HabitEditor(original: nil) }
            .sheet(item: $editing) { h in HabitEditor(original: h) }
        }
    }

    struct Row: Identifiable {
        let habit: Habit
        let status: HabitStatus
        var id: UUID { habit.id }
    }

    private func rows(in section: HabitSection) -> [Row] {
        let now = store.now
        var list = store.sorted.map { Row(habit: $0, status: $0.status(now: now)) }.filter { $0.status.section == section }
        if section == .later {
            list.sort { ($0.status.when ?? .distantFuture) < ($1.status.when ?? .distantFuture) }
        } else {
            list.sort { a, b in
                if a.status.met != b.status.met { return !a.status.met }
                if a.habit.priority.rank != b.habit.priority.rank { return a.habit.priority.rank < b.habit.priority.rank }
                return a.status.isDue && !b.status.isDue
            }
        }
        return list
    }

    private func hint(for section: HabitSection) -> String {
        let now = store.now
        switch section {
        case .week:
            let n = 7 - Day.dayIdx(now)
            return "\(n) day\(n > 1 ? "s" : "") left"
        case .month:
            let n = Day.daysInMonth(now) - Day.cal.component(.day, from: now) + 1
            return "\(n) day\(n > 1 ? "s" : "") left"
        default:
            return ""
        }
    }
}

// MARK: - Summary ring

struct SummaryCard: View {
    @Environment(HabitStore.self) private var store

    var body: some View {
        let now = store.now
        let statuses = store.habits.map { $0.status(now: now) }
        let today = statuses.filter { $0.section == .today }
        let dm = today.filter(\.met).count, dt = today.count
        let weekly = store.habits.filter { $0.freq == .weekly }
        let monthly = store.habits.filter { $0.freq == .monthly }
        let wm = weekly.filter { $0.count(in: .week, at: now) >= $0.effectiveTarget }.count
        let mm = monthly.filter { $0.count(in: .month, at: now) >= $0.effectiveTarget }.count
        let useToday = dt > 0
        let frac = useToday ? Double(dm) / Double(dt) : (weekly.isEmpty ? 0 : Double(wm) / Double(weekly.count))
        let remaining = dt - dm
        let cheer = dt == 0 ? "Nothing is due today. Pick something from this week if you have the energy."
            : remaining == 0 ? "Everything due today is done. Nice work."
            : dm == 0 ? "Start with the easiest one."
            : "\(remaining) more to go today."

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(Palette.sunk, lineWidth: 12)
                    Circle().trim(from: 0, to: frac)
                        .stroke(Palette.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 0.6), value: frac)
                    VStack(spacing: 2) {
                        (Text("\(useToday ? dm : wm)").font(.system(size: 34, weight: .heavy, design: .rounded))
                         + Text("/\(useToday ? dt : weekly.count)").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(Palette.muted))
                        Text(useToday ? "DONE TODAY" : "THIS WEEK").font(.caption2.weight(.bold)).foregroundStyle(Palette.muted)
                    }
                }
                .frame(width: 120, height: 120)
                VStack(spacing: 12) {
                    Meter(label: "Due today", m: dm, t: dt)
                    Meter(label: "Weekly", m: wm, t: weekly.count)
                    Meter(label: "Monthly", m: mm, t: monthly.count)
                }
            }
            Text(cheer).font(.subheadline.weight(.semibold))
        }
        .card()
    }
}

struct Meter: View {
    let label: String
    let m: Int
    let t: Int
    var body: some View {
        if t > 0 {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(label).font(.caption.weight(.bold))
                    Spacer()
                    Text("\(m) of \(t)").font(.caption.weight(.bold)).foregroundStyle(Palette.muted).monospacedDigit()
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.sunk)
                        Capsule().fill(Palette.accent).frame(width: g.size.width * CGFloat(m) / CGFloat(max(t, 1)))
                    }
                }
                .frame(height: 9)
                .animation(.spring(duration: 0.6), value: m)
            }
        }
    }
}

// MARK: - Habit card

struct HabitCard: View {
    @Environment(HabitStore.self) private var store
    let habit: Habit
    let status: HabitStatus
    let onEdit: () -> Void

    var body: some View {
        let color = Palette.color(for: habit)
        let s = habit.streak(now: store.now)
        HStack(spacing: 12) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(habit.symbol).font(.title3)
                        Text(habit.name)
                            .font(.body.weight(.bold))
                            .strikethrough(status.met, color: color)
                            .multilineTextAlignment(.leading)
                        PriorityPill(priority: habit.priority)
                    }
                    FlowLayout(spacing: 10) {
                        if status.target > 1 && !(habit.hasSetDays && status.section == .today) {
                            Text("\(status.count) of \(status.target)").monospacedDigit()
                        }
                        if status.section == .later, let when = status.when {
                            Text("\(habit.describe) · next \(Day.friendly(when, now: store.now))")
                        } else if let note = status.note {
                            Text(note).foregroundStyle(status.isDue && !status.met ? Palette.accent : Palette.muted)
                                .fontWeight(status.isDue && !status.met ? .heavy : .semibold)
                        } else if habit.freq != .daily && status.target == 1 {
                            Text(status.met ? "Done" : habit.describe)
                        }
                        if s > 0 {
                            Label(habit.streakText(s), systemImage: "flame.fill").foregroundStyle(color)
                        }
                        if habit.freq == .weekly { WeekPips(habit: habit, color: color) }
                        if habit.freq == .daily { LastSevenDots(habit: habit, color: color) }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(habit.name)")

            CheckButton(color: color, count: status.count, target: status.target, met: status.met) {
                store.tap(habit.id)
            }
        }
        .card(status.met ? color.opacity(0.15) : Palette.surface)
        .opacity(status.section == .later ? 0.8 : 1)
    }
}

struct CheckButton: View {
    let color: Color
    let count: Int
    let target: Int
    let met: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(color, lineWidth: 3)
                if met {
                    Circle().fill(color)
                    Image(systemName: "checkmark").font(.title2.weight(.heavy)).foregroundStyle(Palette.onAccent)
                        .transition(.scale.combined(with: .opacity))
                } else if count > 0 {
                    Circle().fill(color.opacity(0.2))
                    Circle().trim(from: 0, to: CGFloat(count) / CGFloat(max(target, 1)))
                        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(count)").font(.subheadline.weight(.heavy)).foregroundStyle(color)
                }
            }
            .frame(width: 54, height: 54)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: met)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: count)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: met) { _, new in new }
        .sensoryFeedback(.impact(weight: .light), trigger: count)
        .accessibilityLabel(met ? "Undo check-in" : "Mark done")
    }
}

struct WeekPips: View {
    @Environment(HabitStore.self) private var store
    let habit: Habit
    let color: Color
    var body: some View {
        let ws = Day.weekStart(store.now)
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { i in
                let done = habit.count(on: Day.add(ws, i)) > 0
                let sched = habit.days.contains(i)
                Capsule()
                    .fill(done ? color : (sched ? color.opacity(0.3) : Palette.sunk))
                    .frame(width: 16, height: 6)
            }
        }
    }
}

struct LastSevenDots: View {
    @Environment(HabitStore.self) private var store
    let habit: Habit
    let color: Color
    var body: some View {
        HStack(spacing: 3) {
            ForEach((0..<7).reversed(), id: \.self) { i in
                let d = Day.add(store.now, -i)
                Circle()
                    .fill(habit.count(on: d) >= habit.perDayTarget ? color : Palette.sunk)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(i == 0 ? Palette.muted : .clear, lineWidth: 1).padding(-2))
            }
        }
    }
}

// MARK: - Starter list

struct StarterCard: View {
    @Environment(HabitStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your list is ready to add").font(.title2.weight(.heavy))
            Text("These are the habits and chores you sent. Add them all at once, or tap the ones you want. Tap any habit later to change it.")
                .foregroundStyle(Palette.muted)
            Button {
                store.addStarters(store.startersLeft)
            } label: {
                Text("Add all \(store.startersLeft.count)").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            StarterChips()
        }
        .card()
    }
}

struct StillOnListCard: View {
    @Environment(HabitStore.self) private var store
    var body: some View {
        let left = store.startersLeft
        VStack(alignment: .leading, spacing: 12) {
            Text("Still on your list").font(.title3.weight(.heavy))
            Text("\(left.count) item\(left.count > 1 ? "s" : "") from your list aren't in the app yet.").foregroundStyle(Palette.muted)
            StarterChips()
            Button("Add all \(left.count)") { store.addStarters(left) }.buttonStyle(.bordered)
        }
        .card()
    }
}

struct StarterChips: View {
    @Environment(HabitStore.self) private var store
    var onPick: (() -> Void)? = nil
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(store.startersLeft, id: \.name) { s in
                Button {
                    store.addStarters([s])
                    onPick?()
                } label: {
                    HStack(spacing: 4) {
                        Text("\(s.symbol) \(s.name)").font(.subheadline.weight(.semibold))
                        Text(s.describe.lowercased()).font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .overlay(Capsule().stroke(Palette.sunk, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Undo toast

struct UndoToast: View {
    @Environment(HabitStore.self) private var store
    var body: some View {
        if let u = store.undo {
            HStack(spacing: 12) {
                Text(u.message).font(.subheadline.weight(.semibold)).lineLimit(2)
                if u.canUndo {
                    Button("Undo") { u.revert(); store.undo = nil }
                        .font(.subheadline.weight(.heavy))
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(radius: 8, y: 4)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(u.id)
            .task(id: u.id) {
                try? await Task.sleep(for: .seconds(4.5))
                if store.undo?.id == u.id { withAnimation { store.undo = nil } }
            }
        }
    }
}
