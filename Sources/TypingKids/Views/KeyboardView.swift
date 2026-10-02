import SwiftUI

/// 屏幕上的彩色键盘：每个键按负责它的手指着色，下一个要按的键会放大发亮。
/// 打开 showHands 时，键盘上会叠加半透明的双手，循环演示该用哪个手指去按。
struct KeyboardView: View {
    var highlighted: Set<String> = []
    var flashed: String? = nil
    /// 选区展示：这些键用完整颜色显示，其余键变淡（用于按键练习选区域）
    var emphasized: Set<String>? = nil
    var showHands = false
    var handTarget: Character? = nil
    /// 每次变化都会让手的演示动画从头开始（例如打了下一个字）
    var step = 0
    var unit: CGFloat = 46
    var spacing: CGFloat = 6

    /// 手掌会伸出键盘下边缘这么多
    static let handsOverflow: CGFloat = 60

    private let inset: CGFloat = 12
    @State private var cycleStart = Date()

    var body: some View {
        let frames = KeyboardLayout.keyFrames(unit: unit, spacing: spacing, inset: inset)
        let size = KeyboardLayout.size(unit: unit, spacing: spacing, inset: inset)
        VStack(spacing: spacing) {
            ForEach(Array(KeyboardLayout.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(row) { key in
                        KeyCapView(key: key,
                                   isTarget: highlighted.contains(key.id),
                                   isWrong: flashed == key.id,
                                   emphasis: emphasized.map { $0.contains(key.id) },
                                   unit: unit, spacing: spacing)
                    }
                }
            }
        }
        .padding(inset)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.90))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        )
        .overlay(alignment: .top) {
            if showHands {
                HandsOverlay(frames: frames, unit: unit, target: handTarget, cycleStart: cycleStart)
                    .frame(width: size.width, height: size.height + Self.handsOverflow)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: step) { cycleStart = Date() }
    }
}

private struct KeyCapView: View {
    let key: KeyCap
    let isTarget: Bool
    let isWrong: Bool
    /// nil：普通显示；true：选中（完整颜色）；false：未选中（变淡）
    var emphasis: Bool? = nil
    let unit: CGFloat
    let spacing: CGFloat

    private var fill: Color {
        if isWrong { return Theme.bad }
        guard let finger = key.finger else { return Color(white: 0.82) }
        if isTarget || emphasis == true { return finger.color }
        return key.char == nil ? Color(white: 0.82) : finger.color.opacity(0.22)
    }

    var body: some View {
        let width = key.width * unit + (key.width - 1) * spacing
        let lit = isTarget || isWrong || emphasis == true
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fill)
            if isTarget {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white, lineWidth: 3)
            }
            VStack(spacing: 0) {
                if let shift = key.shiftLabel {
                    Text(shift).font(Theme.font(10, .medium)).opacity(0.6)
                }
                Text(key.label)
                    .font(key.char != nil && key.id != " " ? Theme.font(19, .bold) : Theme.font(11, .medium))
            }
            .foregroundStyle(lit ? .white : Theme.ink)

            if key.id == "f" || key.id == "j" {
                Capsule()
                    .fill(lit ? .white : Theme.ink.opacity(0.5))
                    .frame(width: 12, height: 3)
                    .offset(y: unit * 0.32)
            }
        }
        .frame(width: width, height: unit)
        .shadow(color: isTarget || isWrong ? fill.opacity(0.7) : .black.opacity(0.12),
                radius: isTarget || isWrong ? 10 : 1, y: isTarget || isWrong ? 0 : 1)
        .opacity(emphasis == false ? 0.45 : 1)
        .scaleEffect(isTarget ? 1.12 : 1)
        .zIndex(lit ? 1 : 0)
        .animation(.spring(duration: 0.25), value: isTarget)
        .animation(.easeOut(duration: 0.1), value: isWrong)
        .animation(.easeOut(duration: 0.15), value: emphasis)
    }
}

/// 一个小键帽徽章，用在提示文字里。
struct KeyBadge: View {
    let char: Character
    var size: CGFloat = 40

    var body: some View {
        let finger = KeyboardLayout.fingers(for: char).first
        let target = KeyboardLayout.target(for: char)
        let label = char == " " ? "空格" : (target.key.isLetter ? target.key.uppercased() : String(target.key))
        Text(target.needsShift ? "⇧ \(label)" : label)
            .font(Theme.font(char == " " ? size * 0.4 : size * 0.5, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, char == " " || target.needsShift ? size * 0.3 : 0)
            .frame(minWidth: size, minHeight: size)
            .background(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(finger?.color ?? Theme.accent))
    }
}
