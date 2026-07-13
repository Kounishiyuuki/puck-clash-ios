import Foundation

struct GameEngine {
    private(set) var state: GameState

    init(state: GameState = .initial()) {
        self.state = state
    }

    mutating func update(deltaTime: TimeInterval, inputs: [PlayerInput]) {
        guard deltaTime > 0, state.phase != .finished else {
            return
        }

        if state.phase == .ready {
            state.phase = .running
        }

        state.remainingTime = max(0, state.remainingTime - deltaTime)

        // Buzzer: the frame the clock reaches zero ends the match immediately.
        // No striker movement, collision, puck update, or goal on this frame.
        if state.remainingTime == 0 {
            state.phase = .finished
            return
        }

        let homeInput = latestInput(for: .home, in: inputs)
        let awayInput = latestInput(for: .away, in: inputs) ?? awayCPUInput()

        // Boost activation (input is already edge-triggered by the session): a ready
        // boost becomes active; a request while active or on cooldown is ignored.
        state.homeBoost = boostActivated(state.homeBoost, requested: homeInput?.activatedSkills.contains(.boost) ?? false)
        state.awayBoost = boostActivated(state.awayBoost, requested: awayInput.activatedSkills.contains(.boost))

        // Shot activation (also edge-triggered by the session): a ready shot becomes armed
        // (active); a request while armed or on cooldown is ignored. The away side keeps a
        // symmetric shot state but has no activation path yet, so this stays a no-op for it.
        state.homeShot = shotActivated(state.homeShot, requested: homeInput?.activatedSkills.contains(.shot) ?? false)
        state.awayShot = shotActivated(state.awayShot, requested: awayInput.activatedSkills.contains(.shot))

        state.homePlayer = movedStriker(
            state.homePlayer,
            moveVector: homeInput?.moveVector,
            target: homeInput?.targetPosition,
            maxSpeed: effectiveStrikerSpeed(boost: state.homeBoost),
            deltaTime: deltaTime
        )
        state.awayPlayer = movedStriker(
            state.awayPlayer,
            moveVector: awayInput.moveVector,
            target: awayInput.targetPosition,
            maxSpeed: effectiveStrikerSpeed(boost: state.awayBoost),
            deltaTime: deltaTime
        )

        // Pass each side's shot state in and take the (possibly consumed) state back, so
        // an armed shot amplifies its one hit and is consumed — no inout aliasing with the
        // puck the collision also mutates.
        state.homeShot = resolveStrikerPuckCollision(with: state.homePlayer, shot: state.homeShot)
        state.awayShot = resolveStrikerPuckCollision(with: state.awayPlayer, shot: state.awayShot)

        updatePuck(deltaTime: deltaTime)

        // Advance skill timers with the same fixed deltaTime so they are deterministic.
        state.homeBoost = boostAdvanced(state.homeBoost, deltaTime: deltaTime)
        state.awayBoost = boostAdvanced(state.awayBoost, deltaTime: deltaTime)
        state.homeShot = shotAdvanced(state.homeShot, deltaTime: deltaTime)
        state.awayShot = shotAdvanced(state.awayShot, deltaTime: deltaTime)
    }

    // A ready boost with a fresh request starts its active window; otherwise unchanged.
    private func boostActivated(_ boost: SkillState, requested: Bool) -> SkillState {
        guard requested, boost.phase == .ready else {
            return boost
        }
        var updated = boost
        updated.activeRemaining = state.config.boost.duration
        return updated
    }

    // The striker's max speed, scaled by the boost multiplier while its effect is active.
    private func effectiveStrikerSpeed(boost: SkillState) -> Double {
        let multiplier = boost.activeRemaining > 0 ? state.config.boost.speedMultiplier : 1
        return state.config.strikerMaxSpeed * multiplier
    }

    // Count down the active window, then (once it ends) the cooldown, back to ready.
    private func boostAdvanced(_ boost: SkillState, deltaTime: TimeInterval) -> SkillState {
        var updated = boost
        if updated.activeRemaining > 0 {
            updated.activeRemaining = max(0, updated.activeRemaining - deltaTime)
            if updated.activeRemaining == 0 {
                updated.cooldownRemaining = state.config.boost.cooldown
            }
        } else if updated.cooldownRemaining > 0 {
            updated.cooldownRemaining = max(0, updated.cooldownRemaining - deltaTime)
        }
        return updated
    }

