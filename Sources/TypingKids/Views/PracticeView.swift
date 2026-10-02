import AppKit
import SwiftUI

struct PracticeView: View {
    let lesson: Lesson
    let onExit: () -> Void
    let onFinish: (PracticeResult) -> Void

    @State private var session: PracticeSession
    @State private var started = false
    @State private var capsLockOn = NSEvent.modifierFlags.contains(.capsLock)
    @State private var flashWrong = false
    @AppStorage("showKeyboard") private var showKeyboard = true
    @AppStorage("showHands") private var showHands = true

    init(lesson: Lesson, onExit: @escaping () -> Void, onFinish: @escaping (PracticeResult) -> Void) {
        self.lesson = lesson
        self.onExit = onExit
        self.onFinish = onFinish
        _session = State(initialValue: PracticeSession(lesson: lesson))
    }

    var body: some View {
        VStack(spacing: 14) {
            topBar
            textCard
            feedbackLine
            if let current = session.current {
                fingerHint(for: current)
            }
            Spacer(minLength: 0)
            if showKeyboard { keyboardArea }
        }
        .padding(24)
        .overlay {
            if !started {
                ReadyOverlay(lesson: lesson)
                    .transition(.opacity)
            }
        }
        .onKeyboardInput(handleKey)
    }

    // MARK: - 按键处理

