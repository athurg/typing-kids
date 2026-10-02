import SwiftUI

/// 叠加在键盘上的半透明双手。手指平时停在基准键上，
/// 循环演示：对应手指伸到目标键 → 按下 → 回到基准键。
struct HandsOverlay: View {
    let frames: [String: CGRect]
    let unit: CGFloat
    let target: Character?
    let cycleStart: Date

    /// 一次完整演示的时长（秒）
    static let cycle: Double = 1.8

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, _ in
                let elapsed = max(timeline.date.timeIntervalSince(cycleStart), 0)
                draw(in: ctx, time: elapsed.truncatingRemainder(dividingBy: Self.cycle))
            }
        }
    }

    // MARK: - 手的静止姿势

    private static let leftFingers: [Finger] = [.leftPinky, .leftRing, .leftMiddle, .leftIndex, .leftThumb]
    private static let rightFingers: [Finger] = [.rightThumb, .rightIndex, .rightMiddle, .rightRing, .rightPinky]

    private static let homeKeyID: [Finger: String] = [
        .leftPinky: "a", .leftRing: "s", .leftMiddle: "d", .leftIndex: "f",
        .rightIndex: "j", .rightMiddle: "k", .rightRing: "l", .rightPinky: ";",
    ]

    private func center(_ id: String) -> CGPoint {
        guard let r = frames[id] else { return .zero }
        return CGPoint(x: r.midX, y: r.midY)
    }

    private var homeRowY: CGFloat { center("f").y }
    private var knuckleY: CGFloat { homeRowY + 1.95 * unit }

    /// 手指根部和指尖的粗细
    private func widths(_ f: Finger) -> (CGFloat, CGFloat) {
        switch f {
        case .leftPinky, .rightPinky: (0.52 * unit, 0.42 * unit)
        case .leftRing, .rightRing: (0.60 * unit, 0.48 * unit)
        case .leftMiddle, .rightMiddle: (0.66 * unit, 0.52 * unit)
        case .leftIndex, .rightIndex: (0.64 * unit, 0.51 * unit)
        case .leftThumb, .rightThumb: (0.78 * unit, 0.58 * unit)
        }
    }

    /// 手指根部（指关节）位置
    private func knuckle(_ f: Finger) -> CGPoint {
        switch f {
        case .leftThumb:
            return CGPoint(x: knuckle(.leftIndex).x + 0.2 * unit, y: knuckleY + 1.35 * unit)
        case .rightThumb:
            return CGPoint(x: knuckle(.rightIndex).x - 0.2 * unit, y: knuckleY + 1.35 * unit)
        default:
            let dx: CGFloat = switch f {
            case .leftPinky: 0.35
            case .leftRing: 0.15
            case .leftIndex: -0.15
            case .rightIndex: 0.15
            case .rightRing: -0.15
            case .rightPinky: -0.35
            default: 0
            }
            let isPinky = f == .leftPinky || f == .rightPinky
            return CGPoint(x: center(Self.homeKeyID[f]!).x + dx * unit,
                           y: isPinky ? homeRowY + 1.8 * unit : knuckleY)
        }
    }

    /// 指尖的静止位置：八个手指在基准键上，大拇指在空格键上
    private func restTip(_ f: Finger) -> CGPoint {
        switch f {
        case .leftThumb: CGPoint(x: knuckle(.leftIndex).x + 1.15 * unit, y: center(" ").y)
        case .rightThumb: CGPoint(x: knuckle(.rightIndex).x - 1.15 * unit, y: center(" ").y)
        default: center(Self.homeKeyID[f]!)
        }
    }

    /// 手背的轮廓：小指一侧圆润，拇指一侧有鼓起的肌肉，下面连着手腕
    private func palmPath(left: Bool, offset o: CGVector) -> Path {
        let outer: CGFloat = left ? -1 : 1          // 小指那一侧的方向
        let u = unit
        let kp = knuckle(left ? .leftPinky : .rightPinky)
        let km = knuckle(left ? .leftMiddle : .rightMiddle)
        let ki = knuckle(left ? .leftIndex : .rightIndex)
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x + o.dx, y: y + o.dy) }

        let pinkyTop = pt(kp.x + outer * 0.36 * u, kp.y + 0.1 * u)
        let wristOuter = pt(kp.x + outer * 0.05 * u, knuckleY + 2.35 * u)
        let wristInner = pt(ki.x - outer * 0.15 * u, knuckleY + 2.4 * u)
        let indexTop = pt(ki.x - outer * 0.36 * u, ki.y + 0.15 * u)

        return Path { p in
            p.move(to: pinkyTop)
            // 小指一侧
            p.addCurve(to: wristOuter,
                       control1: pt(kp.x + outer * 0.55 * u, knuckleY + 0.7 * u),
                       control2: pt(kp.x + outer * 0.35 * u, knuckleY + 1.8 * u))
            // 手腕
            p.addQuadCurve(to: wristInner, control: pt((kp.x + ki.x) / 2, knuckleY + 2.55 * u))
            // 拇指根部的鼓起
            p.addCurve(to: indexTop,
                       control1: pt(ki.x - outer * 0.85 * u, knuckleY + 1.9 * u),
                       control2: pt(ki.x - outer * 0.7 * u, knuckleY + 0.6 * u))
            // 指关节一线，微微拱起
            p.addCurve(to: pinkyTop,
                       control1: pt(ki.x + outer * 0.1 * u, km.y - 0.35 * u),
                       control2: pt(kp.x - outer * 0.4 * u, km.y - 0.2 * u))
            p.closeSubpath()
        }
    }

    // MARK: - 动画

    private struct Motion {
        let finger: Finger
        let to: CGPoint
        let start: Double      // 开始伸出的时间
        let hold: Double       // 停在目标键上的时长
        let sustain: Bool      // true：一直按住（Shift）；false：按一下
    }

    private static let moveTime = 0.25

    /// reach：0 在基准键，1 到达目标键；press：按下的程度
    private func phase(_ m: Motion, at t: Double) -> (reach: CGFloat, press: CGFloat, ripple: Double?) {
        let local = t - m.start
        func ease(_ x: Double) -> CGFloat { CGFloat(x * x * (3 - 2 * x)) }
        if local < 0 { return (0, 0, nil) }
        if local < Self.moveTime { return (ease(local / Self.moveTime), 0, nil) }
        let inHold = local - Self.moveTime
        if inHold < m.hold {
            let p = inHold / m.hold
            let press = m.sustain ? CGFloat(min(1, p * 4, (1 - p) * 4)) : CGFloat(sin(.pi * p))
            return (1, press, m.sustain ? nil : p)
        }
        let back = inHold - m.hold
        if back < Self.moveTime { return (1 - ease(back / Self.moveTime), 0, nil) }
        return (0, 0, nil)
    }

    private func motions() -> [Motion] {
        guard let c = target else { return [] }
        let t = KeyboardLayout.target(for: c)
        if t.key == " " {
            return [.leftThumb, .rightThumb].map {
                Motion(finger: $0, to: restTip($0), start: 0.15, hold: 0.4, sustain: false)
            }
        }
        guard let main = KeyboardLayout.fingerMap[t.key] else { return [] }
        let mainMotion = Motion(finger: main, to: center(String(t.key)),
                                start: t.needsShift ? 0.25 : 0.1, hold: 0.4, sustain: false)
        guard t.needsShift else { return [mainMotion] }
        let shiftFinger = KeyboardLayout.shiftFinger(for: main)
        let shiftID = shiftFinger.isLeft ? "lshift" : "rshift"
        return [Motion(finger: shiftFinger, to: center(shiftID), start: 0, hold: 0.85, sustain: true), mainMotion]
    }

    // MARK: - 绘制

    private func draw(in ctx: GraphicsContext, time t: Double) {
        let motions = motions()
        var tips: [Finger: CGPoint] = [:]
        var presses: [Finger: CGFloat] = [:]
        var handOffset: [Bool: CGVector] = [true: .zero, false: .zero]
        var ripples: [(CGPoint, Double, Color)] = []

        for f in Finger.allCases { tips[f] = restTip(f) }
        // 整只手跟着伸出去的手指稍微移动一点，看起来更自然
        for m in motions {
            let (reach, press, ripple) = phase(m, at: t)
            let rest = restTip(m.finger)
            let d = CGVector(dx: m.to.x - rest.x, dy: m.to.y - rest.y)
            let side = m.finger.isLeft
            handOffset[side] = CGVector(dx: handOffset[side]!.dx + d.dx * 0.3 * reach,
                                        dy: handOffset[side]!.dy + d.dy * 0.3 * reach)
            tips[m.finger] = CGPoint(x: rest.x + d.dx * reach, y: rest.y + d.dy * reach)
            presses[m.finger] = press
            if let ripple { ripples.append((m.to, ripple, m.finger.color)) }
        }
        let active = Set(motions.map(\.finger))
        for f in Finger.allCases where !active.contains(f) {
            let o = handOffset[f.isLeft]!
            tips[f] = CGPoint(x: tips[f]!.x + o.dx, y: tips[f]!.y + o.dy)
        }

        func base(_ f: Finger) -> CGPoint {
            let k = knuckle(f), o = handOffset[f.isLeft]!
            // 手指根部稍微藏进手背里
            let sink: CGFloat = (f == .leftThumb || f == .rightThumb) ? 0 : 0.3 * unit
            return CGPoint(x: k.x + o.dx, y: k.y + o.dy + sink)
        }
        func shape(_ f: Finger) -> FingerShape {
            let press = 1 + 0.12 * (presses[f] ?? 0)
            let (wb, wt) = widths(f)
            return FingerShape(base: base(f), tip: tips[f]!, baseWidth: wb * press, tipWidth: wt * press)
        }

        // 1. 半透明的双手（先画在一个图层里再整体降低透明度，重叠处不会变深）
        var handCtx = ctx
        handCtx.opacity = 0.6
        handCtx.drawLayer { layer in
            for left in [true, false] {
              layer.drawLayer { layer in
                let o = handOffset[left]!
                let palm = palmPath(left: left, offset: o)
                let fingers = (left ? Self.leftFingers : Self.rightFingers).map { ($0, shape($0)) }
                var silhouette = palm
                for (_, f) in fingers { silhouette.addPath(f.path) }

                // 投在键盘上的柔和阴影
                var shadow = layer
                shadow.addFilter(.blur(radius: 0.18 * unit))
                shadow.translateBy(x: 0.06 * unit, y: 0.14 * unit)
                shadow.fill(silhouette, with: .color(.black.opacity(0.35)))

                // 外轮廓
                layer.stroke(silhouette, with: .color(Skin.outline), lineWidth: 3.5)

                // 先画手指，再画手背盖住手指根部，衔接更自然
                for (finger, f) in fingers {
                    f.fill(in: layer, colors: [Skin.shade, Skin.light, Skin.light, Skin.mid, Skin.shade])
                    f.drawDetails(in: layer, nailTint: finger.color.opacity(0.35),
                                  creases: (finger == .leftThumb || finger == .rightThumb) ? [0.5] : [0.4, 0.68])
                }
                // 手背：中间亮、边缘暗
                let palmBox = palm.boundingRect
                layer.fill(palm, with: .radialGradient(
                    Gradient(colors: [Skin.light, Skin.mid, Skin.shade]),
                    center: CGPoint(x: palmBox.midX, y: palmBox.minY + palmBox.height * 0.35),
                    startRadius: 0, endRadius: palmBox.width * 0.75))
                // 指关节的小凸起
                for f in left ? [Finger.leftPinky, .leftRing, .leftMiddle, .leftIndex]
                              : [Finger.rightIndex, .rightMiddle, .rightRing, .rightPinky] {
                    let k = knuckle(f)
                    let r = CGRect(x: k.x + o.dx - 0.22 * unit, y: k.y + o.dy + 0.02 * unit,
                                   width: 0.44 * unit, height: 0.16 * unit)
                    layer.fill(Path(ellipseIn: r), with: .color(.white.opacity(0.18)))
                }

                // 手腕往下渐渐淡出
                var fade = layer
                fade.blendMode = .destinationOut
                let fadeTop = knuckleY + o.dy + 1.6 * unit
                let fadeRect = CGRect(x: 0, y: fadeTop, width: 10_000, height: 3 * unit)
                fade.fill(Path(fadeRect), with: .linearGradient(
                    Gradient(colors: [.clear, .black]),
                    startPoint: CGPoint(x: 0, y: fadeTop), endPoint: CGPoint(x: 0, y: fadeTop + 0.85 * unit)))
              }
            }
        }

        // 2. 正在用的手指：染上手指的颜色，更醒目
        var activeCtx = ctx
        activeCtx.opacity = 0.85
        activeCtx.drawLayer { layer in
            for finger in active {
                let f = shape(finger)
                var layer = layer
                // 四指的根部藏在手背下面；大拇指在手背外侧，整根都画出来
                if finger != .leftThumb && finger != .rightThumb {
                    layer.clip(to: palmPath(left: finger.isLeft, offset: handOffset[finger.isLeft]!), options: .inverse)
                }
                layer.stroke(f.path, with: .color(finger.color), lineWidth: 3.5)
                f.fill(in: layer, colors: [Skin.shade, Skin.light, Skin.light, Skin.mid, Skin.shade])
                f.fill(in: layer, colors: [finger.color.opacity(0.75), finger.color.opacity(0.35),
                                           finger.color.opacity(0.3), finger.color.opacity(0.45), finger.color.opacity(0.75)])
                f.drawDetails(in: layer, nailTint: finger.color.opacity(0.5),
                              creases: (finger == .leftThumb || finger == .rightThumb) ? [0.5] : [0.4, 0.68])
            }
        }

        // 3. 按下时的波纹
        let isSpace = target == " "
        for (point, p, color) in ripples {
            let r = unit * (isSpace ? 0.3 + 0.3 * p : 0.45 + 0.55 * p)
            let circle = Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: 2 * r, height: 2 * r))
            ctx.stroke(circle, with: .color(color.opacity(1 - p)), lineWidth: isSpace ? 3 : 4)
        }

        // 4. 目标键上的字重新画在最上层，不被手指挡住
        var labelCtx = ctx
        labelCtx.addFilter(.shadow(color: .black.opacity(0.35), radius: 2, y: 1))
        for m in motions {
            guard let id = targetKeyID(m), let key = Self.keyCaps[id], let frame = frames[id] else { continue }
            let big = key.char != nil && key.id != " "
            labelCtx.draw(Text(key.label)
                .font(Theme.font(big ? 21 : 13, .heavy))
                .foregroundColor(.white),
                at: CGPoint(x: frame.midX, y: frame.midY + (key.shiftLabel != nil ? 5 : 0)))
        }
    }

    private static let keyCaps: [String: KeyCap] = {
        var map: [String: KeyCap] = [:]
        for row in KeyboardLayout.rows { for key in row { map[key.id] = key } }
        return map
    }()

    private func targetKeyID(_ m: Motion) -> String? {
        guard let c = target else { return nil }
        if m.finger == .rightThumb { return nil }   // 空格只画一次
        if m.finger == .leftThumb { return " " }
        let t = KeyboardLayout.target(for: c)
        return KeyboardLayout.fingerMap[t.key] == m.finger ? String(t.key) : (m.finger.isLeft ? "lshift" : "rshift")
    }
}

