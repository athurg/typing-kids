import AppKit
import SwiftUI

@main
struct TypingKidsApp: App {
    @State private var progress = ProgressStore()

    init() {
        // 直接用 `swift run` 启动（不在 .app 包里）时，也让它像正常 App 一样出现在 Dock 并获得焦点
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApplication.shared.activate(ignoringOtherApps: true) }

        // 进入 App 自动切到英文输入法，离开或退出时恢复
        let center = NotificationCenter.default
        center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            InputSourceSwitcher.switchToEnglish()
        }
        center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
            InputSourceSwitcher.restore()
        }
        center.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            InputSourceSwitcher.restore()
        }
    }

    var body: some Scene {
        WindowGroup("打字小能手") {
            RootView()
                .environment(progress)
                .frame(minWidth: DesignCanvas.minWindowSize.width, minHeight: DesignCanvas.minWindowSize.height)
                .preferredColorScheme(.light)
        }
        .defaultSize(DesignCanvas.designSize)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environment(progress)
        }
    }
}

enum Screen: Equatable {
    case home
    case keySelect
    case practice(Lesson)
    case result(Lesson, PracticeResult, isNewBest: Bool)
    case game(GameKind)
}

struct RootView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var screen: Screen = .home

    var body: some View {
        ZStack {
            // 背景一直铺到标题栏下面，和窗口融为一体
            Theme.background.ignoresSafeArea()

            ScaledCanvas {
                screenView
            }
        }
        .background(WindowConfigurator())
    }

    @ViewBuilder
    private var screenView: some View {
        ZStack {
            switch screen {
            case .home:
                HomeView(onSelectCategory: open, onGame: { go(.game($0)) })
                    .transition(.opacity)

            case .keySelect:
                KeySelectView(onStart: { go(.practice($0)) }, onBack: { go(.home) })
                    .transition(.opacity)

            case .practice(let lesson):
                PracticeView(lesson: lesson,
                             onExit: { go(selectScreen(for: lesson)) },
                             onFinish: { result in
                                 let isNewBest = progress.record(result, lessonID: lesson.id)
                                 go(.result(lesson, result, isNewBest: isNewBest))
                             })
                    .id(lesson.id)
                    .transition(.opacity)

            case let .result(lesson, result, isNewBest):
                ResultView(lesson: lesson, result: result, isNewBest: isNewBest,
                           onRetry: { go(.practice(lesson)) },
                           onChangeRegion: lesson.category == .keys ? { go(.keySelect) } : nil,
                           onHome: { go(.home) })
                    .transition(.opacity)

            case .game(let game):
                Group {
                    switch game {
                    case .balloon: BalloonGameView(onExit: { go(.home) })
                    case .piano: PianoGameView(onExit: { go(.home) })
                    case .bubbles: BubbleGameView(onExit: { go(.home) })
                    case .frog: FrogGameView(onExit: { go(.home) })
                    }
                }
                .transition(.opacity)
            }
        }
    }

    /// 练习中按 esc 回到哪里：按键练习回到区域选择，其它回首页
    private func selectScreen(for lesson: Lesson) -> Screen {
        lesson.category == .keys ? .keySelect : .home
    }

    /// 词语、短句练习直接按系统语言开始
    private func open(_ category: PracticeCategory) {
        switch category {
        case .keys: go(.keySelect)
        case .words: go(.practice(.words(.system)))
        case .sentences: go(.practice(.sentences(.system)))
        }
    }

    private func go(_ next: Screen) {
        withAnimation(.easeInOut(duration: 0.25)) { screen = next }
    }
}
