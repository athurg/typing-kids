import SwiftUI

struct PianoGameView: View {
    let onExit: () -> Void

    @Environment(ProgressStore.self) private var progress
    @State private var game: PianoGame
    @State private var pressedKey: Character?
    @State private var wrongKey: Character?
    @State private var shake = 0
    @State private var isNewHigh = false
    @State private var replayTask: Task<Void, Never>?
    @AppStorage("pianoSong") private var savedSong = PianoSong.all[0].id

    init(onExit: @escaping () -> Void, game: PianoGame = PianoGame()) {
        self.onExit = onExit
        _game = State(initialValue: game)
    }

    var body: some View {
        VStack(spacing: 18) {
            GameTopBar(game: .piano, onExit: onExit) {
                GameChip(icon: game.song.emoji, value: game.song.title)
                GameChip(icon: "🎵", value: "\(min(game.index, game.notes.count))/\(game.notes.count)")
                GameChip(icon: "🎯", value: "弹对率 \(game.liveAccuracy)%")
            }

            ZStack {
                VStack(spacing: 18) {
                    HStack(alignment: .top, spacing: 30) {
                        sheet.frame(maxWidth: .infinity)
                        lyricsOverview.frame(width: 250)
                    }
                    hint
                    Spacer(minLength: 0)
                    piano
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 0.95, green: 0.93, blue: 1.0), .white],
                                             startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                )

                switch game.phase {
                case .ready: readyPanel
                case .done: donePanel
                case .playing, .replaying: EmptyView()
                }
            }
        }
        .padding(24)
        .onAppear { game.song = PianoSong.all.first { $0.id == savedSong } ?? PianoSong.all[0] }
        .onDisappear { replayTask?.cancel() }
        .onKeyboardInput(handleKey)
    }

    // MARK: - 按键

    private func handleKey(_ press: KeyPress) {
        switch press.kind {
        case .escape: onExit()
        case .flagsChanged: break
        case .character(let c):
            switch game.phase {
            case .ready, .done:
                if c == " " {
                    isNewHigh = false
                    game.start()
                } else if let n = Int(String(c)), (1...PianoSong.all.count).contains(n) {
                    selectSong(PianoSong.all[n - 1])
                }
            case .replaying:
                break
            case .playing:
                flash(c)
                switch game.press(c) {
                case .correct(let midi):
                    SoundFX.play(.note(midi: midi))
                case .finished(let midi):
                    SoundFX.play(.note(midi: midi))
                    isNewHigh = progress.recordGame("piano", score: game.score,
                                                    seconds: Date().timeIntervalSince(game.startDate))
                    Cheer.say(VoiceLines.pianoDone, interrupt: true)
                    startReplay(after: 3.2)
                case .wrong:
                    SoundFX.play(.wrong)
                    withAnimation(.linear(duration: 0.3)) { shake += 1 }
                case .ignored:
                    break
                }
            }
        }
    }

    private func flash(_ c: Character) {
        let key = Character(c.lowercased())
        let isRight = key == game.current?.key
        if isRight { pressedKey = key } else { wrongKey = PianoKeys.index(of: key) != nil ? key : nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if pressedKey == key { pressedKey = nil }
            if wrongKey == key { wrongKey = nil }
        }
    }

    private func selectSong(_ song: PianoSong) {
        game.song = song
        savedSong = song.id
    }

    /// 弹完后按真正的节奏完整播放一遍
    private func startReplay(after delay: Double) {
        replayTask?.cancel()
        replayTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            let beat = 0.45
            for (i, note) in game.notes.enumerated() {
                if Task.isCancelled { return }
                game.setReplayIndex(i)
                if let k = PianoKeys.index(of: note.key) {
                    SoundFX.play(.note(midi: PianoKeys.midi[k]))
                    pressedKey = note.key
                }
                try? await Task.sleep(for: .seconds(note.beats * beat))
                pressedKey = nil
            }
            try? await Task.sleep(for: .seconds(0.4))
            game.finishReplay()
        }
    }

    // MARK: - 乐谱

    private var activeIndex: Int { game.replayIndex ?? game.index }

    private var sheet: some View {
        let pos = game.position(of: min(activeIndex, max(game.notes.count - 1, 0)))
        let phrases = game.song.phrases
        let startOfPhrase = phrases.prefix(pos.phrase).reduce(0) { $0 + $1.count }
        return VStack(spacing: 14) {
            // 当前乐句
            HStack(spacing: 14) {
                ForEach(Array(phrases[pos.phrase].enumerated()), id: \.offset) { offset, note in
                    NoteBubble(note: note, state: noteState(startOfPhrase + offset), shake: shake)
                }
            }
            .frame(height: 190)
            // 下一句（淡一点）
            if pos.phrase + 1 < phrases.count {
                HStack(spacing: 8) {
                    Text("下一句").font(Theme.font(14, .semibold)).foregroundStyle(.secondary)
                    ForEach(Array(phrases[pos.phrase + 1].enumerated()), id: \.offset) { _, note in
                        Text(note.lyric).font(Theme.font(20, .bold)).foregroundStyle(Theme.ink.opacity(0.35))
                    }
                }
            } else {
                Text("最后一句啦！").font(Theme.font(16, .semibold)).foregroundStyle(.secondary)
            }
        }
    }

    /// 右侧的整首歌词：唱到哪一句就高亮哪一句
    private var lyricsOverview: some View {
        let current = game.position(of: min(activeIndex, max(game.notes.count - 1, 0))).phrase
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(game.song.emoji) \(game.song.title)").font(Theme.font(18, .heavy)).foregroundStyle(Theme.ink)
            ForEach(Array(game.song.phrases.enumerated()), id: \.offset) { i, phrase in
                Text(phrase.map(\.lyric).joined())
                    .font(Theme.font(i == current ? 20 : 17, i == current ? .heavy : .semibold))
                    .foregroundStyle(i == current ? Theme.accent : Theme.ink.opacity(i < current ? 0.35 : 0.6))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.8)))
        .animation(.easeOut(duration: 0.2), value: current)
    }

    private func noteState(_ i: Int) -> NoteBubble.State {
        if i < activeIndex { return .done }
        if i == activeIndex && (game.phase == .playing || game.replayIndex != nil) { return .current }
        return .pending
    }

    @ViewBuilder
    private var hint: some View {
        if game.phase == .playing, let note = game.current, let i = PianoKeys.index(of: note.key),
           let finger = KeyboardLayout.fingers(for: note.key).first {
            HStack(spacing: 10) {
                Text("下一个").foregroundStyle(.secondary)
                KeyBadge(char: note.key, size: 44)
                Text("（\(PianoKeys.solfege[i])）").foregroundStyle(.secondary)
                Text("用").foregroundStyle(.secondary)
                Text(finger.name).foregroundStyle(finger.color)
            }
            .font(Theme.font(22, .bold))
        } else if game.phase == .replaying {
            Text("🎧 一起来听一遍完整的《\(game.song.title)》").font(Theme.font(22, .bold)).foregroundStyle(Theme.accent)
        }
    }

    // MARK: - 钢琴

    private var piano: some View {
        HStack(spacing: 8) {
            ForEach(Array(PianoKeys.keys.enumerated()), id: \.offset) { i, key in
                PianoKeyView(key: key, index: i,
                             isTarget: game.phase == .playing && game.current?.key == key,
                             isPressed: pressedKey == key,
                             isWrong: wrongKey == key)
            }
        }
    }

    // MARK: - 面板

    private var readyPanel: some View {
        GamePanel {
            Text("🎹 键盘钢琴").font(Theme.font(40, .heavy))
            Text("基准键变成了钢琴键！照着乐谱一个一个按，\n按对了才会响，弹完一整首歌吧。")
                .font(Theme.font(19))
            Text("选一首歌（也可以按数字键 1 2 3 4）")
                .font(Theme.font(16, .semibold)).foregroundStyle(.secondary)
            GameOptionButtons(options: PianoSong.all, selected: game.song,
                              title: { "\($0.emoji) \($0.title)" }, onSelect: selectSong)
            Text("按 空格键 开始！").font(Theme.font(26, .heavy)).foregroundStyle(Theme.good)
        }
    }

    private var donePanel: some View {
        GamePanel {
            Text(isNewHigh ? "🏆 新纪录！" : "🎉 弹完啦！").font(Theme.font(40, .heavy))
            Text("弹对率 \(game.score)%").font(Theme.font(52, .heavy)).foregroundStyle(Theme.accent)
            Text("按错 \(game.mistakes) 次 · 最高 \(progress.gameHighScore("piano"))%")
                .font(Theme.font(19, .semibold)).foregroundStyle(.secondary)
            GameOptionButtons(options: PianoSong.all, selected: game.song,
                              title: { "\($0.emoji) \($0.title)" }, onSelect: selectSong)
            Text("按 空格键 再弹一次，按 esc 返回").font(Theme.font(20, .bold)).foregroundStyle(Theme.good)
        }
    }
}

