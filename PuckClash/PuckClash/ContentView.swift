//
//  ContentView.swift
//  PuckClash
//
//  Created by yuuki kounishi on 2026/06/24.
//

import Combine
import SwiftUI

// How a match is driven, decided in the UI flow. Presentation-only: GameCore never
// sees this type — it only receives the per-side config values derived from it.
enum MatchMode: Equatable {
    case cpuPractice(CPUDifficulty)
    case localVersus
}

enum MatchFlow {
    case start
    case modeSelect
    case difficultySelect
    case mapSelect(MatchMode)
    case match(MapDefinition, MatchMode)
    case result(ScoreState, MapDefinition, MatchMode)
}

// UI-facing difficulty text. GameCore stays free of presentation strings, so the
// display names and descriptions live here next to the views that show them.
extension CPUDifficulty {
    var displayName: String {
        switch self {
        case .easy:
            return "かんたん"
        case .normal:
            return "ふつう"
        case .hard:
            return "むずかしい"
        }
    }

    var summary: String {
        switch self {
        case .easy:
            return "ゆっくり判断するCPU。初めての練習向け"
        case .normal:
            return "標準的な反応のCPU。おすすめ"
        case .hard:
            return "素早くスキルを判断するCPU。慣れたプレイヤー向け"
        }
    }
}

// Plain value snapshot the SpriteKit scene pushes to the SwiftUI HUD. Holds no
// game rules — just the numbers to display.
struct MatchHUD: Equatable {
    var homeScore = 0
    var awayScore = 0
    var remainingSeconds = 0
    // Match flow published by GameCore: countdown/goalPause drive the overlays and
    // input gating. Coarse whole seconds keep the publish rate low. Defaults match a
    // freshly created match (opening countdown) so controls start disabled.
    var matchPhase: MatchPhase = .countdown
    var phaseRemainingSeconds = 0
    var lastScorer: PlayerSide? = nil
    var boostPhase: SkillPhase = .ready
    var boostRemainingSeconds = 0
    var shotPhase: SkillPhase = .ready
    var shotRemainingSeconds = 0
    var blockPhase: SkillPhase = .ready
    var blockRemainingSeconds = 0
    // Away-side skill states, displayed only when the away side is a local human
    // (the CPU never needs buttons). Same coarse whole-second derivation.
    var awayBoostPhase: SkillPhase = .ready
    var awayBoostRemainingSeconds = 0
    var awayShotPhase: SkillPhase = .ready
    var awayShotRemainingSeconds = 0
    var awayBlockPhase: SkillPhase = .ready
    var awayBlockRemainingSeconds = 0
}

// Owns the match: a LocalMatchSession (the simulation) and the RinkScene that renders
// it, and republishes the low-frequency HUD snapshot. It carries no game rules.
final class MatchController: ObservableObject {
    let session: LocalMatchSession
    let scene: RinkScene
    @Published var hud = MatchHUD()
    // App-level pause (player button or app going inactive). GameCore has no paused
    // state: the scene simply stops advancing the session while this is true, so
    // every simulation timer freezes together and resume continues exactly in place.
    @Published private(set) var isPaused = false

    init(config: MatchConfig, awayExternallyDriven: Bool = false, onFinished: @escaping (ScoreState) -> Void) {
        let session = LocalMatchSession(config: config, awayExternallyDriven: awayExternallyDriven)
        self.session = session
        let scene = RinkScene(session: session)
        self.scene = scene
        scene.onFinished = onFinished
        scene.onHUDChange = { [weak self] snapshot in
            self?.hud = snapshot
        }
    }

    // Side-neutral input entry points, mirroring the session API: the home side is
    // the bottom player, the away side is the top player (or, later, a remote
    // player fed into the same away-side calls).
    // Movement goes straight to the session (not through @Published) so dragging
    // does not re-render SwiftUI every frame. The session treats zero as no input.
    func setMovement(_ vector: Vector2, for side: PlayerID) {
        session.setMovement(vector, for: side)
    }

    // Fire a skill for one side; the session edge-triggers it onto one fixed step.
    func activateSkill(_ skill: SkillID, for side: PlayerID) {
        session.queueSkill(skill, for: side)
    }

