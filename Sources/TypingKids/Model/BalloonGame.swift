import SwiftUI
import Observation

enum BalloonKeySet: String, CaseIterable, Identifiable {
    case home, homeTop, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "基准键"
        case .homeTop: "基准键 + 上排"
        case .all: "全部字母"
        }
    }

    var keys: [Character] {
        switch self {
        case .home: Array("asdfghjkl")
        case .homeTop: Array("asdfghjklqwertyuiop")
        case .all: Array("abcdefghijklmnopqrstuvwxyz")
        }
    }
}

/// 字母气球：气球从下往上飘，按下气球上的字母就能把它戳破。
@Observable
final class BalloonGame {
    enum Phase { case ready, playing, over }

    struct Balloon: Identifiable {
        let id = UUID()
        let char: Character
        let x: CGFloat          // 0...1 水平位置
        var y: CGFloat          // 0 底部 ... 1 顶部
        let speed: CGFloat
        let color: Color
        let wobblePhase: Double
    }

    struct Pop: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let points: Int
        var age: Double = 0
    }

    static let roundLength: Double = 60
    private static let colors: [Color] = [
        Color(red: 1.0, green: 0.35, blue: 0.4), Color(red: 1.0, green: 0.6, blue: 0.15),
        Color(red: 0.95, green: 0.75, blue: 0.1), Color(red: 0.3, green: 0.75, blue: 0.4),
        Color(red: 0.2, green: 0.6, blue: 0.95), Color(red: 0.6, green: 0.4, blue: 0.95),
        Color(red: 0.95, green: 0.4, blue: 0.75),
    ]

    var keySet: BalloonKeySet = .home
    private(set) var phase: Phase = .ready
    private(set) var balloons: [Balloon] = []
    private(set) var pops: [Pop] = []
    private(set) var score = 0
    private(set) var combo = 0
    private(set) var bestCombo = 0
    private(set) var hits = 0
    private(set) var missed = 0
    private(set) var wrong = 0
    private(set) var timeLeft = BalloonGame.roundLength
    private(set) var elapsed: Double = 0

    @ObservationIgnored private var spawnCountdown: Double = 0
    @ObservationIgnored private var lastTick: Date?

    func start() {
        balloons = []
        pops = []
        score = 0; combo = 0; bestCombo = 0; hits = 0; missed = 0; wrong = 0
        timeLeft = Self.roundLength
        elapsed = 0
        spawnCountdown = 0
        lastTick = nil
        phase = .playing
    }

    /// 每帧调用。返回 true 表示这一局刚刚结束。
    func tick(now: Date) -> Bool {
        defer { lastTick = now }
        guard phase == .playing else { return false }
        let dt = min(now.timeIntervalSince(lastTick ?? now), 0.05)

        elapsed += dt
        timeLeft -= dt
        if timeLeft <= 0 {
            timeLeft = 0
            phase = .over
            return true
        }

        spawnCountdown -= dt
        if spawnCountdown <= 0 {
            spawn()
            spawnCountdown = max(0.75, 1.7 - elapsed * 0.015)
        }

        for i in balloons.indices { balloons[i].y += balloons[i].speed * dt }
        let escaped = balloons.filter { $0.y > 1.15 }.count
        if escaped > 0 {
            missed += escaped
            combo = 0
            balloons.removeAll { $0.y > 1.15 }
        }

        for i in pops.indices { pops[i].age += dt }
        pops.removeAll { $0.age > 0.6 }
        return false
    }

    private func spawn() {
        let onScreen = Set(balloons.map(\.char))
        let candidates = keySet.keys.filter { !onScreen.contains($0) }
        guard let char = (candidates.isEmpty ? keySet.keys : candidates).randomElement() else { return }
        let speed = CGFloat(0.075 + elapsed * 0.0009) * CGFloat.random(in: 0.85...1.15)
        balloons.append(Balloon(char: char, x: .random(in: 0.08...0.92), y: -0.12,
                                speed: speed, color: Self.colors.randomElement()!,
                                wobblePhase: .random(in: 0...(2 * .pi))))
    }

    /// 返回 true 表示戳破了一个气球。
    func type(_ c: Character) -> Bool {
        guard phase == .playing else { return false }
        let key = Character(c.lowercased())
        // 同一个字母有多个气球时，先戳飞得最高的那个
        guard let i = balloons.indices.filter({ balloons[$0].char == key }).max(by: { balloons[$0].y < balloons[$1].y }) else {
            wrong += 1
            combo = 0
            return false
        }
        let b = balloons.remove(at: i)
        let points = 10 + min(combo, 10)
        score += points
        combo += 1
        bestCombo = max(bestCombo, combo)
        hits += 1
        pops.append(Pop(x: b.x, y: b.y, points: points))
        return true
    }
}
