//
//  ContentView.swift
//  PuckClash
//
//  Created by yuuki kounishi on 2026/06/24.
//

import Combine
import SwiftUI

enum GameMode {
    case cpuPractice
    case online
}

enum MatchFlow {
    case start
    case modeSelect
    case mapSelect(GameMode)
    case match(MapDefinition)
    case result(ScoreState, MapDefinition)
}

// Plain value snapshot the SpriteKit scene pushes to the SwiftUI HUD. Holds no
// game rules — just the numbers to display.
struct MatchHUD: Equatable {
    var homeScore = 0
    var awayScore = 0
    var remainingSeconds = 0
}

// Owns the match: a LocalMatchSession (the simulation) and the RinkScene that renders
// it, and republishes the low-frequency HUD snapshot. It carries no game rules.
final class MatchController: ObservableObject {
    let session: LocalMatchSession
    let scene: RinkScene
    @Published var hud = MatchHUD()

    init(config: MatchConfig, onFinished: @escaping (ScoreState) -> Void) {
        let session = LocalMatchSession(config: config)
        self.session = session
        let scene = RinkScene(session: session)
        self.scene = scene
        scene.onFinished = onFinished
        scene.onHUDChange = { [weak self] snapshot in
            self?.hud = snapshot
        }
    }

    // Joystick vector goes straight to the session (not through @Published) so dragging
    // does not re-render SwiftUI every frame. The session treats zero as no input.
    func setMoveVector(_ vector: Vector2) {
        session.setHomeInput(moveVector: vector)
    }
}

private enum Palette {
    static let backgroundTop = Color(red: 0.06, green: 0.10, blue: 0.17)
    static let backgroundBottom = Color(red: 0.02, green: 0.04, blue: 0.08)
    static let home = Color(red: 0.16, green: 0.52, blue: 1.0)
    static let away = Color(red: 0.95, green: 0.28, blue: 0.34)
    static let accent = Color(red: 0.55, green: 0.78, blue: 0.95)
}

struct ContentView: View {
    @State private var flow: MatchFlow = .start
    @State private var matchID = UUID()
    @State private var showSettings = false
    @State private var showHowToPlay = false

    var body: some View {
        content
            .sheet(isPresented: $showSettings) {
                SettingsView(onClose: { showSettings = false })
            }
            .sheet(isPresented: $showHowToPlay) {
                HowToPlayView(onClose: { showHowToPlay = false })
            }
    }

    @ViewBuilder private var content: some View {
        switch flow {
        case .start:
            StartView(
                onStart: { flow = .modeSelect },
                onSettings: { showSettings = true },
                onHowToPlay: { showHowToPlay = true }
            )
        case .modeSelect:
            ModeSelectView(
                onSelectCPU: { flow = .mapSelect(.cpuPractice) },
                onBack: { flow = .start }
            )
        case .mapSelect:
            MapSelectView(
                onSelectMap: { map in startMatch(map) },
                onBack: { flow = .modeSelect }
            )
        case .match(let map):
            MatchView(map: map, onFinished: { score in flow = .result(score, map) })
                .id(matchID)
        case .result(let score, let map):
            ResultView(
                score: score,
                onRetry: { startMatch(map) },
                onBackToTitle: { flow = .start }
            )
        }
    }

    // A new match identity rebuilds the controller (and its scene/engine).
    private func startMatch(_ map: MapDefinition) {
        matchID = UUID()
        flow = .match(map)
    }
}

private struct ArenaBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Palette.backgroundTop, Palette.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct ModeSelectView: View {
    let onSelectCPU: () -> Void
    let onBack: () -> Void
    @State private var showComingSoon = false

    var body: some View {
        ZStack {
            ArenaBackground()

            VStack(spacing: 18) {
                Text("モード選択")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)

                SelectionCard(
                    title: "CPU練習",
                    subtitle: "オフラインでCPUと対戦",
                    accent: Palette.home,
                    dimmed: false,
                    action: onSelectCPU
                )
                .accessibilityIdentifier("mode-cpu-practice")

                SelectionCard(
                    title: "オンライン対戦",
                    subtitle: "準備中",
                    accent: Palette.away,
                    dimmed: true,
                    action: { showComingSoon = true }
                )
                .accessibilityIdentifier("mode-online-match")

                Button("戻る", action: onBack)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 8)
            }
            .padding()
        }
        .sheet(isPresented: $showComingSoon) {
            ComingSoonView()
        }
    }
}

