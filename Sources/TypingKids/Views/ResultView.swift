import SwiftUI

struct ResultView: View {
    let lesson: Lesson
    let result: PracticeResult
    let isNewBest: Bool
    let onRetry: () -> Void
    /// 按键练习：回到区域选择
    let onChangeRegion: (() -> Void)?
    let onHome: () -> Void

    @State private var shownScore = 0
    @State private var revealed = false

    private var scoreColor: Color {
        switch result.score {
        case 90...: Theme.good
        case 75...: Theme.accent
        case 60...: Theme.warn
        default: Theme.bad
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            Text(result.grade.emoji).font(.system(size: 72))
            Text(result.grade.title)
                .font(Theme.font(34, .heavy))
                .foregroundStyle(Theme.ink)
            Text("\(lesson.emoji) \(lesson.title)")
                .font(Theme.font(19))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(shownScore)")
                    .font(Theme.font(96, .heavy))
                    .foregroundStyle(scoreColor)
                    .contentTransition(.numericText(value: Double(shownScore)))
                    .monospacedDigit()
                Text("分").font(Theme.font(30, .bold)).foregroundStyle(scoreColor)
            }

            if isNewBest && revealed {
                Text("🏅 刷新了最高分！")
                    .font(Theme.font(22, .bold))
                    .foregroundStyle(Theme.warn)
                    .transition(.scale.combined(with: .opacity))
            }

            VStack(spacing: 14) {
                ScoreBar(title: "🎯 正确率", detail: "\(Int((result.accuracy * 100).rounded()))%",
                         points: result.accuracyPoints, maxPoints: Int(PracticeResult.accuracyWeight),
                         color: Theme.good, revealed: revealed)
                ScoreBar(title: "🚀 速度", detail: "\(result.cpm) 字/分（基准 \(result.benchmarkCPM)）",
                         points: result.speedPoints, maxPoints: Int(PracticeResult.speedWeight),
                         color: Theme.accent, revealed: revealed)
            }
            .frame(width: 640)
            .card(padding: 22)

            HStack(spacing: 14) {
                SmallStat(title: "用时", value: formatDuration(result.duration))
                SmallStat(title: "按错", value: "\(result.mistakes) 次")
                SmallStat(title: "最多连对", value: "\(result.bestStreak) 个")
            }

            HStack(spacing: 18) {
                Button("返回首页", action: onHome)
                    .buttonStyle(KidButtonStyle(color: Color(white: 0.6)))
                    .keyboardShortcut(.cancelAction)
                if let onChangeRegion {
                    Button("换个区域", action: onChangeRegion)
                        .buttonStyle(KidButtonStyle(color: Theme.accent))
                }
                Button("再练一次 ↩", action: onRetry)
                    .buttonStyle(KidButtonStyle(color: Theme.good))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 6)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await reveal() }
    }

    /// 分数从 0 往上数，数完再亮出得分条和语音点评
    private func reveal() async {
        let target = result.score
        let steps = 30
        for i in 1...steps {
            try? await Task.sleep(for: .milliseconds(28))
            withAnimation(.snappy(duration: 0.1)) { shownScore = target * i / steps }
            if i % 6 == 0 { SoundFX.play(.correct(streak: i / 6)) }
        }
        let level = target >= 90 ? 2 : (target >= 75 ? 1 : 0)
        SoundFX.play(.star(index: level))
        withAnimation(.spring(duration: 0.6, bounce: 0.4)) { revealed = true }
        Cheer.say(isNewBest ? [VoiceLines.newBest, result.grade.speech] : [result.grade.speech], interrupt: true)
    }
}

private struct ScoreBar: View {
    let title: String
    let detail: String
    let points: Int
    let maxPoints: Int
    let color: Color
    let revealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(Theme.font(18, .bold)).foregroundStyle(Theme.ink)
                Text(detail).font(Theme.font(15)).foregroundStyle(.secondary)
                Spacer()
                Text("\(points) / \(maxPoints) 分").font(Theme.font(18, .heavy)).foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color)
                        .frame(width: revealed ? geo.size.width * CGFloat(points) / CGFloat(maxPoints) : 0)
                }
            }
            .frame(height: 14)
        }
    }
}

private struct SmallStat: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(Theme.font(15)).foregroundStyle(.secondary)
            Text(value).font(Theme.font(18, .bold)).foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(.white))
    }
}
