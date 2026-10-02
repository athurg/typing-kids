import Foundation

struct PracticeItem: Hashable {
    let text: String
    var hint: String? = nil
}

/// 打字练习区的三个类别
enum PracticeCategory: String, CaseIterable, Identifiable {
    case keys, words, sentences

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keys: "按键练习"
        case .words: "词语练习"
        case .sentences: "短句练习"
        }
    }

    var emoji: String {
        switch self {
        case .keys: "⌨️"
        case .words: "📖"
        case .sentences: "💬"
        }
    }

    var subtitle: String {
        switch self {
        case .keys: "自选键盘区域，一排一排练熟"
        case .words: PracticeLanguage.system == .pinyin ? "看汉字打拼音：苹果 → pingguo" : "英文单词：cat dog apple"
        case .sentences: PracticeLanguage.system == .pinyin ? "日常对话：妈妈，我回来了！" : "英文短句：I like cats."
        }
    }

    /// 速度评分的基准（字符/分钟），达到即速度满分。
    /// 成人正常打字约 40 词/分 ≈ 200 字符/分；随机字母比真单词难打，基准略低。
    var benchmarkCPM: Int {
        switch self {
        case .keys: 160
        case .words, .sentences: 200
        }
    }
}

/// 词语、短句练习的语种
enum PracticeLanguage: String, CaseIterable, Identifiable {
    case english, pinyin

    /// 跟随系统语言：系统首选语言是中文就练拼音，否则练英文
    static var system: PracticeLanguage {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .pinyin : .english
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english: "英文"
        case .pinyin: "拼音"
        }
    }

    var emoji: String {
        switch self {
        case .english: "🔤"
        case .pinyin: "🀄"
        }
    }
}

/// 按键练习可选的六个键盘区域
enum KeyRegion: String, CaseIterable, Identifiable, Hashable {
    case topLeft, topRight, homeLeft, homeRight, bottomLeft, bottomRight

    enum Row: Int, CaseIterable { case top, home, bottom }

    var id: String { rawValue }

    var row: Row {
        switch self {
        case .topLeft, .topRight: .top
        case .homeLeft, .homeRight: .home
        case .bottomLeft, .bottomRight: .bottom
        }
    }

    var isLeft: Bool { self == .topLeft || self == .homeLeft || self == .bottomLeft }

    var keys: String {
        switch self {
        case .topLeft: "qwert"
        case .topRight: "yuiop"
        case .homeLeft: "asdfg"
        case .homeRight: "hjkl;"
        case .bottomLeft: "zxcvb"
        case .bottomRight: "nm,./"
        }
    }

    var title: String { "\(row.title)\(isLeft ? "左手" : "右手")" }
}

extension KeyRegion.Row {
    var title: String {
        switch self {
        case .top: "上排"
        case .home: "基准"
        case .bottom: "下排"
        }
    }

    /// 用在练习名称里的叫法
    var name: String {
        switch self {
        case .top: "上排"
        case .home: "基准键"
        case .bottom: "下排"
        }
    }

    var tip: String {
        switch self {
        case .home: "手指放在基准键上：左手 A S D F，右手 J K L ;，摸一摸 F 和 J 上的小凸起。食指往中间伸一步按 G 和 H。"
        case .top: "按上排时手指往前够一下，按完马上回到基准键。"
        case .bottom: "按下排时手指往里弯一弯，手腕不要压在桌子上。"
        }
    }
}

/// 可以附加在任何区域选择上的数字区、符号区
enum KeyExtra: String, CaseIterable, Identifiable, Hashable {
    case numbers, symbols

    var id: String { rawValue }

    var keys: String {
        switch self {
        case .numbers: "1234567890"
        case .symbols: "`-=[]\\'"
        }
    }

    var title: String {
        switch self {
        case .numbers: "包括数字区"
        case .symbols: "包括符号区"
        }
    }

    var name: String {
        switch self {
        case .numbers: "数字"
        case .symbols: "符号"
        }
    }

