import AVFoundation

/// 儿童版音效：全部用程序实时合成（木琴音色），不需要任何声音文件。
enum SoundFX {
    /// 按对：连续按对时音高一级级往上爬，像在弹一段旋律
    case correct(streak: Int)
    /// 按错：轻柔的“哦哦～”
    case wrong
    /// 连对里程碑：一串亮晶晶的琶音
    case milestone
    /// 过关 / 游戏结束：小号角
    case finish
    /// 戳破气球：“啵”，连击越高音调越高
    case pop(combo: Int)
    /// 结果页亮起第 index 颗星
    case star(index: Int)
    /// 键盘钢琴的一个音
    case note(midi: Int)
    /// 青蛙起跳
    case jump
    /// 掉进水里
    case splash

    static func play(_ fx: SoundFX) {
        guard UserDefaults.standard.object(forKey: "soundOn") as? Bool ?? true else { return }
        switch fx {
        case .correct(let streak):
            // C 大调五声音阶，两个八度
            let scale = [72, 74, 76, 79, 81, 84, 86, 88, 91, 93]
            let note = scale[max(streak - 1, 0) % scale.count]
            SoundEngine.shared.play("correct\(note)") { Synth.bell(midi: note, duration: 0.3, volume: 0.32) }
        case .wrong:
            SoundEngine.shared.play("wrong") {
                Synth.mix([(0, Synth.soft(midi: 67, duration: 0.13, volume: 0.32)),
                           (0.13, Synth.soft(midi: 63, duration: 0.24, volume: 0.32))])
            }
        case .milestone:
            SoundEngine.shared.play("milestone") {
                Synth.mix([84, 88, 91, 96, 100].enumerated().map { i, n in
                    (Double(i) * 0.06, Synth.bell(midi: n, duration: 0.45, volume: 0.2))
                })
            }
        case .finish:
            SoundEngine.shared.play("finish") {
                Synth.mix([
                    (0.00, Synth.bell(midi: 72, duration: 0.25, volume: 0.35)),
                    (0.12, Synth.bell(midi: 76, duration: 0.25, volume: 0.35)),
                    (0.24, Synth.bell(midi: 79, duration: 0.25, volume: 0.35)),
                    (0.40, Synth.bell(midi: 84, duration: 0.9, volume: 0.3)),
                    (0.40, Synth.bell(midi: 88, duration: 0.9, volume: 0.16)),
                    (0.40, Synth.bell(midi: 91, duration: 0.9, volume: 0.16)),
                ])
            }
        case .pop(let combo):
            let step = min(combo, 12)
            SoundEngine.shared.play("pop\(step)") {
                let base = 380.0 * pow(2, Double(step) / 12)
                return Synth.mix([(0, Synth.sweep(from: base, to: base * 3, duration: 0.07, volume: 0.45)),
                                  (0.03, Synth.bell(midi: 84 + step, duration: 0.15, volume: 0.15))])
            }
        case .note(let midi):
            SoundEngine.shared.play("note\(midi)") { Synth.bell(midi: midi, duration: 0.9, volume: 0.4) }
        case .jump:
            SoundEngine.shared.play("jump") { Synth.sweep(from: 300, to: 700, duration: 0.15, volume: 0.35) }
        case .splash:
            SoundEngine.shared.play("splash") {
                Synth.mix([(0, Synth.sweep(from: 600, to: 120, duration: 0.35, volume: 0.4)),
                           (0.05, Synth.noise(duration: 0.4, volume: 0.25))])
            }
        case .star(let index):
            let notes = [79, 84, 88]
            let n = notes[min(index, notes.count - 1)]
            SoundEngine.shared.play("star\(n)") {
                Synth.mix([(0, Synth.bell(midi: n, duration: 0.7, volume: 0.32)),
                           (0.05, Synth.bell(midi: n + 12, duration: 0.6, volume: 0.15))])
            }
        }
    }
}

/// 语音鼓励：优先播放打包时预先录好的自然人声（见 VoiceLines），没有录音时才用系统语音合成
enum Cheer {
    private static let synthesizer = AVSpeechSynthesizer()
    private static var player: AVAudioPlayer?
    private static var queued: [DispatchWorkItem] = []
    private static var lastLine: String?

    /// 设置里“鼓励的声音”的取值：录好的自然人声
    static let recordedVoiceTag = ""

    /// 从一组台词里随机挑一句，且不和上一句重复
    static func pick(_ lines: [String]) -> String {
        let candidates = lines.filter { $0 != lastLine }
        return (candidates.isEmpty ? lines : candidates).randomElement()!
    }

    static var hasRecordings: Bool { recordingURL(for: VoiceLines.preview) != nil }

