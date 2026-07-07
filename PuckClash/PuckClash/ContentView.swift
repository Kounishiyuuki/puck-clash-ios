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

struct StartView: View {
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.13, blue: 0.20)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Puck Clash")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(.white)

                Text("1v1 skill hockey prototype")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))

                Button(action: onStart) {
                    Text("Start")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: 220)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.12, green: 0.35, blue: 0.95))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityIdentifier("start-match-button")
                .padding(.top, 12)
            }
            .padding()
        }
    }
}

struct MatchView: View {
    let onFinished: (ScoreState) -> Void

    var body: some View {
        RinkSceneView(onFinished: onFinished)
    }
}

struct ResultView: View {
    let score: ScoreState
    let onRetry: () -> Void
    let onBackToTitle: () -> Void

    private var outcomeText: String {
        switch score.winner {
        case .home:
            return "Home Win"
        case .away:
            return "Away Win"
        case nil:
            return "Draw"
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.13, blue: 0.20)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Full Time")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))

                Text(outcomeText)
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(.white)

                Text("\(score.home) - \(score.away)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Button(action: onRetry) {
                    Text("Retry")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: 220)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.12, green: 0.35, blue: 0.95))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityIdentifier("retry-match-button")
                .padding(.top, 12)

                Button(action: onBackToTitle) {
                    Text("Back to Title")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .accessibilityIdentifier("back-to-title-button")
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
