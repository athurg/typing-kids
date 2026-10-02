import Carbon

/// 进入 App 时自动切换到英文（ABC）输入法，离开时恢复原来的输入法。
enum InputSourceSwitcher {
    private static var previous: TISInputSource?

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "autoEnglishInput") as? Bool ?? true
    }

    static func switchToEnglish() {
        guard isEnabled else { return }
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        // 系统当前可用的英文键盘布局（通常是 ABC 或 美国）
        guard let english = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue() else { return }
        guard identifier(of: current) != identifier(of: english) else { return }
        previous = current
        TISSelectInputSource(english)
    }

    static func restore() {
        guard let previous else { return }
        TISSelectInputSource(previous)
        self.previous = nil
    }

    private static func identifier(of source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}
