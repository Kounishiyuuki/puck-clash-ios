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
        playerSpeed: 20,
        goalMouthHalfHeight: 10
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

    @Test func homeScoresWhenPuckCrossesRightGoalLineInsideGoalMouth() {
        var state = GameState.initial(config: config)
        state.puck.velocity = Vector2(x: 60, y: 0)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        #expect(engine.state.score.home == 1)
        #expect(engine.state.score.away == 0)
    }

    @Test func awayScoresWhenPuckCrossesLeftGoalLineInsideGoalMouth() {
        var state = GameState.initial(config: config)
        state.puck.velocity = Vector2(x: -60, y: 0)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        #expect(engine.state.score.home == 0)
        #expect(engine.state.score.away == 1)
    }

    @Test func noScoreWhenPuckCrossesRightBoundaryOutsideGoalMouth() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 95, y: 5)
        state.puck.velocity = Vector2(x: 10, y: 0)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        #expect(engine.state.score == .zero)
        #expect(engine.state.puck.position == Vector2(x: 100, y: 5))
        #expect(engine.state.puck.velocity == Vector2(x: 10, y: 0))
    }

    @Test func noScoreWhenPuckCrossesLeftBoundaryOutsideGoalMouth() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 5, y: 45)
        state.puck.velocity = Vector2(x: -10, y: 0)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        #expect(engine.state.score == .zero)
        #expect(engine.state.puck.position == Vector2(x: 0, y: 45))
        #expect(engine.state.puck.velocity == Vector2(x: -10, y: 0))
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

    // MARK: - Possession

    private var possessionConfig: MatchConfig {
        MatchConfig(
            rinkSize: Vector2(x: 100, y: 50),
            matchDuration: 10,
            playerSpeed: 20,
            goalMouthHalfHeight: 10,
            pickupRadius: 5,
            puckCarryOffset: 2,
            shotSpeed: 40,
            contestRadius: 5,
            contestCooldown: 0.5
        )
    }

    @Test func homeGainsPossessionWhenCloseToPuck() {
        var state = GameState.initial(config: possessionConfig)
        state.homePlayer.position = Vector2(x: 47, y: 25)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.1, inputs: [])

        #expect(engine.state.possession == .home)
    }

    @Test func homeDoesNotGainPossessionOutsidePickupRadius() {
        var state = GameState.initial(config: possessionConfig)
        state.homePlayer.position = Vector2(x: 40, y: 25)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.1, inputs: [])

        #expect(engine.state.possession == PuckPossession.none)
    }

    @Test func possessedPuckFollowsHomePlayer() {
        var state = GameState.initial(config: possessionConfig)
        state.possession = .home
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 0.5,
            inputs: [
                PlayerInput(
                    playerId: .home,
                    moveDirection: Vector2(x: 0, y: 1),
                    timestamp: 1
                )
            ]
        )

        #expect(engine.state.homePlayer.position == Vector2(x: 25, y: 35))
        #expect(engine.state.puck.position == Vector2(x: 25, y: 37))
        #expect(engine.state.puck.velocity == .zero)
    }

    @Test func goalResetClearsPossession() {
        var state = GameState.initial(config: possessionConfig)
        state.possession = .away
        state.awayPlayer.position = Vector2(x: 20, y: 25)
        state.homePlayer.position = Vector2(x: 75, y: 25)
        state.puck.position = Vector2(x: 18, y: 25)
        var engine = GameEngine(state: state)

        // Away CPU shoots toward the home goal; the shot scores and the reset clears possession.
        engine.update(deltaTime: 0.5, inputs: [])

        #expect(engine.state.score.away == 1)
        #expect(engine.state.possession == PuckPossession.none)
        #expect(engine.state.puck.position == possessionConfig.rinkCenter)
        #expect(engine.state.puck.velocity == .zero)
    }

    // MARK: - Shooting

    @Test func shootingClearsPossessionAndSetsPuckVelocity() {
        var state = GameState.initial(config: possessionConfig)
        state.possession = .home
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 0.1,
            inputs: [
                PlayerInput(
                    playerId: .home,
                    moveDirection: Vector2(x: 1, y: 0),
                    isShooting: true,
                    timestamp: 1
                )
            ]
        )

        #expect(engine.state.possession == PuckPossession.none)
        #expect(engine.state.puck.velocity == Vector2(x: 40, y: 0))
    }

    @Test func shootingWithoutDirectionAimsAtAwayGoal() {
        var state = GameState.initial(config: possessionConfig)
        state.possession = .home
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 0.1,
            inputs: [
                PlayerInput(playerId: .home, isShooting: true, timestamp: 1)
            ]
        )

        #expect(engine.state.puck.velocity == Vector2(x: 40, y: 0))
    }

    @Test func shootingWithoutPossessionDoesNotChangePuck() {
        var state = GameState.initial(config: possessionConfig)
        state.homePlayer.position = Vector2(x: 10, y: 10)
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 0.1,
            inputs: [
                PlayerInput(playerId: .home, isShooting: true, timestamp: 1)
            ]
        )

        #expect(engine.state.possession == PuckPossession.none)
        #expect(engine.state.puck.velocity == .zero)
        #expect(engine.state.puck.position == possessionConfig.rinkCenter)
    }

    // MARK: - Away CPU

    @Test func awayCPUMovesTowardFreePuck() {
        var engine = GameEngine(state: .initial(config: possessionConfig))

        engine.update(deltaTime: 0.5, inputs: [])

        #expect(engine.state.awayPlayer.position == Vector2(x: 65, y: 25))
        #expect(engine.state.awayPlayer.velocity == Vector2(x: -20, y: 0))
    }

    @Test func awayCPUChasesHomeCarrierWhenHomePossesses() {
        var state = GameState.initial(config: possessionConfig)
        state.possession = .home
        state.homePlayer.position = Vector2(x: 25, y: 5)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.5, inputs: [])

        // Away chases the home carrier at (25, 5) to contest the puck.
        #expect(engine.state.awayPlayer.position.x < 75)
        #expect(engine.state.awayPlayer.position.y < 25)
    }

    @Test func awayCPUStaysInsideRinkBounds() {
        var engine = GameEngine(state: .initial(config: possessionConfig))

        for _ in 0..<200 {
            engine.update(deltaTime: 0.05, inputs: [])
        }

        let position = engine.state.awayPlayer.position
        #expect(position.x >= 0 && position.x <= possessionConfig.rinkSize.x)
        #expect(position.y >= 0 && position.y <= possessionConfig.rinkSize.y)
    }

    // MARK: - Away possession

    @Test func awayGainsPossessionWhenCloseToFreePuck() {
        var state = GameState.initial(config: possessionConfig)
        state.awayPlayer.position = Vector2(x: 53, y: 25)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.1, inputs: [])

        #expect(engine.state.possession == .away)
    }

    @Test func awayDoesNotGainPossessionOutsidePickupRadius() {
        var state = GameState.initial(config: possessionConfig)
        state.awayPlayer.position = Vector2(x: 70, y: 25)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.1, inputs: [])

        #expect(engine.state.possession == PuckPossession.none)
    }

    @Test func awayPossessedPuckFollowsAwayPlayer() {
        var state = GameState.initial(config: possessionConfig)
        state.possession = .away
        var engine = GameEngine(state: state)

        // Away CPU carries toward the home goal: (75, 25) -> (65, 25) with carry offset -2.
        engine.update(deltaTime: 0.5, inputs: [])

        #expect(engine.state.awayPlayer.position == Vector2(x: 65, y: 25))
        #expect(engine.state.puck.position == Vector2(x: 63, y: 25))
        #expect(engine.state.puck.velocity == .zero)
    }

    @Test func closerPlayerWinsPickupWhenBothInRange() {
        var state = GameState.initial(config: possessionConfig)
        state.homePlayer.position = Vector2(x: 46, y: 25)
        state.awayPlayer.position = Vector2(x: 52, y: 25)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.01, inputs: [])

        #expect(engine.state.possession == .away)
    }

    // MARK: - Away shooting

    @Test func awayCPUShootsTowardHomeGoalWhenInRange() {
        var state = GameState.initial(config: possessionConfig)
        state.possession = .away
        state.awayPlayer.position = Vector2(x: 30, y: 25)
        state.homePlayer.position = Vector2(x: 75, y: 40)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.1, inputs: [])

        #expect(engine.state.possession == PuckPossession.none)
        #expect(engine.state.puck.velocity == Vector2(x: -40, y: 0))
    }

    @Test func awayCannotShootWithoutPossession() {
        var state = GameState.initial(config: possessionConfig)
        state.awayPlayer.position = Vector2(x: 30, y: 25)
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 0.5,
            inputs: [
                PlayerInput(
                    playerId: .away,
                    moveDirection: Vector2(x: 1, y: 0),
                    isShooting: true,
                    timestamp: 1
                )
            ]
        )

        #expect(engine.state.possession == PuckPossession.none)
        #expect(engine.state.puck.velocity == .zero)
        #expect(engine.state.puck.position == possessionConfig.rinkCenter)
    }

    // MARK: - Contest / steal

    @Test func homeStealsFromAwayWithinContestRadius() {
        var state = GameState.initial(config: possessionConfig)
        state.possession = .away
        state.awayPlayer.position = Vector2(x: 60, y: 25)
        state.homePlayer.position = Vector2(x: 58, y: 25)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.1, inputs: [])

        #expect(engine.state.possession == .home)
    }

    @Test func awayStealsFromHomeWithinContestRadius() {
        var state = GameState.initial(config: possessionConfig)
        state.possession = .home
        state.homePlayer.position = Vector2(x: 58, y: 25)
        state.awayPlayer.position = Vector2(x: 60, y: 25)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.1, inputs: [])

        #expect(engine.state.possession == .away)
    }

    @Test func homeDoesNotStealOutsideContestRadius() {
        var state = GameState.initial(config: possessionConfig)
        state.possession = .away
        state.awayPlayer.position = Vector2(x: 80, y: 25)
        state.homePlayer.position = Vector2(x: 40, y: 25)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.1, inputs: [])

        #expect(engine.state.possession == .away)
    }

    @Test func stealDoesNotImmediatelyFlipBack() {
        var state = GameState.initial(config: possessionConfig)
        state.possession = .home
        state.homePlayer.position = Vector2(x: 58, y: 25)
        state.awayPlayer.position = Vector2(x: 60, y: 25)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.1, inputs: [])
        #expect(engine.state.possession == .away)

        // Contest cooldown (0.5) blocks the counter-steal on the next frame.
        engine.update(deltaTime: 0.1, inputs: [])
        #expect(engine.state.possession == .away)
    }

    @Test func awayCPUDoesNotOverrideExplicitAwayInput() {
        var engine = GameEngine(state: .initial(config: possessionConfig))

        engine.update(
            deltaTime: 0.5,
            inputs: [
                PlayerInput(
                    playerId: .away,
                    moveDirection: Vector2(x: 1, y: 0),
                    timestamp: 1
                )
            ]
        )

        #expect(engine.state.awayPlayer.position == Vector2(x: 85, y: 25))
    }
}