    func pause() {
        guard !isPaused else {
            return
        }
        isPaused = true
        scene.isMatchPaused = true
        // Drop all held movement and queued skills (both sides) so resuming never
        // replays anything from before the pause.
        session.clearAllInputs()
    }

    func resume() {
        isPaused = false
        scene.isMatchPaused = false
    }
}

// Human-controlled strikers get a small speed edge over the map's base speed so a
// player can realistically keep up with the puck. Applied where a match config is
// built (never a GameCore global): CPU practice scales only the human home side;
// a mode with two human sides applies it to both, and a future remote opponent
// would use the same value for their side.
private let humanControlSpeedScale = 1.12

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
    @State private var showSkillGuide = false

    var body: some View {
        content
            .sheet(isPresented: $showSettings) {
                SettingsView(onClose: { showSettings = false })
            }
            .sheet(isPresented: $showHowToPlay) {
                HowToPlayView(onClose: { showHowToPlay = false })
            }
            .sheet(isPresented: $showSkillGuide) {
                SkillGuideView(onClose: { showSkillGuide = false })
            }
    }

    @ViewBuilder private var content: some View {
        switch flow {
        case .start:
            StartView(
                onStart: { flow = .modeSelect },
                onSettings: { showSettings = true },
                onHowToPlay: { showHowToPlay = true },
                onSkillGuide: { showSkillGuide = true }
            )
        case .modeSelect:
            ModeSelectView(
                onSelectCPU: { flow = .difficultySelect },
                onSelectLocal: { flow = .mapSelect(.localVersus) },
                onBack: { flow = .start }
            )
        case .difficultySelect:
            DifficultySelectView(
                onSelectDifficulty: { difficulty in flow = .mapSelect(.cpuPractice(difficulty)) },
                onBack: { flow = .modeSelect }
            )
        case .mapSelect(let mode):
            MapSelectView(
                onSelectMap: { map in startMatch(map, mode: mode) },
                onBack: {
                    // Local versus skips the difficulty screen, so back leads there
                    // only for CPU practice.
                    switch mode {
                    case .cpuPractice:
                        flow = .difficultySelect
                    case .localVersus:
                        flow = .modeSelect
                    }
                }
            )
        case .match(let map, let mode):
            MatchView(
                map: map,
                mode: mode,
                onFinished: { score in flow = .result(score, map, mode) },
                onQuit: { flow = .start }
            )
            .id(matchID)
        case .result(let score, let map, let mode):
            ResultView(
                score: score,
                mode: mode,
                onRetry: { startMatch(map, mode: mode) },
                onBackToTitle: { flow = .start }
            )
        }
    }

    // A new match identity rebuilds the controller (and its scene/engine).
    private func startMatch(_ map: MapDefinition, mode: MatchMode) {
        matchID = UUID()
        flow = .match(map, mode)
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
    let onSelectLocal: () -> Void
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
                    title: "ローカル対戦",
                    subtitle: "1台で2人対戦",
                    accent: Palette.accent,
                    dimmed: false,
                    action: onSelectLocal
                )
                .accessibilityIdentifier("local-versus-mode-button")

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

// CPU difficulty picker between mode and map selection. Shows the three presets as
// cards; internal thresholds and timings stay hidden from the player.
private struct DifficultySelectView: View {
    let onSelectDifficulty: (CPUDifficulty) -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            ArenaBackground()

            VStack(spacing: 14) {
                Text("CPUの強さ")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)
                    .accessibilityIdentifier("cpu-difficulty-screen")

                ForEach(CPUDifficulty.allCases, id: \.self) { difficulty in
                    SelectionCard(
                        title: difficulty.displayName,
                        subtitle: difficulty.summary,
                        accent: Palette.home,
                        dimmed: false,
                        action: { onSelectDifficulty(difficulty) }
                    )
                    .accessibilityIdentifier("cpu-difficulty-\(difficulty.rawValue)")
                }

