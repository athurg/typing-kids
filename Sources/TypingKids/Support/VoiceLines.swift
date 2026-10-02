import Foundation

/// 所有语音台词。打包时 Scripts/make_voices.swift 会用本机最自然的中文语音
/// 把它们预先录成音频放进 App，运行时直接播放录音（第三方 App 不能直接调用 Siri 自然语音）。
/// 注意：这个文件只能依赖 Foundation，因为生成脚本也要用它。
enum VoiceLines {
    static let praise = [
        "哇，连着打对了这么多，真厉害！",
        "太棒啦，继续保持！",
        "你的手指越来越灵活了！",
        "好样的，就是这个节奏！",
        "真不错，一个都没打错！",
        "厉害厉害，你是打字小能手！",
    ]

    static let comfort = [
        "没关系，看看键盘上亮起来的那个键。",
        "别着急，慢慢来，先找准位置哦。",
        "这个键有点难，我们再试一次！",
    ]

    static let start = [
        "准备好了吗？我们开始吧！",
        "加油，你一定可以的！",
        "眼睛看屏幕，我们开始啦！",
    ]

    static let newBest = "哇，刷新了最高分！"
    static let gameOver = "时间到！这一局玩得真不错！"
    static let gameNewHigh = "新纪录！你太棒了！"
    static let preview = "你好呀！我们一起来练习打字吧。你真棒！"
    static let pianoDone = "弹完啦，真好听！我们一起来听一遍吧。"
    static let frogSplash = "扑通！没关系，再跳一次！"
    static let frogStart = "小青蛙要过河啦，加油！"

    /// 练习结束时按分数点评
    static func scoreLine(_ score: Int) -> String {
        switch score {
        case 90...: "哇，\(score)分！太优秀了，你真是打字小能手！"
        case 75...: "\(score)分，很棒哦！再练一练就能拿优秀啦。"
        case 60...: "\(score)分，及格啦！继续加油，你会越来越快的。"
        default: "这次是\(score)分。没关系，多练几次一定会进步的！"
        }
    }

    /// 气球游戏连击（每 10 连击一次）
    static func comboLine(_ combo: Int) -> String {
        combo <= 200 ? "\(combo)连击！太厉害啦！" : "连击停不下来啦，太厉害了！"
    }

    /// 需要预先录好的全部台词
    static var all: [String] {
        praise + comfort + start + [newBest, gameOver, gameNewHigh, preview, pianoDone, frogSplash, frogStart]
            + (0...100).map(scoreLine)
            + stride(from: 10, through: 210, by: 10).map(comboLine)
    }

    /// 台词对应的录音文件名（稳定的 FNV-1a 哈希，每次运行都一样）
    static func fileName(for text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(format: "%016llx", hash)
    }
}
