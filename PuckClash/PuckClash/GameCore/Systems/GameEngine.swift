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
        // No movement, shooting, contest, puck update, pickup, or goal happens
        // on this frame; time expiry wins over a same-frame goal.
        if state.remainingTime == 0 {
            state.phase = .finished
            return
        }

        state.contestCooldownRemaining = max(0, state.contestCooldownRemaining - deltaTime)

        let homeInput = latestInput(for: .home, in: inputs)
        let awayInput = latestInput(for: .away, in: inputs) ?? awayCPUInput()

        state.homePlayer = updatedPlayer(state.homePlayer, input: homeInput, deltaTime: deltaTime)
        state.awayPlayer = updatedPlayer(state.awayPlayer, input: awayInput, deltaTime: deltaTime)

        let homeShot = handleShot(by: .home, input: homeInput)
        let awayShot = handleShot(by: .away, input: awayInput)

        resolveContest()

        switch state.possession {
        case .home:
            carryPuck(by: .home)
        case .away:
            carryPuck(by: .away)
        case .none:
            updatePuck(deltaTime: deltaTime)
        }

        if !homeShot && !awayShot {
            tryPickup()
        }
    }

    private func latestInput(for playerId: PlayerID, in inputs: [PlayerInput]) -> PlayerInput? {
        inputs
            .filter { $0.playerId == playerId }
            .max { $0.timestamp < $1.timestamp }
    }

    private func updatedPlayer(
        _ player: PlayerState,
        input: PlayerInput?,
        deltaTime: TimeInterval
    ) -> PlayerState {
        var updatedPlayer = player
        let direction = input?.moveDirection.normalized ?? .zero
        if direction != .zero {
            updatedPlayer.lastMoveDirection = direction
        }
        updatedPlayer.velocity = direction * state.config.playerSpeed
        updatedPlayer.position = clampedToRink(updatedPlayer.position + updatedPlayer.velocity * deltaTime)
        return updatedPlayer
    }

    // Minimal deterministic away CPU: carry toward the home goal and shoot when
    // close enough, chase the home carrier to contest, or chase the free puck.
    private func awayCPUInput() -> PlayerInput {
        let target: Vector2
        var isShooting = false

        switch state.possession {
        case .away:
            target = state.config.homeGoalCenter
            isShooting = state.awayPlayer.position.x <= cpuShotTriggerX
        case .home:
            target = state.homePlayer.position
        case .none:
            target = state.puck.position
        }

        let toTarget = target - state.awayPlayer.position
        let direction = toTarget.length > Self.cpuArrivalThreshold ? toTarget.normalized : .zero
        return PlayerInput(playerId: .away, moveDirection: direction, isShooting: isShooting)
    }

    private static let cpuArrivalThreshold: Double = 2

    private var cpuShotTriggerX: Double {
        state.config.rinkSize.x * 0.35
    }

    private mutating func handleShot(by side: PlayerSide, input: PlayerInput?) -> Bool {
        guard let input, input.isShooting, state.possession == possession(for: side) else {
            return false
        }

        state.possession = .none
        state.puck.velocity = aimDirection(for: side, preferring: input.moveDirection) * state.config.shotSpeed
        return true
    }

    // A defender close enough to the carrier steals the puck. The cooldown keeps
    // the same pair from trading steals back on every subsequent frame.
    private mutating func resolveContest() {
        guard state.contestCooldownRemaining == 0 else {
            return
        }

        let playerDistance = (state.homePlayer.position - state.awayPlayer.position).length
        guard playerDistance <= state.config.contestRadius else {
            return
        }

        switch state.possession {
        case .home:
            state.possession = .away
        case .away:
            state.possession = .home
        case .none:
            return
        }

        state.contestCooldownRemaining = state.config.contestCooldown
    }

    private mutating func carryPuck(by side: PlayerSide) {
        let carrier = player(for: side)
        let carryDirection = aimDirection(for: side, preferring: .zero)
        state.puck.position = clampedToRink(carrier.position + carryDirection * state.config.puckCarryOffset)
        state.puck.velocity = .zero
    }

    private mutating func tryPickup() {
        guard state.possession == PuckPossession.none else {
            return
        }

        let homeDistance = (state.puck.position - state.homePlayer.position).length
        let awayDistance = (state.puck.position - state.awayPlayer.position).length
        let homeInRange = homeDistance <= state.config.pickupRadius
        let awayInRange = awayDistance <= state.config.pickupRadius

        if homeInRange && (!awayInRange || homeDistance <= awayDistance) {
            state.possession = .home
        } else if awayInRange {
            state.possession = .away
        }
    }

    private func aimDirection(for side: PlayerSide, preferring preferred: Vector2) -> Vector2 {
        let normalizedPreferred = preferred.normalized
        if normalizedPreferred != .zero {
            return normalizedPreferred
        }

        let shooter = player(for: side)
        if shooter.lastMoveDirection != .zero {
            return shooter.lastMoveDirection
        }

        let towardGoal = (opponentGoalCenter(for: side) - shooter.position).normalized
        return towardGoal != .zero ? towardGoal : Vector2(x: side == .home ? 1 : -1, y: 0)
    }

    private func player(for side: PlayerSide) -> PlayerState {
        side == .home ? state.homePlayer : state.awayPlayer
    }

    private func possession(for side: PlayerSide) -> PuckPossession {
        side == .home ? .home : .away
    }

    private func opponentGoalCenter(for side: PlayerSide) -> Vector2 {
        side == .home ? state.config.awayGoalCenter : state.config.homeGoalCenter
    }

    private mutating func updatePuck(deltaTime: TimeInterval) {
        let nextPosition = state.puck.position + state.puck.velocity * deltaTime

        if nextPosition.x <= state.config.leftGoalBoundaryX && isInsideGoalMouth(nextPosition) {
            scoreGoal(for: .away)
            return
        }

        if nextPosition.x >= state.config.rightGoalBoundaryX && isInsideGoalMouth(nextPosition) {
            scoreGoal(for: .home)
            return
        }

        state.puck.position = clampedToRink(nextPosition)
    }

    private func isInsideGoalMouth(_ position: Vector2) -> Bool {
        position.y >= state.config.goalMouthMinY && position.y <= state.config.goalMouthMaxY
    }

    private mutating func scoreGoal(for side: PlayerSide) {
        switch side {
        case .home:
            state.score.home += 1
        case .away:
            state.score.away += 1
        }

        state.puck = PuckState(position: state.config.rinkCenter, velocity: .zero)
        state.possession = .none
    }

    private func clampedToRink(_ position: Vector2) -> Vector2 {
        Vector2(
            x: min(max(position.x, 0), state.config.rinkSize.x),
            y: min(max(position.y, 0), state.config.rinkSize.y)
        )
    }
}
