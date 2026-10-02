import Foundation
import Observation

/// 成绩记录，保存在 UserDefaults。
@Observable
final class ProgressStore {
    struct Record: Codable {
        var bestScore = 0
        var bestCPM = 0
        var bestAccuracy = 0.0
        var plays = 0
    }

    private struct Snapshot: Codable {
        var records: [String: Record]
        var gameHighScore: Int          // 旧版本只有气球游戏的最高分
        var totalSeconds: Double
        var gameScores: [String: Int]?  // 每个游戏的最高分
    }

    private(set) var records: [String: Record] = [:]
    private(set) var gameScores: [String: Int] = [:]
    private(set) var totalSeconds: Double = 0

    @ObservationIgnored private let defaultsKey = "progress.v2"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            records = snapshot.records
            gameScores = snapshot.gameScores ?? [:]
            if gameScores["balloon"] == nil, snapshot.gameHighScore > 0 {
                gameScores["balloon"] = snapshot.gameHighScore
            }
            totalSeconds = snapshot.totalSeconds
        }
    }

    func record(for lessonID: String) -> Record? { records[lessonID] }

    /// 某个类别里所有练习的记录（按键练习有很多种区域组合）
    private func records(in category: PracticeCategory) -> [Record] {
        records.filter { $0.key == category.rawValue || $0.key.hasPrefix(category.rawValue + ":") }.map(\.value)
    }

    func bestScore(in category: PracticeCategory) -> Int? {
        records(in: category).map(\.bestScore).max()
    }

    func plays(in category: PracticeCategory) -> Int {
        records(in: category).reduce(0) { $0 + $1.plays }
    }

    var totalPlays: Int { records.values.reduce(0) { $0 + $1.plays } }
    var overallBest: Int { records.values.map(\.bestScore).max() ?? 0 }

    /// 记录一次练习，返回是否刷新了最高分（第一次练习不算）。
    @discardableResult
    func record(_ result: PracticeResult, lessonID: String) -> Bool {
        var rec = records[lessonID] ?? Record()
        let isNewBest = rec.plays > 0 && result.score > rec.bestScore
        rec.plays += 1
        rec.bestScore = max(rec.bestScore, result.score)
        rec.bestCPM = max(rec.bestCPM, result.cpm)
        rec.bestAccuracy = max(rec.bestAccuracy, result.accuracy)
        records[lessonID] = rec
        totalSeconds += result.duration
        save()
        return isNewBest
    }

    func gameHighScore(_ gameID: String) -> Int { gameScores[gameID] ?? 0 }

    /// 记录一局游戏，返回是否是新的最高分。
    @discardableResult
    func recordGame(_ gameID: String, score: Int, seconds: Double) -> Bool {
        totalSeconds += seconds
        let isNew = score > gameHighScore(gameID)
        if isNew { gameScores[gameID] = score }
        save()
        return isNew
    }

    /// 记录一局用时越短越好的游戏（打幽灵记最快通关秒数），返回是否是新纪录。
    @discardableResult
    func recordFastest(_ gameID: String, seconds: Double) -> Bool {
        totalSeconds += seconds
        let rounded = max(1, Int(seconds.rounded()))
        let best = gameHighScore(gameID)
        let isNew = best == 0 || rounded < best
        if isNew { gameScores[gameID] = rounded }
        save()
        return isNew
    }

    func reset() {
        records = [:]
        gameScores = [:]
        totalSeconds = 0
        save()
    }

    private func save() {
        let snapshot = Snapshot(records: records, gameHighScore: gameHighScore("balloon"),
                                totalSeconds: totalSeconds, gameScores: gameScores)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
