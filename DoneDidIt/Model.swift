import Foundation

// MARK: - Habit

enum Frequency: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, monthly, every
    var id: String { rawValue }
    var label: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .every: return "Repeat"
        }
    }
    var periodWord: String {
        switch self {
        case .daily: return "day"
        case .weekly: return "week"
        case .monthly: return "month"
        case .every: return "time"
        }
    }
}

enum Priority: String, Codable, CaseIterable, Identifiable {
    case high, med, low
    var id: String { rawValue }
    var label: String {
        switch self {
        case .high: return "High"
        case .med: return "Medium"
        case .low: return "Low"
        }
    }
    var rank: Int {
        switch self {
        case .high: return 0
        case .med: return 1
        case .low: return 2
        }
    }
}

enum IntervalUnit: String, Codable, CaseIterable, Identifiable {
    case days, weeks
    var id: String { rawValue }
}

struct Habit: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var freq: Frequency = .daily
    /// Times per period, for habits without set days or dates.
    var target: Int = 1
    /// Set weekdays for weekly habits. 0 = Monday ... 6 = Sunday.
    var days: [Int] = []
    /// Set day of the month for monthly habits. 0 = any day.
    var date: Int = 0
    /// For "repeat" habits: every N days or weeks.
    var every: Int = 2
    var unit: IntervalUnit = .days
    var symbol: String = "⭐"
    var colorIndex: Int = 0
    var priority: Priority = .med
    /// Check-ins per day, keyed "yyyy-MM-dd".
    var done: [String: Int] = [:]
    var created: Date = Date()
}

// MARK: - Dates

enum PeriodKind { case day, week, month }

