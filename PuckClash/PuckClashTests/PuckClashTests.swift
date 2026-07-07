//
//  PuckClashTests.swift
//  PuckClashTests
//
//  Created by yuuki kounishi on 2026/06/24.
//

import Testing
@testable import PuckClash

struct PuckClashTests {
    // Vertical board: 100 wide x 200 tall, home defends bottom (y=0) / attacks top
    // goal (y=200), away is the mirror. Goal mouth is x in [30, 70].
    private let config = MatchConfig(
        rinkSize: Vector2(x: 100, y: 200),
        matchDuration: 10,
        strikerMaxSpeed: 1000,
        goalMouthHalfWidth: 20,
        strikerRadius: 10,
        puckRadius: 5,
        strikerHitRestitution: 1.0,
        wallRestitution: 1.0,
        puckDamping: 1.0,
        puckStopSpeed: 0
    )

    private var frictionConfig: MatchConfig {
        MatchConfig(
            rinkSize: Vector2(x: 100, y: 200),
            matchDuration: 10,
            strikerMaxSpeed: 1000,
            goalMouthHalfWidth: 20,
            strikerRadius: 10,
            puckRadius: 5,
            puckDamping: 0.25,
            puckStopSpeed: 5
        )
    }

    // MARK: - Initial state / layout

    @Test func initialStateUsesVerticalRinkAndPositions() {
        let state = GameState.initial(config: config)

        #expect(state.score == .zero)
        #expect(state.phase == .ready)
        #expect(state.remainingTime == 10)
        #expect(state.homePlayer.position == Vector2(x: 50, y: 40))
        #expect(state.awayPlayer.position == Vector2(x: 50, y: 160))
        #expect(state.puck.position == Vector2(x: 50, y: 100))
    }

    // MARK: - Striker movement / half clamp

    @Test func homeStrikerClampsToLowerHalf() {
        var engine = GameEngine(state: .initial(config: config))

        engine.update(
            deltaTime: 0.5,
            inputs: [PlayerInput(playerId: .home, targetPosition: Vector2(x: 20, y: 180), timestamp: 1)]
        )

        // Target y 180 is above center; home is clamped to the lower half (y <= 100).
        #expect(engine.state.homePlayer.position == Vector2(x: 20, y: 100))
    }

    @Test func awayStrikerClampsToUpperHalf() {
        var engine = GameEngine(state: .initial(config: config))

        engine.update(
            deltaTime: 0.5,
            inputs: [PlayerInput(playerId: .away, targetPosition: Vector2(x: 80, y: 20), timestamp: 1)]
        )

        // Target y 20 is below center; away is clamped to the upper half (y >= 100).
        #expect(engine.state.awayPlayer.position == Vector2(x: 80, y: 100))
    }

    @Test func targetPositionMovesStrikerCappedBySpeed() {
        var engine = GameEngine(state: .initial(config: config))

        // maxStep = 1000 * 0.01 = 10; from (50,40) toward (50,10) advances 10 to (50,30).
        engine.update(
            deltaTime: 0.01,
            inputs: [PlayerInput(playerId: .home, targetPosition: Vector2(x: 50, y: 10), timestamp: 1)]
        )

        #expect(engine.state.homePlayer.position == Vector2(x: 50, y: 30))
    }

    // MARK: - Free puck

    @Test func puckMovesFreelyByVelocity() {
        var state = GameState.initial(config: config)
        state.puck.velocity = Vector2(x: 6, y: 0)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        #expect(engine.state.puck.position == Vector2(x: 56, y: 100))
        #expect(engine.state.puck.velocity == Vector2(x: 6, y: 0))
    }

    // MARK: - Striker / puck collision

    @Test func strikerPuckCollisionChangesPuckVelocity() {
        var state = GameState.initial(config: config)
        state.homePlayer.position = Vector2(x: 50, y: 80)
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 0.1,
            inputs: [PlayerInput(playerId: .home, targetPosition: Vector2(x: 50, y: 100), timestamp: 1)]
        )

