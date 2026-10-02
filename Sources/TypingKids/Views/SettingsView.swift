import SwiftUI

/// 家长设置（菜单 打字小能手 → 设置…，或 ⌘,）
struct SettingsView: View {
    @Environment(ProgressStore.self) private var progress
    @AppStorage("soundOn") private var soundOn = true
    @AppStorage("voiceOn") private var voiceOn = true
    @AppStorage("voiceID") private var voiceID = ""
    @AppStorage("autoEnglishInput") private var autoEnglishInput = true
    @AppStorage("showKeyboard") private var showKeyboard = true
    @AppStorage("showHands") private var showHands = true
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("练习") {
                Toggle("按键音效", isOn: $soundOn)
                Toggle("语音鼓励", isOn: $voiceOn)
                HStack {
                    Picker("鼓励的声音", selection: $voiceID) {
                        Text(Cheer.hasRecordings ? "自然人声（推荐）" : "自然人声（未录制）").tag(Cheer.recordedVoiceTag)
                        ForEach(Cheer.systemVoices, id: \.identifier) { voice in
                            Text("系统语音 · \(voice.name)（较机械）").tag(voice.identifier)
                        }
                    }
                    Button("试听") { Cheer.preview(voiceTag: voiceID) }
                }
                .disabled(!voiceOn)
                Toggle("进入时自动切换到英文输入法", isOn: $autoEnglishInput)
                Toggle("显示屏幕键盘", isOn: $showKeyboard)
                Toggle("显示手指提示", isOn: $showHands)
                    .disabled(!showKeyboard)
            }
            Section("家长") {
                Button("清除所有成绩…", role: .destructive) { confirmReset = true }
            }
            Section {
                Text("熟练以后可以关掉屏幕键盘，练习不看键盘打字（盲打）。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("想要更多自然的声音：系统设置 → 辅助功能 → 朗读内容 → 系统声音 → 管理声音，下载“中文（中国大陆）”里的高品质声音。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .confirmationDialog("确定要清除所有成绩吗？", isPresented: $confirmReset) {
            Button("清除", role: .destructive) { progress.reset() }
        } message: {
            Text("此操作无法撤销。")
        }
    }
}