    var tip: String {
        switch self {
        case .numbers: "数字在最上面一排，手指要伸得远一点，按完记得回到基准键。"
        case .symbols: "符号键大多在右手小指那边，小指要多练练哦。"
        }
    }
}

/// 按键练习的完整选择：字母区域 + 附加的数字 / 符号区
struct KeySelection: Hashable {
    var regions: Set<KeyRegion> = []
    var extras: Set<KeyExtra> = []

    var isEmpty: Bool { regions.isEmpty && extras.isEmpty }

    /// 存到 UserDefaults 的字符串，例如 "homeLeft,homeRight,numbers"
    init(storage: String) {
        for part in storage.split(separator: ",").map(String.init) {
            if let r = KeyRegion(rawValue: part) { regions.insert(r) }
            if let e = KeyExtra(rawValue: part) { extras.insert(e) }
        }
    }

    init(regions: Set<KeyRegion>, extras: Set<KeyExtra> = []) {
        self.regions = regions
        self.extras = extras
    }

    var storage: String { orderedIDs.joined(separator: ",") }

    var orderedIDs: [String] {
        KeyRegion.allCases.filter(regions.contains).map(\.rawValue) + KeyExtra.allCases.filter(extras.contains).map(\.rawValue)
    }

    var keys: String {
        KeyRegion.allCases.filter(regions.contains).map(\.keys).joined()
            + KeyExtra.allCases.filter(extras.contains).map(\.keys).joined()
    }
}

enum KeyRegionNamer {
    /// 根据选择起一个好懂的名字，例如“基准键 · 双手”“左手 · 三排全练”“全键盘（含数字）”
    static func name(for selection: KeySelection) -> String {
        let extras = KeyExtra.allCases.filter(selection.extras.contains).map(\.name)
        if selection.regions.isEmpty {
            switch extras.count {
            case 0: return "请选择练习区域"
            case 1: return extras[0] + "键"
            default: return extras.joined(separator: " + ") + "键"
            }
        }
        let base = name(for: selection.regions)
        return extras.isEmpty ? base : "\(base)（含\(extras.joined(separator: "和"))）"
    }

    /// 只看字母区域的名字
    static func name(for regions: Set<KeyRegion>) -> String {
        guard !regions.isEmpty else { return "请选择练习区域" }
        if regions.count == KeyRegion.allCases.count { return "全键盘" }

        // 命名时基准键排最前（它是“家”），然后上排、下排
        let order: [KeyRegion.Row] = [.home, .top, .bottom]
        let rows = order.filter { row in regions.contains { $0.row == row } }
        let rowNames = rows.map(\.name).joined(separator: " + ")
        let hands = Set(regions.map(\.isLeft))
        func isFull(_ row: KeyRegion.Row) -> Bool {
            regions.contains { $0.row == row && $0.isLeft } && regions.contains { $0.row == row && !$0.isLeft }
        }

        // 只用一只手
        if hands.count == 1 {
            let hand = hands.first! ? "左手" : "右手"
            return rows.count == 3 ? "\(hand) · 三排全练" : "\(rowNames) · \(hand)"
        }
        // 每个选中的排都是左右手都选了
        if rows.allSatisfy(isFull) { return "\(rowNames) · 双手" }
        // 其它混合情况：双手都选的排合在一起说
        return rows.map { row in
            if isFull(row) { return "\(row.title)双手" }
            let region = regions.first { $0.row == row }!
            return region.title
        }.joined(separator: " + ")
    }
}

enum LessonContent: Hashable {
    case keys(String)
    case words(PracticeLanguage)
    case sentences(PracticeLanguage)
}

/// 一次具体的练习
struct Lesson: Identifiable, Hashable {
    /// 也是成绩记录的 key，例如 "keys:homeLeft+homeRight"、"words"
    let id: String
    let category: PracticeCategory
    let emoji: String
    let title: String
    let newKeys: String
    let tip: String
    let content: LessonContent