// MARK: - 皮肤与手指形状

private enum Skin {
    static let light = Color(red: 1.00, green: 0.90, blue: 0.82)
    static let mid = Color(red: 0.98, green: 0.82, blue: 0.71)
    static let shade = Color(red: 0.91, green: 0.69, blue: 0.57)
    static let outline = Color(red: 0.72, green: 0.50, blue: 0.40)
    static let crease = Color(red: 0.70, green: 0.48, blue: 0.38)
}

/// 一根从根部到指尖逐渐变细、指尖圆润的手指（从手背方向看）
private struct FingerShape {
    let base: CGPoint
    let tip: CGPoint
    let baseWidth: CGFloat
    let tipWidth: CGFloat

    private var dir: CGVector {
        let dx = tip.x - base.x, dy = tip.y - base.y
        let len = max(sqrt(dx * dx + dy * dy), 0.001)
        return CGVector(dx: dx / len, dy: dy / len)
    }
    private var normal: CGVector { CGVector(dx: -dir.dy, dy: dir.dx) }

    private func point(along t: CGFloat, side: CGFloat) -> CGPoint {
        // t: 0 根部 ... 1 指尖圆弧的圆心；side: -1 ... 1 横向位置
        let center = CGPoint(x: base.x + (tipCenter.x - base.x) * t, y: base.y + (tipCenter.y - base.y) * t)
        let w = (baseWidth + (tipWidth - baseWidth) * t) / 2
        return CGPoint(x: center.x + normal.dx * w * side, y: center.y + normal.dy * w * side)
    }

