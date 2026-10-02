import SwiftUI

struct HomeView: View {
    @Environment(ProgressStore.self) private var progress

    let onSelectCategory: (PracticeCategory) -> Void
    let onGame: (GameKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            SectionTitle(emoji: "📚", title: "打字练习区", subtitle: "认真练，拿高分")
            HStack(spacing: 18) {
                ForEach(PracticeCategory.allCases) { category in
                    Button { onSelectCategory(category) } label: {
                        HomeCard(emoji: category.emoji, title: category.title, subtitle: category.subtitle,
                                 colors: Self.colors(for: category),
                                 badge: progress.bestScore(in: category).map { ("\($0)", "最高分") },
                                 footnote: progress.plays(in: category) > 0
                                     ? "已练习 \(progress.plays(in: category)) 次" : "还没练过，来试试吧！",
                                 large: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 260)

            SectionTitle(emoji: "🎮", title: "打字游戏区", subtitle: "边玩边练，越玩越快")
            HStack(spacing: 18) {
                ForEach(GameKind.allCases) { game in
                    Button { onGame(game) } label: {
                        HomeCard(emoji: game.emoji, title: game.title, subtitle: game.subtitle,
                                 colors: game.colors,
                                 badge: gameBadge(game),
                                 footnote: nil,
                                 large: false)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 230)

            Spacer(minLength: 0)
            TipTicker()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 22)
    }

    private func gameBadge(_ game: GameKind) -> (String, String)? {
        let best = progress.gameHighScore(game.rawValue)
        guard best > 0 else { return nil }
        switch game {
        case .piano: return ("\(best)%", "最高弹对率")
        case .frog: return ("\(best)", "最多荷叶")
        default: return ("\(best)", "最高分")
        }
    }

    private static func colors(for category: PracticeCategory) -> [Color] {
        switch category {
        case .keys: [Color(red: 0.40, green: 0.55, blue: 1.00), Color(red: 0.55, green: 0.42, blue: 0.95)]
        case .words: [Color(red: 0.25, green: 0.75, blue: 0.55), Color(red: 0.15, green: 0.62, blue: 0.70)]
        case .sentences: [Color(red: 0.98, green: 0.70, blue: 0.22), Color(red: 0.95, green: 0.48, blue: 0.22)]
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("⌨️ 打字小能手")
                    .font(Theme.font(42, .heavy))
                    .foregroundStyle(Theme.ink)
                Text("每天练一练，学会用十个手指打字")
                    .font(Theme.font(19))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 14) {
                SummaryTile(icon: "🏅", value: "\(progress.overallBest)", label: "练习最高分")
                SummaryTile(icon: "📝", value: "\(progress.totalPlays)", label: "练习次数")
                SummaryTile(icon: "⏱", value: "\(Int(progress.totalSeconds / 60))", label: "累计分钟")
            }
        }
    }
}

private struct SectionTitle: View {
    let emoji: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(emoji) \(title)").font(Theme.font(24, .heavy)).foregroundStyle(Theme.ink)
            Text(subtitle).font(Theme.font(16)).foregroundStyle(.secondary)
        }
    }
}

private struct SummaryTile: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(icon) \(value)")
                .font(Theme.font(22, .heavy))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(Theme.font(13))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 100)
        .card(padding: 14)
    }
}

private struct HomeCard: View {
    let emoji: String
    let title: String
    let subtitle: String
    let colors: [Color]
    let badge: (value: String, label: String)?
    let footnote: String?
    let large: Bool

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(emoji).font(.system(size: large ? 54 : 46))
                Spacer()
                if let badge {
                    VStack(spacing: 0) {
                        Text(badge.value).font(Theme.font(large ? 26 : 22, .heavy))
                        Text(badge.label).font(Theme.font(11, .semibold)).opacity(0.85)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.22)))
                }
            }
            Spacer(minLength: 0)
            Text(title)
                .font(Theme.font(large ? 32 : 26, .heavy))
            Text(subtitle)
                .font(Theme.font(large ? 17 : 15))
                .opacity(0.92)
                .lineLimit(1)
            if let footnote {
                Text(footnote)
                    .font(Theme.font(13, .semibold))
                    .opacity(0.8)
            }
        }
        .foregroundStyle(.white)
        .padding(large ? 24 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: colors[1].opacity(hovering ? 0.45 : 0.25), radius: hovering ? 16 : 10, y: 6)
        )
        .scaleEffect(hovering ? 1.03 : 1)
        .animation(.spring(duration: 0.2), value: hovering)
        .onHover { hovering = $0 }
    }
}

/// 底部的小贴士：一次一行，每隔几秒像跑马灯一样从下往上换一条
private struct TipTicker: View {
    private static let tips: [(String, String)] = [
        ("🪑", "坐直，双脚平放在地上"),
        ("👀", "眼睛离屏幕一臂远，看屏幕不看键盘"),
        ("🏠", "手指轻轻放在基准键上：A S D F 和 J K L ;"),
        ("👆", "摸一摸 F 和 J 上的小凸起，那是手指的家"),
        ("↩️", "按完一个键，手指马上回到基准键"),
        ("🎯", "先求准，再求快，准确比速度更重要"),
        ("👍", "空格键用大拇指按，轻轻一点就好"),
        ("⇧", "打大写字母：一只手按字母，另一只手的小指按住 Shift"),
        ("⏰", "每练 20 分钟，起来活动一下、看看远处"),
        ("🌟", "每天练一会儿，比一次练很久更有效"),
    ]
    private static let interval: Double = 4

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.interval)) { context in
            let index = Int(context.date.timeIntervalSinceReferenceDate / Self.interval) % Self.tips.count
            let tip = Self.tips[index]
            HStack(spacing: 12) {
                Text("💡 小贴士")
                    .font(Theme.font(15, .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.accent))
                ZStack(alignment: .leading) {
                    HStack(spacing: 8) {
                        Text(tip.0)
                        Text(tip.1)
                    }
                    .font(Theme.font(19, .semibold))
                    .foregroundStyle(Theme.ink)
                    .id(index)
                    .transition(.push(from: .bottom))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
                .animation(.spring(duration: 0.6), value: index)
            }
            .padding(.horizontal, 18)
            .frame(height: 50)
            .background(Capsule().fill(.white.opacity(0.85)))
        }
    }
}
