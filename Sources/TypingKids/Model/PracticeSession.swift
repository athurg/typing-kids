import Foundation
import Observation

struct PracticeResult: Equatable {
    let cpm: Int
    let accuracy: Double
    let duration: TimeInterval
    let mistakes: Int
    let characters: Int
    let bestStreak: Int
    /// 速度满分的基准（字符/分钟）
    let benchmarkCPM: Int

    // 百分制 = 正确率 60 分 + 速度 40 分（入门阶段先求准，再求快）
    static let accuracyWeight = 60.0
    static let speedWeight = 40.0
    /// 正确率低于这个值，正确率得分为 0
    static let accuracyFloor = 0.6

    var accuracyPoints: Int {
        let ratio = (accuracy - Self.accuracyFloor) / (1 - Self.accuracyFloor)
        return Int((min(max(ratio, 0), 1) * Self.accuracyWeight).rounded())
    }

    var speedPoints: Int {
        let ratio = Double(cpm) / Double(max(benchmarkCPM, 1))
        return Int((min(ratio, 1) * Self.speedWeight).rounded())
    }

    var score: Int { accuracyPoints + speedPoints }

    var grade: (emoji: String, title: String, speech: String) {
        let speech = VoiceLines.scoreLine(score)
        switch score {
        case 90...: return ("🏆", "优秀！你是打字小能手！", speech)
        case 75...: return ("🎉", "良好！再练练就是优秀啦", speech)
        case 60...: return ("👍", "及格啦！继续加油", speech)
        default: return ("💪", "别灰心，多练几次就会进步", speech)
        }
    }
}

enum CellState {
    case done, fixed, current, pending
}

/// 一次练习的状态。打错时不前进，必须按对才能继续（适合初学者养成准确的习惯）。
@Observable
final class PracticeSession {
    struct Unit: Identifiable {
        let id: Int
        let range: Range<Int>   // 包含单词后面的空格
        let hint: String?
    }

    enum Outcome { case correct, wrong, finished, ignored }

    let lesson: Lesson
    private(set) var chars: [Character] = []
    private(set) var units: [Unit] = []
    private(set) var index = 0
    private(set) var mistakes = 0
    private(set) var mistakePositions: Set<Int> = []
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var lastWrong: Character?
    private(set) var wrongCount = 0
    /// 连续按错了几次（按对就清零）
    private(set) var wrongRun = 0
    private(set) var startDate: Date?
    private(set) var endDate: Date?

    init(lesson: Lesson) {
        self.lesson = lesson
        restart()
    }

    func restart() {
        let items = lesson.makeItems()
        var chars: [Character] = []
        var units: [Unit] = []
        for (i, item) in items.enumerated() {
            let start = chars.count
            chars.append(contentsOf: item.text)
            if i < items.count - 1 { chars.append(" ") }
            units.append(Unit(id: i, range: start..<chars.count, hint: item.hint))
        }
        self.chars = chars
        self.units = units
        index = 0
        mistakes = 0
        mistakePositions = []
        streak = 0
        bestStreak = 0
        lastWrong = nil
        wrongRun = 0
        startDate = nil
        endDate = nil
    }

    var current: Character? { index < chars.count ? chars[index] : nil }
    var isFinished: Bool { index >= chars.count }
    var hasHints: Bool { units.contains { $0.hint != nil } }
    var progress: Double { chars.isEmpty ? 0 : Double(index) / Double(chars.count) }

    func state(at i: Int) -> CellState {
        if i < index { return mistakePositions.contains(i) ? .fixed : .done }
        return i == index ? .current : .pending
    }

    @discardableResult
    func type(_ c: Character) -> Outcome {
        guard let target = current else { return .ignored }
        if startDate == nil { startDate = Date() }
        if c == target {
            index += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            lastWrong = nil
            wrongRun = 0
            if isFinished {
                endDate = Date()
                return .finished
            }
            return .correct
        } else {
            mistakes += 1
            mistakePositions.insert(index)
            streak = 0
            lastWrong = c
            wrongCount += 1
            wrongRun += 1
            return .wrong
        }
    }

    var elapsed: TimeInterval {
        guard let startDate else { return 0 }
        return (endDate ?? Date()).timeIntervalSince(startDate)
    }

    var accuracy: Double {
        let total = index + mistakes
        return total == 0 ? 1 : Double(index) / Double(total)
    }

    /// 每分钟打对的字符数
    var cpm: Int {
        let minutes = max(elapsed, 1) / 60
        return Int((Double(index) / minutes).rounded())
    }

    func result() -> PracticeResult {
        PracticeResult(cpm: cpm, accuracy: accuracy, duration: elapsed, mistakes: mistakes,
                       characters: chars.count, bestStreak: bestStreak,
                       benchmarkCPM: lesson.category.benchmarkCPM)
    }
}
