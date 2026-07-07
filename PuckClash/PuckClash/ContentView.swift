//
//  ContentView.swift
//  PuckClash
//
//  Created by yuuki kounishi on 2026/06/24.
//

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

    // A new match identity forces RinkSceneView to rebuild its scene/engine.
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
    let onFinished: (ScoreState) -> Void
    @State private var hud = MatchHUD()

    var body: some View {
        ZStack {
            ArenaBackground()

            RinkSceneView(onFinished: onFinished, onHUDChange: { hud = $0 })
        }
        .safeAreaInset(edge: .top) {
            MatchHUDBar(hud: hud)
        }
        .safeAreaInset(edge: .bottom) {
            SkillSlotBar()
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

// Visual-only placeholder for future skills. Disabled; tapping does nothing and
// no game rule is attached.
private struct SkillSlotBar: View {
    private let slots = ["Boost", "Block", "Shot"]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(slots, id: \.self) { name in
                VStack(spacing: 6) {
                    Circle()
                        .strokeBorder(.white.opacity(0.18), lineWidth: 2)
                        .background(Circle().fill(.white.opacity(0.05)))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "lock.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.3))
                        )
                    Text(name)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
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