    /// 系统里可用的普通话语音（第三方 App 能直接用的，通常只有较机械的 Tingting）
    static var systemVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "zh-CN" && !$0.identifier.contains("eloquence") && !$0.identifier.contains("super-compact") }
    }

    // MARK: 播放

    static func say(_ text: String, interrupt: Bool = false) {
        say([text], interrupt: interrupt)
    }

    /// 依次说几句话
    static func say(_ lines: [String], interrupt: Bool = false) {
        guard UserDefaults.standard.object(forKey: "voiceOn") as? Bool ?? true else { return }
        speak(lines, interrupt: interrupt, voiceTag: UserDefaults.standard.string(forKey: "voiceID") ?? recordedVoiceTag)
    }

    /// 设置里的“试听”，不受语音开关影响
    static func preview(voiceTag: String) {
        speak([VoiceLines.preview], interrupt: true, voiceTag: voiceTag)
    }

    private static var isBusy: Bool { (player?.isPlaying ?? false) || synthesizer.isSpeaking || !queued.isEmpty }

    private static func speak(_ lines: [String], interrupt: Bool, voiceTag: String) {
        guard !lines.isEmpty else { return }
        if isBusy {
            guard interrupt else { return }
            stop()
        }
        lastLine = lines.last

        let useRecording = voiceTag == recordedVoiceTag && lines.allSatisfy { recordingURL(for: $0) != nil }
        if useRecording {
            // 一句接一句播放
            var delay: TimeInterval = 0
            for (i, line) in lines.enumerated() {
                guard let url = recordingURL(for: line) else { continue }
                if i == 0 {
                    play(url)
                    delay = player?.duration ?? 0
                } else {
                    let item = DispatchWorkItem { play(url) }
                    queued.append(item)
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.15, execute: item)
                    delay += 0.15 + ((try? AVAudioPlayer(contentsOf: url))?.duration ?? 0)
                }
            }
            if !queued.isEmpty {
                let clear = DispatchWorkItem { queued.removeAll() }
                queued.append(clear)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: clear)
            }
            return
        }

        let voice = AVSpeechSynthesisVoice(identifier: voiceTag) ?? systemVoices.first
        for line in lines {
            let utterance = AVSpeechUtterance(string: line)
            utterance.voice = voice
            // 正常语速、原本音调：强行调高音调是“机器味”的主要来源
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.pitchMultiplier = 1.0
            synthesizer.speak(utterance)
        }
    }

    private static func play(_ url: URL) {
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    private static func stop() {
        queued.forEach { $0.cancel() }
        queued.removeAll()
        player?.stop()
        synthesizer.stopSpeaking(at: .immediate)
    }

    private static func recordingURL(for text: String) -> URL? {
        Bundle.main.url(forResource: VoiceLines.fileName(for: text), withExtension: "m4a", subdirectory: "Voices")
    }
}

// MARK: - 播放

private final class SoundEngine {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 1)!
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var cache: [String: AVAudioPCMBuffer] = [:]

    private init() {
        // 多个播放器轮流用，快速连按时声音可以叠在一起
        for _ in 0..<10 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
    }

    func play(_ key: String, make: () -> [Float]) {
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        let buffer: AVAudioPCMBuffer
        if let cached = cache[key] {
            buffer = cached
        } else {
            guard let made = makeBuffer(make()) else { return }
            cache[key] = made
            buffer = made
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer, completionHandler: nil)
        player.play()
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for i in samples.indices { channel[i] = samples[i] }
        return buffer
    }
}

// MARK: - 合成

private enum Synth {
    static let sampleRate = 44_100.0

    static func frequency(midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }

    /// 木琴 / 钟琴音色：基音 + 泛音，起音很快，然后自然衰减
    static func bell(midi: Int, duration: Double, volume: Float) -> [Float] {
        let f = frequency(midi: midi)
        let n = Int(duration * sampleRate)
        return (0..<n).map { i in
            let t = Double(i) / sampleRate
            let attack = min(1, t / 0.003)
            let body = sin(2 * .pi * f * t) * exp(-t * 7)
            let overtone = 0.4 * sin(2 * .pi * f * 2 * t) * exp(-t * 12)
            let sparkle = 0.18 * sin(2 * .pi * f * 3.98 * t) * exp(-t * 25)
            return Float(attack * (body + overtone + sparkle)) * volume
        }
    }

    /// 圆润柔和的音（按错时用），带一点颤音
    static func soft(midi: Int, duration: Double, volume: Float) -> [Float] {
        let f = frequency(midi: midi)
        let n = Int(duration * sampleRate)
        return (0..<n).map { i in
            let t = Double(i) / sampleRate
            let envelope = min(1, t / 0.015) * min(1, (duration - t) / 0.05)
            let vibrato = 1 + 0.012 * sin(2 * .pi * 7 * t)
            let wave = sin(2 * .pi * f * vibrato * t) + 0.2 * sin(2 * .pi * f * 2 * t)
            return Float(envelope * wave * 0.8) * volume
        }
    }

    /// 音高快速上滑（气泡“啵”）
    static func sweep(from f0: Double, to f1: Double, duration: Double, volume: Float) -> [Float] {
        let n = Int(duration * sampleRate)
        var phase = 0.0
        return (0..<n).map { i in
            let p = Double(i) / Double(n)
            phase += 2 * .pi * (f0 + (f1 - f0) * p * p) / sampleRate
            let envelope = min(1, p / 0.1) * (1 - p)
            return Float(sin(phase) * envelope) * volume
        }
    }

    /// 水花声：逐渐变弱的噪声
    static func noise(duration: Double, volume: Float) -> [Float] {
        let n = Int(duration * sampleRate)
        var last: Float = 0
        return (0..<n).map { i in
            let p = Double(i) / Double(n)
            // 简单低通，让噪声柔和一点
            last = last * 0.85 + Float.random(in: -1...1) * 0.15
            return last * Float(pow(1 - p, 2)) * volume * 3
        }
    }

    /// 把几段声音按各自的起始时间叠在一起
    static func mix(_ parts: [(offset: Double, samples: [Float])]) -> [Float] {
        let length = parts.map { Int($0.offset * sampleRate) + $0.samples.count }.max() ?? 0
        var out = [Float](repeating: 0, count: length)
        for part in parts {
            let start = Int(part.offset * sampleRate)
            for (i, s) in part.samples.enumerated() { out[start + i] += s }
        }
        return out.map { max(-1, min(1, $0)) }
    }
}
