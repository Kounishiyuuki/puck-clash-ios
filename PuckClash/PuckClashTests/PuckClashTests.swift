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
}
