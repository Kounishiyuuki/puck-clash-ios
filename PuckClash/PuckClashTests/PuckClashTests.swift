//
//  PuckClashTests.swift
//  PuckClashTests
//
//  Created by yuuki kounishi on 2026/06/24.
//

import Testing
@testable import PuckClash

struct PuckClashTests {
    private let config = MatchConfig(
        rinkSize: Vector2(x: 100, y: 50),
        matchDuration: 10,
        playerSpeed: 20
    )

    @Test func initialStateUsesExpectedMatchDefaults() {
        let state = GameState.initial(config: config)

        #expect(state.score == .zero)
        #expect(state.phase == .ready)
        #expect(state.remainingTime == 10)
        #expect(state.homePlayer.position == Vector2(x: 25, y: 25))
        #expect(state.awayPlayer.position == Vector2(x: 75, y: 25))
        #expect(state.puck.position == Vector2(x: 50, y: 25))
    }

    @Test func playerMovesWhenInputIsApplied() {
        var engine = GameEngine(state: .initial(config: config))

        engine.update(
            deltaTime: 0.5,
            inputs: [
                PlayerInput(
                    playerId: .home,
                    moveDirection: Vector2(x: 1, y: 0),
                    timestamp: 1
                )
            ]
        )

        #expect(engine.state.homePlayer.position == Vector2(x: 35, y: 25))
        #expect(engine.state.homePlayer.velocity == Vector2(x: 20, y: 0))
    }

    @Test func playerIsClampedInsideRinkBounds() {
        var state = GameState.initial(config: config)
        state.homePlayer.position = Vector2(x: 95, y: 45)
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 1,
            inputs: [
                PlayerInput(
                    playerId: .home,
                    moveDirection: Vector2(x: 1, y: 1),
                    timestamp: 1
                )
            ]
        )

        #expect(engine.state.homePlayer.position.x <= config.rinkSize.x)
        #expect(engine.state.homePlayer.position.y <= config.rinkSize.y)
        #expect(engine.state.homePlayer.position == Vector2(x: 100, y: 50))
    }

    @Test func puckPositionUpdatesByVelocity() {
        var state = GameState.initial(config: config)
        state.puck.velocity = Vector2(x: 4, y: -2)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 2, inputs: [])

        #expect(engine.state.puck.position == Vector2(x: 58, y: 21))
    }

    @Test func homeScoresWhenPuckEntersRightGoal() {
        var state = GameState.initial(config: config)
        state.puck.velocity = Vector2(x: 60, y: 0)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        #expect(engine.state.score.home == 1)
        #expect(engine.state.score.away == 0)
    }

    @Test func awayScoresWhenPuckEntersLeftGoal() {
        var state = GameState.initial(config: config)
        state.puck.velocity = Vector2(x: -60, y: 0)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        #expect(engine.state.score.home == 0)
        #expect(engine.state.score.away == 1)
    }

    @Test func puckResetsToCenterAfterGoal() {
        var state = GameState.initial(config: config)
        state.puck.velocity = Vector2(x: 60, y: 0)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        #expect(engine.state.puck.position == config.rinkCenter)
    }

    @Test func puckVelocityResetsAfterGoal() {
        var state = GameState.initial(config: config)
        state.puck.velocity = Vector2(x: -60, y: 5)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        #expect(engine.state.puck.velocity == .zero)
    }

    @Test func scoreDoesNotChangeAfterMatchEnded() {
        var state = GameState.initial(config: config)
        state.phase = .finished
        state.remainingTime = 0
        state.puck.velocity = Vector2(x: 60, y: 0)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        #expect(engine.state.score == .zero)
        #expect(engine.state.puck.position == config.rinkCenter)
        #expect(engine.state.puck.velocity == Vector2(x: 60, y: 0))
    }

    @Test func remainingTimeDecreases() {
        var engine = GameEngine(state: .initial(config: config))

        engine.update(deltaTime: 3, inputs: [])

        #expect(engine.state.remainingTime == 7)
        #expect(engine.state.phase == .running)
    }

    @Test func matchEndsWhenTimeReachesZero() {
        var engine = GameEngine(state: .initial(config: config))

        engine.update(deltaTime: 12, inputs: [])

        #expect(engine.state.remainingTime == 0)
        #expect(engine.state.phase == .finished)
    }
}
