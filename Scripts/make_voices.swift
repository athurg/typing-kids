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

let fm = FileManager.default
let marker = outDir.appendingPathComponent("voice.txt")
/// 已提交到仓库的录音是用哪个语音录的
let recordedWith = (try? String(contentsOf: marker, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
let requestedID = ProcessInfo.processInfo.environment["VOICE_ID"]

// 录音已经齐全（比如 CI 上直接用仓库里提交的录音）就直接结束，不去碰语音合成
let allFiles = Set(VoiceLines.all.map { VoiceLines.fileName(for: $0) + ".m4a" })
if requestedID == nil, allFiles.allSatisfy({ fm.fileExists(atPath: outDir.appendingPathComponent($0).path) }) {
    print("🎙  语音录音齐全，共 \(allFiles.count) 句（\(recordedWith ?? "未知语音")）")
    exit(0)
}

let best = AVSpeechSynthesisVoice.speechVoices()
    .filter { $0.language == "zh-CN" && !$0.identifier.contains("eloquence") }
    .max { rank($0) < rank($1) }

// 选语音：明确指定的 > 原来录音用的（保证声音一致）> 本机最自然的
let voice: AVSpeechSynthesisVoice? = {
    if let requestedID { return AVSpeechSynthesisVoice(identifier: requestedID) }
    if let recordedWith, let same = AVSpeechSynthesisVoice(identifier: recordedWith) { return same }
    return best
}()

// 只有明确指定了另一个语音，才清空旧录音全部重录；
// 换到没有原语音的电脑上时，保留已有录音，只补录缺少的句子。
if let requestedID, let recordedWith, requestedID != recordedWith, voice != nil {
    print("🔁 换用语音 \(requestedID)，全部重新录制")
    for f in (try? fm.contentsOfDirectory(at: outDir, includingPropertiesForKeys: nil)) ?? [] where f.pathExtension == "m4a" {
        try? fm.removeItem(at: f)
    }
}

let lines = Array(Set(VoiceLines.all))
let wanted = Set(lines.map { VoiceLines.fileName(for: $0) + ".m4a" })
// 清掉已经不用的旧录音
for f in (try? fm.contentsOfDirectory(at: outDir, includingPropertiesForKeys: nil)) ?? []
    where f.pathExtension == "m4a" && !wanted.contains(f.lastPathComponent) {
    try? fm.removeItem(at: f)
}

let missing = lines.filter { !fm.fileExists(atPath: outDir.appendingPathComponent(VoiceLines.fileName(for: $0) + ".m4a").path) }
if missing.isEmpty {
    print("🎙  语音录音齐全，共 \(lines.count) 句（\(recordedWith ?? "未知语音")）")
    exit(0)
}
guard let voice, rank(voice) >= 2 else {
    print("⚠️  缺少 \(missing.count) 句录音，但本机没有高品质中文语音，这几句会改用系统语音。")
    print("   可在 系统设置 → 辅助功能 → 朗读内容 → 系统声音 → 管理声音 中下载。")
    exit(0)
}
if requestedID == nil, let recordedWith, recordedWith != voice.identifier {
    print("⚠️  本机没有原来录音用的语音（\(recordedWith)），新增的句子会用 \(voice.identifier) 录制，声音可能不一样。")
} else {
    try? voice.identifier.write(to: marker, atomically: true, encoding: .utf8)
}

let synth = AVSpeechSynthesizer()
var made = 0
for text in missing {
    let url = outDir.appendingPathComponent(VoiceLines.fileName(for: text) + ".m4a")

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