private struct ComingSoonView: View {
    var body: some View {
        ZStack {
            ArenaBackground()

            VStack(spacing: 14) {
                Image(systemName: "wifi")
                    .font(.system(size: 40))
                    .foregroundStyle(Palette.accent)
                Text("オンライン対戦")
                    .font(.title.weight(.heavy))
                    .foregroundStyle(.white)
                Text("準備中 — オンライン対戦は現在開発中です。今はCPU練習をお楽しみください。")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 24)
                    .accessibilityIdentifier("online-coming-soon")
            }
            .padding()
        }
    }
}

private struct MapSelectView: View {
    let onSelectMap: (MapDefinition) -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            ArenaBackground()

            VStack(spacing: 14) {
                Text("マップ選択")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)

                ForEach(MapDefinition.all) { map in
                    SelectionCard(
                        title: map.displayName,
                        subtitle: map.summary,
                        accent: Palette.home,
                        dimmed: false,
                        action: { onSelectMap(map) }
                    )
                    .accessibilityIdentifier("map-\(map.id.rawValue)")
                }

                Button("戻る", action: onBack)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 8)
            }
            .padding()
        }
    }
}

// Reused card for mode and map choices. `dimmed` styles a not-yet-available option
// while keeping it tappable (e.g. to show a Coming Soon sheet).
private struct SelectionCard: View {
    let title: String
    let subtitle: String
    let accent: Color
    let dimmed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(18)
            .frame(maxWidth: 360)
            .background(accent.opacity(dimmed ? 0.12 : 0.28), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(accent.opacity(dimmed ? 0.3 : 0.7), lineWidth: 1.5))
        }
        .opacity(dimmed ? 0.65 : 1.0)
    }
}

struct MatchView: View {
    @StateObject private var controller: MatchController

    init(map: MapDefinition, onFinished: @escaping (ScoreState) -> Void) {
        _controller = StateObject(wrappedValue: MatchController(config: map.config, onFinished: onFinished))
    }

    var body: some View {
        ZStack {
            ArenaBackground()
            RinkSceneView(scene: controller.scene)
        }
        .safeAreaInset(edge: .top) {
            MatchHUDBar(hud: controller.hud)
        }
        .safeAreaInset(edge: .bottom) {
            BottomControls(onMove: { controller.setMoveVector($0) })
        }
    }
}

private struct MatchHUDBar: View {
    let hud: MatchHUD

    var body: some View {
        HStack(alignment: .center) {
            scoreColumn(title: "あなた", score: hud.homeScore, color: Palette.home)

            Spacer()

            VStack(spacing: 2) {
                Text("タイム")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(hud.remainingSeconds)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            Spacer()

            scoreColumn(title: "CPU", score: hud.awayScore, color: Palette.away)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    private func scoreColumn(title: String, score: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
            Text("\(score)")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: score)
        }
        .frame(width: 64)
    }
}

// Bottom control zone: joystick on the left, skill placeholders on the right.
private struct BottomControls: View {
    let onMove: (Vector2) -> Void

    var body: some View {
        HStack(alignment: .center) {
            JoystickView(onMove: onMove)
            Spacer()
            SkillSlots()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
    }
}

// Fixed virtual joystick. Produces a 0...1 magnitude vector in GameCore rink
// orientation (y up); returns to neutral on release. Holds no game rules.
private struct JoystickView: View {
    let onMove: (Vector2) -> Void
    @State private var knobOffset: CGSize = .zero