    // A ready shot with a fresh request enters its armed (active) window; otherwise unchanged.
    private func shotActivated(_ shot: SkillState, requested: Bool) -> SkillState {
        guard requested, shot.phase == .ready else {
            return shot
        }
        var updated = shot
        updated.activeRemaining = state.config.shot.activeDuration
        return updated
    }

    // Count down the armed window; when it ends without a hit, start the cooldown. A hit
    // consumes the shot in resolveStrikerPuckCollision (which sets the cooldown directly),
    // so by the time this runs the armed window is already 0 and only the cooldown ticks.
    private func shotAdvanced(_ shot: SkillState, deltaTime: TimeInterval) -> SkillState {
        var updated = shot
        if updated.activeRemaining > 0 {
            updated.activeRemaining = max(0, updated.activeRemaining - deltaTime)
            if updated.activeRemaining == 0 {
                updated.cooldownRemaining = state.config.shot.cooldown
            }
        } else if updated.cooldownRemaining > 0 {
            updated.cooldownRemaining = max(0, updated.cooldownRemaining - deltaTime)
        }
        return updated
    }

    private func latestInput(for playerId: PlayerID, in inputs: [PlayerInput]) -> PlayerInput? {
        inputs
            .filter { $0.playerId == playerId }
            .max { $0.timestamp < $1.timestamp }
    }

    // Strikers move from a velocity-style stick vector (home) or by following a
    // target position (away CPU / legacy), capped by strikerMaxSpeed and confined
    // to the player's own half. Velocity is derived from the actual displacement so
    // the collision impulse reflects real motion. moveVector takes precedence.
    private func movedStriker(
        _ striker: PlayerState,
        moveVector: Vector2?,
        target: Vector2?,
        maxSpeed: Double,
        deltaTime: TimeInterval
    ) -> PlayerState {
        var updated = striker
        var newPosition = striker.position

        if let moveVector {
            // Treat magnitude as 0...1; anything longer is clamped to a unit vector.
            let bounded = moveVector.length > 1 ? moveVector.normalized : moveVector
            let step = bounded * (maxSpeed * deltaTime)
            newPosition = clampedToHalf(striker.position + step, side: striker.side)
        } else if let target {
            let desired = clampedToHalf(target, side: striker.side)
            let toTarget = desired - striker.position
            let maxStep = maxSpeed * deltaTime
            let step = toTarget.length <= maxStep ? toTarget : toTarget.normalized * maxStep
            newPosition = clampedToHalf(striker.position + step, side: striker.side)
        }

        updated.velocity = (newPosition - striker.position) * (1 / deltaTime)
        updated.position = newPosition
        return updated
    }

    // Minimal deterministic away CPU: track the puck's x, intercept it in the upper
    // half, otherwise hold a default defensive spot. The half clamp keeps it above
    // center, so it never crosses the center line.
    private func awayCPUInput() -> PlayerInput {
        let targetX = state.puck.position.x
        let targetY: Double
        if state.puck.position.y > state.config.rinkCenter.y {
            targetY = state.puck.position.y
        } else {
            targetY = state.config.rinkSize.y * 0.8
        }
        return PlayerInput(playerId: .away, targetPosition: Vector2(x: targetX, y: targetY))
    }

    // Elastic circle-circle resolution with the striker treated as infinite mass.
    // Pushes the puck out of overlap and reflects its velocity relative to the
    // striker, so a moving striker imparts speed to the puck.
    // Returns the striker's shot state, consumed into cooldown if an armed shot actually
    // landed this call; otherwise it is returned unchanged.
    private mutating func resolveStrikerPuckCollision(with striker: PlayerState, shot: SkillState) -> SkillState {
        let delta = state.puck.position - striker.position
        let distance = delta.length
        let minDistance = state.config.strikerRadius + state.config.puckRadius

        guard distance < minDistance else {
            return shot
        }

        // Fall back to a fixed normal when centers coincide to avoid NaN.
        let normal = distance > 0 ? delta * (1 / distance) : Vector2(x: 0, y: 1)

        let overlap = minDistance - distance
        state.puck.position = state.puck.position + normal * overlap

        let relativeVelocity = state.puck.velocity - striker.velocity
        let approachSpeed = relativeVelocity.x * normal.x + relativeVelocity.y * normal.y

        // Only a closing contact imparts an impulse. A mere overlap with no approach speed
        // neither speeds the puck nor consumes an armed shot.
        guard approachSpeed < 0 else {
            return shot
        }

        // An armed shot amplifies this single hit; a normal hit uses multiplier 1 and so
        // keeps its exact previous behaviour.
        let shotArmed = shot.phase == .active
        let multiplier = shotArmed ? state.config.shot.speedMultiplier : 1
        let impulse = -(1 + state.config.strikerHitRestitution) * approachSpeed * multiplier
        state.puck.velocity = state.puck.velocity + normal * impulse

        guard shotArmed else {
            return shot
        }
        // Consume the armed shot: end the armed window now and start its cooldown.
        var consumed = shot
        consumed.activeRemaining = 0
        consumed.cooldownRemaining = state.config.shot.cooldown
        return consumed
    }