    private var tipCenter: CGPoint {
        CGPoint(x: tip.x - dir.dx * tipWidth / 2, y: tip.y - dir.dy * tipWidth / 2)
    }

    var path: Path {
        let r = tipWidth / 2, k: CGFloat = 0.5523
        let d = dir, n = normal
        let p1 = point(along: 1, side: 1)
        let p2 = point(along: 1, side: -1)
        return Path { p in
            p.move(to: point(along: 0, side: 1))
            // 侧边略微鼓一点，更像真手指
            p.addQuadCurve(to: p1, control: point(along: 0.5, side: 1.08))
            p.addCurve(to: tip,
                       control1: CGPoint(x: p1.x + d.dx * r * k, y: p1.y + d.dy * r * k),
                       control2: CGPoint(x: tip.x + n.dx * r * k, y: tip.y + n.dy * r * k))
            p.addCurve(to: p2,
                       control1: CGPoint(x: tip.x - n.dx * r * k, y: tip.y - n.dy * r * k),
                       control2: CGPoint(x: p2.x + d.dx * r * k, y: p2.y + d.dy * r * k))
            let q2 = point(along: 0, side: -1), q1 = point(along: 0, side: 1)
            p.addQuadCurve(to: q2, control: point(along: 0.5, side: -1.08))
            // 根部也是圆的（大拇指的根部露在手背外面）
            let rb = baseWidth / 2
            let apex = CGPoint(x: base.x - d.dx * rb, y: base.y - d.dy * rb)
            p.addCurve(to: apex,
                       control1: CGPoint(x: q2.x - d.dx * rb * k, y: q2.y - d.dy * rb * k),
                       control2: CGPoint(x: apex.x - n.dx * rb * k, y: apex.y - n.dy * rb * k))
            p.addCurve(to: q1,
                       control1: CGPoint(x: apex.x + n.dx * rb * k, y: apex.y + n.dy * rb * k),
                       control2: CGPoint(x: q1.x - d.dx * rb * k, y: q1.y - d.dy * rb * k))
            p.closeSubpath()
        }
    }