                Button("戻る", action: onBack)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 8)
                    .accessibilityIdentifier("cpu-difficulty-back")
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
                        .multilineTextAlignment(.leading)
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmingQuit = false
    private let mode: MatchMode
    private let onQuit: () -> Void

    init(
        map: MapDefinition,
        mode: MatchMode,
        onFinished: @escaping (ScoreState) -> Void,
        onQuit: @escaping () -> Void
    ) {
        let controller = MatchController(
            config: Self.matchConfig(map: map, mode: mode),
            awayExternallyDriven: mode == .localVersus,
            onFinished: onFinished
        )
        if mode == .localVersus {
            // The dual-cluster layout reserves a P2 control band above the HUD; the
            // scene fits the board between the enlarged bands.
            controller.scene.topReservedBand = 270
            controller.scene.bottomReservedBand = 195
        }
        _controller = StateObject(wrappedValue: controller)
        self.mode = mode
        self.onQuit = onQuit
    }

    // The GameCore config for a mode: CPU practice speeds up only the human home
    // side and applies the chosen CPU difficulty; local versus gives both human
    // sides the same speed edge (the CPU never runs — the session always feeds an
    // explicit away input).
    private static func matchConfig(map: MapDefinition, mode: MatchMode) -> MatchConfig {
        switch mode {
        case .cpuPractice(let difficulty):
            return map.config
                .withCPUBehavior(difficulty.behavior)
                .withStrikerSpeedScales(home: humanControlSpeedScale, away: 1.0)
        case .localVersus:
            return map.config
                .withStrikerSpeedScales(home: humanControlSpeedScale, away: humanControlSpeedScale)
        }
    }

    // Player input is only meaningful while the match is actually playing: the
    // GameCore phase is running and the app-level pause is off. Everything else
    // (countdown, goal pause, paused, finished) shows disabled controls.
    private var controlsEnabled: Bool {
        controller.hud.matchPhase == .running && !controller.isPaused
    }

    var body: some View {
        ZStack {
            ArenaBackground()
            RinkSceneView(scene: controller.scene)

            if !controller.isPaused {
                if controller.hud.matchPhase == .countdown {
                    CountdownOverlay(seconds: controller.hud.phaseRemainingSeconds)
                } else if controller.hud.matchPhase == .goalPause, let scorer = controller.hud.lastScorer {
                    GoalOverlay(scorer: scorer, isLocalVersus: mode == .localVersus)
                }
            }

            if controller.isPaused {
                PauseOverlay(
                    confirmingQuit: confirmingQuit,
                    onResume: { controller.resume() },
                    onQuitRequest: { confirmingQuit = true },
                    onQuitConfirm: onQuit,
                    onQuitCancel: { confirmingQuit = false }
                )
            }
        }
        .overlay(alignment: .topTrailing) {
            if !controller.isPaused {
                Button(action: { controller.pause() }) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.1), in: Circle())
                }
                .accessibilityIdentifier("pause-match-button")
                .accessibilityLabel("一時停止")
                .padding(.trailing, 14)
                .padding(.top, 4)
            }
        }
        .animation(.snappy(duration: 0.2), value: controller.hud.phaseRemainingSeconds)
        .animation(.snappy(duration: 0.2), value: controller.hud.matchPhase)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                if mode == .localVersus {
                    // Player 2's cluster sits at the top of the device, rendered
                    // rotated 180° so its labels read from that side. Gesture
                    // coordinates rotate with the view; the single world-space flip
                    // lives in the setMovement wiring below (and only there).
                    BottomControls(
                        onMove: { controller.setMovement(Vector2(x: -$0.x, y: -$0.y), for: .away) },
                        boostPhase: controller.hud.awayBoostPhase,
                        boostRemainingSeconds: controller.hud.awayBoostRemainingSeconds,
                        onBoost: { controller.activateSkill(.boost, for: .away) },
                        shotPhase: controller.hud.awayShotPhase,
                        shotRemainingSeconds: controller.hud.awayShotRemainingSeconds,
                        onShot: { controller.activateSkill(.shot, for: .away) },
                        blockPhase: controller.hud.awayBlockPhase,
                        blockRemainingSeconds: controller.hud.awayBlockRemainingSeconds,
                        onBlock: { controller.activateSkill(.block, for: .away) },
                        identifierPrefix: "away-",
                        playerLabel: "PLAYER 2",
                        playerLabelIdentifier: "player-two-label",
                        compact: true
                    )
                    .rotationEffect(.degrees(180))
                    .disabled(!controlsEnabled)
                    .opacity(controlsEnabled ? 1 : 0.45)
                }

                MatchHUDBar(hud: controller.hud, isLocalVersus: mode == .localVersus)
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomControls(
                onMove: { controller.setMovement($0, for: .home) },
                boostPhase: controller.hud.boostPhase,
                boostRemainingSeconds: controller.hud.boostRemainingSeconds,
                onBoost: { controller.activateSkill(.boost, for: .home) },
                shotPhase: controller.hud.shotPhase,
                shotRemainingSeconds: controller.hud.shotRemainingSeconds,
                onShot: { controller.activateSkill(.shot, for: .home) },
                blockPhase: controller.hud.blockPhase,
                blockRemainingSeconds: controller.hud.blockRemainingSeconds,
                onBlock: { controller.activateSkill(.block, for: .home) },
                playerLabel: mode == .localVersus ? "PLAYER 1" : nil,
                playerLabelIdentifier: "player-one-label",
                compact: mode == .localVersus
            )
            .disabled(!controlsEnabled)
            .opacity(controlsEnabled ? 1 : 0.45)
        }
        .onChange(of: controlsEnabled) { _, enabled in
            // Gating can flip mid-drag; make sure no stale movement survives.
            if !enabled {
                controller.setMovement(.zero, for: .home)
                controller.setMovement(.zero, for: .away)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Leaving the foreground pauses the match; the player resumes manually.
            if newPhase != .active {
                controller.pause()
            }
        }
    }
}