        // Striker moving up at 200 hits the puck: impulse = -(1+1)*(-200) = 400.
        #expect(engine.state.puck.velocity == Vector2(x: 0, y: 400))
        #expect(engine.state.puck.position == Vector2(x: 50, y: 155))
    }

    @Test func collisionPushesPuckOutOfOverlap() {
        var state = GameState.initial(config: config)
        state.homePlayer.position = Vector2(x: 50, y: 95)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.1, inputs: [])

        // Overlap resolved along +y; puck sits exactly at strikerRadius+puckRadius (15).
        #expect(engine.state.puck.position == Vector2(x: 50, y: 110))
        let separation = (engine.state.puck.position - engine.state.homePlayer.position).length
        #expect(separation >= 15)
    }

    // MARK: - Goals (top/bottom)

    @Test func topGoalScoresForHome() {
        var state = GameState.initial(config: config)
        state.homePlayer.position = Vector2(x: 20, y: 40)
        state.awayPlayer.position = Vector2(x: 20, y: 160)
        state.puck.position = Vector2(x: 50, y: 190)
        state.puck.velocity = Vector2(x: 0, y: 100)
        var engine = GameEngine(state: state)

        // Pin away to a corner so it does not intercept the shot.
        engine.update(
            deltaTime: 1,
            inputs: [PlayerInput(playerId: .away, targetPosition: Vector2(x: 10, y: 110), timestamp: 1)]
        )

        #expect(engine.state.score.home == 1)
        #expect(engine.state.score.away == 0)
    }

    @Test func bottomGoalScoresForAway() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 10)
        state.puck.velocity = Vector2(x: 0, y: -100)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        #expect(engine.state.score.away == 1)
        #expect(engine.state.score.home == 0)
    }

    @Test func outsideTopGoalMouthReflectsInsteadOfScoring() {
        var state = GameState.initial(config: config)
        state.homePlayer.position = Vector2(x: 80, y: 40)
        state.awayPlayer.position = Vector2(x: 80, y: 160)
        state.puck.position = Vector2(x: 10, y: 190)
        state.puck.velocity = Vector2(x: 0, y: 100)
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 1,
            inputs: [PlayerInput(playerId: .away, targetPosition: Vector2(x: 80, y: 110), timestamp: 1)]
        )

        // x=10 is outside the mouth [30,70]: reflect off the top wall, no goal.
        #expect(engine.state.score == .zero)
        #expect(engine.state.puck.velocity == Vector2(x: 0, y: -100))
    }

    @Test func leftAndRightWallsReflect() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 5, y: 100)
        state.puck.velocity = Vector2(x: -10, y: 0)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        #expect(engine.state.score == .zero)
        #expect(engine.state.puck.position == Vector2(x: 5, y: 100))
        #expect(engine.state.puck.velocity == Vector2(x: 10, y: 0))
    }

    @Test func goalResetsPuckAndStrikers() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 10)
        state.puck.velocity = Vector2(x: 0, y: -100)
        state.homePlayer.position = Vector2(x: 10, y: 20)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        #expect(engine.state.score.away == 1)
        #expect(engine.state.puck.position == config.rinkCenter)
        #expect(engine.state.puck.velocity == .zero)
        #expect(engine.state.homePlayer.position == config.homeStartPosition)
        #expect(engine.state.awayPlayer.position == config.awayStartPosition)
    }

    // MARK: - Damping

    @Test func puckDampingStillApplies() {
        var state = GameState.initial(config: frictionConfig)
        state.puck.velocity = Vector2(x: 40, y: 0)
        var engine = GameEngine(state: state)

        // 40 -> 10 after pow(0.25, 1); position uses the pre-damped velocity.
        engine.update(deltaTime: 1, inputs: [])

        #expect(engine.state.puck.position == Vector2(x: 90, y: 100))
        #expect(engine.state.puck.velocity == Vector2(x: 10, y: 0))
    }

    // MARK: - Away CPU

    @Test func awayCPUStaysInUpperHalf() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 40)
        state.puck.velocity = .zero
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.5, inputs: [])

        // Even chasing a puck in the lower half, away never crosses the center line.
        #expect(engine.state.awayPlayer.position.y >= config.rinkCenter.y)
    }

    // MARK: - Timer / phase / buzzer

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

    @Test func buzzerFrameEndsMatchWithoutSimulating() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 190)
        state.puck.velocity = Vector2(x: 0, y: 100)
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 10,
            inputs: [PlayerInput(playerId: .home, targetPosition: Vector2(x: 50, y: 10), timestamp: 1)]
        )

        #expect(engine.state.phase == .finished)
        #expect(engine.state.score == .zero)
        #expect(engine.state.puck.position == Vector2(x: 50, y: 190))
        #expect(engine.state.puck.velocity == Vector2(x: 0, y: 100))
        #expect(engine.state.homePlayer.position == config.homeStartPosition)
    }

    @Test func finishedStateIsImmutable() {
        var state = GameState.initial(config: config)
        state.phase = .finished
        state.puck.velocity = Vector2(x: 0, y: 100)
        let frozen = state
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 1,
            inputs: [PlayerInput(playerId: .home, targetPosition: Vector2(x: 50, y: 10), timestamp: 1)]
        )

        #expect(engine.state == frozen)
    }

    // MARK: - Score winner

    @Test func winnerIsHomeWhenHomeScoresMore() {
        #expect(ScoreState(home: 3, away: 1).winner == .home)
    }

    @Test func winnerIsAwayWhenAwayScoresMore() {
        #expect(ScoreState(home: 0, away: 2).winner == .away)
    }

    @Test func winnerIsNilOnDraw() {
        #expect(ScoreState(home: 2, away: 2).winner == nil)
        #expect(ScoreState.zero.winner == nil)
    }
}