    private func handleKey(_ press: KeyPress) {
        capsLockOn = press.capsLock
        switch press.kind {
        case .escape:
            onExit()
        case .flagsChanged:
            break
        case .character(let c):
            guard started else {
                if c == " " {
                    withAnimation(.easeOut(duration: 0.25)) { started = true }
                    Cheer.say(Cheer.pick(VoiceLines.start))
                }
                return
            }
            switch session.type(c) {
            case .correct:
                if session.streak % 10 == 0 {
                    SoundFX.play(.milestone)
                    Cheer.say(Cheer.pick(VoiceLines.praise))
                } else {
                    SoundFX.play(.correct(streak: session.streak))
                }
            case .wrong:
                SoundFX.play(.wrong)
                if session.wrongRun == 3 {
                    Cheer.say(Cheer.pick(VoiceLines.comfort), interrupt: true)
                }
                flashWrong = true
                let count = session.wrongCount
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if session.wrongCount == count { flashWrong = false }
                }
            case .finished:
                SoundFX.play(.finish)
                let result = session.result()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onFinish(result) }
            case .ignored:
                break
            }
        }
    }

    // MARK: - 顶部

    private var topBar: some View {
        HStack(spacing: 16) {
            Button { onExit() } label: {
                Label("返回", systemImage: "chevron.left")
            }
            .buttonStyle(KidButtonStyle(color: Color(white: 0.6)))
            .controlSize(.small)

            Text("\(lesson.emoji) \(lesson.title)")
                .font(Theme.font(26, .bold))
                .foregroundStyle(Theme.ink)

            Spacer()

            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                HStack(spacing: 12) {
                    StatChip(icon: "⏱", value: formatDuration(session.elapsed))
                    StatChip(icon: "🚀", value: "\(session.startDate == nil ? 0 : session.cpm) 字/分")
                    StatChip(icon: "🎯", value: "\(Int((session.accuracy * 100).rounded()))%")
                }
            }
        }
    }

    // MARK: - 练习文字

    private var textCard: some View {
        VStack(spacing: 14) {
            FlowLayout(spacing: 0, lineSpacing: 10) {
                ForEach(session.units) { unit in
                    VStack(spacing: 2) {
                        if session.hasHints {
                            Text(unit.hint ?? " ")
                                .font(Theme.font(20, .semibold))
                                .foregroundStyle(unit.range.contains(session.index) ? Theme.accent : .secondary)
                        }
                        HStack(spacing: 0) {
                            ForEach(unit.range, id: \.self) { i in
                                CharCell(char: session.chars[i],
                                         state: session.state(at: i),
                                         isWrong: flashWrong && i == session.index,
                                         shakes: i == session.index ? session.wrongCount : 0)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            ProgressView(value: session.progress)
                .tint(Theme.good)
        }
        .card(padding: 22)
    }

    // MARK: - 鼓励 / 提醒

    @ViewBuilder
    private var feedbackLine: some View {
        Group {
            if capsLockOn {
                Text("⚠️ 大写锁定（caps lock）开着，请按一下它关掉哦")
                    .foregroundStyle(Theme.bad)
            } else if let wrong = session.lastWrong, let current = session.current {
                Text("哎呀，按成了 \(KeyboardLayout.displayName(wrong))，应该按 \(KeyboardLayout.displayName(current))，再试一次 😊")
                    .foregroundStyle(Theme.warn)
            } else if session.streak >= 10 {
                Text("🔥 连续打对 \(session.streak) 个，太厉害了！")
                    .foregroundStyle(Theme.good)
            } else {
                Text("眼睛看屏幕，手指找位置，不偷看键盘更厉害 👀")
                    .foregroundStyle(.secondary)
            }
        }
        .font(Theme.font(20, .semibold))
        .frame(height: 28)
    }

    private func fingerHint(for c: Character) -> some View {
        let fingers = KeyboardLayout.fingers(for: c)
        let target = KeyboardLayout.target(for: c)
        return HStack(spacing: 10) {
            Text("下一个").foregroundStyle(.secondary)
            KeyBadge(char: c, size: 44)
            if c == " " {
                Text("用 大拇指 按空格键").foregroundStyle(Finger.leftThumb.color)
            } else if let main = fingers.first {
                Text("用").foregroundStyle(.secondary)
                Text(main.name).foregroundStyle(main.color)
                if target.needsShift, fingers.count > 1 {
                    Text("，").foregroundStyle(.secondary)
                    Text(fingers[1].name).foregroundStyle(fingers[1].color)
                    Text("按住 Shift").foregroundStyle(.secondary)
                }
            }
        }
        .font(Theme.font(22, .bold))
    }

    // MARK: - 键盘和小手

    private var keyboardArea: some View {
        let current = session.current
        let highlighted = current.map { KeyboardLayout.highlightedKeyIDs(for: $0) } ?? []
        let flashed = flashWrong ? session.lastWrong.map { String(KeyboardLayout.target(for: $0).key) } : nil
        return KeyboardView(highlighted: highlighted, flashed: flashed,
                            showHands: showHands, handTarget: current,
                            step: session.index &+ session.wrongCount << 20)
            .padding(.bottom, showHands ? KeyboardView.handsOverflow : 0)
    }
}

// MARK: - 子视图

private struct CharCell: View {
    let char: Character
    let state: CellState
    let isWrong: Bool
    let shakes: Int

    var body: some View {
        let isSpace = char == " "
        ZStack {
            if state == .current {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isWrong ? Theme.bad.opacity(0.85) : Color(red: 1, green: 0.88, blue: 0.35))
                    .shadow(color: .orange.opacity(0.3), radius: 6)
                Capsule()
                    .fill(isWrong ? .white : Theme.ink)
                    .frame(width: 22, height: 4)
                    .offset(y: 20)
            }
            Text(isSpace ? (state == .current ? "␣" : " ") : String(char))
                .font(.system(size: 36, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(width: 32, height: 50)
        .scaleEffect(state == .current ? 1.12 : 1)
        .modifier(ShakeEffect(animatableData: CGFloat(shakes)))
        .animation(.linear(duration: 0.3), value: shakes)
        .animation(.spring(duration: 0.2), value: state == .current)
    }

    private var color: Color {
        switch state {
        case .done: Theme.good
        case .fixed: Theme.warn
        case .current: isWrong ? .white : Theme.ink
        case .pending: Theme.ink.opacity(0.45)
        }
    }
}

private struct StatChip: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(icon)
            Text(value).monospacedDigit()
        }
        .font(Theme.font(18, .bold))
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(.white))
    }
}

private struct ReadyOverlay: View {
    let lesson: Lesson

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 20) {
                Text(lesson.emoji).font(.system(size: 64))
                Text(lesson.title)
                    .font(Theme.font(32, .heavy))
                    .foregroundStyle(Theme.ink)

                if !lesson.newKeys.isEmpty && lesson.newKeys.count <= 20 {
                    Text("这次要练的键")
                        .font(Theme.font(18, .semibold))
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 12, lineSpacing: 10) {
                        ForEach(Array(lesson.newKeys), id: \.self) { c in
                            VStack(spacing: 6) {
                                KeyBadge(char: c, size: lesson.newKeys.count > 10 ? 44 : 54)
                                Text(KeyboardLayout.fingers(for: c).first?.name ?? "")
                                    .font(Theme.font(13, .semibold))
                                    .foregroundStyle(KeyboardLayout.fingers(for: c).first?.color ?? .secondary)
                            }
                        }
                    }
                    .frame(maxWidth: 900)
                } else if lesson.newKeys.count > 20 {
                    Text("这次要练 \(lesson.newKeys.count) 个键，加油！")
                        .font(Theme.font(18, .semibold))
                        .foregroundStyle(.secondary)
                }

                Text(lesson.tip)
                    .font(Theme.font(19))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 560)

                Text("准备好了吗？按 空格键 开始！")
                    .font(Theme.font(24, .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.accent))

                Text("按 esc 返回")
                    .font(Theme.font(15))
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(.white))
            .shadow(radius: 30)
        }
    }
}
