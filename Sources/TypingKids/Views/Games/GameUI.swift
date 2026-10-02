import SwiftUI

/// 打字游戏区的游戏
enum GameKind: String, CaseIterable, Identifiable {
    case balloon, piano, bubbles, frog

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balloon: "字母气球"
        case .piano: "键盘钢琴"
        case .bubbles: "拼音泡泡"
        case .frog: "青蛙过河"
        }
    }

    var emoji: String {
        switch self {
        case .balloon: "🎈"
        case .piano: "🎹"
        case .bubbles: "🫧"
        case .frog: "🐸"
        }
    }

    var subtitle: String {
        switch self {
        case .balloon: "按下字母，把气球戳破！"
        case .piano: "用基准键弹儿歌"
        case .bubbles: "打出拼音，戳破汉字泡泡"
        case .frog: "打对字母，青蛙跳过河"
        }
    }

    var colors: [Color] {
        switch self {
        case .balloon: [Color(red: 1.00, green: 0.55, blue: 0.40), Color(red: 0.95, green: 0.35, blue: 0.60)]
        case .piano: [Color(red: 0.55, green: 0.45, blue: 0.95), Color(red: 0.38, green: 0.30, blue: 0.80)]
        case .bubbles: [Color(red: 0.30, green: 0.78, blue: 0.95), Color(red: 0.25, green: 0.55, blue: 0.95)]
        case .frog: [Color(red: 0.40, green: 0.80, blue: 0.35), Color(red: 0.15, green: 0.62, blue: 0.45)]
        }
    }
}

/// 游戏页顶部：返回 + 标题 + 右侧信息
struct GameTopBar<Trailing: View>: View {
    let game: GameKind
    let onExit: () -> Void
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onExit) { Label("返回", systemImage: "chevron.left") }
                .buttonStyle(KidButtonStyle(color: Color(white: 0.6)))
            Text("\(game.emoji) \(game.title)")
                .font(Theme.font(28, .heavy))
                .foregroundStyle(Theme.ink)
            Spacer()
            trailing
        }
    }
}

struct GameChip: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(icon)
            Text(value).monospacedDigit()
        }
        .font(Theme.font(20, .bold))
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(.white))
    }
}

/// 游戏开始 / 结束时的白色面板
struct GamePanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 16) { content }
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .padding(40)
            .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white.opacity(0.96)))
            .shadow(radius: 20)
    }
}

/// 游戏开始前的模式选择按钮（也可以按数字键选择）
struct GameOptionButtons<Option: Hashable>: View {
    let options: [Option]
    let selected: Option
    let title: (Option) -> String
    let onSelect: (Option) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(options.enumerated()), id: \.element) { i, option in
                Button { onSelect(option) } label: { Text("\(i + 1). \(title(option))") }
                    .buttonStyle(KidButtonStyle(color: option == selected ? Theme.accent : Color(white: 0.72)))
            }
        }
    }
}