    private let radius: CGFloat = 64
    private let knobSize: CGFloat = 58
    // Ignore tiny thumb jitter, then ease the low end so small tilts still respond.
    private let deadZone: Double = 0.12

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.07))
                .overlay(Circle().strokeBorder(.white.opacity(0.24), lineWidth: 2))
            Circle()
                .fill(Palette.home.opacity(0.85))
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 2))
                .frame(width: knobSize, height: knobSize)
                .offset(knobOffset)
        }
        .frame(width: radius * 2, height: radius * 2)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    let length = hypot(dx, dy)
                    let clampedLength = min(length, radius)

                    if length > 0 {
                        knobOffset = CGSize(width: dx / length * clampedLength, height: dy / length * clampedLength)
                    } else {
                        knobOffset = .zero
                    }

                    let magnitude = Double(clampedLength / radius)
                    guard length > 0, magnitude >= deadZone else {
                        onMove(.zero)
                        return
                    }

                    // Remap [deadZone, 1] -> [0, 1] and ease so small pushes still move.
                    let normalized = (magnitude - deadZone) / (1 - deadZone)
                    let response = pow(normalized, 0.75)
                    let directionX = Double(dx / length)
                    let directionY = Double(dy / length)
                    onMove(Vector2(x: directionX * response, y: -directionY * response))
                }
                .onEnded { _ in
                    knobOffset = .zero
                    onMove(.zero)
                }
        )
        .accessibilityIdentifier("joystick-control")
    }
}

// Visual-only placeholders for future skills. Disabled; no game rule attached.
private struct SkillSlots: View {
    private let slots = ["ブースト", "ブロック", "ショット"]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(slots, id: \.self) { name in
                VStack(spacing: 4) {
                    Circle()
                        .strokeBorder(.white.opacity(0.18), lineWidth: 2)
                        .background(Circle().fill(.white.opacity(0.05)))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: "lock.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.3))
                        )
                    Text(name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .disabled(true)
    }
}

struct StartView: View {
    let onStart: () -> Void
    let onSettings: () -> Void
    let onHowToPlay: () -> Void

    var body: some View {
        ZStack {
            ArenaBackground()

            VStack(spacing: 22) {
                RinkEmblem()
                    .frame(width: 120, height: 150)

                VStack(spacing: 8) {
                    Text("Puck Clash")
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("縦型エアホッケー・1対1 — CPUに勝とう")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Button(action: onStart) {
                        Text("スタート")
                            .font(.title2.weight(.bold))
                            .frame(maxWidth: 240)
                            .padding(.vertical, 16)
                            .background(Palette.home, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }
                    .accessibilityIdentifier("start-match-button")

                    HStack(spacing: 12) {
                        secondaryButton("遊び方", identifier: "how-to-play-button", action: onHowToPlay)
                        secondaryButton("設定", identifier: "settings-button", action: onSettings)
                    }
                    .frame(maxWidth: 240)
                }
                .padding(.top, 8)

                Text("オンライン対戦 — 準備中")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding()
        }
    }

    // Outlined secondary action styled to sit beneath the primary Start button.
    private func secondaryButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.2), lineWidth: 1))
                .foregroundStyle(.white.opacity(0.9))
        }
        .accessibilityIdentifier(identifier)
    }
}

// Small vertical-rink motif drawn with SwiftUI shapes (no external assets).
private struct RinkEmblem: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.10, green: 0.20, blue: 0.32))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.accent.opacity(0.8), lineWidth: 2))
                Rectangle()
                    .fill(Palette.accent.opacity(0.4))
                    .frame(height: 2)
                Circle()
                    .strokeBorder(Palette.accent.opacity(0.5), lineWidth: 2)
                    .frame(width: w * 0.4, height: w * 0.4)
                Rectangle().fill(Palette.away).frame(width: w * 0.5, height: 5).position(x: w / 2, y: 4)
                Rectangle().fill(Palette.home).frame(width: w * 0.5, height: 5).position(x: w / 2, y: h - 4)
            }
        }
    }
}

struct ResultView: View {
    let score: ScoreState
    let onRetry: () -> Void
    let onBackToTitle: () -> Void

    private var outcomeText: String {
        switch score.winner {
        case .home:
            return "あなたの勝ち"
        case .away:
            return "CPUの勝ち"
        case nil:
            return "引き分け"
        }
    }

