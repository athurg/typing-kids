import AppKit
import SwiftUI

struct KeyPress {
    enum Kind {
        case character(Character)
        case escape
        case flagsChanged
    }

    let kind: Kind
    let capsLock: Bool
}

extension View {
    /// 直接监听本窗口的按键（绕过输入法），用于打字练习。
    func onKeyboardInput(_ handler: @escaping (KeyPress) -> Void) -> some View {
        modifier(KeyboardInputModifier(handler: handler))
    }
}

private struct KeyboardInputModifier: ViewModifier {
    let handler: (KeyPress) -> Void
    @State private var monitor = KeyMonitor()

    func body(content: Content) -> some View {
        content
            .background(WindowReader(monitor: monitor))
            .onAppear { monitor.install(handler) }
            .onDisappear { monitor.uninstall() }
    }
}

private final class KeyMonitor {
    weak var window: NSWindow?
    private var token: Any?

    func install(_ handler: @escaping (KeyPress) -> Void) {
        uninstall()
        token = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            // 只处理练习窗口的按键，设置窗口等不受影响
            guard let window = self?.window, event.window === window else { return event }
            let capsLock = event.modifierFlags.contains(.capsLock)

            if event.type == .flagsChanged {
                handler(KeyPress(kind: .flagsChanged, capsLock: capsLock))
                return event
            }
            // ⌘Q、⌘W 等快捷键照常交给系统
            if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
                return event
            }
            if event.keyCode == 53 {
                handler(KeyPress(kind: .escape, capsLock: capsLock))
                return nil
            }
            if let ch = event.characters?.first,
               ch == " " || ch.isLetter || ch.isNumber || ch.isPunctuation || ch.isSymbol {
                handler(KeyPress(kind: .character(ch), capsLock: capsLock))
            }
            // 其它键（回车、删除、方向键）吞掉，避免系统“咚”的提示音
            return nil
        }
    }

    func uninstall() {
        if let token { NSEvent.removeMonitor(token) }
        token = nil
    }

    deinit { uninstall() }
}

private struct WindowReader: NSViewRepresentable {
    let monitor: KeyMonitor

    func makeNSView(context: Context) -> NSView {
        let view = ReaderView()
        view.monitor = monitor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class ReaderView: NSView {
        weak var monitor: KeyMonitor?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            monitor?.window = window
        }
    }
}
