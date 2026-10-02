import Foundation
import Observation

/// 打幽灵：左边三只小龙，右边三只小幽灵，每只幽灵身上有一个字母。
/// 按下字母，那一排的小龙就喷出火球，打中一次幽灵掉一格血并换一个字母，打中 5 次幽灵消失。
/// 幽灵会越走越快地朝小龙飘过来，每按错一次幽灵还会往前冲一小段；碰到任何一只小龙就输了，三只都打完就赢了。
@Observable
final class GhostGame {
    enum Phase { case ready, playing, won, lost }
    enum Outcome { case fired, wrong, ignored }
    /// tick 里发生的事，给界面播放音效和语音
    enum Event { case hit, vanished, won, lost }

    struct Ghost: Identifiable {
        let id: Int             // 也是所在的那一排
        var char: Character
        var hp = GhostGame.maxHP
        var x = GhostGame.ghostStartX
        let speedFactor: Double
        /// 被打中后的闪烁计时（秒）
        var hitAge: Double = 1
        /// 按错后还没冲完的距离
        var dash: Double = 0
        /// 血打完后消失动画的计时，nil 表示还活着
        var vanishAge: Double?
        var isAlive: Bool { hp > 0 }
    }

    struct Fireball: Identifiable {
        let id = UUID()
        let lane: Int
        var x: Double
    }

    static let lanes = 3
    static let maxHP = 5
    /// 横坐标都是 0...1 的比例
    static let dragonX = 0.1
    static let ghostStartX = 0.88
    /// 幽灵走到这里就碰到小龙了
    static let touchX = 0.18
    static let fireballSpeed = 2.2
    static let vanishDuration = 0.7
    /// 每按错一次，幽灵往前冲的距离（全程约 0.7，冲一次约占 6%）
    static let wrongDash = 0.04
    /// 往前冲的速度：0.25 秒冲完，看得出是“冲”过来而不是瞬移
    static let dashSpeed = wrongDash / 0.25

    var keySet: BalloonKeySet = .home
    private(set) var phase: Phase = .ready
    private(set) var ghosts: [Ghost] = []
    private(set) var fireballs: [Fireball] = []
    private(set) var elapsed: Double = 0
    private(set) var hits = 0
    private(set) var wrong = 0
    /// 输掉时碰到的是哪一排的小龙
    private(set) var caughtLane: Int?

    @ObservationIgnored private var lastTick: Date?

    var ghostsLeft: Int { ghosts.filter(\.isAlive).count }

    /// 幽灵现在的前进速度（每秒走多少比例）：一开始很慢，越来越快
    var speed: Double { 0.010 + elapsed * 0.0011 }

    init() { reset() }

    /// 摆好小龙和幽灵，等待开始
    func reset() {
        ghosts = []
        for lane in 0..<Self.lanes {
            let char = nextLetter(avoiding: Set(ghosts.map(\.char)))
            ghosts.append(Ghost(id: lane, char: char, speedFactor: .random(in: 0.88...1.12)))
        }
        fireballs = []
        elapsed = 0
        hits = 0
        wrong = 0
        caughtLane = nil
        lastTick = nil
    }

    func start() {
        reset()
        phase = .playing
    }

    func selectKeySet(_ set: BalloonKeySet) {
        keySet = set
        // 准备阶段马上换上新范围的字母；结束画面保留这一局的样子，下一局开始时再换
        if phase == .ready { reset() }
    }

    private func nextLetter(avoiding used: Set<Character>) -> Character {
        let candidates = keySet.keys.filter { !used.contains($0) }
        return (candidates.isEmpty ? keySet.keys : candidates).randomElement()!
    }

    /// 某只幽灵是不是已经有火球在路上了（这时它的字母先不能再打）
    func hasIncoming(_ ghost: Ghost) -> Bool {
        fireballs.contains { $0.lane == ghost.id }
    }

    /// 每帧调用
    func tick(now: Date) -> [Event] {
        defer { lastTick = now }
        let dt = min(now.timeIntervalSince(lastTick ?? now), 0.05)
        var events: [Event] = []

        // 消失动画结束后不管输赢都继续播完
        for i in ghosts.indices {
            ghosts[i].hitAge += dt
            if let age = ghosts[i].vanishAge { ghosts[i].vanishAge = age + dt }
        }
        guard phase == .playing else { return events }
        elapsed += dt

        // 火球往右飞，追上幽灵就算打中
        var landed: [UUID] = []
        for i in fireballs.indices {
            fireballs[i].x += Self.fireballSpeed * dt
            let fb = fireballs[i]
            guard let g = ghosts.firstIndex(where: { $0.id == fb.lane }), ghosts[g].isAlive else {
                landed.append(fb.id)
                continue
            }
            if fb.x >= ghosts[g].x - 0.03 {
                landed.append(fb.id)
                hits += 1
                ghosts[g].hp -= 1
                ghosts[g].hitAge = 0
                if ghosts[g].isAlive {
                    let others = Set(ghosts.filter { $0.isAlive && $0.id != fb.lane }.map(\.char))
                    ghosts[g].char = nextLetter(avoiding: others.union([ghosts[g].char]))
                    events.append(.hit)
                } else {
                    ghosts[g].vanishAge = 0
                    events.append(.vanished)
                }
            }
        }
        fireballs.removeAll { landed.contains($0.id) }

        if ghostsLeft == 0 {
            phase = .won
            fireballs = []
            events.append(.won)
            return events
        }

        // 幽灵朝小龙飘过来
        for i in ghosts.indices where ghosts[i].isAlive {
            ghosts[i].x -= speed * ghosts[i].speedFactor * dt
            if ghosts[i].dash > 0 {
                let step = min(ghosts[i].dash, Self.dashSpeed * dt)
                ghosts[i].x -= step
                ghosts[i].dash -= step
            }
            if ghosts[i].x <= Self.touchX {
                ghosts[i].x = Self.touchX
                caughtLane = ghosts[i].id
                phase = .lost
                fireballs = []
                events.append(.lost)
                return events
            }
        }
        return events
    }

    func type(_ c: Character) -> Outcome {
        guard phase == .playing else { return .ignored }
        let key = Character(c.lowercased())
        guard let ghost = ghosts.first(where: { $0.isAlive && $0.char == key }) else {
            wrong += 1
            // 按错了，所有幽灵往前冲一段
            for i in ghosts.indices where ghosts[i].isAlive { ghosts[i].dash += Self.wrongDash }
            return .wrong
        }
        // 火球已经在路上了，等它打中换了字母再打
        if hasIncoming(ghost) { return .ignored }
        fireballs.append(Fireball(lane: ghost.id, x: Self.dragonX + 0.05))
        return .fired
    }
}
