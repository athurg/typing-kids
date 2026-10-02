import Foundation
import Observation

/// 青蛙过河：打出下一片荷叶上的字母（或单词），青蛙就跳过去；
/// 脚下的荷叶会慢慢下沉，沉下去之前要跳走，否则掉进水里少一条命。
@Observable
final class FrogGame {
    enum Phase { case ready, playing, splashing, over }
    enum Outcome { case jumped, progress, wrong, ignored }

    enum Mode: String, CaseIterable, Identifiable {
        case home, letters, words
        var id: String { rawValue }
        var title: String {
            switch self {
            case .home: "基准键字母"
            case .letters: "全部字母"
            case .words: "英文单词"
            }
        }
        /// 第一片荷叶下沉需要的时间（秒）
        var startSinkTime: Double { self == .words ? 7 : 4.5 }
        var minSinkTime: Double { self == .words ? 3.5 : 1.6 }
    }

    struct Pad: Identifiable {
        let id: Int
        let label: String
    }

    static let jumpDuration = 0.35
    static let splashDuration = 1.3

    var mode: Mode = .home
    private(set) var phase: Phase = .ready
    private(set) var pads: [Pad] = []
    /// 青蛙所在的荷叶
    private(set) var frogIndex = 0
    /// 0...1，跳跃进行中（从 frogIndex - 1 跳到 frogIndex）
    private(set) var jumpProgress: Double = 1
    /// 已经打出的单词字母
    private(set) var buffer = ""
    private(set) var sinkElapsed: Double = 0
    private(set) var sinkLimit: Double = 4.5
    private(set) var lives = 3
    private(set) var splashElapsed: Double = 0
    private(set) var elapsed: Double = 0

    @ObservationIgnored private var lastTick: Date?

    /// 跳过的荷叶数就是得分
    var score: Int { frogIndex }
    var target: Pad? { frogIndex + 1 < pads.count ? pads[frogIndex + 1] : nil }
    var sinkRatio: Double { min(sinkElapsed / sinkLimit, 1) }

    func start() {
        pads = [Pad(id: 0, label: "")]
        frogIndex = 0
        jumpProgress = 1
        buffer = ""
        sinkElapsed = 0
        sinkLimit = mode.startSinkTime
        lives = 3
        elapsed = 0
        lastTick = nil
        ensurePads()
        phase = .playing
    }

    /// 准备阶段：先把荷叶摆好当背景，但还不开始
    func forceReady() { phase = .ready }

    private func ensurePads() {
        while pads.count < frogIndex + 10 {
            pads.append(Pad(id: pads.count, label: makeLabel(avoiding: Set(pads.suffix(6).map(\.label)))))
        }
    }

    /// 新荷叶上的字：字母不和上一片相同，单词不和最近几片重复
    private func makeLabel(avoiding recent: Set<String>) -> String {
        switch mode {
        case .home, .letters:
            let letters = Array(mode == .home ? "asdfghjkl" : "abcdefghijklmnopqrstuvwxyz").map(String.init)
            let previous = pads.last?.label
            return letters.filter { $0 != previous }.randomElement()!
        case .words:
            return WordBank.english.filter { $0.count <= 5 && !recent.contains($0) }.randomElement()!
        }
    }

    /// 每帧调用，返回 true 表示游戏刚结束
    func tick(now: Date) -> Bool {
        defer { lastTick = now }
        let dt = min(now.timeIntervalSince(lastTick ?? now), 0.05)
        switch phase {
        case .ready, .over:
            return false
        case .splashing:
            splashElapsed += dt
            if splashElapsed >= Self.splashDuration {
                if lives > 0 {
                    // 回到同一片荷叶上，重新开始计时
                    sinkElapsed = 0
                    buffer = ""
                    phase = .playing
                } else {
                    phase = .over
                    return true
                }
            }
            return false
        case .playing:
            elapsed += dt
            if jumpProgress < 1 {
                jumpProgress = min(1, jumpProgress + dt / Self.jumpDuration)
                return false
            }
            sinkElapsed += dt
            if sinkElapsed >= sinkLimit {
                lives -= 1
                splashElapsed = 0
                phase = .splashing
            }
            return false
        }
    }

    func type(_ c: Character) -> Outcome {
        guard phase == .playing, let target else { return .ignored }
        // 上一次跳跃还没落地，就直接让它落地
        if jumpProgress < 1 { jumpProgress = 1 }
        let next = buffer + String(c)
        guard target.label.hasPrefix(next) else { return .wrong }
        if next == target.label {
            frogIndex += 1
            jumpProgress = 0
            buffer = ""
            sinkElapsed = 0
            // 越往后荷叶沉得越快
            sinkLimit = max(mode.minSinkTime, sinkLimit - (mode == .words ? 0.12 : 0.08))
            ensurePads()
            return .jumped
        }
        buffer = next
        return .progress
    }
}
