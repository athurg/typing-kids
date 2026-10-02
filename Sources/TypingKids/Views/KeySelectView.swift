import SwiftUI

/// 按键练习：自选键盘区域
struct KeySelectView: View {
    let onStart: (Lesson) -> Void
    let onBack: () -> Void

    @Environment(ProgressStore.self) private var progress
    /// 每次的选择都会保存，下次进来默认还是它
    @AppStorage("keyRegions") private var savedSelection = KeyRegion.homeLeft.rawValue

    private var selection: KeySelection { KeySelection(storage: savedSelection) }

    private func update(_ change: (inout KeySelection) -> Void) {
        var s = selection
        change(&s)
        savedSelection = s.storage
    }

    private func toggle(_ region: KeyRegion) {
        update { s in
            if s.regions.contains(region) { s.regions.remove(region) } else { s.regions.insert(region) }
        }
    }

    var body: some View {
        let selection = selection
        let lesson = Lesson.keys(selection)
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Button(action: onBack) { Label("返回", systemImage: "chevron.left") }
                    .buttonStyle(KidButtonStyle(color: Color(white: 0.6)))
                    .keyboardShortcut(.cancelAction)
                Text("⌨️ 按键练习")
                    .font(Theme.font(28, .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }

            // 名称 + 开始
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("这次练习").font(Theme.font(15)).foregroundStyle(.secondary)
                    Text(lesson.title)
                        .font(Theme.font(34, .heavy))
                        .foregroundStyle(selection.isEmpty ? .secondary : Theme.ink)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: lesson.title)
                    Text(selection.isEmpty ? "在下面点选要练的键盘区域" : "共 \(lesson.newKeys.count) 个键")
                        .font(Theme.font(15)).foregroundStyle(.secondary)
                }
                Spacer()
                if let best = progress.record(for: lesson.id)?.bestScore, !selection.isEmpty {
                    VStack(spacing: 2) {
                        Text("\(best)").font(Theme.font(34, .heavy)).foregroundStyle(Theme.accent)
                        Text("最高分").font(Theme.font(13)).foregroundStyle(.secondary)
                    }
                }
                Button { onStart(lesson) } label: { Text("开始练习 ↩") }
                    .buttonStyle(KidButtonStyle(color: selection.isEmpty ? Color(white: 0.75) : Theme.good))
                    .keyboardShortcut(.defaultAction)
                    .disabled(selection.isEmpty)
            }
            .card(padding: 22)

            KeyboardView(emphasized: Set(lesson.newKeys.map { String($0) }))

            HStack(alignment: .top, spacing: 28) {
                regionGrid(selection.regions)
                Divider().frame(height: 160)
                presets(selection)
            }
            .card(padding: 20)

            Spacer(minLength: 0)
        }
        .padding(24)
    }

    private func regionGrid(_ selection: Set<KeyRegion>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("选择区域（可多选）").font(Theme.font(16, .bold)).foregroundStyle(.secondary)
            ForEach(KeyRegion.Row.allCases, id: \.self) { row in
                HStack(spacing: 10) {
                    Text(row.name)
                        .font(Theme.font(17, .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 60, alignment: .leading)
                    ForEach(KeyRegion.allCases.filter { $0.row == row }) { region in
                        RegionButton(region: region, isOn: selection.contains(region)) { toggle(region) }
                    }
                }
            }
        }
    }

    private func presets(_ selection: KeySelection) -> some View {
        let left: Set<KeyRegion> = [.topLeft, .homeLeft, .bottomLeft]
        let right: Set<KeyRegion> = [.topRight, .homeRight, .bottomRight]
        // 前两行设定字母区域（保留数字 / 符号的勾选），第三行是附加开关
        let regionPresets: [(String, Set<KeyRegion>)] = [
            ("基准键双手", [.homeLeft, .homeRight]),
            ("上排双手", [.topLeft, .topRight]),
            ("下排双手", [.bottomLeft, .bottomRight]),
            ("左手全部", left),
            ("右手全部", right),
            ("全键盘", left.union(right)),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            Text("快速选择").font(Theme.font(16, .bold)).foregroundStyle(.secondary)
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(0..<2, id: \.self) { row in
                    GridRow {
                        ForEach(regionPresets[(row * 3)..<(row * 3 + 3)], id: \.0) { title, regions in
                            PresetButton(title: title, isOn: selection.regions == regions) {
                                update { $0.regions = regions }
                            }
                        }
                    }
                }
                GridRow {
                    ForEach(KeyExtra.allCases) { extra in
                        PresetButton(title: extra.title, isOn: selection.extras.contains(extra), isToggle: true) {
                            update { s in
                                if s.extras.contains(extra) { s.extras.remove(extra) } else { s.extras.insert(extra) }
                            }
                        }
                    }
                    PresetButton(title: "清空选择", isOn: false) { update { $0 = KeySelection(storage: "") } }
                }
            }
        }
    }
}

private struct RegionButton: View {
    let region: KeyRegion
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                Text(region.isLeft ? "左手" : "右手")
                    .font(Theme.font(16, .bold))
                Text(region.keys.uppercased().map(String.init).joined(separator: " "))
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .opacity(0.85)
            }
            .foregroundStyle(isOn ? .white : Theme.ink)
            .padding(.horizontal, 14)
            .frame(width: 210, height: 42, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isOn ? Theme.accent : Color(white: 0.93)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isOn)
    }
}

private struct PresetButton: View {
    let title: String
    let isOn: Bool
    var isToggle = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isToggle {
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                }
                Text(title)
            }
                .font(Theme.font(15, .bold))
                .foregroundStyle(isOn ? .white : Theme.accent)
                .frame(width: 136, height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOn ? Theme.accent : Theme.accent.opacity(0.12)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