// The 3-2-1 opening countdown, driven by the GameCore phase timer (no SwiftUI
// timers). Hit testing stays off so it never swallows input.
private struct CountdownOverlay: View {
    let seconds: Int

    var body: some View {
        Text("\(max(1, seconds))")
            .font(.system(size: 120, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 14)
            .accessibilityIdentifier("match-countdown-overlay")
            .id(seconds) // re-enter the transition on every displayed second
            .transition(.scale(scale: 1.4).combined(with: .opacity))
            .allowsHitTesting(false)
    }
}

// Short banner during the goal pause, attributed by GameCore's lastScorer.
private struct GoalOverlay: View {
    let scorer: PlayerSide
    let isLocalVersus: Bool

    private var text: String {
        switch scorer {
        case .home:
            return isLocalVersus ? "PLAYER 1 SCORE" : "GOAL!"
        case .away:
            return isLocalVersus ? "PLAYER 2 SCORE" : "CPU SCORE"
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 48, weight: .heavy, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(scorer == .home ? Palette.home : Palette.away)
            .shadow(color: .black.opacity(0.7), radius: 10)
            .padding(.horizontal, 26)
            .padding(.vertical, 12)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 18))
            .accessibilityIdentifier("goal-pause-overlay")
            .transition(.scale(scale: 0.8).combined(with: .opacity))
            .allowsHitTesting(false)
    }
}

// Full-screen pause menu. Quitting asks for confirmation first; the match state is
// simply discarded (no result, no persistence).
private struct PauseOverlay: View {
    let confirmingQuit: Bool
    let onResume: () -> Void
    let onQuitRequest: () -> Void
    let onQuitConfirm: () -> Void
    let onQuitCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                if confirmingQuit {
                    Text("タイトルへ戻りますか？")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.white)
                    Text("進行中の試合は保存されません")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    primaryButton("タイトルへ戻る", identifier: "quit-confirm-button", action: onQuitConfirm)
                    secondaryButton("キャンセル", identifier: "quit-cancel-button", action: onQuitCancel)
                } else {
                    Text("一時停止")
                        .font(.title.weight(.heavy))
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("pause-overlay")
                    primaryButton("再開", identifier: "resume-match-button", action: onResume)
                    secondaryButton("タイトルへ戻る", identifier: "quit-match-button", action: onQuitRequest)
                }
            }
            .padding(28)
        }
    }

    private func primaryButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.bold))
                .frame(maxWidth: 240)
                .padding(.vertical, 14)
                .background(Palette.home, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
        .accessibilityIdentifier(identifier)
    }

    private func secondaryButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
        .accessibilityIdentifier(identifier)
    }
}

private struct MatchHUDBar: View {
    let hud: MatchHUD
    var isLocalVersus = false