private struct NoteBubble: View {
    enum State { case done, current, pending }

    let note: PianoNote
    let state: State
    let shake: Int

    var body: some View {
        let i = PianoKeys.index(of: note.key) ?? 0
        let color = KeyboardLayout.fingers(for: note.key).first?.color ?? Theme.accent
        VStack(spacing: 6) {
            Text(PianoKeys.jianpu[i])
                .font(Theme.font(22, .bold))
                .foregroundStyle(.secondary)
            ZStack {
                Circle()
                    .fill(state == .pending ? color.opacity(0.18) : color)
                Text(note.key.uppercased())
                    .font(Theme.font(40, .heavy))
                    .foregroundStyle(state == .pending ? color : .white)
            }
            .frame(width: 84, height: 84)
            .overlay(Circle().stroke(.white, lineWidth: state == .current ? 4 : 0))
            .shadow(color: state == .current ? color.opacity(0.7) : .clear, radius: 12)
            .scaleEffect(state == .current ? 1.2 : (state == .done ? 0.9 : 1))
            .opacity(state == .done ? 0.55 : 1)
            .modifier(ShakeEffect(animatableData: state == .current ? CGFloat(shake) : 0))
            Text(note.lyric)
                .font(Theme.font(32, .heavy))
                .foregroundStyle(state == .pending ? Theme.ink.opacity(0.45) : Theme.ink)
        }
        .animation(.spring(duration: 0.25), value: state)
    }
}

