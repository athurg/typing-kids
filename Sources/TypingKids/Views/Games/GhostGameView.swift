import Combine
import SwiftUI

struct GhostGameView: View {
    let onExit: () -> Void

    @Environment(ProgressStore.self) private var progress
    @State private var game: GhostGame
    @State private var isNewRecord = false
    /// 一直走的时钟，用来让幽灵上下飘、星星闪
    @State private var clock: Double = 0
    @AppStorage("ghostKeySet") private var keySetRaw = BalloonKeySet.home.rawValue

    private let timer = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    init(onExit: @escaping () -> Void, game: GhostGame = GhostGame()) {
        self.onExit = onExit
        _game = State(initialValue: game)
    }

    var body: some View {
        VStack(spacing: 16) {
            GameTopBar(game: .ghost, onExit: onExit) {
                GameChip(icon: "👻", value: "还剩 \(game.ghostsLeft) 只")
                GameChip(icon: "⏱", value: "\(Int(game.elapsed.rounded()))秒")
                let best = progress.gameHighScore("ghost")
                GameChip(icon: "🏆", value: best > 0 ? "最快 \(best)秒" : "还没通关")
            }
            GeometryReader { geo in
                ZStack {
                    NightForest(clock: clock)

                    ForEach(0..<GhostGame.lanes, id: \.self) { lane in
                        DragonView(isCaught: game.caughtLane == lane)
                            .position(x: GhostGame.dragonX * geo.size.width, y: laneY(lane, geo.size))
                    }
                    ForEach(game.fireballs) { fb in
                        FireballView()
                            .position(x: fb.x * geo.size.width, y: laneY(fb.lane, geo.size))
                    }
                    ForEach(game.ghosts) { ghost in
                        if ghost.isAlive || (ghost.vanishAge ?? 0) < GhostGame.vanishDuration {
                            GhostView(ghost: ghost, isWaiting: game.hasIncoming(ghost))
                                .position(x: ghost.x * geo.size.width,
                                          y: laneY(ghost.id, geo.size) + sin(clock * 2.2 + Double(ghost.id) * 2) * 8)
                        }
                    }

                    switch game.phase {
                    case .ready: readyPanel
                    case .won: if allVanished { wonPanel }
                    case .lost: lostPanel
                    case .playing: EmptyView()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        }
        .padding(24)
        .onAppear {
            game.selectKeySet(BalloonKeySet(rawValue: keySetRaw) ?? .home)
        }
        .onReceive(timer) { now in
            clock = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
            for event in game.tick(now: now) {
                switch event {
                case .hit:
                    SoundFX.play(.ghostHit)
                case .vanished:
                    SoundFX.play(.ghostVanish)
                case .won:
                    SoundFX.play(.finish)
                    isNewRecord = progress.recordFastest("ghost", seconds: game.elapsed)
                    Cheer.say(isNewRecord ? VoiceLines.gameNewHigh : VoiceLines.ghostWin, interrupt: true)
                case .lost:
                    SoundFX.play(.splash)
                    progress.recordGame("ghost", score: 0, seconds: game.elapsed)
                    Cheer.say(VoiceLines.ghostLose, interrupt: true)
                }
            }
        }
        .onKeyboardInput(handleKey)
    }

    /// 三排小龙和幽灵的纵坐标
    private func laneY(_ lane: Int, _ size: CGSize) -> CGFloat {
        size.height * (0.3 + 0.26 * CGFloat(lane))
    }

    private var allVanished: Bool {
        game.ghosts.allSatisfy { ($0.vanishAge ?? .infinity) >= GhostGame.vanishDuration }
    }

    // MARK: - 按键

    private func handleKey(_ press: KeyPress) {
        switch press.kind {
        case .escape: onExit()
        case .flagsChanged: break
        case .character(let c):
            switch game.phase {
            case .ready, .won, .lost:
                if c == " " {
                    isNewRecord = false
                    game.start()
                    Cheer.say(VoiceLines.ghostStart)
                } else if let n = Int(String(c)), (1...BalloonKeySet.allCases.count).contains(n) {
                    selectKeySet(BalloonKeySet.allCases[n - 1])
                }
            case .playing:
                switch game.type(c) {
                case .fired: SoundFX.play(.fireball)
                case .wrong: SoundFX.play(.wrong)
                case .ignored: break
                }
            }
        }
    }

    private func selectKeySet(_ set: BalloonKeySet) {
        game.selectKeySet(set)
        keySetRaw = set.rawValue
    }

    // MARK: - 面板

    private var keySetPicker: some View {
        GameOptionButtons(options: BalloonKeySet.allCases, selected: game.keySet,
                          title: \.title, onSelect: selectKeySet)
    }

    private var readyPanel: some View {
        GamePanel {
            Text("👻 打幽灵").font(Theme.font(40, .heavy))
            Text("幽灵身上有字母，按下这个字母，小龙就会喷出火球！\n每只幽灵要打中 5 次。按错了幽灵会往前冲一段，别让它碰到小龙哦。")
                .font(Theme.font(19))
            Text("选择字母范围（也可以按数字键 1 2 3）")
                .font(Theme.font(16, .semibold)).foregroundStyle(.secondary)
            keySetPicker
            Text("按 空格键 开始！").font(Theme.font(26, .heavy)).foregroundStyle(Theme.good)
        }
    }

    private var wonPanel: some View {
        GamePanel {
            Text(isNewRecord ? "🏆 新纪录！" : "🎉 你赢了！").font(Theme.font(40, .heavy))
            Text("用时 \(Int(game.elapsed.rounded())) 秒").font(Theme.font(52, .heavy)).foregroundStyle(Theme.accent)
            Text("最快纪录 \(progress.gameHighScore("ghost")) 秒").font(Theme.font(19, .semibold)).foregroundStyle(.secondary)
            keySetPicker
            Text("按 空格键 再玩一次，按 esc 返回").font(Theme.font(20, .bold)).foregroundStyle(Theme.good)
        }
    }

    private var lostPanel: some View {
        GamePanel {
            Text("😱 幽灵碰到小龙了").font(Theme.font(40, .heavy))
            Text("打跑了 \(GhostGame.lanes - game.ghostsLeft) 只幽灵，命中 \(game.hits) 次")
                .font(Theme.font(28, .heavy)).foregroundStyle(Theme.accent)
            Text("别着急，看准幽灵身上的字母再按").font(Theme.font(19, .semibold)).foregroundStyle(.secondary)
            keySetPicker
            Text("按 空格键 再玩一次，按 esc 返回").font(Theme.font(20, .bold)).foregroundStyle(Theme.good)
        }
    }
}

// MARK: - 场景

/// 黑夜里的森林空地：夜空、月亮、星星、四周一圈树，中间是草地
private struct NightForest: View {
    let clock: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(colors: [Color(red: 0.05, green: 0.06, blue: 0.20), Color(red: 0.13, green: 0.14, blue: 0.36)],
                               startPoint: .top, endPoint: .bottom)
                Canvas { ctx, size in
                    // 星星：位置固定，亮度慢慢闪
                    var rng = SeededRandom(seed: 7)
                    for i in 0..<60 {
                        let x = rng.next() * size.width
                        let y = rng.next() * size.height * 0.3
                        let r = 1 + rng.next() * 1.8
                        let alpha = 0.45 + 0.45 * sin(clock * 1.5 + Double(i))
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(alpha)))
                    }
                }
                // 月亮
                Circle()
                    .fill(Color(red: 1, green: 0.96, blue: 0.78))
                    .frame(width: 70, height: 70)
                    .shadow(color: Color(red: 1, green: 0.95, blue: 0.7).opacity(0.8), radius: 30)
                    .position(x: w * 0.5, y: h * 0.1)

                // 远处的一排树
                treeRow(count: 16, y: h * 0.2, size: 80, width: w, offset: 0, darkness: 0.25)
                // 空地上的草地
                Ellipse()
                    .fill(RadialGradient(colors: [Color(red: 0.16, green: 0.32, blue: 0.22), Color(red: 0.07, green: 0.16, blue: 0.13)],
                                         center: .center, startRadius: 20, endRadius: w * 0.55))
                    .frame(width: w * 1.25, height: h * 0.95)
                    .position(x: w / 2, y: h * 0.72)
                // 近处的树：围在空地上下边缘
                treeRow(count: 13, y: h * 0.24, size: 100, width: w, offset: 45, darkness: 0.4)
                treeRow(count: 13, y: h * 1.02, size: 110, width: w, offset: 20, darkness: 0.35)
                // 萤火虫
                ForEach(0..<8, id: \.self) { i in
                    let d = Double(i)
                    Circle()
                        .fill(Color(red: 0.85, green: 1, blue: 0.4))
                        .frame(width: 5, height: 5)
                        .shadow(color: .yellow, radius: 6)
                        .opacity(0.5 + 0.5 * sin(clock * 2 + d * 1.3))
                        .position(x: w * (0.25 + 0.07 * d) + sin(clock * 0.6 + d) * 30,
                                  y: h * (0.4 + 0.06 * Double(i % 5)) + cos(clock * 0.8 + d * 2) * 20)
                }
            }
        }
    }

    private func treeRow(count: Int, y: CGFloat, size: CGFloat, width: CGFloat, offset: CGFloat, darkness: Double) -> some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                Text(i % 3 == 1 ? "🌳" : "🌲")
                    .font(.system(size: size * (i % 2 == 0 ? 1 : 0.85)))
                    .position(x: offset + CGFloat(i) * width / CGFloat(count - 1), y: y - (i % 2 == 0 ? 0 : 10))
            }
        }
        .brightness(-0.45)
        .saturation(0.6)
        .opacity(1 - darkness * 0.5)
    }
}

