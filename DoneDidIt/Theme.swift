import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    /// A color that switches between light and dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

enum Palette {
    static let bg = Color(light: 0xF3F4FB, dark: 0x12132A)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1D1F3D)
    static let sunk = Color(light: 0xE7E9F5, dark: 0x272A4F)
    static let muted = Color(light: 0x62668A, dark: 0x9DA2CC)
    static let accent = Color(light: 0xFF6B2C, dark: 0xFF7A3D)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x1A0D05)
    static let high = Color(light: 0xE8457A, dark: 0xFF6F9B)

    static let habitColors: [Color] = [
        Color(light: 0xFF6B2C, dark: 0xFF7A3D),
        Color(light: 0x7B5CFF, dark: 0x9D86FF),
        Color(light: 0x14A37F, dark: 0x3FD1A7),
        Color(light: 0xE8457A, dark: 0xFF6F9B),
        Color(light: 0x1F8FE0, dark: 0x56B1FF),
        Color(light: 0xC99500, dark: 0xF0C03C),
    ]

    static let heat: [Color] = [
        Color(light: 0xE3E5F3, dark: 0x262948),
        Color(light: 0xFFD6C2, dark: 0x5A3A3A),
        Color(light: 0xFFAB85, dark: 0x9A4F2F),
        Color(light: 0xFF8247, dark: 0xD8642A),
        Color(light: 0xE5520F, dark: 0xFF8A4D),
    ]

    static func color(for h: Habit) -> Color { habitColors[abs(h.colorIndex) % habitColors.count] }
}

extension Font {
    static let display = Font.system(.title, design: .rounded).weight(.heavy)
}

struct CardBackground: ViewModifier {
    var fill: Color = Palette.surface
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    func card(_ fill: Color = Palette.surface) -> some View { modifier(CardBackground(fill: fill)) }
}

/// Wraps children onto new lines, like text.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxW), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

struct PriorityPill: View {
    let priority: Priority
    var body: some View {
        switch priority {
        case .high:
            Text("HIGH").font(.caption2.weight(.heavy)).foregroundStyle(Palette.high)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Palette.high.opacity(0.16), in: Capsule())
        case .low:
            Text("LOW").font(.caption2.weight(.heavy)).foregroundStyle(Palette.muted)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Palette.sunk, in: Capsule())
        case .med:
            EmptyView()
        }
    }
}

/// A short burst of confetti, replayed whenever `trigger` changes.
struct ConfettiView: View {
    let trigger: Int
    @State private var start: Date? = nil
    @State private var seeds: [(CGFloat, CGFloat, CGFloat, Int)] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { tl in
            Canvas { ctx, size in
                guard let start else { return }
                let t = tl.date.timeIntervalSince(start)
                guard t < 2.2 else { return }
                for (i, s) in seeds.enumerated() {
                    let (angle, speed, spin, colorIdx) = s
                    let x = size.width / 2 + cos(angle) * speed * CGFloat(t) * 60
                    let y = size.height / 3 + sin(angle) * speed * CGFloat(t) * 60 + 260 * CGFloat(t * t)
                    var p = ctx
                    p.opacity = max(0, 1 - t / 2.2)
                    p.translateBy(x: x, y: y)
                    p.rotate(by: .radians(Double(spin) * t + Double(i)))
                    p.fill(Path(CGRect(x: -5, y: -2.5, width: 10, height: 5)), with: .color(Palette.habitColors[colorIdx % Palette.habitColors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion else { return }
            seeds = (0..<90).map { _ in
                (CGFloat.random(in: 0...(2 * .pi)), CGFloat.random(in: 2...9), CGFloat.random(in: 2...8), Int.random(in: 0..<6))
            }
            start = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) { start = nil }
        }
    }
}
