// 把 VoiceLines 里的所有台词用本机最自然的中文语音录成 .m4a。
// 由 build_app.sh 调用（和 VoiceLines.swift 拼在一起，用 `swift` 解释器运行，
// 因为只有 Apple 签名的程序才能使用 Siri 自然语音 / 神经网络语音）。
// 用法：swift <合并后的脚本> <输出目录>    可用环境变量 VOICE_ID 指定语音
import AVFoundation

let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func rank(_ v: AVSpeechSynthesisVoice) -> Int {
    if v.identifier.contains("siri") { return 5 }
    if v.identifier.contains("neural") { return 4 }
    switch v.quality {
    case .premium: return 3
    case .enhanced: return 2
    default: return 0
    }
}

let voice: AVSpeechSynthesisVoice? = {
    if let id = ProcessInfo.processInfo.environment["VOICE_ID"] { return AVSpeechSynthesisVoice(identifier: id) }
    return AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language == "zh-CN" && !$0.identifier.contains("eloquence") }
        .max { rank($0) < rank($1) }
}()

guard let voice, rank(voice) >= 2 else {
    print("⚠️  本机没有高品质中文语音，跳过录制（App 会使用系统语音）。")
    print("   可在 系统设置 → 辅助功能 → 朗读内容 → 系统声音 → 管理声音 中下载。")
    exit(0)
}

// 换了语音就全部重录
let marker = outDir.appendingPathComponent("voice.txt")
if (try? String(contentsOf: marker, encoding: .utf8)) != voice.identifier {
    for f in (try? FileManager.default.contentsOfDirectory(at: outDir, includingPropertiesForKeys: nil)) ?? [] {
        try? FileManager.default.removeItem(at: f)
    }
    try? voice.identifier.write(to: marker, atomically: true, encoding: .utf8)
}

let lines = Array(Set(VoiceLines.all))
let wanted = Set(lines.map { VoiceLines.fileName(for: $0) + ".m4a" })
// 清掉已经不用的旧录音
for f in (try? FileManager.default.contentsOfDirectory(at: outDir, includingPropertiesForKeys: nil)) ?? []
    where f.pathExtension == "m4a" && !wanted.contains(f.lastPathComponent) {
    try? FileManager.default.removeItem(at: f)
}

let synth = AVSpeechSynthesizer()
var made = 0
for text in lines {
    let url = outDir.appendingPathComponent(VoiceLines.fileName(for: text) + ".m4a")
    if FileManager.default.fileExists(atPath: url.path) { continue }

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = voice
    var file: AVAudioFile?
    var finished = false
    synth.write(utterance) { buffer in
        guard let pcm = buffer as? AVAudioPCMBuffer else { return }
        if pcm.frameLength == 0 { finished = true; return }
        if file == nil {
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: pcm.format.sampleRate,
                AVNumberOfChannelsKey: pcm.format.channelCount,
                AVEncoderBitRateKey: 64_000,
            ]
            file = try? AVAudioFile(forWriting: url, settings: settings,
                                    commonFormat: pcm.format.commonFormat, interleaved: pcm.format.isInterleaved)
        }
        try? file?.write(from: pcm)
    }
    let deadline = Date().addingTimeInterval(30)
    while !finished && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    file = nil   // 关闭文件
    if finished { made += 1 } else { try? FileManager.default.removeItem(at: url); print("⚠️  录制超时：\(text)") }
}
print("🎙  语音：\(voice.name)（\(voice.identifier)），新录制 \(made) 句，共 \(lines.count) 句")