    private var outcomeColor: Color {
        switch score.winner {
        case .home:
            return Palette.home
        case .away:
            return Palette.away
        case nil:
            return Palette.accent
        }
    }

    var body: some View {
        ZStack {
            ArenaBackground()

            VStack(spacing: 20) {
                Text("試合終了")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.6))

                Text(outcomeText)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(outcomeColor)

                HStack(spacing: 20) {
                    scoreCard(title: "あなた", value: score.home, color: Palette.home)
                    Text("-").font(.system(size: 32, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                    scoreCard(title: "CPU", value: score.away, color: Palette.away)
                }
                .padding(.vertical, 8)

                Button(action: onRetry) {
                    Text("もう一度")
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: 240)
                        .padding(.vertical, 16)
                        .background(Palette.home, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .accessibilityIdentifier("retry-match-button")
                .padding(.top, 4)

                Button(action: onBackToTitle) {
                    Text("タイトルへ")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .accessibilityIdentifier("back-to-title-button")
            }
            .padding()
        }
    }

    private func scoreCard(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(width: 96)
        .padding(.vertical, 12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}

// Reusable modal scaffold for the information screens: a titled header with a close
// button over the shared arena background, and a scrolling body of sections. Holds no
// game state — purely presentational.
private struct InfoScreen<Content: View>: View {
    let title: String
    let screenIdentifier: String
    let closeIdentifier: String
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            ArenaBackground()

            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(.title.weight(.heavy))
                        .foregroundStyle(.white)
                        .accessibilityIdentifier(screenIdentifier)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .accessibilityIdentifier(closeIdentifier)
                    .accessibilityLabel("閉じる")
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        content()
                    }
                    .padding(20)
                }
            }
        }
    }
}

// A titled group of bullet lines used inside the information screens.
private struct InfoSection: View {
    let title: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(Palette.accent)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Palette.accent.opacity(0.6))
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }
}

// Information-only settings. No functional toggles, accounts, or network status —
// it describes what the prototype currently offers.
private struct SettingsView: View {
    let onClose: () -> Void

    var body: some View {
        InfoScreen(
            title: "設定",
            screenIdentifier: "settings-screen",
            closeIdentifier: "close-settings-button",
            onClose: onClose
        ) {
            InfoSection(title: "ゲーム", lines: [
                "対戦モード：CPU練習が利用可能",
                "オンライン対戦：準備中"
            ])
            InfoSection(title: "操作", lines: [
                "ジョイスティックで下側のストライカーを動かす",
                "パックを弾いて相手ゴールへ入れる"
            ])
            InfoSection(title: "マップ", lines: [
                "クラシック — 標準的なバランス型リンク",
                "ワイド — 広めの盤面で角度が増える",
                "スピード — ストライカーとパックが速い"
            ])
            InfoSection(title: "このアプリについて", lines: [
                "プロトタイプ・ローカル対戦中心",
                "オンラインは現在未対応"
            ])
        }
    }
}

// Explains the objective, controls, rules and maps. Online is noted as Coming Soon.
private struct HowToPlayView: View {
    let onClose: () -> Void

    var body: some View {
        InfoScreen(
            title: "遊び方",
            screenIdentifier: "how-to-play-screen",
            closeIdentifier: "close-how-to-play-button",
            onClose: onClose
        ) {
            InfoSection(title: "目的", lines: [
                "パックを上側の相手ゴールに入れる"
            ])
            InfoSection(title: "操作", lines: [
                "左下のジョイスティックで自分のストライカーを動かす"
            ])
            InfoSection(title: "ルール", lines: [
                "上のゴールに入ると自分の得点",
                "下のゴールに入るとCPUの得点",
                "制限時間が終わると勝敗が表示される"
            ])
            InfoSection(title: "マップ", lines: [
                "クラシック：標準",
                "ワイド：広め",
                "スピード：速め"
            ])
            InfoSection(title: "オンライン", lines: [
                "準備中"
            ])
        }
    }
}

#Preview {
    ContentView()
}
