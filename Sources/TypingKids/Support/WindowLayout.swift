import AppKit
import SwiftUI

enum DesignCanvas {
    /// 所有页面都按这个尺寸设计
    static let designSize = CGSize(width: 1280, height: 820)
    static let minWindowSize = CGSize(width: 800, height: 512)
}

/// 按固定的设计尺寸排版，再整体等比缩放到窗口大小（不需要滚动）。
struct ScaledCanvas<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geo in
            let size = DesignCanvas.designSize
            let scale = min(geo.size.width / size.width, geo.size.height / size.height)
            content
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// 配置主窗口：透明标题栏、内容铺满、锁定宽高比、首次打开时按屏幕大小调整
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ConfigView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ConfigView: NSView {
        private var configured = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, !configured else { return }
            configured = true

            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.backgroundColor = NSColor(Theme.bgTop)

            // 标题栏占的高度（内容区要留出来，背景则铺到标题栏下面）
            let titlebarHeight = window.frame.height - window.contentLayoutRect.height
            let design = DesignCanvas.designSize
            window.contentAspectRatio = NSSize(width: design.width, height: design.height + titlebarHeight)

            // 窗口尽量大，但不超过屏幕可用区域的 92%
            if let screen = window.screen ?? NSScreen.main {
                let visible = screen.visibleFrame
                let scale = min(visible.width * 0.92 / design.width,
                                visible.height * 0.92 / (design.height + titlebarHeight), 1.25)
                let size = NSSize(width: design.width * scale, height: design.height * scale + titlebarHeight)
                let origin = NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
                window.setFrame(NSRect(origin: origin, size: size), display: true)
            }
        }
    }
}
