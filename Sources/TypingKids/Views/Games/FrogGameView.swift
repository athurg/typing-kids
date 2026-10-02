import Combine
import SwiftUI

struct FrogGameView: View {
    let onExit: () -> Void

    @Environment(ProgressStore.self) private var progress
    @State private var game: FrogGame
    @State private var isNewHigh = false
    @State private var shake = 0
    @AppStorage("frogMode") private var savedMode = FrogGame.Mode.home.rawValue

    private let timer = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()
    /// 荷叶之间的距离
    private let spacing: CGFloat = 200

    init(onExit: @escaping () -> Void, game: FrogGame = FrogGame()) {
        self.onExit = onExit
        _game = State(initialValue: game)
    }

    var body: some View {
        VStack(spacing: 16) {
            GameTopBar(game: .frog, onExit: onExit) {
                GameChip(icon: "🍃", value: "跳了 \(game.score) 片")
                GameChip(icon: "❤️", value: "×\(max(game.lives, 0))")
                GameChip(icon: "🏆", value: "\(progress.gameHighScore("frog"))")
            }
            GeometryReader { geo in
                ZStack {
                    river(size: geo.size)
                    ForEach(visiblePads) { pad in
                        LilyPad(pad: pad,
                                isTarget: pad.id == game.frogIndex + 1 && game.phase != .ready,
                                typed: pad.id == game.frogIndex + 1 ? game.buffer.count : 0,
                                sink: pad.id == game.frogIndex ? game.sinkRatio : 0,
                                shake: pad.id == game.frogIndex + 1 ? shake : 0,
                                isPassed: pad.id <= game.frogIndex)
                            .position(screenPosition(of: pad.id, size: geo.size))
                    }
                    frog(size: geo.size)

                    switch game.phase {
                    case .ready: readyPanel
                    case .over: overPanel
                    case .playing, .splashing: EmptyView()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        }
        .padding(24)
        .onAppear {
            game.mode = FrogGame.Mode(rawValue: savedMode) ?? .home
            if game.pads.isEmpty { game.start(); game.forceReady() }
        }
        .onReceive(timer) { now in
            let wasPlaying = game.phase == .playing
            if game.tick(now: now) {
                SoundFX.play(.finish)
                isNewHigh = progress.recordGame("frog", score: game.score, seconds: game.elapsed)
                Cheer.say(isNewHigh ? VoiceLines.gameNewHigh : VoiceLines.gameOver, interrupt: true)
            } else if wasPlaying && game.phase == .splashing {
                SoundFX.play(.splash)
                if game.lives > 0 { Cheer.say(VoiceLines.frogSplash, interrupt: true) }
            }
        }
        .onKeyboardInput(handleKey)
    }

    // MARK: - 位置

    private var visiblePads: [FrogGame.Pad] {
        game.pads.filter { $0.id >= game.frogIndex - 2 && $0.id <= game.frogIndex + 7 }
    }

    /// 青蛙当前的位置（跳跃中在两片荷叶之间）
    private var frogPosition: CGFloat {
        CGFloat(game.frogIndex - 1) + CGFloat(easeOut(game.jumpProgress))
    }

    private func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 2) }

    private func screenPosition(of padIndex: Int, size: CGSize) -> CGPoint {
        // 镜头跟着青蛙走：青蛙固定在画面左边 25% 处
        let x = size.width * 0.25 + (CGFloat(padIndex) - frogPosition) * spacing
        let wiggle: CGFloat = padIndex % 2 == 0 ? -40 : 40
        return CGPoint(x: x, y: size.height * 0.55 + (padIndex == 0 ? 0 : wiggle))
    }

    @ViewBuilder
    private func frog(size: CGSize) -> some View {
        // 镜头跟着青蛙，所以青蛙的横坐标固定；纵坐标在两片荷叶之间插值，再加上跳跃的弧线
        let from = screenPosition(of: max(game.frogIndex - 1, 0), size: size)
        let to = screenPosition(of: game.frogIndex, size: size)
        let t = CGFloat(easeOut(game.jumpProgress))
        let arc = sin(.pi * t) * 90
        let x = size.width * 0.25
        let y = from.y + (to.y - from.y) * t - arc - 20
        if game.phase == .splashing {
            let p = game.splashElapsed / FrogGame.splashDuration
            ZStack {
                Text("💦").font(.system(size: 80)).scaleEffect(0.6 + p).opacity(1 - p)
                Text("🐸").font(.system(size: 70)).offset(y: p * 60).opacity(max(0, 1 - p * 1.8))
            }
            .position(x: x, y: to.y)
        } else {
            Text("🐸")
                .font(.system(size: 76))
                .scaleEffect(game.jumpProgress < 1 ? 1.15 : 1)
                .position(x: x, y: game.frogIndex == 0 ? to.y - 20 : y)
        }
    }

    private func river(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, canvasSize in
                ctx.fill(Path(CGRect(origin: .zero, size: canvasSize)),
                         with: .linearGradient(Gradient(colors: [Color(red: 0.35, green: 0.7, blue: 0.95),
                                                                 Color(red: 0.2, green: 0.5, blue: 0.85)]),
                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: canvasSize.height)))
                // 跟着镜头移动的水波纹
                let t = timeline.date.timeIntervalSinceReferenceDate
                let shift = (frogPosition * spacing).truncatingRemainder(dividingBy: 160)
                for row in 0..<9 {
                    let y = CGFloat(row) * canvasSize.height / 8 + 20
                    for col in -1...Int(canvasSize.width / 160) + 1 {
                        let x = CGFloat(col) * 160 - shift + CGFloat(row % 2) * 80 + sin(t + Double(row)) * 8
                        var wave = Path()
                        wave.move(to: CGPoint(x: x, y: y))
                        wave.addQuadCurve(to: CGPoint(x: x + 40, y: y), control: CGPoint(x: x + 20, y: y - 8))
                        ctx.stroke(wave, with: .color(.white.opacity(0.35)), lineWidth: 2.5)
                    }
                }
            }
        }
    }

    // MARK: - 按键

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
                    Cheer.say(VoiceLines.frogStart)
                } else if let n = Int(String(c)), (1...FrogGame.Mode.allCases.count).contains(n) {
                    selectMode(FrogGame.Mode.allCases[n - 1])
                }
            case .splashing:
                break
            case .playing:
                switch game.type(c) {
                case .jumped: SoundFX.play(.jump)
                case .progress: SoundFX.play(.correct(streak: game.buffer.count))
                case .wrong:
                    SoundFX.play(.wrong)
                    withAnimation(.linear(duration: 0.3)) { shake += 1 }
                case .ignored: break
                }
            }
        }
    }

    private func selectMode(_ mode: FrogGame.Mode) {
        game.mode = mode
        savedMode = mode.rawValue
        if game.phase == .ready { game.start(); game.forceReady() }
    }

    // MARK: - 面板

    private var readyPanel: some View {
        GamePanel {
            Text("🐸 青蛙过河").font(Theme.font(40, .heavy))
            Text("打出下一片荷叶上的字，小青蛙就跳过去！\n脚下的荷叶会慢慢沉下去，要快点跳哦。")
                .font(Theme.font(19))
            Text("选择荷叶上的内容（也可以按数字键 1 2 3）")
                .font(Theme.font(16, .semibold)).foregroundStyle(.secondary)
            GameOptionButtons(options: FrogGame.Mode.allCases, selected: game.mode,
                              title: \.title, onSelect: selectMode)
            Text("按 空格键 开始！").font(Theme.font(26, .heavy)).foregroundStyle(Theme.good)
        }
    }

    private var overPanel: some View {
        GamePanel {
            Text(isNewHigh ? "🏆 新纪录！" : "🌊 游戏结束").font(Theme.font(40, .heavy))
            Text("跳过 \(game.score) 片荷叶").font(Theme.font(52, .heavy)).foregroundStyle(Theme.accent)
            Text("最高纪录 \(progress.gameHighScore("frog")) 片").font(Theme.font(19, .semibold)).foregroundStyle(.secondary)
            GameOptionButtons(options: FrogGame.Mode.allCases, selected: game.mode,
                              title: \.title, onSelect: selectMode)
            Text("按 空格键 再玩一次，按 esc 返回").font(Theme.font(20, .bold)).foregroundStyle(Theme.good)
        }
    }
}