/// 固定种子的随机数，让星星每帧都在同一个位置
private struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(1 << 53)
    }
}

private struct DragonView: View {
    let isCaught: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .fill(.black.opacity(0.3))
                .frame(width: 90, height: 18)
                .offset(y: 48)
            Text("🐉")
                .font(.system(size: 92))
                .scaleEffect(x: -1, y: 1)   // 让小龙面朝右边的幽灵
            if isCaught {
                Text("😵").font(.system(size: 40)).offset(x: 10, y: -50)
            }
        }
        .saturation(isCaught ? 0.2 : 1)
    }
}

private struct FireballView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.yellow.opacity(0.9), .orange.opacity(0.6), .clear],
                                     center: .center, startRadius: 2, endRadius: 30))
                .frame(width: 60, height: 60)
            Text("🔥")
                .font(.system(size: 44))
                .rotationEffect(.degrees(-90))  // 火苗尾巴拖在后面
        }
    }
}

private struct GhostView: View {
    let ghost: GhostGame.Ghost
    /// 火球已经在路上，字母先变暗
    let isWaiting: Bool

    var body: some View {
        let flash = ghost.hitAge < 0.3
        let vanish = (ghost.vanishAge ?? 0) / GhostGame.vanishDuration
        VStack(spacing: 6) {
            ZStack {
                GhostShape()
                    .fill(LinearGradient(colors: [.white, Color(red: 0.82, green: 0.86, blue: 1)],
                                         startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(red: 0.7, green: 0.8, blue: 1).opacity(0.9), radius: 16)
                    .frame(width: 104, height: 118)
                    .colorMultiply(flash ? Color(red: 1, green: 0.55, blue: 0.5) : .white)
                // 眼睛和嘴巴
                HStack(spacing: 22) {
                    Capsule().fill(Theme.ink).frame(width: 11, height: 16)
                    Capsule().fill(Theme.ink).frame(width: 11, height: 16)
                }
                .offset(y: -32)
                Ellipse().fill(Theme.ink).frame(width: 12, height: flash ? 12 : 6).offset(y: -15)
                // 身上的字母
                if ghost.isAlive {
                    Text(String(ghost.char))
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.45, green: 0.25, blue: 0.85))
                        .opacity(isWaiting ? 0.3 : 1)
                        .offset(y: 24)
                }
                if flash {
                    Text("💥").font(.system(size: 50)).offset(x: -40, y: 10)
                        .opacity(1 - ghost.hitAge / 0.3)
                }
            }
            .offset(x: flash ? sin(ghost.hitAge * 60) * 5 : 0)
            // 血条：5 格
            HStack(spacing: 4) {
                ForEach(0..<GhostGame.maxHP, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i < ghost.hp ? Color(red: 1, green: 0.4, blue: 0.45) : .white.opacity(0.25))
                        .frame(width: 14, height: 8)
                }
            }
            .opacity(ghost.isAlive ? 1 : 0)
        }
        .overlay(alignment: .trailing) {
            if ghost.dash > 0 && ghost.isAlive {
                Text("💨").font(.system(size: 40)).offset(x: 34, y: -10)
            }
        }
        .scaleEffect(1 + vanish * 0.6)
        .opacity(1 - vanish)
        .offset(y: -vanish * 50)
        .overlay {
            if ghost.vanishAge != nil {
                Text("✨").font(.system(size: 70)).opacity(1 - vanish).scaleEffect(0.5 + vanish)
            }
        }
    }
}

/// 幽灵的身体：圆顶，下摆是波浪
private struct GhostShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let r = rect.width / 2
            let bottom = rect.maxY
            p.move(to: CGPoint(x: rect.minX, y: rect.minY + r))
            p.addArc(center: CGPoint(x: rect.midX, y: rect.minY + r), radius: r,
                     startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: CGPoint(x: rect.maxX, y: bottom - 10))
            // 下摆：四个小波浪
            let waves = 4
            let step = rect.width / CGFloat(waves)
            for i in 0..<waves {
                let x0 = rect.maxX - CGFloat(i) * step
                p.addQuadCurve(to: CGPoint(x: x0 - step, y: bottom - 10),
                               control: CGPoint(x: x0 - step / 2, y: i % 2 == 0 ? bottom + 8 : bottom - 22))
            }
            p.closeSubpath()
        }
    }
}
