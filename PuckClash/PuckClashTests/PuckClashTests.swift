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
        puckStopSpeed: 0,
        // Phase-less: the engine tests below exercise the running match directly.
        // The match-phase tests use phaseConfig instead.
        openingCountdownDuration: 0,
        goalPauseDuration: 0
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
            puckStopSpeed: 5,
            openingCountdownDuration: 0,
            goalPauseDuration: 0
        )
    }

    // The same board as `config` but with the real match phases enabled
    // (3s opening countdown, 1s goal pause) for the match-flow tests.
    private var phaseConfig: MatchConfig {
        MatchConfig(
            rinkSize: Vector2(x: 100, y: 200),
            matchDuration: 10,
            strikerMaxSpeed: 1000,
            goalMouthHalfWidth: 20,
            strikerRadius: 10,
            puckRadius: 5,
            strikerHitRestitution: 1.0,
            wallRestitution: 1.0,
            puckDamping: 1.0,
            puckStopSpeed: 0,
            openingCountdownDuration: 3.0,
            goalPauseDuration: 1.0
        )
    }

    // MARK: - Initial state / layout

    @Test func initialStateUsesVerticalRinkAndPositions() {
        let state = GameState.initial(config: config)

        #expect(state.score == .zero)
        #expect(state.phase == .running) // countdown disabled in this config
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

    // MARK: - moveVector (joystick) input

    @Test func moveVectorMovesHomeStriker() {
        var engine = GameEngine(state: .initial(config: config))

        // Unit vector (0.6,-0.8); step = vector * strikerMaxSpeed(1000) * dt(0.01) = (6,-8).
        engine.update(
            deltaTime: 0.01,
            inputs: [PlayerInput(playerId: .home, moveVector: Vector2(x: 0.6, y: -0.8), timestamp: 1)]
        )

        #expect(engine.state.homePlayer.position == Vector2(x: 56, y: 32))
    }

    @Test func moveVectorMagnitudeIsClampedToOne() {
        var engine = GameEngine(state: .initial(config: config))

        // Magnitude 5 along +x is clamped to a unit vector, so step is 1000*0.01 = 10.
        engine.update(
            deltaTime: 0.01,
            inputs: [PlayerInput(playerId: .home, moveVector: Vector2(x: 5, y: 0), timestamp: 1)]
        )

        #expect(engine.state.homePlayer.position == Vector2(x: 60, y: 40))
    }

    @Test func moveVectorHomeStillClampsToLowerHalf() {
        var engine = GameEngine(state: .initial(config: config))

        // Push straight up hard; home is confined to the lower half (y <= 100).
        engine.update(
            deltaTime: 1,
            inputs: [PlayerInput(playerId: .home, moveVector: Vector2(x: 0, y: 1), timestamp: 1)]
        )

        #expect(engine.state.homePlayer.position.y <= config.rinkCenter.y)
    }

    @Test func moveVectorTakesPrecedenceOverTargetPosition() {
        var engine = GameEngine(state: .initial(config: config))

        // Both provided: moveVector (+x) wins, targetPosition (toward -y) is ignored.
        engine.update(
            deltaTime: 0.01,
            inputs: [
                PlayerInput(
                    playerId: .home,
                    moveVector: Vector2(x: 1, y: 0),
                    targetPosition: Vector2(x: 50, y: 10),
                    timestamp: 1
                )
            ]
        )

        #expect(engine.state.homePlayer.position == Vector2(x: 60, y: 40))
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

    @Test func leftWallReflects() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 5, y: 100)
        state.puck.velocity = Vector2(x: -10, y: 0)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        #expect(engine.state.score == .zero)
        #expect(engine.state.puck.position == Vector2(x: 5, y: 100))
        #expect(engine.state.puck.velocity == Vector2(x: 10, y: 0))
    }

    @Test func rightWallReflects() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 95, y: 100)
        state.puck.velocity = Vector2(x: 10, y: 0)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        // next.x = 105 mirrors to 2*100-105 = 95, x velocity flips.
        #expect(engine.state.score == .zero)
        #expect(engine.state.puck.position == Vector2(x: 95, y: 100))
        #expect(engine.state.puck.velocity == Vector2(x: -10, y: 0))
    }

    @Test func outsideBottomGoalMouthReflectsInsteadOfScoring() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 10, y: 10)
        state.puck.velocity = Vector2(x: 0, y: -20)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1, inputs: [])

        // x=10 is outside the mouth [30,70]: next.y = -10 mirrors to 10 and the
        // y velocity flips, so the puck reflects off the bottom wall, no goal.
        #expect(engine.state.score == .zero)
        #expect(engine.state.puck.position == Vector2(x: 10, y: 10))
        #expect(engine.state.puck.velocity == Vector2(x: 0, y: 20))
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

    // MARK: - Map definitions

    @Test func mapDefinitionsCoverAllIDs() {
        #expect(MapDefinition.all.count == 3)
        #expect(MapDefinition.all.map(\.id) == [.classic, .wide, .speed])
        #expect(Set(MapID.allCases) == Set(MapDefinition.all.map(\.id)))
    }

    @Test func mapDisplayNamesAreUnique() {
        let names = MapDefinition.all.map(\.displayName)
        #expect(Set(names).count == names.count)
    }

    @Test func classicMapMatchesStandardConfig() {
        #expect(MapDefinition.classic.config == MatchConfig.standard)
    }

    @Test func wideMapIsWiderThanClassic() {
        #expect(MapDefinition.wide.config.rinkSize.x > MapDefinition.classic.config.rinkSize.x)
    }

    @Test func speedMapIsFasterThanClassic() {
        #expect(MapDefinition.speed.config.strikerMaxSpeed > MapDefinition.classic.config.strikerMaxSpeed)
    }

    @Test func mapsAreSymmetricAroundCenter() {
        // The goal mouth is centered on every map, so neither side is favored.
        for map in MapDefinition.all {
            let config = map.config
            let leftGap = config.rinkCenter.x - config.goalMouthMinX
            let rightGap = config.goalMouthMaxX - config.rinkCenter.x
            #expect(leftGap == rightGap)
        }
    }

    // MARK: - LocalMatchSession

    @Test func localSessionAdvanceMatchesEngineUpdate() {
        // The session drains time in fixed steps: an advance of exactly one fixedDelta
        // runs exactly one GameEngine step, matching a bare engine stepped the same way.
        let move = Vector2(x: 0.6, y: -0.8)
        let fixedDelta = 1.0 / config.tickRate
        let session = LocalMatchSession(config: config)
        session.setHomeInput(moveVector: move)
        var engine = GameEngine(state: .initial(config: config))

        for _ in 0..<5 {
            let snapshot = session.advance(deltaTime: fixedDelta)
            engine.update(deltaTime: fixedDelta, inputs: [PlayerInput(playerId: .home, moveVector: move)])
            #expect(snapshot.state == engine.state)
        }
    }

    @Test func setHomeInputMovesHomeStriker() {
        let session = LocalMatchSession(config: config)
        let fixedDelta = 1.0 / config.tickRate
        let start = session.state.homePlayer.position

        session.setHomeInput(moveVector: Vector2(x: 1, y: 0))
        session.advance(deltaTime: fixedDelta)

        // One fixed step moves home to the right (by strikerMaxSpeed * fixedDelta),
        // with the y coordinate unchanged. Exact distance is left to the engine tests.
        #expect(session.state.homePlayer.position.x > start.x)
        #expect(session.state.homePlayer.position.y == start.y)
    }

    @Test func zeroOrNilHomeInputKeepsHomeStrikerPut() {
        let session = LocalMatchSession(config: config)
        let start = session.state.homePlayer.position

        session.setHomeInput(moveVector: .zero)
        session.advance(deltaTime: 0.1)
        #expect(session.state.homePlayer.position == start)

        session.setHomeInput(moveVector: nil)
        session.advance(deltaTime: 0.1)
        #expect(session.state.homePlayer.position == start)
    }

    @Test func awayCPURunsThroughSessionWithoutHomeInput() {
        // Strike the puck up into the away half for a few frames, then release home
        // input entirely. The away CPU must still run (move) and must match a bare
        // GameEngine step for step, proving it lives inside the session's engine.
        let fixedDelta = 1.0 / config.tickRate
        let session = LocalMatchSession(config: config)
        var engine = GameEngine(state: .initial(config: config))
        let up = Vector2(x: 0, y: 1)

        var awayMoved = false
        for frame in 0..<60 {
            let homeInput: [PlayerInput]
            if frame < 6 {
                session.setHomeInput(moveVector: up)
                homeInput = [PlayerInput(playerId: .home, moveVector: up)]
            } else {
                session.setHomeInput(moveVector: nil)
                homeInput = []
            }

            let snapshot = session.advance(deltaTime: fixedDelta)
            engine.update(deltaTime: fixedDelta, inputs: homeInput)
            #expect(snapshot.state == engine.state)

            if snapshot.state.awayPlayer.position != config.awayStartPosition {
                awayMoved = true
            }
        }

        #expect(awayMoved)
    }

    @Test func localSessionFinishesAtTimeLimit() {
        let session = LocalMatchSession(config: config)
        let fixedDelta = 1.0 / config.tickRate

        // matchDuration is 10; one big delta only runs maxCatchUpSteps, so step the
        // session forward until the clock runs out (with a safety bound on the loop).
        var guardCount = 0
        while session.state.phase != .finished, guardCount < 10_000 {
            session.advance(deltaTime: fixedDelta)
            guardCount += 1
        }

        #expect(session.state.phase == .finished)
        #expect(session.state.remainingTime == 0)
    }

    @Test func localSessionKeepsProvidedConfig() {
        let session = LocalMatchSession(config: MapDefinition.wide.config)

        #expect(session.config == MapDefinition.wide.config)
        #expect(session.state.config == MapDefinition.wide.config)
    }

    // MARK: - Fixed-step accumulator

    @Test func standardConfigUsesSixtyHzTickRate() {
        #expect(MatchConfig.standard.tickRate == 60)
        // Every selectable map must carry a usable (positive) tick rate.
        for map in MapDefinition.all {
            #expect(map.config.tickRate > 0)
        }
    }

    @Test func advanceShorterThanOneStepRunsNoStepButCarriesOver() {
        let fixedDelta = 1.0 / config.tickRate
        let session = LocalMatchSession(config: config)
        let start = session.state

        // Half a step: nothing simulates yet, and the state is untouched.
        session.advance(deltaTime: fixedDelta * 0.5)
        #expect(session.state == start)

        // A second half step completes exactly one step's worth of carried-over time,
        // so precisely one engine step runs.
        session.advance(deltaTime: fixedDelta * 0.5)
        var engine = GameEngine(state: .initial(config: config))
        engine.update(deltaTime: fixedDelta, inputs: [])
        #expect(session.state == engine.state)
    }

    @Test func advanceOfOneStepRunsExactlyOneEngineStep() {
        let fixedDelta = 1.0 / config.tickRate
        let session = LocalMatchSession(config: config)

        session.advance(deltaTime: fixedDelta)

        var engine = GameEngine(state: .initial(config: config))
        engine.update(deltaTime: fixedDelta, inputs: [])
        #expect(session.state == engine.state)
    }

    @Test func advanceOfSeveralStepsRunsThatManyEngineSteps() {
        let fixedDelta = 1.0 / config.tickRate
        let session = LocalMatchSession(config: config)

        // 3.5 steps of time drains exactly 3 whole steps (0.5 carried over). Using a
        // non-integer multiple avoids a floating-point boundary at exactly 3 steps.
        session.advance(deltaTime: fixedDelta * 3.5)

        var engine = GameEngine(state: .initial(config: config))
        for _ in 0..<3 {
            engine.update(deltaTime: fixedDelta, inputs: [])
        }
        #expect(session.state == engine.state)
    }

    @Test func catchUpIsBoundedAndBacklogDropped() {
        let fixedDelta = 1.0 / config.tickRate
        let session = LocalMatchSession(config: config)

        // A huge delta must run at most maxCatchUpSteps (5), not hundreds of steps.
        session.advance(deltaTime: 100)

        var engine = GameEngine(state: .initial(config: config))
        for _ in 0..<5 {
            engine.update(deltaTime: fixedDelta, inputs: [])
        }
        #expect(session.state == engine.state)

        // Backlog beyond the cap is dropped, so a following zero delta runs no steps.
        let afterCap = session.state
        session.advance(deltaTime: 0)
        #expect(session.state == afterCap)
    }

    // MARK: - MatchSnapshot

    @Test func matchSnapshotHoldsFieldsAndIsEquatable() {
        let state = GameState.initial(config: config)
        let snapshot = MatchSnapshot(tick: 7, state: state, isAuthoritative: true)

        #expect(snapshot.tick == 7)
        #expect(snapshot.state == state)
        #expect(snapshot.isAuthoritative)

        #expect(snapshot == MatchSnapshot(tick: 7, state: state, isAuthoritative: true))
        #expect(snapshot != MatchSnapshot(tick: 8, state: state, isAuthoritative: true))
        #expect(snapshot != MatchSnapshot(tick: 7, state: state, isAuthoritative: false))
    }

    @Test func localSessionInitialSnapshotHasZeroTickAndIsAuthoritative() {
        let fixedDelta = 1.0 / config.tickRate
        let session = LocalMatchSession(config: config)

        // A sub-step advance runs no engine step: tick stays 0, state is the initial one.
        let snapshot = session.advance(deltaTime: fixedDelta * 0.5)

        #expect(snapshot.tick == 0)
        #expect(snapshot.isAuthoritative)
        #expect(snapshot.state == session.state)
    }

    @Test func localSessionSnapshotTickAdvancesByOneStep() {
        let fixedDelta = 1.0 / config.tickRate
        let session = LocalMatchSession(config: config)

        let snapshot = session.advance(deltaTime: fixedDelta)

        var engine = GameEngine(state: .initial(config: config))
        engine.update(deltaTime: fixedDelta, inputs: [])
        #expect(snapshot.tick == 1)
        #expect(snapshot.state == engine.state)
        #expect(snapshot.isAuthoritative)
    }

    @Test func localSessionSnapshotTickAdvancesByStepCount() {
        let fixedDelta = 1.0 / config.tickRate
        let session = LocalMatchSession(config: config)

        // 3.5 steps of time runs exactly 3 whole steps (avoids the exact-boundary case).
        let snapshot = session.advance(deltaTime: fixedDelta * 3.5)

        var engine = GameEngine(state: .initial(config: config))
        for _ in 0..<3 {
            engine.update(deltaTime: fixedDelta, inputs: [])
        }
        #expect(snapshot.tick == 3)
        #expect(snapshot.state == engine.state)
    }

    @Test func localSessionSnapshotTickCarriesOverAcrossSubStepAdvances() {
        let fixedDelta = 1.0 / config.tickRate
        let session = LocalMatchSession(config: config)

        let first = session.advance(deltaTime: fixedDelta * 0.5)
        #expect(first.tick == 0)

        // The carried-over half plus another half completes exactly one step: tick -> 1.
        let second = session.advance(deltaTime: fixedDelta * 0.5)
        #expect(second.tick == 1)
    }

    @Test func localSessionSnapshotTickIsBoundedByCatchUpCap() {
        let session = LocalMatchSession(config: config)

        // A huge delta runs at most maxCatchUpSteps (5): tick advances by exactly 5.
        let capped = session.advance(deltaTime: 100)
        #expect(capped.tick == 5)

        // Backlog beyond the cap is dropped, so a following zero delta runs no step
        // and the tick does not move.
        let after = session.advance(deltaTime: 0)
        #expect(after.tick == 5)
        #expect(after.state == capped.state)
    }

    // MARK: - Determinism (regression net for future fixed-tick work)

    // A fixed script of (deltaTime, home moveVector) steps that exercises home
    // movement, striker/puck collision, puck travel and the away CPU chase. These
    // tests never assert hand-written physics values — they assert that identical
    // inputs produce identical GameStates, locking in that GameEngine.update is a
    // pure function of (state, inputs, deltaTime). Total scripted time (~0.95s)
    // stays under matchDuration so the match keeps running.
    private var determinismScript: [(dt: Double, home: Vector2?)] {
        [
            (0.10, Vector2(x: 0, y: 1)),
            (0.10, Vector2(x: 0, y: 1)),
            (0.05, Vector2(x: 1, y: 0.2)),
            (0.05, Vector2(x: -0.5, y: 0.8)),
            (0.10, nil),
            (0.10, Vector2(x: 0.3, y: -0.4)),
            (0.20, Vector2(x: -1, y: 0)),
            (0.05, nil),
            (0.10, Vector2(x: 0, y: 1)),
            (0.10, Vector2(x: 0.6, y: 0.6)),
        ]
    }

    private func homeInputs(_ moveVector: Vector2?) -> [PlayerInput] {
        guard let moveVector else {
            return []
        }
        return [PlayerInput(playerId: .home, moveVector: moveVector, timestamp: 1)]
    }

    @Test func repeatedSimulationYieldsIdenticalFinalState() {
        func runToEnd() -> GameState {
            var engine = GameEngine(state: .initial(config: config))
            for step in determinismScript {
                engine.update(deltaTime: step.dt, inputs: homeInputs(step.home))
            }
            return engine.state
        }

        // Same initial state + same script, run twice, must land on the same state.
        #expect(runToEnd() == runToEnd())
    }

    @Test func independentEnginesAgreeAtEveryStep() {
        var engineA = GameEngine(state: .initial(config: config))
        var engineB = GameEngine(state: .initial(config: config))

        for step in determinismScript {
            let inputs = homeInputs(step.home)
            engineA.update(deltaTime: step.dt, inputs: inputs)
            engineB.update(deltaTime: step.dt, inputs: inputs)
            #expect(engineA.state == engineB.state)
        }
    }

    @Test func cpuOnlySimulationIsDeterministic() {
        // Start the puck inside the away half sliding sideways, so that with no home
        // input the puck travels and the away CPU actively chases it; the whole
        // trajectory (away / puck / score / timer) must be reproducible run to run.
        var initial = GameState.initial(config: frictionConfig)
        initial.puck.position = Vector2(x: 30, y: 150)
        initial.puck.velocity = Vector2(x: 60, y: 0)
        let deltas: [Double] = [0.05, 0.05, 0.10, 0.10, 0.05, 0.10, 0.20, 0.05, 0.10, 0.10]

        func run() -> [GameState] {
            var engine = GameEngine(state: initial)
            var states: [GameState] = []
            for dt in deltas {
                engine.update(deltaTime: dt, inputs: [])
                states.append(engine.state)
            }
            return states
        }

        let first = run()
        let second = run()
        #expect(first == second)

        // Guard against a vacuous pass: confirm the away CPU was actually exercised
        // (it moved off its start at some frame), so this is a live simulation and
        // not a trivially-constant state. The puck may drift back by the last frame,
        // so check the whole trajectory rather than only the final state.
        #expect(first.contains { $0.awayPlayer.position != initial.awayPlayer.position })
    }

    // MARK: - OnlineMatchSession (skeleton, no real networking)

    // In-memory stand-in for a real transport: records what was sent and lets a test
    // push server snapshots into the session via `emit`.
    private final class MockTransport: MatchTransport {
        private(set) var sendCount = 0
        private(set) var lastSentMoveVector: Vector2?
        private(set) var lastSentTick: Int?
        var onSnapshot: ((MatchSnapshot) -> Void)?
        var onDisconnect: (() -> Void)?

        func sendHomeInput(moveVector: Vector2?, tick: Int) {
            sendCount += 1
            lastSentMoveVector = moveVector
            lastSentTick = tick
        }

        // Simulate the server pushing an authoritative snapshot to the client.
        func emit(_ snapshot: MatchSnapshot) {
            onSnapshot?(snapshot)
        }
    }

    @Test func onlineSessionFallsBackToInitialSnapshotBeforeReceivingServerSnapshot() {
        let transport = MockTransport()
        let session = OnlineMatchSession(config: config, transport: transport)

        let snapshot = session.advance(deltaTime: 0.1)
        #expect(snapshot.tick == 0)
        #expect(snapshot.state == GameState.initial(config: config))
        #expect(snapshot.isAuthoritative)
    }

    @Test func onlineSessionReturnsInjectedSnapshot() {
        let transport = MockTransport()
        let session = OnlineMatchSession(config: config, transport: transport)

        var injected = GameState.initial(config: config)
        injected.score.home = 2
        injected.puck.position = Vector2(x: 10, y: 20)
        let serverSnapshot = MatchSnapshot(tick: 42, state: injected, isAuthoritative: true)
        transport.emit(serverSnapshot)

        #expect(session.advance(deltaTime: 0.016) == serverSnapshot)
        #expect(session.state == injected)
    }

    @Test func onlineSessionForwardsHomeInputToTransport() {
        let transport = MockTransport()
        let session = OnlineMatchSession(config: config, transport: transport)

        // Establish a server tick so the forwarded input carries it.
        transport.emit(MatchSnapshot(tick: 9, state: .initial(config: config), isAuthoritative: true))

        let move = Vector2(x: 0.6, y: -0.8)
        session.setHomeInput(moveVector: move)
        #expect(transport.sendCount == 1)
        #expect(transport.lastSentMoveVector == move)
        #expect(transport.lastSentTick == 9)

        // A released / zero stick is normalized to "no input", like LocalMatchSession.
        session.setHomeInput(moveVector: .zero)
        #expect(transport.lastSentMoveVector == nil)
    }

    @Test func onlineSessionKeepsProvidedConfig() {
        let transport = MockTransport()
        let session = OnlineMatchSession(config: MapDefinition.wide.config, transport: transport)

        #expect(session.config == MapDefinition.wide.config)
        #expect(session.state.config == MapDefinition.wide.config)
    }

    @Test func onlineSessionDoesNotAdvanceLocalPhysics() {
        let transport = MockTransport()
        let session = OnlineMatchSession(config: config, transport: transport)

        // No server snapshot yet: repeated advances never move the state or tick.
        let a = session.advance(deltaTime: 0.1)
        let b = session.advance(deltaTime: 5)
        #expect(a == b)
        #expect(b.tick == 0)

        // After one snapshot, further advances keep returning it — no local stepping.
        let server = MatchSnapshot(tick: 3, state: .initial(config: config), isAuthoritative: true)
        transport.emit(server)
        #expect(session.advance(deltaTime: 0.1) == server)
        #expect(session.advance(deltaTime: 0.1) == server)
    }

    // MARK: - Boost skill

    @Test func boostIncreasesHomeStrikerSpeed() {
        let start = GameState.initial(config: config).homePlayer.position.x
        let move = Vector2(x: 1, y: 0)

        var plain = GameEngine(state: .initial(config: config))
        plain.update(deltaTime: 0.01, inputs: [PlayerInput(playerId: .home, moveVector: move)])

        var boosted = GameEngine(state: .initial(config: config))
        boosted.update(
            deltaTime: 0.01,
            inputs: [PlayerInput(playerId: .home, moveVector: move, activatedSkills: [.boost])]
        )

        let plainStep = plain.state.homePlayer.position.x - start
        let boostedStep = boosted.state.homePlayer.position.x - start
        #expect(boostedStep > plainStep)
        #expect(boostedStep == plainStep * config.boost.speedMultiplier)
        #expect(boosted.state.homeBoost.phase == .active)
    }

    @Test func boostSpeedReturnsToNormalAfterDuration() {
        var engine = GameEngine(state: .initial(config: config))
        // Activate, then run past the active window (no movement) so it enters cooldown.
        engine.update(deltaTime: 0.5, inputs: [PlayerInput(playerId: .home, activatedSkills: [.boost])])
        engine.update(deltaTime: config.boost.duration, inputs: [])
        #expect(engine.state.homeBoost.phase == .cooldown)

        // A move step now runs at normal speed (1000 * 0.01 = 10), not boosted.
        let before = engine.state.homePlayer.position.x
        engine.update(deltaTime: 0.01, inputs: [PlayerInput(playerId: .home, moveVector: Vector2(x: 1, y: 0))])
        #expect(engine.state.homePlayer.position.x - before == 10)
    }

    @Test func boostCannotReactivateDuringCooldown() {
        var engine = GameEngine(state: .initial(config: config))
        // One long step drives the boost through its active window into cooldown.
        engine.update(
            deltaTime: config.boost.duration + 0.5,
            inputs: [PlayerInput(playerId: .home, activatedSkills: [.boost])]
        )
        #expect(engine.state.homeBoost.phase == .cooldown)

        let before = engine.state.homePlayer.position.x
        engine.update(
            deltaTime: 0.01,
            inputs: [PlayerInput(playerId: .home, moveVector: Vector2(x: 1, y: 0), activatedSkills: [.boost])]
        )
        // Re-activation is ignored on cooldown, so the step is normal speed.
        #expect(engine.state.homePlayer.position.x - before == 10)
        #expect(engine.state.homeBoost.phase == .cooldown)
    }

    @Test func boostReactivatesAfterCooldown() {
        let start = GameState.initial(config: config).homePlayer.position.x
        var engine = GameEngine(state: .initial(config: config))
        // Active window -> cooldown, then let the cooldown fully elapse -> ready.
        engine.update(
            deltaTime: config.boost.duration,
            inputs: [PlayerInput(playerId: .home, activatedSkills: [.boost])]
        )
        engine.update(deltaTime: config.boost.cooldown, inputs: [])
        #expect(engine.state.homeBoost.phase == .ready)

        let before = engine.state.homePlayer.position.x
        engine.update(
            deltaTime: 0.01,
            inputs: [PlayerInput(playerId: .home, moveVector: Vector2(x: 1, y: 0), activatedSkills: [.boost])]
        )
        // Boosted again: 1000 * 1.6 * 0.01 = 16.
        #expect(engine.state.homePlayer.position.x - before == 16)
        #expect(before == start) // it never moved before this step
    }

    @Test func boostDoesNotActivateAfterMatchEnds() {
        var engine = GameEngine(state: .initial(config: config))
        engine.update(deltaTime: 12, inputs: []) // matchDuration is 10 -> finished
        #expect(engine.state.phase == .finished)

        let before = engine.state.homePlayer.position
        engine.update(
            deltaTime: 0.01,
            inputs: [PlayerInput(playerId: .home, moveVector: Vector2(x: 1, y: 0), activatedSkills: [.boost])]
        )
        #expect(engine.state.homeBoost.phase == .ready)
        #expect(engine.state.homePlayer.position == before)
    }

    @Test func repeatedBoostInputDoesNotResetDuration() {
        var engine = GameEngine(state: .initial(config: config))
        engine.update(deltaTime: 0.5, inputs: [PlayerInput(playerId: .home, activatedSkills: [.boost])])
        #expect(engine.state.homeBoost.activeRemaining == config.boost.duration - 0.5)

        // A second activation while still active must not refill the active window.
        engine.update(deltaTime: 0.5, inputs: [PlayerInput(playerId: .home, activatedSkills: [.boost])])
        #expect(engine.state.homeBoost.activeRemaining == config.boost.duration - 1.0)
    }

    @Test func localSessionActivatesBoostOnNextAdvance() {
        let session = LocalMatchSession(config: config)
        let fixedDelta = 1.0 / config.tickRate

        session.activateHomeSkill(.boost)
        let snapshot = session.advance(deltaTime: fixedDelta)

        #expect(snapshot.state.homeBoost.phase == .active)
        #expect(snapshot.state.homeBoost.activeRemaining > 0)
    }

    @Test func localSessionCarriesBoostActivationAcrossSubStepAdvance() {
        let session = LocalMatchSession(config: config)
        let fixedDelta = 1.0 / config.tickRate

        session.activateHomeSkill(.boost)
        // Sub-step advance runs no fixed step: the activation must wait, not fire.
        let s1 = session.advance(deltaTime: fixedDelta * 0.5)
        #expect(s1.state.homeBoost.phase == .ready)

        // Completing the step consumes the still-pending activation.
        let s2 = session.advance(deltaTime: fixedDelta * 0.5)
        #expect(s2.state.homeBoost.phase == .active)
    }

    @Test func localSessionBoostFiresOnceAcrossCatchUp() {
        let session = LocalMatchSession(config: config)
        let fixedDelta = 1.0 / config.tickRate

        session.activateHomeSkill(.boost)
        // A large delta drains several fixed steps in one advance; boost must fire on
        // the first step only and then just tick down (not re-fire each step).
        let snapshot = session.advance(deltaTime: fixedDelta * 4)

        #expect(snapshot.state.homeBoost.phase == .active)
        let expected = config.boost.duration - 4 * fixedDelta
        #expect(abs(snapshot.state.homeBoost.activeRemaining - expected) < 1e-9)
    }

    // MARK: - Shot skill

    @Test func shotActivationArmsShot() {
        var engine = GameEngine(state: .initial(config: config))
        engine.update(deltaTime: 0.01, inputs: [PlayerInput(playerId: .home, activatedSkills: [.shot])])
        #expect(engine.state.homeShot.phase == .active)
        #expect(engine.state.homeShot.activeRemaining > 0)
    }

    @Test func armedShotHitsPuckHarder() {
        // Same striker-into-puck collision, with and without an armed Shot.
        func puckVelocityYAfterHit(withShot: Bool) -> Double {
            var state = GameState.initial(config: config)
            state.homePlayer.position = Vector2(x: 50, y: 80)
            var engine = GameEngine(state: state)
            let skills: Set<SkillID> = withShot ? [.shot] : []
            engine.update(
                deltaTime: 0.1,
                inputs: [PlayerInput(playerId: .home, targetPosition: Vector2(x: 50, y: 100), activatedSkills: skills, timestamp: 1)]
            )
            return engine.state.puck.velocity.y
        }

        let plain = puckVelocityYAfterHit(withShot: false)
        let shot = puckVelocityYAfterHit(withShot: true)
        #expect(shot > plain)
        // The armed hit scales the impulse by exactly speedMultiplier (400 -> 720).
        #expect(shot == plain * config.shot.speedMultiplier)
    }

    @Test func shotIsConsumedOnHitAndEntersCooldown() {
        var state = GameState.initial(config: config)
        state.homePlayer.position = Vector2(x: 50, y: 80)
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 0.1,
            inputs: [PlayerInput(playerId: .home, targetPosition: Vector2(x: 50, y: 100), activatedSkills: [.shot], timestamp: 1)]
        )

        // The single hit consumed the armed shot: window is zeroed and it is on cooldown.
        #expect(engine.state.homeShot.phase == .cooldown)
        #expect(engine.state.homeShot.activeRemaining == 0)
    }

    @Test func shotCannotReactivateDuringCooldown() {
        var engine = GameEngine(state: .initial(config: config))
        // Arm it, then let the window elapse unused so it drops to cooldown.
        engine.update(
            deltaTime: config.shot.activeDuration + 0.5,
            inputs: [PlayerInput(playerId: .home, activatedSkills: [.shot])]
        )
        #expect(engine.state.homeShot.phase == .cooldown)
        let cooldownBefore = engine.state.homeShot.cooldownRemaining

        // A re-activation request on cooldown is ignored; it stays on cooldown, still ticking.
        engine.update(deltaTime: 0.01, inputs: [PlayerInput(playerId: .home, activatedSkills: [.shot])])
        #expect(engine.state.homeShot.phase == .cooldown)
        #expect(engine.state.homeShot.cooldownRemaining < cooldownBefore)
    }

    @Test func shotReactivatesAfterCooldown() {
        var engine = GameEngine(state: .initial(config: config))
        // Armed window straight into cooldown, then let the cooldown fully elapse -> ready.
        engine.update(
            deltaTime: config.shot.activeDuration,
            inputs: [PlayerInput(playerId: .home, activatedSkills: [.shot])]
        )
        engine.update(deltaTime: config.shot.cooldown, inputs: [])
        #expect(engine.state.homeShot.phase == .ready)

        engine.update(deltaTime: 0.01, inputs: [PlayerInput(playerId: .home, activatedSkills: [.shot])])
        #expect(engine.state.homeShot.phase == .active)
    }

    @Test func shotWhiffEntersCooldownAfterDuration() {
        var engine = GameEngine(state: .initial(config: config))
        engine.update(deltaTime: 0.5, inputs: [PlayerInput(playerId: .home, activatedSkills: [.shot])])
        #expect(engine.state.homeShot.phase == .active)

        // No collision happens; once the armed window elapses it enters cooldown.
        engine.update(deltaTime: config.shot.activeDuration, inputs: [])
        #expect(engine.state.homeShot.phase == .cooldown)
    }

    @Test func shotDoesNotActivateAfterMatchEnds() {
        var engine = GameEngine(state: .initial(config: config))
        engine.update(deltaTime: 12, inputs: []) // matchDuration is 10 -> finished
        #expect(engine.state.phase == .finished)

        engine.update(deltaTime: 0.01, inputs: [PlayerInput(playerId: .home, activatedSkills: [.shot])])
        #expect(engine.state.homeShot.phase == .ready)
    }

    @Test func shotIsNotConsumedByNonImpulseOverlap() {
        var state = GameState.initial(config: config)
        // Striker and puck overlap, but the puck is separating (moving away): no impulse.
        state.homePlayer.position = Vector2(x: 50, y: 100)
        state.puck.position = Vector2(x: 50, y: 110)
        state.puck.velocity = Vector2(x: 0, y: 60)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.01, inputs: [PlayerInput(playerId: .home, activatedSkills: [.shot])])

        // The non-closing contact must not consume the shot; it stays armed.
        #expect(engine.state.homeShot.phase == .active)
    }

    @Test func localSessionActivatesShotOnNextAdvance() {
        let session = LocalMatchSession(config: config)
        let fixedDelta = 1.0 / config.tickRate

        session.activateHomeSkill(.shot)
        let snapshot = session.advance(deltaTime: fixedDelta)

        #expect(snapshot.state.homeShot.phase == .active)
        #expect(snapshot.state.homeShot.activeRemaining > 0)
    }

    @Test func localSessionShotFiresOnceAcrossCatchUp() {
        let session = LocalMatchSession(config: config)
        let fixedDelta = 1.0 / config.tickRate

        session.activateHomeSkill(.shot)
        // Several fixed steps drain in one advance; shot must arm on the first step only
        // and then just tick down, not re-arm each step.
        let snapshot = session.advance(deltaTime: fixedDelta * 4)

        #expect(snapshot.state.homeShot.phase == .active)
        let expected = config.shot.activeDuration - 4 * fixedDelta
        #expect(abs(snapshot.state.homeShot.activeRemaining - expected) < 1e-9)
    }

    @Test func blockActivationDoesNotAffectBoostOrShot() {
        var engine = GameEngine(state: .initial(config: config))
        // Activating Block raises its own shield without touching Boost or Shot.
        engine.update(
            deltaTime: 0.5,
            inputs: [PlayerInput(playerId: .home, moveVector: Vector2(x: 1, y: 0), activatedSkills: [.block])]
        )
        #expect(engine.state.homeBlock.phase == .active)
        #expect(engine.state.homeBoost.phase == .ready)
        #expect(engine.state.homeShot.phase == .ready)
    }

    // MARK: - Block skill

    @Test func blockActivationActivatesShield() {
        var engine = GameEngine(state: .initial(config: config))
        engine.update(deltaTime: 0.01, inputs: [PlayerInput(playerId: .home, activatedSkills: [.block])])
        #expect(engine.state.homeBlock.phase == .active)
        #expect(engine.state.homeBlock.activeRemaining > 0)
    }

    @Test func blockDurationEntersCooldown() {
        var engine = GameEngine(state: .initial(config: config))
        engine.update(deltaTime: 0.5, inputs: [PlayerInput(playerId: .home, activatedSkills: [.block])])
        #expect(engine.state.homeBlock.phase == .active)
        engine.update(deltaTime: config.block.duration, inputs: [])
        #expect(engine.state.homeBlock.phase == .cooldown)
    }

    @Test func blockCannotReactivateDuringCooldown() {
        var engine = GameEngine(state: .initial(config: config))
        engine.update(
            deltaTime: config.block.duration + 0.5,
            inputs: [PlayerInput(playerId: .home, activatedSkills: [.block])]
        )
        #expect(engine.state.homeBlock.phase == .cooldown)
        let before = engine.state.homeBlock.cooldownRemaining

        engine.update(deltaTime: 0.01, inputs: [PlayerInput(playerId: .home, activatedSkills: [.block])])
        #expect(engine.state.homeBlock.phase == .cooldown)
        #expect(engine.state.homeBlock.cooldownRemaining < before)
    }

    @Test func blockReactivatesAfterCooldown() {
        var engine = GameEngine(state: .initial(config: config))
        engine.update(
            deltaTime: config.block.duration,
            inputs: [PlayerInput(playerId: .home, activatedSkills: [.block])]
        )
        engine.update(deltaTime: config.block.cooldown, inputs: [])
        #expect(engine.state.homeBlock.phase == .ready)

        engine.update(deltaTime: 0.01, inputs: [PlayerInput(playerId: .home, activatedSkills: [.block])])
        #expect(engine.state.homeBlock.phase == .active)
    }

    @Test func blockDoesNotActivateAfterMatchEnds() {
        var engine = GameEngine(state: .initial(config: config))
        engine.update(deltaTime: 12, inputs: []) // matchDuration is 10 -> finished
        #expect(engine.state.phase == .finished)

        engine.update(deltaTime: 0.01, inputs: [PlayerInput(playerId: .home, activatedSkills: [.block])])
        #expect(engine.state.homeBlock.phase == .ready)
    }

    @Test func activeBlockReflectsPuckBeforeBottomGoal() {
        // Puck heading down through the goal mouth; shield line is offsetFromGoal
        // (puckRadius * 4 = 20) spanning the mouth [30, 70].
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 25)
        state.puck.velocity = Vector2(x: 0, y: -600)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.05, inputs: [PlayerInput(playerId: .home, activatedSkills: [.block])])

        #expect(engine.state.homeBlock.phase == .active)
        #expect(engine.state.puck.velocity.y > 0) // reflected upward
        #expect(engine.state.score.away == 0) // no goal
    }

    @Test func withoutBlockSamePuckScoresAtBottom() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 25)
        state.puck.velocity = Vector2(x: 0, y: -600)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.05, inputs: []) // no Block

        #expect(engine.state.score.away == 1)
    }

    @Test func blockDoesNotReflectPuckOutsideMouth() {
        // x well outside the goal mouth / shield span: Block must not catch it; the puck
        // passes the shield line and bounces off the bottom wall instead (ends below 20).
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 10, y: 25)
        state.puck.velocity = Vector2(x: 0, y: -600)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.05, inputs: [PlayerInput(playerId: .home, activatedSkills: [.block])])

        #expect(engine.state.homeBlock.phase == .active)
        #expect(engine.state.puck.position.y < 20)
    }

    @Test func homeBlockDoesNotReflectUpwardPuck() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 15)
        state.puck.velocity = Vector2(x: 0, y: 300)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.05, inputs: [PlayerInput(playerId: .home, activatedSkills: [.block])])

        // An upward puck passes the home shield untouched.
        #expect(engine.state.puck.velocity.y > 0)
        #expect(engine.state.puck.position.y > 15)
    }

    @Test func homeBlockDoesNotBlockHomeScoringAtTop() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 190)
        state.puck.velocity = Vector2(x: 0, y: 600)
        var engine = GameEngine(state: state)

        // Park the away striker out of the puck's path so it does not intercept.
        engine.update(
            deltaTime: 0.05,
            inputs: [
                PlayerInput(playerId: .home, activatedSkills: [.block]),
                PlayerInput(playerId: .away, targetPosition: Vector2(x: 10, y: 160), timestamp: 1)
            ]
        )

        #expect(engine.state.score.home == 1)
    }

    @Test func activeBlockReflectsHighSpeedPuck() {
        // A Shot-speed puck that would tunnel a naive thin-bar check: the crossing test
        // still catches it at the shield line.
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 22)
        state.puck.velocity = Vector2(x: 0, y: -3000)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.05, inputs: [PlayerInput(playerId: .home, activatedSkills: [.block])])

        #expect(engine.state.puck.velocity.y > 0)
        #expect(engine.state.score.away == 0)
    }

    @Test func localSessionActivatesBlockOnNextAdvance() {
        let session = LocalMatchSession(config: config)
        let fixedDelta = 1.0 / config.tickRate

        session.activateHomeSkill(.block)
        let snapshot = session.advance(deltaTime: fixedDelta)

        #expect(snapshot.state.homeBlock.phase == .active)
        #expect(snapshot.state.homeBlock.activeRemaining > 0)
    }

    @Test func localSessionBlockFiresOnceAcrossCatchUp() {
        let session = LocalMatchSession(config: config)
        let fixedDelta = 1.0 / config.tickRate

        session.activateHomeSkill(.block)
        let snapshot = session.advance(deltaTime: fixedDelta * 4)

        #expect(snapshot.state.homeBlock.phase == .active)
        let expected = config.block.duration - 4 * fixedDelta
        #expect(abs(snapshot.state.homeBlock.activeRemaining - expected) < 1e-9)
    }

    // MARK: - Away CPU skill decisions

    // With the test config (Normal CPU): away shield line y = 200 - puckRadius*4 = 180;
    // goal mouth x in [30, 70]; Shot contact range = 10 + 5 + 5*1.35 = 21.75; Boost far
    // threshold = 200 * 0.38 = 76; Block reaction window 0.27s. awaySkillDecisionRemaining
    // starts at 0, so the first CPU-driven update is a decision tick. deltaTime 0.001
    // keeps strikers from reaching the puck within the asserted tick.

    @Test func cpuBlockActivatesAgainstPuckAimedAtTopGoalMouth() {
        var state = GameState.initial(config: config)
        state.awayPlayer.position = Vector2(x: 10, y: 190) // out of the puck's path
        state.puck.position = Vector2(x: 50, y: 150)
        state.puck.velocity = Vector2(x: 0, y: 200) // crosses y=180 in 0.15s at x=50 (in mouth)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.001, inputs: [])

        #expect(engine.state.awayBlock.phase == .active)
        #expect(engine.state.awayShot.phase == .ready)
        #expect(engine.state.awayBoost.phase == .ready)
    }

    @Test func cpuBlockDoesNotActivateWhenPredictionMissesGoalMouth() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 10, y: 150)
        state.puck.velocity = Vector2(x: 0, y: 200) // reaches the shield line at x=10, outside [30,70]
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.001, inputs: [])

        #expect(engine.state.awayBlock.phase == .ready)
        #expect(engine.state.awayShot.phase == .ready)
        #expect(engine.state.awayBoost.phase == .ready)
    }

    @Test func cpuBlockDoesNotActivateOncePuckIsPastShieldLine() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 185) // already beyond the shield line (180)
        state.puck.velocity = Vector2(x: 0, y: 200)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.001, inputs: [])

        #expect(engine.state.awayBlock.phase == .ready)
        #expect(engine.state.awayShot.phase == .ready)
        #expect(engine.state.awayBoost.phase == .ready)
    }

    @Test func cpuBlockDoesNotActivateForDownwardOrStationaryPuck() {
        for velocity in [Vector2(x: 0, y: -50), Vector2.zero] {
            var state = GameState.initial(config: config)
            state.puck.position = Vector2(x: 50, y: 120) // in the mouth column, but not incoming
            state.puck.velocity = velocity
            var engine = GameEngine(state: state)

            engine.update(deltaTime: 0.001, inputs: [])

            #expect(engine.state.awayBlock.phase == .ready)
            #expect(engine.state.awayShot.phase == .ready)
            #expect(engine.state.awayBoost.phase == .ready)
        }
    }

    @Test func cpuShotActivatesWhenPuckCloseAndBelowStriker() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 140) // distance 20 <= 21.75, striker above
        state.puck.velocity = .zero
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.001, inputs: [])

        #expect(engine.state.awayShot.phase == .active)
        #expect(engine.state.awayBlock.phase == .ready)
        #expect(engine.state.awayBoost.phase == .ready)
    }

    @Test func cpuShotDoesNotActivateWhenPuckFar() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 100) // distance 60 > 21.75 (and <= 76: no Boost)
        state.puck.velocity = .zero
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.001, inputs: [])

        #expect(engine.state.awayShot.phase == .ready)
        #expect(engine.state.awayBoost.phase == .ready)
    }

    @Test func cpuShotDoesNotActivateWhenStrikerBelowPuck() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 178) // distance 18 <= 21.75 but puck is above
        state.puck.velocity = .zero
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.001, inputs: [])

        #expect(engine.state.awayShot.phase == .ready)
        #expect(engine.state.awayBlock.phase == .ready)
        #expect(engine.state.awayBoost.phase == .ready)
    }

    @Test func cpuBoostActivatesWhenPuckFarFromStriker() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 80) // distance 80 > 76
        state.puck.velocity = .zero
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.001, inputs: [])

        #expect(engine.state.awayBoost.phase == .active)
        #expect(engine.state.awayBlock.phase == .ready)
        #expect(engine.state.awayShot.phase == .ready)
    }

    @Test func cpuBoostDoesNotActivateWhenPuckNear() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 120) // distance 40 <= 76
        state.puck.velocity = .zero
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.001, inputs: [])

        #expect(engine.state.awayBoost.phase == .ready)
    }

    @Test func cpuActivatesOnlyBlockWhenBlockAndShotBothApply() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 150) // Shot: distance 10, striker above
        state.puck.velocity = Vector2(x: 0, y: 200)  // Block: crosses 180 in 0.15s in the mouth
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.001, inputs: [])

        // One decision activates at most one skill, priority Block > Shot > Boost.
        #expect(engine.state.awayBlock.phase == .active)
        #expect(engine.state.awayShot.phase == .ready)
        #expect(engine.state.awayBoost.phase == .ready)
    }

    @Test func cpuDoesNotRefireSkillOnCooldown() {
        var state = GameState.initial(config: config)
        state.awayPlayer.position = Vector2(x: 10, y: 190)
        state.puck.position = Vector2(x: 50, y: 150)
        state.puck.velocity = Vector2(x: 0, y: 200) // Block condition holds...
        state.awayBlock = SkillState(activeRemaining: 0, cooldownRemaining: 5) // ...but it is cooling down
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.001, inputs: [])

        // Not re-fired: still on cooldown, timer merely ticking down; no fallback skill fires
        // because neither the Shot nor Boost condition holds here.
        #expect(engine.state.awayBlock.phase == .cooldown)
        #expect(engine.state.awayBlock.cooldownRemaining < 5)
        #expect(engine.state.awayShot.phase == .ready)
        #expect(engine.state.awayBoost.phase == .ready)
    }

    @Test func cpuSkillsDoNotFireAfterMatchEnds() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 150)
        state.puck.velocity = Vector2(x: 0, y: 200) // Block condition would hold
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 12, inputs: []) // matchDuration is 10 -> buzzer, no simulation
        #expect(engine.state.phase == .finished)
        #expect(engine.state.awaySkillDecisionRemaining == 0) // buzzer frame never ran the CPU

        engine.update(deltaTime: 0.001, inputs: [])
        #expect(engine.state.awayBlock.phase == .ready)
        #expect(engine.state.awayShot.phase == .ready)
        #expect(engine.state.awayBoost.phase == .ready)
        #expect(engine.state.awaySkillDecisionRemaining == 0)
    }

    @Test func cpuDecisionTimerGatesActivation() {
        var state = GameState.initial(config: config)
        state.awayPlayer.position = Vector2(x: 10, y: 190)
        state.puck.position = Vector2(x: 50, y: 150)
        state.puck.velocity = Vector2(x: 0, y: 200) // Block condition holds throughout
        state.awaySkillDecisionRemaining = 0.02
        var engine = GameEngine(state: state)

        // Timer still positive after this tick: no decision, nothing fires.
        engine.update(deltaTime: 0.01, inputs: [])
        #expect(engine.state.awayBlock.phase == .ready)
        #expect(abs(engine.state.awaySkillDecisionRemaining - 0.01) < 1e-9)

        // Timer reaches zero: the decision runs, Block fires, timer resets to the interval.
        engine.update(deltaTime: 0.01, inputs: [])
        #expect(engine.state.awayBlock.phase == .active)
        #expect(engine.state.awaySkillDecisionRemaining == 0.18)
    }

    @Test func cpuCatchUpRunsSingleDecision() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 80) // Boost condition (distance 80 > 76)
        state.puck.velocity = .zero
        var engine = GameEngine(state: state)

        // One update spanning several decision intervals still evaluates exactly one
        // decision and resets the timer to one interval — no multi-fire catch-up.
        engine.update(deltaTime: 0.5, inputs: [])

        #expect(engine.state.awayBoost.phase == .active)
        #expect(engine.state.awaySkillDecisionRemaining == 0.18)
        // Home skills are untouched by the CPU decision.
        #expect(engine.state.homeBoost.phase == .ready)
        #expect(engine.state.homeShot.phase == .ready)
        #expect(engine.state.homeBlock.phase == .ready)
    }

    @Test func explicitAwayInputBypassesCPUSkillDecision() {
        var state = GameState.initial(config: config)
        state.awayPlayer.position = Vector2(x: 10, y: 190)
        state.puck.position = Vector2(x: 50, y: 150)
        state.puck.velocity = Vector2(x: 0, y: 200) // Block condition would hold for the CPU
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 0.01,
            inputs: [PlayerInput(playerId: .away, targetPosition: Vector2(x: 10, y: 190), timestamp: 1)]
        )

        // The explicit input replaces the CPU entirely: no skill, and the decision
        // timer does not advance.
        #expect(engine.state.awayBlock.phase == .ready)
        #expect(engine.state.awaySkillDecisionRemaining == 0)
    }

    @Test func cpuSkillSimulationIsDeterministic() {
        // Same initial state + same deltaTime sequence must reproduce the exact same
        // away skill states and decision timer at every step (GameState equality
        // includes awaySkillDecisionRemaining).
        var initial = GameState.initial(config: config)
        initial.puck.position = Vector2(x: 40, y: 150)
        initial.puck.velocity = Vector2(x: 20, y: 120)
        let deltas: [Double] = [0.02, 0.05, 0.10, 0.02, 0.15, 0.05, 0.10, 0.02, 0.10, 0.05]

        func run() -> [GameState] {
            var engine = GameEngine(state: initial)
            var states: [GameState] = []
            for dt in deltas {
                engine.update(deltaTime: dt, inputs: [])
                states.append(engine.state)
            }
            return states
        }

        let first = run()
        let second = run()
        #expect(first == second)

        // Guard against a vacuous pass: some away skill actually fired during the run.
        #expect(first.contains {
            $0.awayBlock.phase != .ready || $0.awayShot.phase != .ready || $0.awayBoost.phase != .ready
        })
    }

    // MARK: - CPU difficulty

    // Same 100x200 board as the CPU decision tests. Contact ranges by difficulty:
    // easy 10+5+5*0.70 = 18.5, normal 21.75, hard 24. Boost thresholds: easy 96,
    // normal 76, hard 62. Shield line stays at y = 180.

    private func config(_ difficulty: CPUDifficulty) -> MatchConfig {
        config.withCPUBehavior(difficulty.behavior)
    }

    @Test func normalPresetHoldsItsTunedValues() {
        // The rebalanced Normal: slightly softer than the original hardcoded engine
        // values so the default CPU is less relentless.
        let normal = CPUBehaviorConfig.normal
        #expect(normal.decisionInterval == 0.18)
        #expect(normal.blockReactionWindow == 0.27)
        #expect(normal.shotContactMarginScale == 1.35)
        #expect(normal.boostDistanceThresholdFraction == 0.38)
        // Configs that never mention a difficulty default to Normal.
        #expect(MatchConfig.standard.cpuBehavior == .normal)
        #expect(config.cpuBehavior == .normal)
    }

    @Test func difficultyPresetsHoldTheirValues() {
        let easy = CPUBehaviorConfig.easy
        #expect(easy.decisionInterval == 0.35)
        #expect(easy.blockReactionWindow == 0.16)
        #expect(easy.shotContactMarginScale == 0.70)
        #expect(easy.boostDistanceThresholdFraction == 0.48)

        let hard = CPUBehaviorConfig.hard
        #expect(hard.decisionInterval == 0.12)
        #expect(hard.blockReactionWindow == 0.34)
        #expect(hard.shotContactMarginScale == 1.80)
        #expect(hard.boostDistanceThresholdFraction == 0.31)

        #expect(CPUDifficulty.easy.behavior == .easy)
        #expect(CPUDifficulty.normal.behavior == .normal)
        #expect(CPUDifficulty.hard.behavior == .hard)
    }

    @Test func easyDecidesSlowerAndHardFasterThanNormal() {
        #expect(CPUBehaviorConfig.easy.decisionInterval > CPUBehaviorConfig.normal.decisionInterval)
        #expect(CPUBehaviorConfig.hard.decisionInterval < CPUBehaviorConfig.normal.decisionInterval)
    }

    @Test func withCPUBehaviorOnlyReplacesCPUBehavior() {
        for map in MapDefinition.all {
            let hardConfig = map.config.withCPUBehavior(.hard)
            #expect(hardConfig.cpuBehavior == .hard)
            // Round-tripping back to Normal restores the original config exactly, so
            // geometry, physics and skill values are untouched by difficulty.
            #expect(hardConfig.withCPUBehavior(.normal) == map.config)
        }
    }

    @Test func decisionTimerResetsToConfiguredInterval() {
        var state = GameState.initial(config: config(.easy))
        state.puck.position = Vector2(x: 50, y: 120) // no skill condition holds
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.001, inputs: [])

        #expect(engine.state.awaySkillDecisionRemaining == 0.35)
    }

    @Test func blockReactionWindowFollowsDifficulty() {
        // timeToShield = (180 - 150) / 120 = 0.25s: inside Normal's 0.27 window,
        // outside Easy's 0.16.
        func stateWithIncomingPuck(_ difficulty: CPUDifficulty) -> GameState {
            var state = GameState.initial(config: config(difficulty))
            state.awayPlayer.position = Vector2(x: 10, y: 190) // out of the puck's path
            state.puck.position = Vector2(x: 50, y: 150)
            state.puck.velocity = Vector2(x: 0, y: 120)
            return state
        }

        var normalEngine = GameEngine(state: stateWithIncomingPuck(.normal))
        normalEngine.update(deltaTime: 0.001, inputs: [])
        #expect(normalEngine.state.awayBlock.phase == .active)

        var easyEngine = GameEngine(state: stateWithIncomingPuck(.easy))
        easyEngine.update(deltaTime: 0.001, inputs: [])
        #expect(easyEngine.state.awayBlock.phase == .ready)
    }

    @Test func shotContactMarginFollowsDifficulty() {
        // Striker at (50,160), puck at (50,140): distance 20 is inside Normal's 21.75
        // contact range but outside Easy's 18.5.
        func stateWithNearPuck(_ difficulty: CPUDifficulty) -> GameState {
            var state = GameState.initial(config: config(difficulty))
            state.puck.position = Vector2(x: 50, y: 140)
            state.puck.velocity = .zero
            return state
        }

        var normalEngine = GameEngine(state: stateWithNearPuck(.normal))
        normalEngine.update(deltaTime: 0.001, inputs: [])
        #expect(normalEngine.state.awayShot.phase == .active)

        var easyEngine = GameEngine(state: stateWithNearPuck(.easy))
        easyEngine.update(deltaTime: 0.001, inputs: [])
        #expect(easyEngine.state.awayShot.phase == .ready)
    }

    @Test func boostThresholdFollowsDifficulty() {
        // Striker at (50,160), puck at (50,90): distance 70 is over Hard's 62
        // threshold but under Normal's 76 (and over Shot contact range for both).
        func stateWithMidPuck(_ difficulty: CPUDifficulty) -> GameState {
            var state = GameState.initial(config: config(difficulty))
            state.puck.position = Vector2(x: 50, y: 90)
            state.puck.velocity = .zero
            return state
        }

        var hardEngine = GameEngine(state: stateWithMidPuck(.hard))
        hardEngine.update(deltaTime: 0.001, inputs: [])
        #expect(hardEngine.state.awayBoost.phase == .active)

        var normalEngine = GameEngine(state: stateWithMidPuck(.normal))
        normalEngine.update(deltaTime: 0.001, inputs: [])
        #expect(normalEngine.state.awayBoost.phase == .ready)
    }

    @Test func hardDifficultySimulationIsDeterministic() {
        var initial = GameState.initial(config: config(.hard))
        initial.puck.position = Vector2(x: 40, y: 150)
        initial.puck.velocity = Vector2(x: 20, y: 120)
        let deltas: [Double] = [0.02, 0.05, 0.10, 0.02, 0.15, 0.05, 0.10, 0.02, 0.10, 0.05]

        func run() -> [GameState] {
            var engine = GameEngine(state: initial)
            var states: [GameState] = []
            for dt in deltas {
                engine.update(deltaTime: dt, inputs: [])
                states.append(engine.state)
            }
            return states
        }

        let first = run()
        let second = run()
        #expect(first == second)
        #expect(first.contains {
            $0.awayBlock.phase != .ready || $0.awayShot.phase != .ready || $0.awayBoost.phase != .ready
        })
    }

    @Test func strictBuzzerHoldsAtAnyDifficulty() {
        var state = GameState.initial(config: config(.hard))
        state.puck.position = Vector2(x: 50, y: 150)
        state.puck.velocity = Vector2(x: 0, y: 200) // Block condition would hold
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 12, inputs: []) // matchDuration 10 -> buzzer frame

        #expect(engine.state.phase == .finished)
        #expect(engine.state.awaySkillDecisionRemaining == 0)
        #expect(engine.state.awayBlock.phase == .ready)
    }

    @Test func explicitAwayInputBypassesCPUAtAnyDifficulty() {
        var state = GameState.initial(config: config(.hard))
        state.awayPlayer.position = Vector2(x: 10, y: 190)
        state.puck.position = Vector2(x: 50, y: 150)
        state.puck.velocity = Vector2(x: 0, y: 200) // Block condition would hold for the CPU
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 0.01,
            inputs: [PlayerInput(playerId: .away, targetPosition: Vector2(x: 10, y: 190), timestamp: 1)]
        )

        #expect(engine.state.awayBlock.phase == .ready)
        #expect(engine.state.awaySkillDecisionRemaining == 0)
    }

    @Test func homeSkillsAreUnaffectedByDifficulty() {
        var engine = GameEngine(state: .initial(config: config(.hard)))

        engine.update(
            deltaTime: 0.001,
            inputs: [PlayerInput(playerId: .home, activatedSkills: [.boost])]
        )

        // Home activation still works and uses the shared (unchanged) skill values.
        #expect(engine.state.homeBoost.phase == .active)
        #expect(abs(engine.state.homeBoost.activeRemaining - (config.boost.duration - 0.001)) < 1e-9)
    }

    // MARK: - Match phases (opening countdown / goal pause)

    // phaseConfig: 3s opening countdown, 1s goal pause, otherwise the same 100x200
    // board. `config` keeps both at 0, so every other test runs the match directly.

    // A phaseConfig state already past the countdown, for tests that start in play.
    private func runningPhaseState() -> GameState {
        var state = GameState.initial(config: phaseConfig)
        state.phase = .running
        state.phaseRemaining = 0
        return state
    }

    @Test func initialStateStartsInOpeningCountdown() {
        let state = GameState.initial(config: phaseConfig)
        #expect(state.phase == .countdown)
        #expect(state.phaseRemaining == 3.0)
        #expect(state.remainingTime == 10)
        #expect(state.score == .zero)
        #expect(state.lastScorer == nil)
    }

    @Test func zeroCountdownConfigStartsRunning() {
        let state = GameState.initial(config: config)
        #expect(state.phase == .running)
        #expect(state.phaseRemaining == 0)
    }

    @Test func countdownFreezesEverythingButItsOwnTimer() {
        var state = GameState.initial(config: phaseConfig)
        state.puck.velocity = Vector2(x: 40, y: 120)
        state.homeBoost = SkillState(activeRemaining: 1.5, cooldownRemaining: 0)
        state.awayShot = SkillState(activeRemaining: 0, cooldownRemaining: 2.0)
        let frozen = state
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 0.1,
            inputs: [PlayerInput(playerId: .home, moveVector: Vector2(x: 1, y: 0), activatedSkills: [.shot])]
        )

        let after = engine.state
        #expect(after.phase == .countdown)
        #expect(abs(after.phaseRemaining - 2.9) < 1e-9)
        // Clock, entities, skills and the CPU decision timer are all untouched.
        #expect(after.remainingTime == frozen.remainingTime)
        #expect(after.puck == frozen.puck)
        #expect(after.homePlayer == frozen.homePlayer)
        #expect(after.awayPlayer == frozen.awayPlayer)
        #expect(after.homeBoost == frozen.homeBoost)
        #expect(after.awayShot == frozen.awayShot)
        #expect(after.homeShot.phase == .ready) // the activation request was ignored
        #expect(after.awaySkillDecisionRemaining == frozen.awaySkillDecisionRemaining)
    }

    @Test func countdownEndStepDoesNotSimulate() {
        var state = GameState.initial(config: phaseConfig)
        state.puck.velocity = Vector2(x: 0, y: 100)
        var engine = GameEngine(state: state)

        // This step finishes the countdown; play resumes on the NEXT step.
        engine.update(deltaTime: 3.0, inputs: [])
        #expect(engine.state.phase == .running)
        #expect(engine.state.phaseRemaining == 0)
        #expect(engine.state.remainingTime == 10)
        #expect(engine.state.puck.position == phaseConfig.rinkCenter)

        // The next step runs the match normally.
        engine.update(deltaTime: 0.1, inputs: [])
        #expect(abs(engine.state.remainingTime - 9.9) < 1e-9)
        #expect(engine.state.puck.position.y > phaseConfig.rinkCenter.y)
    }

    @Test func countdownOverrunDoesNotCarryIntoMatch() {
        var engine = GameEngine(state: .initial(config: phaseConfig))

        // One huge step past the countdown still only ends the phase; none of the
        // excess time leaks into the match clock.
        engine.update(deltaTime: 5.0, inputs: [])

        #expect(engine.state.phase == .running)
        #expect(engine.state.remainingTime == 10)
    }

    @Test func goalEntersGoalPauseAndResetsBoard() {
        var state = runningPhaseState()
        state.puck.position = Vector2(x: 50, y: 199)
        state.puck.velocity = Vector2(x: 0, y: 100)
        state.awayPlayer.position = Vector2(x: 90, y: 190)
        var engine = GameEngine(state: state)

        // The explicit away input parks the CPU striker out of the puck's path.
        engine.update(
            deltaTime: 0.05,
            inputs: [PlayerInput(playerId: .away, targetPosition: Vector2(x: 90, y: 190), timestamp: 1)]
        )

        #expect(engine.state.score == ScoreState(home: 1, away: 0))
        #expect(engine.state.phase == .goalPause)
        #expect(engine.state.phaseRemaining == 1.0)
        #expect(engine.state.lastScorer == .home)
        #expect(engine.state.puck.position == phaseConfig.rinkCenter)
        #expect(engine.state.homePlayer.position == phaseConfig.homeStartPosition)
        #expect(engine.state.awayPlayer.position == phaseConfig.awayStartPosition)
    }

    @Test func awayGoalSetsLastScorerAway() {
        var state = runningPhaseState()
        state.puck.position = Vector2(x: 50, y: 1)
        state.puck.velocity = Vector2(x: 0, y: -100)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.05, inputs: [])

        #expect(engine.state.score == ScoreState(home: 0, away: 1))
        #expect(engine.state.phase == .goalPause)
        #expect(engine.state.lastScorer == .away)
    }

    @Test func goalPauseFreezesEverythingButItsOwnTimer() {
        var state = runningPhaseState()
        state.phase = .goalPause
        state.phaseRemaining = 1.0
        state.homeBoost = SkillState(activeRemaining: 1.2, cooldownRemaining: 0)
        state.awayBlock = SkillState(activeRemaining: 0, cooldownRemaining: 3.0)
        state.awaySkillDecisionRemaining = 0.05
        let frozen = state
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 0.1,
            inputs: [PlayerInput(playerId: .home, moveVector: Vector2(x: 0, y: 1), activatedSkills: [.block])]
        )

        let after = engine.state
        #expect(after.phase == .goalPause)
        #expect(abs(after.phaseRemaining - 0.9) < 1e-9)
        #expect(after.remainingTime == frozen.remainingTime)
        #expect(after.puck == frozen.puck)
        #expect(after.homePlayer == frozen.homePlayer)
        #expect(after.awayPlayer == frozen.awayPlayer)
        #expect(after.homeBoost == frozen.homeBoost)
        #expect(after.awayBlock == frozen.awayBlock)
        #expect(after.homeBlock.phase == .ready) // the activation request was ignored
        #expect(after.awaySkillDecisionRemaining == frozen.awaySkillDecisionRemaining)
    }

    @Test func goalPauseCannotDoubleScore() {
        var state = runningPhaseState()
        state.phase = .goalPause
        state.phaseRemaining = 1.0
        state.score = ScoreState(home: 1, away: 0)
        // Even a puck artificially crossing the goal line must not score while paused.
        state.puck.position = Vector2(x: 50, y: 199)
        state.puck.velocity = Vector2(x: 0, y: 400)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.05, inputs: [])

        #expect(engine.state.score == ScoreState(home: 1, away: 0))
        #expect(engine.state.phase == .goalPause)
    }

    @Test func goalPauseEndStepDoesNotSimulate() {
        var state = runningPhaseState()
        state.phase = .goalPause
        state.phaseRemaining = 0.1
        state.puck.velocity = Vector2(x: 0, y: 100)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.1, inputs: [])
        #expect(engine.state.phase == .running)
        #expect(engine.state.remainingTime == 10)
        #expect(engine.state.puck.position == phaseConfig.rinkCenter)

        engine.update(deltaTime: 0.1, inputs: [])
        #expect(abs(engine.state.remainingTime - 9.9) < 1e-9)
        #expect(engine.state.puck.position.y > phaseConfig.rinkCenter.y)
    }

    @Test func zeroGoalPauseConfigKeepsMatchRunning() {
        var state = GameState.initial(config: config)
        state.puck.position = Vector2(x: 50, y: 199)
        state.puck.velocity = Vector2(x: 0, y: 100)
        state.awayPlayer.position = Vector2(x: 90, y: 190)
        var engine = GameEngine(state: state)

        engine.update(
            deltaTime: 0.05,
            inputs: [PlayerInput(playerId: .away, targetPosition: Vector2(x: 90, y: 190), timestamp: 1)]
        )

        // Pre-phase behaviour: the goal counts and play continues immediately.
        #expect(engine.state.score == ScoreState(home: 1, away: 0))
        #expect(engine.state.phase == .running)
        #expect(engine.state.lastScorer == .home)
    }

    @Test func buzzerRemainsStrictWithPhasesEnabled() {
        var state = runningPhaseState()
        state.remainingTime = 0.05
        state.puck.position = Vector2(x: 50, y: 199)
        state.puck.velocity = Vector2(x: 0, y: 100) // would score without the buzzer
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.1, inputs: [])

        #expect(engine.state.phase == .finished)
        #expect(engine.state.score == .zero)
        #expect(engine.state.phaseRemaining == 0)
    }

    @Test func finishedStateFreezesPhaseTimer() {
        var state = runningPhaseState()
        state.phase = .finished
        state.phaseRemaining = 0.5 // artificial: must stay untouched after finish
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 1.0, inputs: [])

        #expect(engine.state.phase == .finished)
        #expect(engine.state.phaseRemaining == 0.5)
    }

    @Test func matchPhaseFlowIsDeterministic() {
        // Countdown -> running -> home goal -> goal pause -> running, all in one
        // delta sequence. The explicit away input parks the CPU out of the puck's
        // path so the goal is part of the scripted flow.
        var initial = GameState.initial(config: phaseConfig)
        initial.puck.velocity = Vector2(x: 0, y: 300) // frozen until the countdown ends
        let deltas = [Double](repeating: 0.5, count: 6) + [Double](repeating: 0.05, count: 30)

        func run() -> [GameState] {
            var engine = GameEngine(state: initial)
            var states: [GameState] = []
            for dt in deltas {
                engine.update(
                    deltaTime: dt,
                    inputs: [PlayerInput(playerId: .away, targetPosition: Vector2(x: 90, y: 190), timestamp: 1)]
                )
                states.append(engine.state)
            }
            return states
        }

        let first = run()
        let second = run()
        #expect(first == second)
        // Non-vacuous: the run actually passed through a goal pause and scored.
        #expect(first.contains { $0.phase == .goalPause })
        #expect(first.last?.score.home == 1)
    }

    @Test func localSessionRunsOpeningCountdown() {
        let session = LocalMatchSession(config: phaseConfig)
        let fixedDelta = 1.0 / phaseConfig.tickRate

        // ~1.5s of fixed steps: still counting down, match clock untouched.
        for _ in 0..<90 {
            session.advance(deltaTime: fixedDelta)
        }
        #expect(session.state.phase == .countdown)
        #expect(session.state.remainingTime == 10)

        // Past 3s of fixed steps: the match is running.
        for _ in 0..<100 {
            session.advance(deltaTime: fixedDelta)
        }
        #expect(session.state.phase == .running)
    }

    // MARK: - Striker speed scales

    @Test func speedScalesDefaultToOne() {
        #expect(config.homeStrikerSpeedScale == 1.0)
        #expect(config.awayStrikerSpeedScale == 1.0)
        #expect(MatchConfig.standard.homeStrikerSpeedScale == 1.0)
        #expect(MatchConfig.standard.awayStrikerSpeedScale == 1.0)
    }

    @Test func homeSpeedScaleSpeedsUpOnlyHome() {
        let scaled = config.withStrikerSpeedScales(home: 1.12, away: 1.0)
        var baseEngine = GameEngine(state: .initial(config: config))
        var scaledEngine = GameEngine(state: .initial(config: scaled))
        let inputs = [PlayerInput(playerId: .home, moveVector: Vector2(x: 1, y: 0))]

        baseEngine.update(deltaTime: 0.01, inputs: inputs)
        scaledEngine.update(deltaTime: 0.01, inputs: inputs)

        let baseDX = baseEngine.state.homePlayer.position.x - config.homeStartPosition.x
        let scaledDX = scaledEngine.state.homePlayer.position.x - config.homeStartPosition.x
        #expect(abs(baseDX - 1000 * 0.01) < 1e-9)
        #expect(abs(scaledDX - 1000 * 1.12 * 0.01) < 1e-9)
        // The away (CPU-driven) side is byte-identical to the unscaled run.
        #expect(scaledEngine.state.awayPlayer == baseEngine.state.awayPlayer)
    }

    @Test func symmetricScalesMoveBothSidesEqually() {
        let scaled = config.withStrikerSpeedScales(home: 1.12, away: 1.12)
        var engine = GameEngine(state: .initial(config: scaled))

        engine.update(
            deltaTime: 0.01,
            inputs: [
                PlayerInput(playerId: .home, moveVector: Vector2(x: 1, y: 0)),
                PlayerInput(playerId: .away, moveVector: Vector2(x: 1, y: 0), timestamp: 1)
            ]
        )

        let homeDX = engine.state.homePlayer.position.x - scaled.homeStartPosition.x
        let awayDX = engine.state.awayPlayer.position.x - scaled.awayStartPosition.x
        #expect(abs(homeDX - awayDX) < 1e-9)
        #expect(abs(homeDX - 1000 * 1.12 * 0.01) < 1e-9)
    }

    @Test func boostMultipliesTheScaledSideSpeed() {
        let scaled = config.withStrikerSpeedScales(home: 1.12, away: 1.0)
        var state = GameState.initial(config: scaled)
        state.homeBoost = SkillState(activeRemaining: 1.0, cooldownRemaining: 0)
        var engine = GameEngine(state: state)

        engine.update(deltaTime: 0.01, inputs: [PlayerInput(playerId: .home, moveVector: Vector2(x: 1, y: 0))])

        // Boost multiplies the side's resolved (scaled) speed — applied once, not twice.
        let dx = engine.state.homePlayer.position.x - scaled.homeStartPosition.x
        #expect(abs(dx - 1000 * 1.12 * 1.6 * 0.01) < 1e-9)
    }

    @Test func speedScalesLeaveThePuckAlone() {
        func puckAfterRun(_ cfg: MatchConfig) -> PuckState {
            var state = GameState.initial(config: cfg)
            state.puck.velocity = Vector2(x: 30, y: 40)
            var engine = GameEngine(state: state)
            for _ in 0..<10 {
                engine.update(
                    deltaTime: 0.01,
                    inputs: [PlayerInput(playerId: .away, targetPosition: Vector2(x: 90, y: 190), timestamp: 1)]
                )
            }
            return engine.state.puck
        }

        let scaled = config.withStrikerSpeedScales(home: 1.12, away: 1.12)
        #expect(puckAfterRun(config) == puckAfterRun(scaled))
    }

    @Test func withStrikerSpeedScalesKeepsEverythingElse() {
        for map in MapDefinition.all {
            let scaled = map.config.withStrikerSpeedScales(home: 1.12, away: 1.0)
            #expect(scaled.strikerMaxSpeed == map.config.strikerMaxSpeed)
            #expect(scaled.homeStrikerSpeedScale == 1.12)
            #expect(scaled.awayStrikerSpeedScale == 1.0)
            // Round-tripping back to 1.0 restores the map config exactly.
            #expect(scaled.withStrikerSpeedScales(home: 1.0, away: 1.0) == map.config)
        }
    }

    // MARK: - Local versus dual input

    // An externally driven session always feeds an explicit away input (even a
    // neutral one), so the engine's away CPU must never run.

    @Test func externallyDrivenAwayDisablesCPU() {
        let session = LocalMatchSession(config: config, awayExternallyDriven: true)

        for _ in 0..<30 {
            session.advance(deltaTime: 1.0 / 60)
        }

        // The CPU decision timer never ticks or resets, no away skill fires, and the
        // away striker holds its start position with no movement input.
        #expect(session.state.awaySkillDecisionRemaining == 0)
        #expect(session.state.awayPlayer.position == config.awayStartPosition)
        #expect(session.state.awayBoost.phase == .ready)
        #expect(session.state.awayShot.phase == .ready)
        #expect(session.state.awayBlock.phase == .ready)
    }

    @Test func cpuStillRunsWithoutExternalDrive() {
        let session = LocalMatchSession(config: config)

        session.advance(deltaTime: 1.0 / 60)

        // The CPU decision ran on the first step and reset its timer to the interval.
        #expect(session.state.awaySkillDecisionRemaining == 0.18)
    }

    @Test func awayMovementMovesAwayStriker() {
        let session = LocalMatchSession(config: config, awayExternallyDriven: true)
        session.setMovement(Vector2(x: 0, y: -1), for: .away)

        session.advance(deltaTime: 1.0 / 60)

        #expect(session.state.awayPlayer.position.y < config.awayStartPosition.y)
        #expect(session.state.homePlayer.position == config.homeStartPosition)
    }

    @Test func dualMovementIsIndependent() {
        let session = LocalMatchSession(config: config, awayExternallyDriven: true)
        session.setMovement(Vector2(x: 1, y: 0), for: .home)
        session.setMovement(Vector2(x: -1, y: 0), for: .away)

        session.advance(deltaTime: 1.0 / 60)

        // Neither side's vector clobbered the other's.
        #expect(session.state.homePlayer.position.x > config.homeStartPosition.x)
        #expect(session.state.awayPlayer.position.x < config.awayStartPosition.x)
    }

    @Test func dualBoostActivatesBothSides() {
        let session = LocalMatchSession(config: config, awayExternallyDriven: true)
        session.queueSkill(.boost, for: .home)
        session.queueSkill(.boost, for: .away)

        session.advance(deltaTime: 1.0 / 60)

        #expect(session.state.homeBoost.phase == .active)
        #expect(session.state.awayBoost.phase == .active)
    }

    @Test func awayShotAndBlockActivate() {
        let session = LocalMatchSession(config: config, awayExternallyDriven: true)
        session.queueSkill(.shot, for: .away)
        session.advance(deltaTime: 1.0 / 60)
        #expect(session.state.awayShot.phase == .active)

        session.queueSkill(.block, for: .away)
        session.advance(deltaTime: 1.0 / 60)
        #expect(session.state.awayBlock.phase == .active)
    }

    @Test func skillQueuesAreIndependent() {
        let session = LocalMatchSession(config: config, awayExternallyDriven: true)
        session.queueSkill(.boost, for: .away)

        session.advance(deltaTime: 1.0 / 60)

        #expect(session.state.homeBoost.phase == .ready)
        #expect(session.state.awayBoost.phase == .active)
    }

    @Test func awaySkillFiresOnceAcrossCatchUp() {
        let session = LocalMatchSession(config: config, awayExternallyDriven: true)
        let fixedDelta = 1.0 / config.tickRate
        session.queueSkill(.boost, for: .away)

        // One advance spanning the 5-step catch-up cap: the boost fires on the first
        // step only, then just counts down — never re-fires on later steps.
        session.advance(deltaTime: fixedDelta * 6)

        #expect(session.state.awayBoost.phase == .active)
        #expect(abs(session.state.awayBoost.activeRemaining - (config.boost.duration - 5 * fixedDelta)) < 1e-9)
    }

    @Test func countdownDropsHeldAndQueuedDualInput() {
        let session = LocalMatchSession(config: phaseConfig, awayExternallyDriven: true)
        session.setMovement(Vector2(x: 1, y: 0), for: .home)
        session.setMovement(Vector2(x: 1, y: 0), for: .away)
        session.queueSkill(.boost, for: .home)
        session.queueSkill(.shot, for: .away)

        // Through the whole 3s countdown and into play.
        for _ in 0..<200 {
            session.advance(deltaTime: 1.0 / 60)
        }

        // Nothing tapped or held during the countdown leaks into the match.
        #expect(session.state.phase == .running)
        #expect(session.state.homeBoost.phase == .ready)
        #expect(session.state.awayShot.phase == .ready)
        #expect(session.state.homePlayer.position == phaseConfig.homeStartPosition)
        #expect(session.state.awayPlayer.position == phaseConfig.awayStartPosition)
    }

    @Test func clearAllInputsDropsEverything() {
        let session = LocalMatchSession(config: config, awayExternallyDriven: true)
        session.setMovement(Vector2(x: 1, y: 0), for: .home)
        session.setMovement(Vector2(x: -1, y: 0), for: .away)
        session.queueSkill(.boost, for: .home)
        session.queueSkill(.block, for: .away)

        session.clearAllInputs()
        session.advance(deltaTime: 1.0 / 60)

        #expect(session.state.homePlayer.position == config.homeStartPosition)
        #expect(session.state.awayPlayer.position == config.awayStartPosition)
        #expect(session.state.homeBoost.phase == .ready)
        #expect(session.state.awayBlock.phase == .ready)
    }

    @Test func finishedMatchIgnoresDualInput() {
        let session = LocalMatchSession(config: config, awayExternallyDriven: true)
        for _ in 0..<610 { // matchDuration 10s at 60Hz -> the buzzer has fired
            session.advance(deltaTime: 1.0 / 60)
        }
        #expect(session.state.phase == .finished)
        let finished = session.state

        session.setMovement(Vector2(x: 1, y: 0), for: .home)
        session.setMovement(Vector2(x: -1, y: 0), for: .away)
        session.queueSkill(.boost, for: .home)
        session.queueSkill(.shot, for: .away)
        for _ in 0..<10 {
            session.advance(deltaTime: 1.0 / 60)
        }

        #expect(session.state == finished)
    }

    @Test func dualInputSimulationIsDeterministic() {
        func run() -> [GameState] {
            let session = LocalMatchSession(config: config, awayExternallyDriven: true)
            var states: [GameState] = []
            for i in 0..<60 {
                if i == 5 {
                    session.queueSkill(.boost, for: .home)
                }
                if i == 10 {
                    session.queueSkill(.shot, for: .away)
                }
                session.setMovement(Vector2(x: i % 2 == 0 ? 0.5 : -0.5, y: 0.2), for: .home)
                session.setMovement(Vector2(x: 0.3, y: i % 3 == 0 ? -0.6 : 0.1), for: .away)
                session.advance(deltaTime: 1.0 / 60)
                states.append(session.state)
            }
            return states
        }

        let first = run()
        let second = run()
        #expect(first == second)
        #expect(first.contains { $0.homeBoost.phase == .active && $0.awayShot.phase == .active })
    }

    @Test func symmetricSpeedScalesApplyToDualInput() {
        let scaled = config.withStrikerSpeedScales(home: 1.12, away: 1.12)
        let session = LocalMatchSession(config: scaled, awayExternallyDriven: true)
        session.setMovement(Vector2(x: 1, y: 0), for: .home)
        session.setMovement(Vector2(x: 1, y: 0), for: .away)

        session.advance(deltaTime: 1.0 / 60)

        let homeDX = session.state.homePlayer.position.x - scaled.homeStartPosition.x
        let awayDX = session.state.awayPlayer.position.x - scaled.awayStartPosition.x
        #expect(abs(homeDX - awayDX) < 1e-9)
        #expect(abs(homeDX - 1000 * 1.12 / 60) < 1e-9)
    }

    @Test func scaledSimulationIsDeterministic() {
        let scaled = config.withStrikerSpeedScales(home: 1.12, away: 1.0)
        var initial = GameState.initial(config: scaled)
        initial.puck.velocity = Vector2(x: 25, y: 130)
        let deltas: [Double] = [0.02, 0.05, 0.10, 0.02, 0.15, 0.05, 0.10, 0.02, 0.10, 0.05]

        func run() -> [GameState] {
            var engine = GameEngine(state: initial)
            var states: [GameState] = []
            for dt in deltas {
                engine.update(
                    deltaTime: dt,
                    inputs: [PlayerInput(playerId: .home, moveVector: Vector2(x: 0.4, y: 0.8))]
                )
                states.append(engine.state)
            }
            return states
        }

        #expect(run() == run())
    }
}
