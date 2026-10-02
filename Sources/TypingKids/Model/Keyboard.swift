import SwiftUI

/// 十个手指。每个键都归某一个手指负责，颜色用来在键盘和小手上做对应提示。
enum Finger: Int, CaseIterable, Hashable {
    case leftPinky, leftRing, leftMiddle, leftIndex, leftThumb
    case rightThumb, rightIndex, rightMiddle, rightRing, rightPinky

    var name: String {
        switch self {
        case .leftPinky: "左手小指"
        case .leftRing: "左手无名指"
        case .leftMiddle: "左手中指"
        case .leftIndex: "左手食指"
        case .leftThumb, .rightThumb: "大拇指"
        case .rightIndex: "右手食指"
        case .rightMiddle: "右手中指"
        case .rightRing: "右手无名指"
        case .rightPinky: "右手小指"
        }
    }

    var isLeft: Bool { rawValue <= Finger.leftThumb.rawValue }

    var color: Color {
        switch self {
        case .leftPinky: Color(red: 1.00, green: 0.45, blue: 0.60)
        case .leftRing: Color(red: 1.00, green: 0.60, blue: 0.20)
        case .leftMiddle: Color(red: 0.90, green: 0.68, blue: 0.00)
        case .leftIndex: Color(red: 0.30, green: 0.75, blue: 0.35)
        case .leftThumb, .rightThumb: Color(red: 0.55, green: 0.60, blue: 0.72)
        case .rightIndex: Color(red: 0.15, green: 0.70, blue: 0.75)
        case .rightMiddle: Color(red: 0.30, green: 0.50, blue: 0.95)
        case .rightRing: Color(red: 0.60, green: 0.40, blue: 0.90)
        case .rightPinky: Color(red: 0.85, green: 0.35, blue: 0.75)
        }
    }
}

struct KeyCap: Identifiable {
    let id: String
    let label: String
    let char: Character?
    let finger: Finger?
    let width: CGFloat
    var shiftLabel: String? = nil
}

enum KeyboardLayout {
    static let shiftedLabel: [Character: String] = [
        "`": "~", "1": "!", "2": "@", "3": "#", "4": "$", "5": "%", "6": "^", "7": "&",
        "8": "*", "9": "(", "0": ")", "-": "_", "=": "+", "[": "{", "]": "}", "\\": "|",
        ";": ":", "'": "\"", ",": "<", ".": ">", "/": "?",
    ]

    private static func keys(_ chars: String, _ fingers: [Finger]) -> [KeyCap] {
        zip(chars, fingers).map { c, f in
            KeyCap(id: String(c), label: c.isLetter ? c.uppercased() : String(c),
                   char: c, finger: f, width: 1, shiftLabel: shiftedLabel[c])
        }
    }

    private static func deco(_ id: String, _ label: String, _ width: CGFloat, _ finger: Finger? = nil) -> KeyCap {
        KeyCap(id: id, label: label, char: nil, finger: finger, width: width)
    }

    /// 简化的 Mac 键盘，每一行总宽度都是 15 个单位。
    static let rows: [[KeyCap]] = {
        let lp = Finger.leftPinky, lr = Finger.leftRing, lm = Finger.leftMiddle, li = Finger.leftIndex
        let ri = Finger.rightIndex, rm = Finger.rightMiddle, rr = Finger.rightRing, rp = Finger.rightPinky
        return [
            keys("`1234567890-=", [lp, lp, lr, lm, li, li, ri, ri, rm, rr, rp, rp, rp])
                + [deco("delete", "delete", 2)],
            [deco("tab", "tab", 1.5)]
                + keys("qwertyuiop[]", [lp, lr, lm, li, li, ri, ri, rm, rr, rp, rp, rp])
                + [KeyCap(id: "\\", label: "\\", char: "\\", finger: rp, width: 1.5, shiftLabel: "|")],
            [deco("caps", "caps lock", 1.75)]
                + keys("asdfghjkl;'", [lp, lr, lm, li, li, ri, ri, rm, rr, rp, rp])
                + [deco("return", "return", 2.25)],
            [deco("lshift", "shift", 2.25, lp)]
                + keys("zxcvbnm,./", [lp, lr, lm, li, li, ri, ri, rm, rr, rp])
                + [deco("rshift", "shift", 2.75, rp)],
            [
                deco("ctrl", "⌃", 1.5), deco("optL", "⌥", 1.5), deco("cmdL", "⌘", 1.75),
                KeyCap(id: " ", label: "空格", char: " ", finger: .leftThumb, width: 5.5),
                deco("cmdR", "⌘", 1.75), deco("optR", "⌥", 1.5), deco("fn", "fn", 1.5),
            ],
        ]
    }()

    /// 每个键在键盘视图里的位置（与 KeyboardView 的排版一致）
    static func keyFrames(unit: CGFloat, spacing: CGFloat, inset: CGFloat) -> [String: CGRect] {
        var frames: [String: CGRect] = [:]
        for (r, row) in rows.enumerated() {
            var x = inset
            let y = inset + CGFloat(r) * (unit + spacing)
            for key in row {
                let w = key.width * unit + (key.width - 1) * spacing
                frames[key.id] = CGRect(x: x, y: y, width: w, height: unit)
                x += w + spacing
            }
        }
        return frames
    }

    static func size(unit: CGFloat, spacing: CGFloat, inset: CGFloat) -> CGSize {
        let count = CGFloat(rows.count)
        return CGSize(width: 15 * unit + 14 * spacing + 2 * inset,
                      height: count * unit + (count - 1) * spacing + 2 * inset)
    }

    static let fingerMap: [Character: Finger] = {
        var map: [Character: Finger] = [:]
        for row in rows {
            for key in row {
                if let c = key.char, let f = key.finger { map[c] = f }
            }
        }
        return map
    }()

    private static let shiftedToBase: [Character: Character] = {
        var map: [Character: Character] = [:]
        for (base, shifted) in shiftedLabel { map[Character(shifted)] = base }
        return map
    }()

    struct Target {
        let key: Character
        let needsShift: Bool
    }

    /// 要打出某个字符，需要按哪个键、是否需要 Shift。
    static func target(for c: Character) -> Target {
        if c.isASCII, c.isLetter, c.isUppercase {
            return Target(key: Character(c.lowercased()), needsShift: true)
        }
        if let base = shiftedToBase[c] { return Target(key: base, needsShift: true) }
        return Target(key: c, needsShift: false)
    }

    /// 打这个字符要用到的手指（大写字母还需要另一只手的小指按 Shift）。
    static func fingers(for c: Character) -> [Finger] {
        let t = target(for: c)
        if t.key == " " { return [.leftThumb, .rightThumb] }
        guard let f = fingerMap[t.key] else { return [] }
        return t.needsShift ? [f, shiftFinger(for: f)] : [f]
    }

    static func shiftFinger(for f: Finger) -> Finger { f.isLeft ? .rightPinky : .leftPinky }

    static func highlightedKeyIDs(for c: Character) -> Set<String> {
        let t = target(for: c)
        var ids: Set<String> = [String(t.key)]
        if t.needsShift, let f = fingerMap[t.key] {
            ids.insert(f.isLeft ? "rshift" : "lshift")
        }
        return ids
    }

    /// 给小朋友看的键名。
    static func displayName(_ c: Character) -> String {
        if c == " " { return "空格" }
        let t = target(for: c)
        let base = t.key.isLetter ? t.key.uppercased() : String(t.key)
        return t.needsShift ? "Shift + \(base)" : base
    }
}
