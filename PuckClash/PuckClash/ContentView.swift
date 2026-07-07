//
//  ContentView.swift
//  PuckClash
//
//  Created by yuuki kounishi on 2026/06/24.
//

import Combine
import SwiftUI

enum MatchFlow {
    case start
    case match
    case result(ScoreState)
}

// Plain value snapshot the SpriteKit scene pushes to the SwiftUI HUD. Holds no
// game rules — just the numbers to display.
struct MatchHUD: Equatable {
    var homeScore = 0
    var awayScore = 0
    var remainingSeconds = 0
}

// Owns a single RinkScene shared by the SpriteView and the joystick, and republishes
// the low-frequency HUD snapshot. It carries no game rules.
final class MatchController: ObservableObject {
    let scene: RinkScene
    @Published var hud = MatchHUD()

    init(onFinished: @escaping (ScoreState) -> Void) {
        let scene = RinkScene(config: .standard)
        self.scene = scene
        scene.onFinished = onFinished
        scene.onHUDChange = { [weak self] snapshot in
            self?.hud = snapshot
        }
    }

    // Joystick vector goes straight to the scene (not through @Published) so dragging
    // does not re-render SwiftUI every frame.
    func setMoveVector(_ vector: Vector2) {
        scene.homeMoveVector = vector == .zero ? nil : vector
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

    var body: some View {
        switch flow {
        case .start:
            StartView(onStart: startMatch)
        case .match:
            MatchView(onFinished: { score in flow = .result(score) })
                .id(matchID)
        case .result(let score):
            ResultView(
                score: score,
                onRetry: startMatch,
                onBackToTitle: { flow = .start }
            )
        }
    }

    // A new match identity rebuilds the controller (and its scene/engine).
    private func startMatch() {
        matchID = UUID()
        flow = .match
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

struct MatchView: View {
    @StateObject private var controller: MatchController

    init(onFinished: @escaping (ScoreState) -> Void) {
        _controller = StateObject(wrappedValue: MatchController(onFinished: onFinished))
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
            scoreColumn(title: "YOU", score: hud.homeScore, color: Palette.home)

            Spacer()

            VStack(spacing: 2) {
                Text("TIME")
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
    private let slots = ["Boost", "Block", "Shot"]

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
                    Text("Vertical air hockey • 1v1")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.65))
                }

                Button(action: onStart) {
                    Text("Start")
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: 240)
                        .padding(.vertical, 16)
                        .background(Palette.home, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .accessibilityIdentifier("start-match-button")
                .padding(.top, 8)
            }
            .padding()
        }
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
            return "You Win"
        case .away:
            return "CPU Wins"
        case nil:
            return "Draw"
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
                Text("Full Time")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.6))

                Text(outcomeText)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(outcomeColor)

                HStack(spacing: 20) {
                    scoreCard(title: "YOU", value: score.home, color: Palette.home)
                    Text("-").font(.system(size: 32, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                    scoreCard(title: "CPU", value: score.away, color: Palette.away)
                }
                .padding(.vertical, 8)

                Button(action: onRetry) {
                    Text("Retry")
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: 240)
                        .padding(.vertical, 16)
                        .background(Palette.home, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .accessibilityIdentifier("retry-match-button")
                .padding(.top, 4)

                Button(action: onBackToTitle) {
                    Text("Back to Title")
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

#Preview {
    ContentView()
}
