import Foundation

enum WordBank {
    /// 适合小学生的简单英文单词。
    static let english: [String] = [
        "cat", "dog", "sun", "fish", "bird", "book", "milk", "cake", "tree", "star",
        "moon", "rain", "snow", "red", "blue", "green", "pink", "black", "white", "apple",
        "happy", "water", "jump", "run", "play", "sing", "read", "draw", "swim", "park",
        "home", "school", "friend", "mom", "dad", "baby", "hand", "foot", "head", "eye",
        "nose", "face", "game", "ball", "kite", "bike", "car", "bus", "ship", "duck",
        "frog", "lion", "bear", "tiger", "panda", "zoo", "egg", "rice", "bread", "juice",
        "tea", "cup", "desk", "pen", "box", "door", "room", "bed", "lamp", "sky",
        "sea", "hill", "rose", "fast", "slow", "big", "small", "good", "nice", "love",
    ]

    /// 只用基准键和少量字母就能拼出来的词，让前几关也有“真单词”。
    private static let easyWords: [String] = [
        "add", "dad", "sad", "fad", "ask", "all", "fall", "hall", "lad", "lass",
        "glad", "flag", "flash", "half", "had", "has", "dash", "salad", "flask", "glass",
        "slash", "gas", "shall", "alas", "jars", "ruler", "tower", "street", "sweet", "quiet",
    ]

    static func words(using keys: Set<Character>) -> [String] {
        Array(Set(english + easyWords)).filter { word in
            word.count >= 2 && word.allSatisfy { keys.contains($0) }
        }
    }

    /// 拼音词语（避开 ü，让小朋友只用 26 个字母）。
    static let pinyin: [(hanzi: String, pinyin: String)] = [
        ("苹果", "pingguo"), ("香蕉", "xiangjiao"), ("学校", "xuexiao"), ("老师", "laoshi"),
        ("同学", "tongxue"), ("妈妈", "mama"), ("爸爸", "baba"), ("小猫", "xiaomao"),
        ("小狗", "xiaogou"), ("太阳", "taiyang"), ("月亮", "yueliang"), ("星星", "xingxing"),
        ("大海", "dahai"), ("熊猫", "xiongmao"), ("中国", "zhongguo"), ("朋友", "pengyou"),
        ("快乐", "kuaile"), ("读书", "dushu"), ("写字", "xiezi"), ("电脑", "diannao"),
        ("键盘", "jianpan"), ("打字", "dazi"), ("飞机", "feiji"), ("汽车", "qiche"),
        ("花朵", "huaduo"), ("草地", "caodi"), ("蓝天", "lantian"), ("白云", "baiyun"),
        ("春天", "chuntian"), ("夏天", "xiatian"), ("秋天", "qiutian"), ("冬天", "dongtian"),
        ("西瓜", "xigua"), ("葡萄", "putao"), ("足球", "zuqiu"), ("跑步", "paobu"),
        ("唱歌", "changge"), ("画画", "huahua"), ("游泳", "youyong"), ("生日", "shengri"),
    ]

    /// 短句：首字母大写 + 句号，练习 Shift 键。
    static let sentences: [String] = [
        "I like cats.", "The sun is hot.", "We go to school.", "My dog can run fast.",
        "I love my mom and dad.", "The sky is blue.", "She has a red hat.",
        "We play in the park.", "Birds can fly.", "I read a book every day.",
        "The cake is sweet.", "Fish can swim.", "It is a nice day.", "Look at the moon.",
    ]

    /// 拼音短句：日常对话片段。每个词写成 “汉字|拼音”，标点跟在汉字后面只做显示。
    /// 避开 ü，让小朋友只用 26 个字母。
    static let pinyinSentences: [String] = [
        "妈妈，|mama 我|wo 回来|huilai 了！|le",
        "今天|jintian 天气|tianqi 真|zhen 好！|hao",
        "我们|women 去|qu 公园|gongyuan 玩|wan 吧！|ba",
        "你|ni 吃饭|chifan 了|le 吗？|ma",
        "早上|zaoshang 好，|hao 老师！|laoshi",
        "谢谢|xiexie 你|ni 帮助|bangzhu 我。|wo",
        "我|wo 想|xiang 喝|he 一杯|yibei 水。|shui",
        "这|zhe 本|ben 书|shu 很|hen 好看。|haokan",
        "我们|women 一起|yiqi 做|zuo 作业|zuoye 吧。|ba",
        "你|ni 叫|jiao 什么|shenme 名字？|mingzi",
        "我|wo 今年|jinnian 十|shi 岁|sui 了。|le",
        "外面|waimian 下雨|xiayu 了，|le 记得|jide 带|dai 伞。|san",
        "晚安，|wanan 做个|zuoge 好梦。|haomeng",
        "我|wo 最|zui 喜欢|xihuan 吃|chi 西瓜。|xigua",
        "周末|zhoumo 我们|women 去|qu 看|kan 电影。|dianying",
        "请问|qingwen 洗手间|xishoujian 在|zai 哪里？|nali",
        "对不起，|duibuqi 我|wo 来|lai 晚|wan 了。|le",
        "没关系，|meiguanxi 下次|xiaci 注意|zhuyi 就|jiu 好。|hao",
        "爸爸，|baba 我们|women 去|qu 踢|ti 足球|zuqiu 吧！|ba",
        "我|wo 饿|e 了，|le 有|you 什么|shenme 好吃的？|haochide",
        "今天|jintian 的|de 作业|zuoye 写完|xiewan 了。|le",
        "我们|women 是|shi 好朋友。|haopengyou",
        "明天|mingtian 见，|jian 路上|lushang 小心！|xiaoxin",
        "生日|shengri 快乐，|kuaile 这|zhe 是|shi 送|song 你|ni 的|de 礼物。|liwu",
        "奶奶，|nainai 我|wo 来|lai 帮|bang 你|ni 拿。|na",
    ]

    /// 把一句拼音短句拆成练习条目
    static func pinyinSentenceItems(_ sentence: String) -> [(hanzi: String, pinyin: String)] {
        sentence.split(separator: " ").compactMap { token in
            let parts = token.split(separator: "|", maxSplits: 1).map(String.init)
            return parts.count == 2 ? (parts[0], parts[1]) : nil
        }
    }
}