    /// 横向渐变，模拟圆柱形手指的明暗
    func fill(in ctx: GraphicsContext, colors: [Color]) {
        let mid = point(along: 0.6, side: 0)
        let w = (baseWidth + tipWidth) / 2
        let start = CGPoint(x: mid.x + normal.dx * w / 2, y: mid.y + normal.dy * w / 2)
        let end = CGPoint(x: mid.x - normal.dx * w / 2, y: mid.y - normal.dy * w / 2)
        ctx.fill(path, with: .linearGradient(Gradient(colors: colors), startPoint: start, endPoint: end))
    }

    /// 指甲和关节纹
    func drawDetails(in ctx: GraphicsContext, nailTint: Color, creases: [CGFloat]) {
        for t in creases {
            let a = point(along: t, side: 0.42)
            let b = point(along: t, side: -0.42)
            let c = point(along: t + 0.04, side: 0)
            var crease = Path()
            crease.move(to: a)
            crease.addQuadCurve(to: b, control: c)
            ctx.stroke(crease, with: .color(Skin.crease.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }

        let nailW = tipWidth * 0.66, nailH = tipWidth * 0.78
        let center = CGPoint(x: tip.x - dir.dx * (nailH / 2 + tipWidth * 0.1),
                             y: tip.y - dir.dy * (nailH / 2 + tipWidth * 0.1))
        let angle = atan2(dir.dy, dir.dx) + .pi / 2
        let transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle)
        let nail = Path(roundedRect: CGRect(x: -nailW / 2, y: -nailH / 2, width: nailW, height: nailH),
                        cornerRadius: nailW * 0.45).applying(transform)
        ctx.fill(nail, with: .color(Color(red: 1.0, green: 0.88, blue: 0.86)))
        ctx.fill(nail, with: .color(nailTint))
        ctx.stroke(nail, with: .color(Skin.outline.opacity(0.55)), lineWidth: 1)
        // 指甲上的高光
        let shine = Path(roundedRect: CGRect(x: -nailW * 0.28, y: -nailH * 0.36, width: nailW * 0.18, height: nailH * 0.5),
                         cornerRadius: nailW * 0.09).applying(transform)
        ctx.fill(shine, with: .color(.white.opacity(0.7)))
    }
}
