import SwiftUI

struct StatsView: View {
    @Environment(HabitStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if store.habits.isEmpty {
                        StarterCard()
                    } else {
                        overview.card()
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Each habit").font(.title3.weight(.heavy))
                            Text("Filled means you hit your goal. The outlined bar is this week or this month.")
                                .font(.footnote).foregroundStyle(Palette.muted)
                            ForEach(store.sorted) { h in
                                HabitHistory(habit: h)
                                if h.id != store.sorted.last?.id { Divider() }
                            }
                        }
                        .card()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(Palette.bg)
            .navigationTitle("Progress")
        }
    }

    private var perDay: [String: Int] {
        var m: [String: Int] = [:]
        for h in store.habits { for (k, n) in h.done where n > 0 { m[k, default: 0] += n } }
        return m
    }

    private var overview: some View {
        let now = store.now
        let pd = perDay
        let last7 = (0..<7).reduce(0) { $0 + (pd[Day.key(Day.add(now, -$1))] ?? 0) }
        let cutoff = Day.add(now, -29)
        let active = pd.keys.filter { Day.parse($0) >= cutoff }.count
        let total = pd.values.reduce(0, +)
        let maxN = max(1, pd.values.max() ?? 1)
        let weeks = 16
        let start = Day.add(Day.weekStart(now), -7 * (weeks - 1))

        return VStack(alignment: .leading, spacing: 14) {
            Text("Everything you got done").font(.title3.weight(.heavy))
            HStack(spacing: 10) {
                stat("\(last7)", "Check-ins · 7d")
                stat("\(active)/30", "Days active")
                stat("\(total)", "All time")
            }
            HStack(spacing: 3) {
                ForEach(0..<weeks, id: \.self) { w in
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { i in
                            let d = Day.add(start, w * 7 + i)
                            let n = pd[Day.key(d)] ?? 0
                            let future = Day.sod(d) > Day.sod(now)
                            let lvl = n == 0 ? 0 : min(4, Int((Double(n) / Double(maxN) * 4).rounded(.up)))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(future ? Color.clear : Palette.heat[lvl])
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Day.diff(d, now) == 0 ? Color.primary : .clear, lineWidth: 1.5))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
            .accessibilityLabel("Check-ins per day for the last 16 weeks")
            HStack(spacing: 4) {
                Text("Less").font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)
                ForEach(0..<5, id: \.self) { i in RoundedRectangle(cornerRadius: 2).fill(Palette.heat[i]).frame(width: 11, height: 11) }
                Text("More").font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 26, weight: .heavy, design: .rounded)).monospacedDigit()
            Text(label.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(Palette.muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.sunk, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct HabitHistory: View {
    @Environment(HabitStore.self) private var store
    let habit: Habit

    var body: some View {
        let now = store.now
        let color = Palette.color(for: habit)
        let s = habit.streak(now: now)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(habit.symbol) \(habit.name)").font(.headline)
                Spacer()
                Text((s > 0 ? "\(habit.streakText(s)) in a row · " : "") + "\(habit.totalDone) total")
                    .font(.caption.weight(.semibold)).foregroundStyle(Palette.muted).monospacedDigit()
            }
            Text(habit.describe).font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
            if habit.freq == .daily || habit.freq == .every {
                let n = (habit.freq == .every && habit.intervalDays >= 7) ? 56 : 28
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 14), spacing: 4) {
                    ForEach(0..<n, id: \.self) { i in
                        let d = Day.add(now, i - (n - 1))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(habit.count(on: d) >= habit.perDayTarget ? color : Palette.sunk)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                axis("\(n / 7) weeks ago", "Today")
            } else {
                let p = habit.periodKind
                let pc = habit.periodCounts(p)
                let t = habit.effectiveTarget
                let periods: [String] = {
                    var d = now
                    var out: [String] = []
                    for _ in 0..<12 { out.insert(Day.periodKey(d, p), at: 0); d = Day.prevPeriod(d, p) }
                    return out
                }()
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(periods.enumerated()), id: \.offset) { i, key in
                        let frac = min(1, CGFloat(pc[key] ?? 0) / CGFloat(t))
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4).fill(Palette.sunk)
                            RoundedRectangle(cornerRadius: 4).fill(color).frame(height: 46 * frac)
                        }
                        .frame(height: 46)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(i == periods.count - 1 ? Palette.muted : .clear, lineWidth: 1.5))
                    }
                }
                axis("12 \(habit.freq.periodWord)s ago", "This \(habit.freq.periodWord)")
            }
        }
    }

    private func axis(_ a: String, _ b: String) -> some View {
        HStack {
            Text(a)
            Spacer()
            Text(b)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Palette.muted)
    }
}