    static func keys(_ selection: KeySelection) -> Lesson {
        let rows = [KeyRegion.Row.home, .top, .bottom].filter { row in selection.regions.contains { $0.row == row } }
        let tips = rows.map(\.tip) + KeyExtra.allCases.filter(selection.extras.contains).map(\.tip)
        return Lesson(id: "keys:" + selection.orderedIDs.joined(separator: "+"),
                      category: .keys, emoji: "⌨️",
                      title: KeyRegionNamer.name(for: selection),
                      newKeys: selection.keys,
                      tip: tips.joined(separator: "\n"),
                      content: .keys(selection.keys))
    }

    static func words(_ language: PracticeLanguage) -> Lesson {
        switch language {
        case .english:
            Lesson(id: "words:english", category: .words, emoji: "🔤", title: "英文单词", newKeys: "",
                   tip: "打真正的英文单词！看一个词，打一个词。", content: .words(.english))
        case .pinyin:
            Lesson(id: "words:pinyin", category: .words, emoji: "🀄", title: "拼音词语", newKeys: "",
                   tip: "看汉字，打出它的拼音（不用打声调）。", content: .words(.pinyin))
        }
    }

    static func sentences(_ language: PracticeLanguage) -> Lesson {
        switch language {
        case .english:
            Lesson(id: "sentences:english", category: .sentences, emoji: "✏️", title: "英文短句", newKeys: "",
                   tip: "打大写字母时，用另一只手的小指按住 Shift，再按字母键。", content: .sentences(.english))
        case .pinyin:
            Lesson(id: "sentences:pinyin", category: .sentences, emoji: "💬", title: "拼音短句", newKeys: "",
                   tip: "看每个词上面的汉字，打出它的拼音（不用打声调和标点）。\n这些都是我们每天会说的话哦！",
                   content: .sentences(.pinyin))
        }
    }

    func makeItems() -> [PracticeItem] {
        switch content {
        case .keys(let keys):
            return DrillGenerator.keyDrill(focus: Array(keys), pool: Array(keys))
        case .words(.english):
            return WordBank.english.shuffled().prefix(10).map { PracticeItem(text: $0) }
        case .words(.pinyin):
            return WordBank.pinyin.shuffled().prefix(7).map { PracticeItem(text: $0.pinyin, hint: $0.hanzi) }
        case .sentences(.english):
            return WordBank.sentences.shuffled().prefix(3).flatMap { sentence in
                sentence.split(separator: " ").map { PracticeItem(text: String($0)) }
            }
        case .sentences(.pinyin):
            // 带汉字提示比较占地方，一次两句
            return WordBank.pinyinSentences.shuffled().prefix(2).flatMap { sentence in
                WordBank.pinyinSentenceItems(sentence).map { PracticeItem(text: $0.pinyin, hint: $0.hanzi) }
            }
        }
    }
}

enum DrillGenerator {
    /// 生成一组键位练习，例如 "fff jjj fjf sad dfa ..."，总长度约 targetLength 个字符。
    static func keyDrill(focus: [Character], pool: [Character], targetLength: Int = 60) -> [PracticeItem] {
        var groups: [String] = []
        // 热身：键少的时候每个键先打三遍
        if focus.count <= 5 {
            groups = focus.map { String(repeating: $0, count: 3) }
        }

        let words = WordBank.words(using: Set(pool)).shuffled()
        var wordIterator = words.makeIterator()
        let wordChance = words.isEmpty ? 0.0 : (pool.count >= 20 ? 0.5 : 0.3)

        var length = groups.reduce(0) { $0 + $1.count + 1 }
        while length < targetLength {
            let group: String
            if Double.random(in: 0..<1) < wordChance, let word = wordIterator.next() {
                group = word
            } else {
                let n = Int.random(in: 2...4)
                group = String((0..<n).map { _ in Bool.random() ? focus.randomElement()! : pool.randomElement()! })
            }
            groups.append(group)
            length += group.count + 1
        }
        return groups.map { PracticeItem(text: $0) }
    }
}