private struct LilyPad: View {
    let pad: FrogGame.Pad
    let isTarget: Bool
    let typed: Int
    let sink: Double
    let shake: Int
    var isPassed = false

    var body: some View {
        let size: CGFloat = pad.label.count > 3 ? 150 : 130
        ZStack {
            // 荷叶：带一个缺口的圆
            LeafShape()
                .fill(RadialGradient(colors: [Color(red: 0.5, green: 0.85, blue: 0.35), Color(red: 0.2, green: 0.6, blue: 0.25)],
                                     center: .center, startRadius: 5, endRadius: size * 0.55))
                .overlay(LeafShape().stroke(Color(red: 0.15, green: 0.45, blue: 0.2), lineWidth: 2))
                .frame(width: size, height: size * 0.72)
                .shadow(color: isTarget ? .yellow.opacity(0.9) : .black.opacity(0.2), radius: isTarget ? 14 : 4, y: 3)

            if pad.id == 0 {
                Text("起点").font(Theme.font(18, .heavy)).foregroundStyle(.white.opacity(0.9))
            } else if !pad.label.isEmpty && !isPassed {
                let done = String(pad.label.prefix(typed))
                let rest = String(pad.label.dropFirst(typed))
                (Text(done).foregroundColor(.yellow) + Text(rest).foregroundColor(.white))
                    .font(.system(size: pad.label.count > 1 ? 30 : 46, weight: .heavy, design: .rounded))
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .offset(y: 12)
            }
        }
        .scaleEffect((isTarget ? 1.06 : 1) * (1 - 0.35 * sink))
        .opacity(1 - 0.55 * sink)
        .modifier(ShakeEffect(animatableData: CGFloat(shake)))
        .overlay {
            // 下沉时的水波圈
            if sink > 0.05 {
                Ellipse()
                    .stroke(.white.opacity(0.6 * sink), lineWidth: 3)
                    .frame(width: size * (1.1 + 0.3 * sink), height: size * 0.75 * (1.1 + 0.3 * sink))
            }
        }
        .animation(.spring(duration: 0.2), value: isTarget)
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let c = CGPoint(x: rect.midX, y: rect.midY)
            p.move(to: c)
            // 从缺口一侧画到另一侧（缺口朝右上）
            p.addArc(center: c, radius: rect.width / 2, startAngle: .degrees(-20), endAngle: .degrees(-55), clockwise: false)
            p.closeSubpath()
        }
        .applying(CGAffineTransform(translationX: -rect.midX, y: -rect.midY)
            .concatenating(CGAffineTransform(scaleX: 1, y: rect.height / rect.width))
            .concatenating(CGAffineTransform(translationX: rect.midX, y: rect.midY)))
    }
}
