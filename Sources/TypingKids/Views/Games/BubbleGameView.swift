import Combine
import SwiftUI

struct BubbleGameView: View {
    let onExit: () -> Void

    @Environment(ProgressStore.self) private var progress
    @State private var game: BubbleGame
    @State private var isNewHigh = false
    @State private var shake = 0
    @AppStorage("bubbleShowPinyin") private var showPinyin = true

    private let timer = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    init(onExit: @escaping () -> Void, game: BubbleGame = BubbleGame()) {
        self.onExit = onExit
        _game = State(initialValue: game)
    }

    var body: some View {
        VStack(spacing: 16) {
            GameTopBar(game: .bubbles, onExit: onExit) {
                if game.phase == .playing { typingBox }
                GameChip(icon: "⭐", value: "\(game.score)")
                GameChip(icon: "🔥", value: "连击 \(game.combo)")
                GameChip(icon: "⏱", value: "\(Int(game.timeLeft.rounded(.up)))秒")
            }
            GeometryReader { geo in
                ZStack {
                    LinearGradient(colors: [Color(red: 0.25, green: 0.55, blue: 0.85), Color(red: 0.55, green: 0.85, blue: 0.95)],
                                   startPoint: .top, endPoint: .bottom)
                    seaFloor(in: geo.size)

                    ForEach(game.bubbles) { bubble in
                        BubbleView(bubble: bubble, typed: typedPrefix(for: bubble), showPinyin: game.showPinyin)
                            .position(x: bubble.x * geo.size.width + sin(game.elapsed * 1.5 + bubble.wobblePhase) * 12,
                                      y: geo.size.height * (1 - bubble.y))
                    }
                    ForEach(game.pops) { pop in
                        VStack(spacing: 2) {
                            Text("✨").font(.system(size: 50))
                            Text("\(pop.hanzi) +\(pop.points)").font(Theme.font(24, .heavy)).foregroundStyle(.white)
                        }
                        .scaleEffect(1 + pop.age)
                        .opacity(1 - pop.age / 0.7)
                        .position(x: pop.x * geo.size.width, y: geo.size.height * (1 - pop.y) - pop.age * 40)
                    }

                    switch game.phase {
                    case .ready: readyPanel
                    case .over: overPanel
                    case .playing: EmptyView()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        }
        .padding(24)
        .onAppear { game.showPinyin = showPinyin }
        .onReceive(timer) { now in
            if game.tick(now: now) {
                SoundFX.play(.finish)
                isNewHigh = progress.recordGame("bubbles", score: game.score, seconds: BubbleGame.roundLength)
                Cheer.say(isNewHigh ? VoiceLines.gameNewHigh : VoiceLines.gameOver, interrupt: true)
            }
        }
        .onKeyboardInput(handleKey)
    }

    private func typedPrefix(for bubble: BubbleGame.Bubble) -> Int {
        !game.buffer.isEmpty && bubble.pinyin.hasPrefix(game.buffer) ? game.buffer.count : 0
    }

    private func handleKey(_ press: KeyPress) {
        switch press.kind {
        case .escape: onExit()
        case .flagsChanged: break
        case .character(let c):
            switch game.phase {
            case .ready, .over:
                if c == " " {
                    isNewHigh = false
                    game.start()
                } else if c == "1" || c == "2" {
                    setShowPinyin(c == "1")
                }
            case .playing:
                switch game.type(c) {
                case .progress:
                    SoundFX.play(.correct(streak: game.buffer.count))
                case .popped:
                    SoundFX.play(.pop(combo: game.combo))
                    if game.combo % 10 == 0 {
                        SoundFX.play(.milestone)
                        Cheer.say(VoiceLines.comboLine(game.combo))
                    }
                case .wrong:
                    SoundFX.play(.wrong)
                    withAnimation(.linear(duration: 0.3)) { shake += 1 }
                case .ignored:
                    break
                }
            }
        }
    }

    private func setShowPinyin(_ on: Bool) {
        showPinyin = on
        game.showPinyin = on
    }

    private func seaFloor(in size: CGSize) -> some View {
        ZStack {
            Text("🪸").font(.system(size: 70)).position(x: size.width * 0.08, y: size.height - 40)
            Text("🐠").font(.system(size: 44)).position(x: size.width * 0.3, y: size.height - 60)
            Text("🌿").font(.system(size: 64)).position(x: size.width * 0.55, y: size.height - 36)
            Text("🐚").font(.system(size: 40)).position(x: size.width * 0.75, y: size.height - 28)
            Text("🪸").font(.system(size: 80)).position(x: size.width * 0.93, y: size.height - 44)
        }
        .opacity(0.85)
    }

    /// 顶栏里显示已经打出的拼音
    private var typingBox: some View {
        HStack(spacing: 8) {
            Text("⌨️")
            Text(game.buffer.isEmpty ? "打出拼音" : game.buffer)
                .font(game.buffer.isEmpty ? Theme.font(18, .semibold) : .system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(game.buffer.isEmpty ? Theme.ink.opacity(0.45) : Theme.good)
        }
        .frame(minWidth: 170)
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(Capsule().fill(.white))
        .overlay(Capsule().stroke(Theme.good.opacity(game.buffer.isEmpty ? 0 : 0.8), lineWidth: 2))
        .modifier(ShakeEffect(animatableData: CGFloat(shake)))
    }

    private var readyPanel: some View {
        GamePanel {
            Text("🫧 拼音泡泡").font(Theme.font(40, .heavy))
            Text("泡泡里写着词语，打出它的拼音就能戳破！\n一局 60 秒，连续戳中还有额外加分。")
                .font(Theme.font(19))
            Text("选择难度（也可以按数字键 1 2）")
                .font(Theme.font(16, .semibold)).foregroundStyle(.secondary)
            GameOptionButtons(options: [true, false], selected: game.showPinyin,
                              title: { $0 ? "显示拼音提示" : "不显示拼音（挑战）" }, onSelect: setShowPinyin)
            Text("按 空格键 开始！").font(Theme.font(26, .heavy)).foregroundStyle(Theme.good)
        }
    }

    private var overPanel: some View {
        GamePanel {
            Text(isNewHigh ? "🏆 新纪录！" : "⏰ 时间到！").font(Theme.font(40, .heavy))
            Text("得分 \(game.score)").font(Theme.font(56, .heavy)).foregroundStyle(Theme.accent)
            HStack(spacing: 28) {
                Text("戳破 \(game.hits) 个")
                Text("飘走 \(game.missed) 个")
                Text("最多连击 \(game.bestCombo)")
            }
            .font(Theme.font(20, .semibold))
            Text("最高分 \(progress.gameHighScore("bubbles"))").font(Theme.font(18)).foregroundStyle(.secondary)
            Text("按 空格键 再玩一次，按 esc 返回").font(Theme.font(20, .bold)).foregroundStyle(Theme.good)
        }
    }
}

private struct BubbleView: View {
    let bubble: BubbleGame.Bubble
    let typed: Int
    let showPinyin: Bool

    var body: some View {
        let size: CGFloat = 132
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.15), bubble.tint.opacity(0.45), bubble.tint.opacity(0.8)],
                                     center: .center, startRadius: size * 0.1, endRadius: size * 0.55))
            Circle().stroke(.white.opacity(0.85), lineWidth: 2.5)
            // 高光
            Ellipse()
                .fill(.white.opacity(0.75))
                .frame(width: size * 0.22, height: size * 0.12)
                .rotationEffect(.degrees(-35))
                .offset(x: -size * 0.24, y: -size * 0.28)
            VStack(spacing: 4) {
                Text(bubble.hanzi)
                    .font(Theme.font(bubble.hanzi.count > 3 ? 26 : 32, .heavy))
                    .foregroundStyle(Theme.ink)
                if showPinyin || typed > 0 {
                    pinyinText
                }
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(typed > 0 ? 1.08 : 1)
        .shadow(color: typed > 0 ? .yellow.opacity(0.8) : .clear, radius: 12)
        .animation(.spring(duration: 0.2), value: typed)
    }

    /// 已经打出的字母变绿；不显示拼音时只显示打出的部分
    private var pinyinText: some View {
        let done = String(bubble.pinyin.prefix(typed))
        let rest = showPinyin ? String(bubble.pinyin.dropFirst(typed)) : ""
        return (Text(done).foregroundColor(Theme.good) + Text(rest).foregroundColor(Theme.ink.opacity(0.6)))
            .font(.system(size: 17, weight: .bold, design: .monospaced))
    }
}
