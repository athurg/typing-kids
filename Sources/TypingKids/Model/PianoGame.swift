import Foundation
import Observation

/// 基准键钢琴：A S D F G H J K L ; 依次是 低sol 低la 低si do re mi fa sol la si（F 是 do）
enum PianoKeys {
    static let keys: [Character] = Array("asdfghjkl;")
    static let solfege = ["低sol", "低la", "低si", "do", "re", "mi", "fa", "sol", "la", "si"]
    static let jianpu = ["5̣", "6̣", "7̣", "1", "2", "3", "4", "5", "6", "7"]
    /// do = C5
    static let midi = [67, 69, 71, 72, 74, 76, 77, 79, 81, 83]

    static func index(of key: Character) -> Int? { keys.firstIndex(of: key) }
}

struct PianoNote: Hashable {
    let key: Character
    let beats: Double
    let lyric: String
}

struct PianoSong: Identifiable, Hashable {
    let id: String
    let title: String
    let emoji: String
    let phrases: [[PianoNote]]

    var notes: [PianoNote] { phrases.flatMap { $0 } }

    /// 一句：按键、每个音的拍数、歌词（每个字对应一个音）
    private static func phrase(_ keys: String, _ beats: [Double], _ lyric: String) -> [PianoNote] {
        let lyrics = lyric.map(String.init)
        precondition(keys.count == beats.count && keys.count == lyrics.count, "乐句长度不一致：\(lyric)")
        return zip(zip(keys, beats), lyrics).map { PianoNote(key: $0.0, beats: $0.1, lyric: $1) }
    }

    static let all: [PianoSong] = [
        PianoSong(id: "star", title: "小星星", emoji: "⭐️", phrases: [
            phrase("ffkkllk", [1, 1, 1, 1, 1, 1, 2], "一闪一闪亮晶晶"),
            phrase("jjhhggf", [1, 1, 1, 1, 1, 1, 2], "满天都是小星星"),
            phrase("kkjjhhg", [1, 1, 1, 1, 1, 1, 2], "挂在天上放光明"),
            phrase("kkjjhhg", [1, 1, 1, 1, 1, 1, 2], "好像许多小眼睛"),
            phrase("ffkkllk", [1, 1, 1, 1, 1, 1, 2], "一闪一闪亮晶晶"),
            phrase("jjhhggf", [1, 1, 1, 1, 1, 1, 2], "满天都是小星星"),
        ]),
        PianoSong(id: "tigers", title: "两只老虎", emoji: "🐯", phrases: [
            phrase("fghf", [1, 1, 1, 1], "两只老虎"),
            phrase("fghf", [1, 1, 1, 1], "两只老虎"),
            phrase("hjk", [1, 1, 2], "跑得快"),
            phrase("hjk", [1, 1, 2], "跑得快"),
            phrase("klkjhf", [0.5, 0.5, 0.5, 0.5, 1, 1], "一只没有眼睛"),
            phrase("klkjhf", [0.5, 0.5, 0.5, 0.5, 1, 1], "一只没有尾巴"),
            phrase("faf", [1, 1, 2], "真奇怪"),
            phrase("faf", [1, 1, 2], "真奇怪"),
        ]),
        PianoSong(id: "joy", title: "欢乐颂", emoji: "🎶", phrases: [
            phrase("hhjkkjhg", [1, 1, 1, 1, 1, 1, 1, 1], "欢乐女神圣洁美丽"),
            phrase("ffghhgg", [1, 1, 1, 1, 1.5, 0.5, 2], "灿烂光芒照大地"),
            phrase("hhjkkjhg", [1, 1, 1, 1, 1, 1, 1, 1], "我们心中充满热情"),
            phrase("ffghgff", [1, 1, 1, 1, 1.5, 0.5, 2], "来到你的圣殿里"),
        ]),
        PianoSong(id: "birthday", title: "生日快乐", emoji: "🎂", phrases: [
            phrase("aasafd", [0.75, 0.25, 1, 1, 1, 2], "祝你生日快乐"),
            phrase("aasagf", [0.75, 0.25, 1, 1, 1, 2], "祝你生日快乐"),
            phrase("aakhfds", [0.75, 0.25, 1, 1, 1, 1, 2], "祝你生日快乐～"),
            phrase("jjhfgf", [0.75, 0.25, 1, 1, 1, 2], "祝你生日快乐"),
        ]),
    ]
}

/// 键盘钢琴：照着乐谱按键，按对才响、才往下走；弹完自动完整播放一遍
@Observable
final class PianoGame {
    enum Phase { case ready, playing, replaying, done }
    enum Outcome { case correct(midi: Int), wrong, finished(midi: Int), ignored }

    var song: PianoSong = PianoSong.all[0]
    private(set) var phase: Phase = .ready
    private(set) var index = 0
    private(set) var mistakes = 0
    private(set) var firstTryCorrect = 0
    private(set) var replayIndex: Int?
    @ObservationIgnored private var wrongOnCurrent = false
    @ObservationIgnored private(set) var startDate = Date()

    var notes: [PianoNote] { song.notes }
    var current: PianoNote? { index < notes.count ? notes[index] : nil }

    /// 弹对率（每个音第一次就按对的比例）
    var score: Int { notes.isEmpty ? 0 : Int((Double(firstTryCorrect) / Double(notes.count) * 100).rounded()) }

    /// 弹奏过程中实时的弹对率
    var liveAccuracy: Int { index == 0 ? 100 : Int((Double(firstTryCorrect) / Double(index) * 100).rounded()) }

    /// 当前音所在的乐句序号，以及它在句中的位置
    func position(of noteIndex: Int) -> (phrase: Int, offset: Int) {
        var remaining = noteIndex
        for (i, phrase) in song.phrases.enumerated() {
            if remaining < phrase.count { return (i, remaining) }
            remaining -= phrase.count
        }
        return (song.phrases.count - 1, song.phrases.last?.count ?? 0)
    }

    func start() {
        index = 0
        mistakes = 0
        firstTryCorrect = 0
        wrongOnCurrent = false
        replayIndex = nil
        startDate = Date()
        phase = .playing
    }

    func press(_ c: Character) -> Outcome {
        guard phase == .playing, let note = current else { return .ignored }
        let key = Character(c.lowercased())
        guard key == note.key, let i = PianoKeys.index(of: key) else {
            mistakes += 1
            wrongOnCurrent = true
            return .wrong
        }
        if !wrongOnCurrent { firstTryCorrect += 1 }
        wrongOnCurrent = false
        index += 1
        if index >= notes.count {
            phase = .replaying
            return .finished(midi: PianoKeys.midi[i])
        }
        return .correct(midi: PianoKeys.midi[i])
    }

    func setReplayIndex(_ i: Int?) { replayIndex = i }
    func finishReplay() {
        replayIndex = nil
        phase = .done
    }
}
