import Combine
import SwiftUI

struct BalloonGameView: View {
    let onExit: () -> Void

    @Environment(ProgressStore.self) private var progress
    @State private var game = BalloonGame()
    @State private var isNewHigh = false
    @AppStorage("balloonKeySet") private var keySetRaw = BalloonKeySet.home.rawValue

    private let timer = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            topBar
            GeometryReader { geo in
                ZStack {
                    LinearGradient(colors: [Color(red: 0.55, green: 0.8, blue: 1), Color(red: 0.85, green: 0.95, blue: 1)],
                                   startPoint: .top, endPoint: .bottom)
                    clouds(in: geo.size)

                    ForEach(game.balloons) { balloon in
                        BalloonView(char: balloon.char, color: balloon.color)
                            .position(x: balloon.x * geo.size.width + sin(game.elapsed * 2 + balloon.wobblePhase) * 10,
                                      y: yPosition(balloon.y, height: geo.size.height))
                    }
                    ForEach(game.pops) { pop in
                        VStack(spacing: 0) {
                            Text("💥").font(.system(size: 56))
                            Text("+\(pop.points)").font(Theme.font(24, .heavy)).foregroundStyle(Theme.warn)
                        }
                        .scaleEffect(1 + pop.age)
                        .opacity(1 - pop.age / 0.6)
                        .position(x: pop.x * geo.size.width, y: yPosition(pop.y, height: geo.size.height) - pop.age * 40)
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
        .onAppear { game.keySet = BalloonKeySet(rawValue: keySetRaw) ?? .home }
        .onReceive(timer) { now in
            if game.tick(now: now) {
                SoundFX.play(.finish)
                isNewHigh = progress.recordGame("balloon", score: game.score, seconds: BalloonGame.roundLength)
                Cheer.say(isNewHigh ? VoiceLines.gameNewHigh : VoiceLines.gameOver, interrupt: true)
            }
        }
        .onKeyboardInput(handleKey)
    }

    private func yPosition(_ y: CGFloat, height: CGFloat) -> CGFloat {
        height - y * height
    }

    private func handleKey(_ press: KeyPress) {
        switch press.kind {
        case .escape:
            onExit()
        case .flagsChanged:
            break
        case .character(let c):
            switch game.phase {
            case .ready, .over:
                if c == " " {
                    isNewHigh = false
                    game.start()
                } else if game.phase == .ready, let n = Int(String(c)), (1...BalloonKeySet.allCases.count).contains(n) {
                    selectKeySet(BalloonKeySet.allCases[n - 1])
                }
            case .playing:
                if game.type(c) {
                    SoundFX.play(.pop(combo: game.combo))
                    if game.combo % 10 == 0 {
                        SoundFX.play(.milestone)
                        Cheer.say(VoiceLines.comboLine(game.combo))
                    }
                } else {
                    SoundFX.play(.wrong)
                }
            }
        }
    }

    private func selectKeySet(_ set: BalloonKeySet) {
        game.keySet = set
        keySetRaw = set.rawValue
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            Button { onExit() } label: { Label("返回", systemImage: "chevron.left") }
                .buttonStyle(KidButtonStyle(color: Color(white: 0.6)))
            Text("🎈 字母气球")
                .font(Theme.font(28, .heavy))
                .foregroundStyle(Theme.ink)
            Spacer()
            GameChip(icon: "⭐", value: "\(game.score)")
            GameChip(icon: "🔥", value: "连击 \(game.combo)")
            GameChip(icon: "⏱", value: "\(Int(game.timeLeft.rounded(.up)))秒")
        }
    }

    private func clouds(in size: CGSize) -> some View {
        ZStack {
            Text("☁️").font(.system(size: 90)).position(x: size.width * 0.15, y: size.height * 0.2)
            Text("☁️").font(.system(size: 70)).position(x: size.width * 0.7, y: size.height * 0.12)
            Text("☁️").font(.system(size: 110)).position(x: size.width * 0.85, y: size.height * 0.55)
            Text("☁️").font(.system(size: 60)).position(x: size.width * 0.35, y: size.height * 0.6)
        }
        .opacity(0.8)
    }

    private var readyPanel: some View {
        VStack(spacing: 18) {
            Text("🎈 字母气球").font(Theme.font(40, .heavy))
            Text("气球上写着字母，按下对应的键就能把它戳破！\n一局 60 秒，连续戳中还有额外加分。")
                .font(Theme.font(19))
                .multilineTextAlignment(.center)
            Text("选择字母范围（也可以按数字键 1 2 3）")
                .font(Theme.font(16, .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(Array(BalloonKeySet.allCases.enumerated()), id: \.element) { i, set in
                    Button { selectKeySet(set) } label: {
                        Text("\(i + 1). \(set.title)")
                    }
                    .buttonStyle(KidButtonStyle(color: game.keySet == set ? Theme.accent : Color(white: 0.72)))
                }
            }
            Text("按 空格键 开始！")
                .font(Theme.font(26, .heavy))
                .foregroundStyle(Theme.good)
                .padding(.top, 6)
        }
        .foregroundStyle(Theme.ink)
        .padding(40)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white.opacity(0.95)))
        .shadow(radius: 20)
    }

    private var overPanel: some View {
        VStack(spacing: 16) {
            Text(isNewHigh ? "🏆 新纪录！" : "⏰ 时间到！").font(Theme.font(40, .heavy))
            Text("得分 \(game.score)").font(Theme.font(56, .heavy)).foregroundStyle(Theme.accent)
            HStack(spacing: 28) {
                Text("戳破 \(game.hits) 个")
                Text("飞走 \(game.missed) 个")
                Text("最多连击 \(game.bestCombo)")
            }
            .font(Theme.font(20, .semibold))
            Text("最高分 \(progress.gameHighScore("balloon"))")
                .font(Theme.font(18))
                .foregroundStyle(.secondary)
            Text("按 空格键 再玩一次，按 esc 返回")
                .font(Theme.font(20, .bold))
                .foregroundStyle(Theme.good)
                .padding(.top, 6)
        }
        .foregroundStyle(Theme.ink)
        .padding(40)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white.opacity(0.95)))
        .shadow(radius: 20)
    }
}

private struct BalloonView: View {
    let char: Character
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [color.opacity(0.7), color], center: UnitPoint(x: 0.35, y: 0.3),
                                         startRadius: 2, endRadius: 55))
                    .frame(width: 78, height: 92)
                Ellipse()
                    .fill(.white.opacity(0.55))
                    .frame(width: 13, height: 22)
                    .rotationEffect(.degrees(20))
                    .offset(x: -20, y: -22)
                Text(String(char))
                    .font(Theme.font(44, .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            }
            Triangle().fill(color).frame(width: 12, height: 8)
            Rectangle().fill(Color.gray.opacity(0.6)).frame(width: 1.5, height: 44)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