enum Day {
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.timeZone = .current
        return c
    }()

    static func key(_ d: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    static func parse(_ k: String) -> Date {
        let p = k.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return Date() }
        return cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) ?? Date()
    }
    static func sod(_ d: Date) -> Date { cal.startOfDay(for: d) }
    static func add(_ d: Date, _ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: sod(d)) ?? d }
    static func diff(_ a: Date, _ b: Date) -> Int { cal.dateComponents([.day], from: sod(a), to: sod(b)).day ?? 0 }
    /// 0 = Monday ... 6 = Sunday
    static func dayIdx(_ d: Date) -> Int { (cal.component(.weekday, from: d) + 5) % 7 }
    static func weekStart(_ d: Date) -> Date { add(d, -dayIdx(d)) }
    static func monthStart(_ d: Date) -> Date { cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? d }
    static func addMonths(_ d: Date, _ n: Int) -> Date { cal.date(byAdding: .month, value: n, to: monthStart(d)) ?? d }
    static func daysInMonth(_ d: Date) -> Int { cal.range(of: .day, in: .month, for: d)?.count ?? 30 }
    static func monthDue(_ d: Date, _ date: Int) -> Date { add(monthStart(d), min(date, daysInMonth(d)) - 1) }

    static func periodKey(_ d: Date, _ p: PeriodKind) -> String {
        switch p {
        case .day: return key(d)
        case .week: return key(weekStart(d))
        case .month: return String(key(d).prefix(7))
        }
    }
    static func prevPeriod(_ d: Date, _ p: PeriodKind) -> Date {
        switch p {
        case .day: return add(d, -1)
        case .week: return add(weekStart(d), -7)
        case .month: return addMonths(d, -1)
        }
    }

    static let shortNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static let longNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    static let letters = ["M", "T", "W", "T", "F", "S", "S"]

    static func ordinal(_ n: Int) -> String {
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 13 { return "\(n)th" }
        switch n % 10 {
        case 1: return "\(n)st"
        case 2: return "\(n)nd"
        case 3: return "\(n)rd"
        default: return "\(n)th"
        }
    }

    /// "today", "tomorrow", "Thursday", or "Dec 1"
    static func friendly(_ d: Date, now: Date) -> String {
        let n = diff(now, d)
        if n == 0 { return "today" }
        if n == 1 { return "tomorrow" }
        if n > 1 && n < 7 { return longNames[dayIdx(d)] }
        return d.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Scheduling

enum HabitSection: Int, CaseIterable {
    case today, week, month, later
    var title: String {
        switch self {
        case .today: return "Due today"
        case .week: return "This week"
        case .month: return "This month"
        case .later: return "Coming up"
        }
    }
}

struct HabitStatus {
    var section: HabitSection
    var count: Int
    var target: Int
    var met: Bool
    var note: String? = nil
    var isDue: Bool = false
    var when: Date? = nil
}

extension Habit {
    var hasSetDays: Bool { freq == .weekly && !days.isEmpty }

    var effectiveTarget: Int {
        if hasSetDays { return days.count }
        if freq == .every || (freq == .monthly && date > 0) { return 1 }
        return max(1, target)
    }

    var periodKind: PeriodKind {
        switch freq {
        case .weekly: return .week
        case .monthly: return .month
        default: return .day
        }
    }

    var intervalDays: Int { max(1, every) * (unit == .weeks ? 7 : 1) }

    var doneKeys: [String] { done.filter { $0.value > 0 }.map(\.key).sorted() }

    func count(on d: Date) -> Int { done[Day.key(d)] ?? 0 }

    /// Check-ins needed on one day to call that day done.
    var perDayTarget: Int { freq == .daily ? max(1, target) : 1 }

    func periodCounts(_ p: PeriodKind) -> [String: Int] {
        var m: [String: Int] = [:]
        for (k, n) in done where n > 0 {
            m[Day.periodKey(Day.parse(k), p), default: 0] += n
        }
        return m
    }

    func count(in p: PeriodKind, at d: Date) -> Int { periodCounts(p)[Day.periodKey(d, p)] ?? 0 }

    var describe: String {
        switch freq {
        case .daily:
            return target > 1 ? "\(target) times a day" : "Every day"
        case .weekly:
            if !days.isEmpty {
                return days.count == 1 ? Day.longNames[days[0]] + "s" : days.sorted().map { Day.shortNames[$0] }.joined(separator: ", ")
            }
            return target > 1 ? "\(target) times a week" : "Once a week"
        case .monthly:
            if date > 0 { return "The \(Day.ordinal(date)) of each month" }
            return target > 1 ? "\(target) times a month" : "Once a month"
        case .every:
            let u = unit == .weeks ? "week" : "day"
            return every <= 1 ? "Every \(u)" : "Every \(every) \(u)s"
        }
    }

    /// Where the habit belongs right now.
    func status(now: Date) -> HabitStatus {
        let today = Day.sod(now)
        let tk = Day.key(now)
        let doneToday = done[tk] ?? 0
        let createdDay = Day.sod(created)
        let t = effectiveTarget

        switch freq {
        case .daily:
            return HabitStatus(section: .today, count: doneToday, target: t, met: doneToday >= t)

        case .weekly:
            let c = count(in: .week, at: now)
            if hasSetDays {
                if days.contains(Day.dayIdx(now)) {
                    return HabitStatus(section: .today, count: doneToday > 0 ? 1 : 0, target: 1, met: doneToday > 0,
                                       note: doneToday > 0 ? nil : "Due today", isDue: true)
                }
                var next = ""
                for i in 1...7 {
                    let d = Day.add(today, i)
                    if days.contains(Day.dayIdx(d)) { next = Day.friendly(d, now: now); break }
                }
                return HabitStatus(section: .week, count: c, target: t, met: c >= t, note: "Next \(next)")
            }
            return HabitStatus(section: .week, count: c, target: t, met: c >= t)

        case .monthly:
            let c = count(in: .month, at: now)
            guard date > 0 else { return HabitStatus(section: .month, count: c, target: t, met: c >= t) }
            let due = Day.monthDue(now, date)
            if c > 0 {
                return HabitStatus(section: (doneToday > 0 && due <= today) ? .today : .month, count: 1, target: 1, met: true, note: "Done this month")
            }
            if due > today {
                return HabitStatus(section: .month, count: 0, target: 1, met: false, note: "On the \(Day.ordinal(date))")
            }
            if due >= createdDay {
                let late = Day.diff(due, today)
                return HabitStatus(section: .today, count: 0, target: 1, met: false,
                                   note: late > 0 ? "Was due the \(Day.ordinal(date))" : "Due today", isDue: true)
            }
            return HabitStatus(section: .later, count: 0, target: 1, met: false, when: Day.monthDue(Day.addMonths(now, 1), date))

        case .every:
            let n = intervalDays
            if doneToday > 0 {
                return HabitStatus(section: .today, count: 1, target: 1, met: true, note: "Next \(Day.friendly(Day.add(today, n), now: now))")
            }
            let past = doneKeys.filter { $0 < tk }
            guard let last = past.last else {
                return HabitStatus(section: .week, count: 0, target: 1, met: false, note: "Not started · then \(describe.lowercased())")
            }
            let due = Day.add(Day.parse(last), n)
            if due <= today {
                let late = Day.diff(due, today)
                let note = late <= 0 ? "Due today" : (late == 1 ? "Due yesterday" : "Due \(late) days ago")
                return HabitStatus(section: .today, count: 0, target: 1, met: false, note: note, isDue: true)
            }
            return HabitStatus(section: .later, count: 0, target: 1, met: false, when: due)
        }
    }

    /// Scheduled for a given day (used by the calendar's day rundowns).
    func isDue(on day: Date, now: Date) -> Bool {
        let d = Day.sod(day)
        if d < Day.sod(created) { return false }
        switch freq {
        case .daily: return true
        case .weekly: return days.contains(Day.dayIdx(d))
        case .monthly: return date > 0 && Day.diff(Day.monthDue(d, date), d) == 0
        case .every:
            let n = intervalDays
            let dk = Day.key(d)
            if Day.diff(now, d) == 0 && status(now: now).section == .today { return true }
            let past = doneKeys.filter { $0 < dk }
            guard let last = past.last else { return false }
            let base = Day.parse(last)
            let g = Day.diff(base, d)
            if d < Day.sod(now) { return g == n }
            if Day.diff(base, Day.sod(now)) > n { return false }
            return g > 0 && g % n == 0
        }
    }

    func streak(now: Date) -> Int {
        if freq == .every {
            let ds: [Date] = Array(doneKeys.map { Day.parse($0) }.reversed())
            guard let first = ds.first, Day.diff(first, now) <= intervalDays else { return 0 }
            var s = 1
            if ds.count > 1 {
                for i in 1..<ds.count {
                    if Day.diff(ds[i], ds[i - 1]) <= intervalDays { s += 1 } else { break }
                }
            }
            return s
        }
        let p = periodKind
        let pc = periodCounts(p)
        let t = effectiveTarget
        var d = now
        var s = 0
        if (pc[Day.periodKey(d, p)] ?? 0) >= t { s += 1 }
        d = Day.prevPeriod(d, p)
        for _ in 0..<1000 {
            if (pc[Day.periodKey(d, p)] ?? 0) >= t { s += 1; d = Day.prevPeriod(d, p) } else { break }
        }
        return s
    }

    func streakText(_ s: Int) -> String {
        if freq == .every { return "\(s) on time" }
        return "\(s) \(freq.periodWord)\(s > 1 ? "s" : "")"
    }

    var totalDone: Int { done.values.reduce(0, +) }
}

// MARK: - Jess's starting list

struct Starter: Identifiable {
    let id: Int
    let habit: Habit
}

enum Starters {
    static let list: [Habit] = [
        Habit(name: "Water plants", freq: .weekly, days: [3], symbol: "🪴"),
        Habit(name: "Water lemon tree", freq: .weekly, days: [0, 2, 4, 5], symbol: "🍋"),
        Habit(name: "Change kitty litter", freq: .monthly, date: 1, symbol: "🐈"),
        Habit(name: "Bathe dogs", freq: .weekly, days: [5], symbol: "🛁"),
        Habit(name: "Bathe Gremlin", freq: .weekly, days: [5], symbol: "🫧"),
        Habit(name: "Brush Smash", freq: .weekly, days: [5], symbol: "🖌️"),
        Habit(name: "Dremel Brigit's nails", freq: .every, every: 3, unit: .days, symbol: "💅"),
        Habit(name: "Trim Phyllis's nails", freq: .every, every: 2, unit: .weeks, symbol: "✂️"),
        Habit(name: "Trim Gremlin's nails", freq: .every, every: 2, unit: .weeks, symbol: "🦴"),
        Habit(name: "Trim Smash's nails", freq: .every, every: 2, unit: .weeks, symbol: "🐾"),
        Habit(name: "Brigit's medication shot", freq: .monthly, symbol: "💉"),
        Habit(name: "Workouts", freq: .weekly, target: 3, symbol: "💪"),
        Habit(name: "Listen to PT podcasts", freq: .weekly, target: 2, symbol: "🎧"),
        Habit(name: "Walk dogs", freq: .daily, symbol: "🐕"),
        Habit(name: "Phyllis fold clean", freq: .every, every: 2, unit: .days, symbol: "🧽"),
    ]

    static let symbols = ["🪴", "🍋", "🐈", "🛁", "🫧", "🖌️", "💅", "✂️", "🦴", "🐾", "💉", "💊", "💪", "🎧", "🐕", "🧽",
                          "🧺", "🍽️", "🧹", "🗑️", "📚", "🧘", "🚶", "💧", "🛏️", "🦷", "💰", "📞", "🍳", "🛒", "🌱", "⭐"]
}
