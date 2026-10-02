import SwiftUI
import Observation

/// 拼音泡泡：写着汉字的泡泡往上飘，打出拼音就能戳破
@Observable
final class BubbleGame {
    enum Phase { case ready, playing, over }
    enum Outcome { case progress, popped(points: Int), wrong, ignored }

    struct Bubble: Identifiable {
        let id = UUID()
        let hanzi: String
        let pinyin: String
        let x: CGFloat
        var y: CGFloat          // 0 底部 ... 1 顶部
        let speed: CGFloat
        let wobblePhase: Double
        let tint: Color
    }

    struct Pop: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let hanzi: String
        let points: Int
        var age: Double = 0
    }

    static let roundLength: Double = 60

    /// 词库：拼音词语 + 日常短句里两个字以上的词
    static let words: [(hanzi: String, pinyin: String)] = {
        var seen = Set<String>()
        var result: [(String, String)] = []
        let fromSentences = WordBank.pinyinSentences.flatMap(WordBank.pinyinSentenceItems).map { item in
            (String(item.hanzi.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.map(Character.init)), item.pinyin)
        }
        for (hanzi, pinyin) in WordBank.pinyin.map({ ($0.hanzi, $0.pinyin) }) + fromSentences
            where hanzi.count >= 2 && !seen.contains(pinyin) {
            seen.insert(pinyin)
            result.append((hanzi, pinyin))
        }
        return result
    }()

    private static let tints: [Color] = [
        Color(red: 0.55, green: 0.80, blue: 1.00), Color(red: 0.75, green: 0.65, blue: 1.00),
        Color(red: 0.55, green: 0.90, blue: 0.80), Color(red: 1.00, green: 0.70, blue: 0.85),
        Color(red: 1.00, green: 0.85, blue: 0.55),
    ]

    var showPinyin = true
    private(set) var phase: Phase = .ready
    private(set) var bubbles: [Bubble] = []
    private(set) var pops: [Pop] = []
    /// 已经打出的拼音字母
    private(set) var buffer = ""
    private(set) var score = 0
    private(set) var combo = 0
    private(set) var bestCombo = 0
    private(set) var hits = 0
    private(set) var missed = 0
    private(set) var timeLeft = BubbleGame.roundLength
    private(set) var elapsed: Double = 0

    @ObservationIgnored private var spawnCountdown: Double = 0
    @ObservationIgnored private var lastTick: Date?

    func start() {
        bubbles = []
        pops = []
        buffer = ""
        score = 0; combo = 0; bestCombo = 0; hits = 0; missed = 0
        timeLeft = Self.roundLength
        elapsed = 0
        spawnCountdown = 0
        lastTick = nil
        phase = .playing
    }

    /// 每帧调用，返回 true 表示这一局刚结束
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
            if bubbles.count < 6 { spawn() }
            spawnCountdown = max(1.8, 2.6 - elapsed * 0.015)
        }

        for i in bubbles.indices { bubbles[i].y += bubbles[i].speed * dt }
        let escaped = bubbles.filter { $0.y > 1.15 }.count
        if escaped > 0 {
            missed += escaped
            combo = 0
            bubbles.removeAll { $0.y > 1.15 }
            // 正在打的那个泡泡飞走了
            if !buffer.isEmpty && !bubbles.contains(where: { $0.pinyin.hasPrefix(buffer) }) { buffer = "" }
        }

        for i in pops.indices { pops[i].age += dt }
        pops.removeAll { $0.age > 0.7 }
        return false
    }

    private func spawn() {
        let onScreen = Set(bubbles.map(\.pinyin))
        guard let word = Self.words.filter({ !onScreen.contains($0.pinyin) }).randomElement() else { return }
        // 尽量不和已有泡泡挤在一起
        var x = CGFloat.random(in: 0.1...0.9)
        for _ in 0..<8 where bubbles.contains(where: { abs($0.x - x) < 0.14 && $0.y < 0.3 }) {
            x = CGFloat.random(in: 0.1...0.9)
        }
        let speed = CGFloat(0.06 + elapsed * 0.0004) * CGFloat.random(in: 0.9...1.1)
        bubbles.append(Bubble(hanzi: word.hanzi, pinyin: word.pinyin, x: x, y: -0.15, speed: speed,
                              wobblePhase: .random(in: 0...(2 * .pi)), tint: Self.tints.randomElement()!))
    }

    func type(_ c: Character) -> Outcome {
        guard phase == .playing, c.isLetter else { return .ignored }
        let letter = String(c.lowercased())
        var next = buffer + letter
        if !bubbles.contains(where: { $0.pinyin.hasPrefix(next) }) {
            // 换一个泡泡重新开始打，不算错
            guard bubbles.contains(where: { $0.pinyin.hasPrefix(letter) }) else {
                combo = 0
                return .wrong
            }
            next = letter
        }
        buffer = next
        // 打完整了：戳破飞得最高的那个
        if let i = bubbles.indices.filter({ bubbles[$0].pinyin == next }).max(by: { bubbles[$0].y < bubbles[$1].y }) {
            let b = bubbles.remove(at: i)
            let points = 10 + b.pinyin.count + min(combo, 10)
            score += points
            combo += 1
            bestCombo = max(bestCombo, combo)
            hits += 1
            buffer = ""
            pops.append(Pop(x: b.x, y: b.y, hanzi: b.hanzi, points: points))
            return .popped(points: points)
        }
        return .progress
    }
}