private struct PianoKeyView: View {
    let key: Character
    let index: Int
    let isTarget: Bool
    let isPressed: Bool
    let isWrong: Bool

    var body: some View {
        let color = KeyboardLayout.fingers(for: key).first?.color ?? Theme.accent
        VStack(spacing: 6) {
            Text(PianoKeys.solfege[index])
                .font(Theme.font(15, .bold))
                .foregroundStyle(isTarget || isPressed ? .white : color)
            Text(PianoKeys.jianpu[index])
                .font(Theme.font(20, .bold))
                .foregroundStyle(isTarget || isPressed ? .white.opacity(0.9) : .secondary)
            Spacer()
            Text(key.uppercased())
                .font(Theme.font(36, .heavy))
                .foregroundStyle(isTarget || isPressed ? .white : Theme.ink)
            if key == "f" || key == "j" {
                Capsule().fill(isTarget || isPressed ? .white : Theme.ink.opacity(0.4)).frame(width: 18, height: 4)
            }
        }
        .padding(.vertical, 16)
        .frame(width: 104, height: 210)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isWrong ? Theme.bad : (isTarget || isPressed ? color : .white))
                .shadow(color: isTarget ? color.opacity(0.7) : .black.opacity(0.15),
                        radius: isTarget ? 14 : 3, y: isPressed ? 1 : 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.5), lineWidth: 2)
        )
        .offset(y: isPressed ? 6 : 0)
        .scaleEffect(isTarget ? 1.04 : 1, anchor: .bottom)
        .animation(.spring(duration: 0.15), value: isPressed)
        .animation(.spring(duration: 0.25), value: isTarget)
    }
}