    private mutating func updatePuck(deltaTime: TimeInterval) {
        let nextPosition = state.puck.position + state.puck.velocity * deltaTime

        if nextPosition.y >= state.config.topGoalBoundaryY && isInsideGoalMouth(nextPosition) {
            scoreGoal(for: .home)
            return
        }

        if nextPosition.y <= state.config.bottomGoalBoundaryY && isInsideGoalMouth(nextPosition) {
            scoreGoal(for: .away)
            return
        }

        reflectPuckOffWalls(nextPosition: nextPosition)
        dampPuckVelocity(deltaTime: deltaTime)
    }

    private func isInsideGoalMouth(_ position: Vector2) -> Bool {
        position.x >= state.config.goalMouthMinX && position.x <= state.config.goalMouthMaxX
    }

    // Mirror the puck off any boundary it overshoots and flip that axis' velocity.
    // Reached only when the puck did not score, so top/bottom reflection applies
    // outside the goal mouth only; left/right edges are always walls.
    private mutating func reflectPuckOffWalls(nextPosition: Vector2) {
        let restitution = state.config.wallRestitution
        let rinkWidth = state.config.rinkSize.x
        let rinkHeight = state.config.rinkSize.y

        var positionX = nextPosition.x
        var positionY = nextPosition.y
        var velocityX = state.puck.velocity.x
        var velocityY = state.puck.velocity.y

        if positionX < 0 {
            positionX = -positionX
            velocityX = -velocityX * restitution
        } else if positionX > rinkWidth {
            positionX = 2 * rinkWidth - positionX
            velocityX = -velocityX * restitution
        }

        if positionY < 0 {
            positionY = -positionY
            velocityY = -velocityY * restitution
        } else if positionY > rinkHeight {
            positionY = 2 * rinkHeight - positionY
            velocityY = -velocityY * restitution
        }

        state.puck.velocity = Vector2(x: velocityX, y: velocityY)
        state.puck.position = clampedToRink(Vector2(x: positionX, y: positionY))
    }

    // Exponential friction on the free puck, then snap to rest below the stop speed.
    private mutating func dampPuckVelocity(deltaTime: TimeInterval) {
        let dampingFactor = pow(state.config.puckDamping, deltaTime)
        let dampedVelocity = state.puck.velocity * dampingFactor

        if dampedVelocity.length < state.config.puckStopSpeed {
            state.puck.velocity = .zero
        } else {
            state.puck.velocity = dampedVelocity
        }
    }

    private mutating func scoreGoal(for side: PlayerSide) {
        switch side {
        case .home:
            state.score.home += 1
        case .away:
            state.score.away += 1
        }

        state.puck = PuckState(position: state.config.rinkCenter, velocity: .zero)
        state.homePlayer.position = state.config.homeStartPosition
        state.homePlayer.velocity = .zero
        state.awayPlayer.position = state.config.awayStartPosition
        state.awayPlayer.velocity = .zero
    }

    // Home is confined to the bottom half (y in [0, center]); away to the top half.
    private func clampedToHalf(_ position: Vector2, side: PlayerSide) -> Vector2 {
        let midY = state.config.rinkCenter.y
        let clampedX = min(max(position.x, 0), state.config.rinkSize.x)
        let clampedY: Double
        switch side {
        case .home:
            clampedY = min(max(position.y, 0), midY)
        case .away:
            clampedY = min(max(position.y, midY), state.config.rinkSize.y)
        }
        return Vector2(x: clampedX, y: clampedY)
    }

    private func clampedToRink(_ position: Vector2) -> Vector2 {
        Vector2(
            x: min(max(position.x, 0), state.config.rinkSize.x),
            y: min(max(position.y, 0), state.config.rinkSize.y)
        )
    }
}

