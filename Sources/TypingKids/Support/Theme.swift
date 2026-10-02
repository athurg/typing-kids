import SwiftUI

enum Theme {
    static let accent = Color(red: 0.35, green: 0.45, blue: 0.95)
    static let bgTop = Color(red: 0.88, green: 0.95, blue: 1.00)
    static let bgBottom = Color(red: 0.97, green: 0.91, blue: 1.00)
    static let skin = Color(red: 1.00, green: 0.90, blue: 0.80)
    static let good = Color(red: 0.20, green: 0.66, blue: 0.35)
    static let warn = Color(red: 0.96, green: 0.55, blue: 0.10)
    static let bad = Color(red: 0.92, green: 0.27, blue: 0.30)
    static let ink = Color(red: 0.18, green: 0.20, blue: 0.30)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static var background: LinearGradient {
        LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            )
    }
}

struct KidButtonStyle: ButtonStyle {
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(20, .bold))
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(Capsule().fill(color))
            .foregroundStyle(.white)
            .shadow(color: color.opacity(0.35), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// 打错时左右晃一晃。
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 7
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * 4), y: 0))
    }
}

/// 自动换行的流式布局，单词不会被拆到两行。
struct FlowLayout: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            // 每行居中
            var x = bounds.minX + (bounds.width - row.width) / 2
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: .unspecified)
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (i, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if !row.indices.isEmpty && needed > maxWidth {
                let nextY = row.y + row.height + lineSpacing
                rows.append(row)
                row = Row(y: nextY)
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(i)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

func formatDuration(_ seconds: TimeInterval) -> String {
    let s = Int(seconds.rounded())
    return String(format: "%d:%02d", s / 60, s % 60)
}