    var body: some View {
        HStack(alignment: .center) {
            scoreColumn(title: isLocalVersus ? "P1" : "あなた", score: hud.homeScore, color: Palette.home)

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

            scoreColumn(title: isLocalVersus ? "P2" : "CPU", score: hud.awayScore, color: Palette.away)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, isLocalVersus ? 4 : 10)
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

// Bottom control zone: joystick centered, with Boost on the left and the Block / Shot
// skills on the right so the movement stick sits under either thumb.
private struct BottomControls: View {
    let onMove: (Vector2) -> Void
    let boostPhase: SkillPhase
    let boostRemainingSeconds: Int
    let onBoost: () -> Void
    let shotPhase: SkillPhase
    let shotRemainingSeconds: Int
    let onShot: () -> Void
    let blockPhase: SkillPhase
    let blockRemainingSeconds: Int
    let onBlock: () -> Void
    // Reuse for the away (P2) cluster in local versus: prefixed identifiers, an
    // optional player label, and a compact size so two clusters fit one screen.
    var identifierPrefix = ""
    var playerLabel: String? = nil
    var playerLabelIdentifier = ""
    var compact = false

    var body: some View {
        VStack(spacing: 2) {
            if let playerLabel {
                Text(playerLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .accessibilityIdentifier(playerLabelIdentifier)
            }

            HStack(alignment: .center, spacing: 6) {
                BoostSkillButton(
                    phase: boostPhase,
                    remainingSeconds: boostRemainingSeconds,
                    onBoost: onBoost,
                    identifier: identifierPrefix + "skill-boost-button"
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                JoystickView(
                    onMove: onMove,
                    radius: compact ? 58 : 80,
                    knobSize: compact ? 54 : 74,
                    identifier: identifierPrefix + "joystick-control"
                )

                HStack(spacing: 6) {
                    BlockSkillButton(
                        phase: blockPhase,
                        remainingSeconds: blockRemainingSeconds,
                        onBlock: onBlock,
                        identifier: identifierPrefix + "skill-block-button"
                    )
                    ShotSkillButton(
                        phase: shotPhase,
                        remainingSeconds: shotRemainingSeconds,
                        onShot: onShot,
                        identifier: identifierPrefix + "skill-shot-button"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, compact ? 4 : 10)
        }
    }
}

// Fixed virtual joystick. Produces a 0...1 magnitude vector in GameCore rink
// orientation (y up); returns to neutral on release. Holds no game rules.
private struct JoystickView: View {
    let onMove: (Vector2) -> Void
    // Large control + hit area by default; the local versus layout passes a smaller
    // size. The produced 0...1 vector (and therefore GameCore movement) is the same
    // for any size since the gesture math is radius-relative.
    var radius: CGFloat = 80
    var knobSize: CGFloat = 74
    var identifier = "joystick-control"
    @State private var knobOffset: CGSize = .zero

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
        .accessibilityIdentifier(identifier)
    }
}

// The live Boost skill button. Enabled while ready; shows active / cooldown state.
// The action is gated to the ready phase (so a cooldown tap is a clear no-op) rather
// than .disabled, which would grey out the active / cooldown look.
private struct BoostSkillButton: View {
    let phase: SkillPhase
    let remainingSeconds: Int
    let onBoost: () -> Void
    var identifier = "skill-boost-button"

    var body: some View {
        Button(action: { if phase == .ready { onBoost() } }) {
            SkillSlotFace(
                systemImage: style.icon,
                iconColor: style.iconColor,
                fill: style.fill,
                stroke: style.stroke,
                strokeWidth: style.strokeWidth,
                label: style.label,
                labelColor: style.labelColor
            )
            .scaleEffect(phase == .active ? 1.06 : 1.0)
            .animation(.snappy(duration: 0.15), value: phase)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(accessibilityValue)
    }

    // Per-phase look: ready is inviting, active is bright, and cooldown reads as
    // "recharging" (accent tint + hourglass) rather than a dead / permanently locked slot.
    private var style: (icon: String, iconColor: Color, fill: Color, stroke: Color, strokeWidth: CGFloat, label: String, labelColor: Color) {
        switch phase {
        case .ready:
            return ("bolt.fill", .white, Palette.home.opacity(0.22), Palette.home.opacity(0.95), 2, "ブースト", .white.opacity(0.95))
        case .active:
            return ("bolt.fill", .white, Palette.home.opacity(0.95), .white.opacity(0.95), 3, "発動中", .white)
        case .cooldown:
            return ("hourglass", Palette.accent.opacity(0.85), .white.opacity(0.06), Palette.accent.opacity(0.5), 2, "CD \(remainingSeconds)", Palette.accent.opacity(0.9))
        }
    }

    private var accessibilityValue: String {
        switch phase {
        case .ready:
            return "使用可能"
        case .active:
            return "発動中"
        case .cooldown:
            return "クールダウン \(remainingSeconds)秒"
        }
    }
}

// The live Shot skill button. Enabled while ready; shows armed / cooldown state. Like
// Boost, the action is gated to the ready phase (so a cooldown tap is a clear no-op)
// rather than .disabled, which would grey out the armed / cooldown look.
private struct ShotSkillButton: View {
    let phase: SkillPhase
    let remainingSeconds: Int
    let onShot: () -> Void
    var identifier = "skill-shot-button"

    var body: some View {
        Button(action: { if phase == .ready { onShot() } }) {
            SkillSlotFace(
                systemImage: style.icon,
                iconColor: style.iconColor,
                fill: style.fill,
                stroke: style.stroke,
                strokeWidth: style.strokeWidth,
                label: style.label,
                labelColor: style.labelColor
            )
            .scaleEffect(phase == .active ? 1.06 : 1.0)
            .animation(.snappy(duration: 0.15), value: phase)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(accessibilityValue)
    }

    // Per-phase look in the attacking (away) colour: ready invites a shot, active reads as
    // "aiming" (構え), and cooldown shows a recharging hourglass rather than a locked slot.
    private var style: (icon: String, iconColor: Color, fill: Color, stroke: Color, strokeWidth: CGFloat, label: String, labelColor: Color) {
        switch phase {
        case .ready:
            return ("bolt.horizontal.fill", .white, Palette.away.opacity(0.22), Palette.away.opacity(0.95), 2, "ショット", .white.opacity(0.95))
        case .active:
            return ("scope", .white, Palette.away.opacity(0.95), .white.opacity(0.95), 3, "構え", .white)
        case .cooldown:
            return ("hourglass", Palette.accent.opacity(0.85), .white.opacity(0.06), Palette.accent.opacity(0.5), 2, "CD \(remainingSeconds)", Palette.accent.opacity(0.9))
        }
    }

    private var accessibilityValue: String {
        switch phase {
        case .ready:
            return "使用可能"
        case .active:
            return "構え"
        case .cooldown:
            return "クールダウン \(remainingSeconds)秒"
        }
    }
}

// The live Block skill button. Enabled while ready; shows defending / cooldown state. Like
// Boost/Shot, the action is gated to the ready phase (so a cooldown tap is a clear no-op)
// rather than .disabled, which would grey out the active / cooldown look.
private struct BlockSkillButton: View {
    let phase: SkillPhase
    let remainingSeconds: Int
    let onBlock: () -> Void
    var identifier = "skill-block-button"

    var body: some View {
        Button(action: { if phase == .ready { onBlock() } }) {
            SkillSlotFace(
                systemImage: style.icon,
                iconColor: style.iconColor,
                fill: style.fill,
                stroke: style.stroke,
                strokeWidth: style.strokeWidth,
                label: style.label,
                labelColor: style.labelColor
            )
            .scaleEffect(phase == .active ? 1.06 : 1.0)
            .animation(.snappy(duration: 0.15), value: phase)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(accessibilityValue)
    }

    // Per-phase look in the defending (home) colour: ready invites a block, active reads as
    // "defending" (防御中), and cooldown shows a recharging hourglass.
    private var style: (icon: String, iconColor: Color, fill: Color, stroke: Color, strokeWidth: CGFloat, label: String, labelColor: Color) {
        switch phase {
        case .ready:
            return ("shield.fill", .white, Palette.home.opacity(0.22), Palette.home.opacity(0.95), 2, "ブロック", .white.opacity(0.95))
        case .active:
            return ("shield.fill", .white, Palette.home.opacity(0.95), .white.opacity(0.95), 3, "防御中", .white)
        case .cooldown:
            return ("hourglass", Palette.accent.opacity(0.85), .white.opacity(0.06), Palette.accent.opacity(0.5), 2, "CD \(remainingSeconds)", Palette.accent.opacity(0.9))
        }
    }

    private var accessibilityValue: String {
        switch phase {
        case .ready:
            return "使用可能"
        case .active:
            return "防御中"
        case .cooldown:
            return "クールダウン \(remainingSeconds)秒"
        }
    }
}

// Shared circular face for a skill button (icon + label).
private struct SkillSlotFace: View {
    let systemImage: String
    let iconColor: Color
    let fill: Color
    let stroke: Color
    let strokeWidth: CGFloat
    let label: String
    let labelColor: Color

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .strokeBorder(stroke, lineWidth: strokeWidth)
                .background(Circle().fill(fill))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 14))
                        .foregroundStyle(iconColor)
                )
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(labelColor)
                .monospacedDigit()
        }
        .frame(width: 52)
    }
}

struct StartView: View {
    let onStart: () -> Void
    let onSettings: () -> Void
    let onHowToPlay: () -> Void
    let onSkillGuide: () -> Void

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

                    secondaryButton("スキルガイド", identifier: "skill-guide-button", action: onSkillGuide)
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
    let mode: MatchMode
    let onRetry: () -> Void
    let onBackToTitle: () -> Void

    private var isLocalVersus: Bool {
        mode == .localVersus
    }

    private var outcomeText: String {
        switch score.winner {
        case .home:
            return isLocalVersus ? "PLAYER 1の勝ち" : "あなたの勝ち"
        case .away:
            return isLocalVersus ? "PLAYER 2の勝ち" : "CPUの勝ち"
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

                // Which kind of match this result came from; retry reuses it. CPU
                // practice shows the chosen difficulty, local versus its own badge.
                switch mode {
                case .cpuPractice(let difficulty):
                    badge("CPU：\(difficulty.displayName)")
                        .accessibilityIdentifier("result-difficulty-badge")
                case .localVersus:
                    badge("ローカル対戦")
                        .accessibilityIdentifier("local-versus-mode-badge")
                }

                HStack(spacing: 20) {
                    scoreCard(title: isLocalVersus ? "PLAYER 1" : "あなた", value: score.home, color: Palette.home)
                    Text("-").font(.system(size: 32, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                    scoreCard(title: isLocalVersus ? "PLAYER 2" : "CPU", value: score.away, color: Palette.away)
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

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(.white.opacity(0.08)))
            .overlay(Capsule().strokeBorder(Palette.away.opacity(0.5), lineWidth: 1))
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

// A titled group of bullet lines used inside the information screens. `identifier`
// tags the section title for UI tests; sections that tests never target omit it.
private struct InfoSection: View {
    let title: String
    let lines: [String]
    var identifier: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(Palette.accent)
                .accessibilityIdentifier(identifier)
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

// Explains the three skills. The numbers shown are the shared MatchConfig defaults
// (identical for the player and the CPU); the CPU's internal decision thresholds are
// deliberately not exposed here.
private struct SkillGuideView: View {
    let onClose: () -> Void

    var body: some View {
        InfoScreen(
            title: "スキルガイド",
            screenIdentifier: "skill-guide-screen",
            closeIdentifier: "close-skill-guide-button",
            onClose: onClose
        ) {
            InfoSection(title: "ブースト", lines: [
                "移動速度が1.6倍になる（効果2.0秒 / CD6秒）",
                "先回りや守備への復帰に使いやすい",
                "扱いやすさ：かんたん"
            ], identifier: "skill-guide-boost")
            InfoSection(title: "ショット", lines: [
                "次の有効な打球が1.8倍の速さで飛ぶ（構え1.2秒 / CD7秒）",
                "強打やブーストとの連携に有効",
                "構え中に当てられないと空振りでもCDに入る",
                "扱いやすさ：ふつう"
            ], identifier: "skill-guide-shot")
            InfoSection(title: "ブロック", lines: [
                "自分のゴール前にシールドを張る（効果1.5秒 / CD8秒）",
                "相手の強打への対応に有効",
                "展開する前に通過したパックは防げない",
                "扱いやすさ：ふつう"
            ], identifier: "skill-guide-block")
            InfoSection(title: "CPU", lines: [
                "CPUも同じ3つのスキルを使ってくる"
            ])
            InfoSection(title: "ローカル対戦", lines: [
                "PLAYER 1 / PLAYER 2も同じ3つのスキルを使う"
            ])
            InfoSection(title: "オンライン", lines: [
                "準備中"
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
            InfoSection(title: "ローカル対戦", lines: [
                "1台を上下から2人で操作する",
                "PLAYER 2の操作UIは反対側から読める向き"
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