// Boundary between the presentation layer and how a match is actually run. A
// session hides whether the simulation is local (GameEngine) or, later, driven by
// a server. The presentation layer only feeds home input and advances time, then
// renders the returned snapshot's state. Foundation-only, like the rest of GameCore.
protocol MatchSession: AnyObject {
    var config: MatchConfig { get }
    var state: GameState { get }
    func setHomeInput(moveVector: Vector2?)
    func activateHomeSkill(_ skill: SkillID)
    @discardableResult func advance(deltaTime: TimeInterval) -> MatchSnapshot
}

extension MatchSession {
    // Default: the local player's skill activation is only meaningful for sessions that
    // run the simulation. Reserved for future non-local session handling.
    func activateHomeSkill(_ skill: SkillID) {}
}

// Runs the match entirely on-device by owning a GameEngine. Home input arrives as
// a joystick move vector; the away CPU stays inside GameEngine.update. All rules,
// physics, scoring and timing remain in GameEngine — this class only wires input
// into it and advances the clock, so a future session implementation can replace it.
final class LocalMatchSession: MatchSession {
    // Cap on fixed steps run per advance. A long hitch (or a backgrounded app) must
    // not trigger a huge burst of catch-up steps that stalls the frame — beyond this
    // cap the leftover backlog is dropped ("spiral of death" guard).
    private static let maxCatchUpSteps = 5

    let config: MatchConfig
    private var engine: GameEngine
    // Latest joystick vector; nil (or zero, normalized to nil) means no home input.
    private var homeMoveVector: Vector2?
    // Real time received but not yet simulated, drained in whole fixedDelta steps.
    private var accumulatedTime: TimeInterval = 0
    // Fixed-step counter: +1 for each engine.update(fixedDelta). Reported in snapshots.
    private var tick = 0
    // Skill activations requested since the last consumed step; applied to exactly one
    // fixed step (edge-triggered) so holding the button or a catch-up burst fires once.
    private var pendingSkillActivations: Set<SkillID> = []

    init(config: MatchConfig) {
        self.config = config
        self.engine = GameEngine(state: .initial(config: config))
    }

    var state: GameState {
        engine.state
    }

    // A zero vector is treated as "no input" so a released joystick does not force
    // the striker through the half clamp every frame (matches the previous scene).
    func setHomeInput(moveVector: Vector2?) {
        if let moveVector, moveVector != .zero {
            homeMoveVector = moveVector
        } else {
            homeMoveVector = nil
        }
    }

    // Queue a skill for the local (home) player; consumed by the next fixed step.
    func activateHomeSkill(_ skill: SkillID) {
        pendingSkillActivations.insert(skill)
    }

    // Accumulate the real frame delta and drain it in fixed 1/tickRate steps, so the
    // simulation advances at a frame-rate-independent rate. The move vector is applied
    // to every step; a pending skill activation is applied to only the first step and
    // then cleared, so it fires once even across a catch-up burst. If no step runs
    // (delta shorter than one step), the pending activation carries over to next time.
    @discardableResult
    func advance(deltaTime: TimeInterval) -> MatchSnapshot {
        let fixedDelta = 1.0 / config.tickRate
        accumulatedTime += max(0, deltaTime)

        var steps = 0
        while accumulatedTime >= fixedDelta, steps < Self.maxCatchUpSteps {
            let activations = steps == 0 ? pendingSkillActivations : []
            engine.update(deltaTime: fixedDelta, inputs: homeInputs(activatedSkills: activations))
            if steps == 0 {
                pendingSkillActivations.removeAll()
            }
            accumulatedTime -= fixedDelta
            tick += 1
            steps += 1
        }

        // Hit the cap: drop the remaining backlog instead of letting it grow forever.
        if steps == Self.maxCatchUpSteps {
            accumulatedTime = 0
        }

        return MatchSnapshot(tick: tick, state: engine.state, isAuthoritative: true)
    }

    // Build the home input for one fixed step. Returns no input only when there is
    // neither movement nor a skill activation to apply.
    private func homeInputs(activatedSkills: Set<SkillID>) -> [PlayerInput] {
        guard homeMoveVector != nil || !activatedSkills.isEmpty else {
            return []
        }
        return [PlayerInput(playerId: .home, moveVector: homeMoveVector, activatedSkills: activatedSkills)]
    }
}
