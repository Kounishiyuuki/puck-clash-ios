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

        let homeInput = latestInput(for: .home, in: inputs)
        let awayInput = latestInput(for: .away, in: inputs) ?? awayCPUInput()

        state.homePlayer = updatedPlayer(state.homePlayer, input: homeInput, deltaTime: deltaTime)
        state.awayPlayer = updatedPlayer(state.awayPlayer, input: awayInput, deltaTime: deltaTime)

        let shotFired = handleShot(input: homeInput)

        if state.possession == .home {
            carryPuck()
        } else {
            updatePuck(deltaTime: deltaTime)
        }

        if !shotFired {
            tryHomePickup()
        }

        if state.remainingTime == 0 {
            state.phase = .finished
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

    // Minimal deterministic away CPU: chase the free puck, or hold a defensive
    // spot between the home carrier and the away goal when home has possession.
    private func awayCPUInput() -> PlayerInput {
        let target: Vector2
        if state.possession == .home {
            target = (state.homePlayer.position + state.config.awayGoalCenter) * 0.5
        } else {
            target = state.puck.position
        }

        let toTarget = target - state.awayPlayer.position
        let direction = toTarget.length > Self.cpuArrivalThreshold ? toTarget.normalized : .zero
        return PlayerInput(playerId: .away, moveDirection: direction)
    }

    private static let cpuArrivalThreshold: Double = 2

    private mutating func handleShot(input: PlayerInput?) -> Bool {
        guard let input, input.isShooting, state.possession == .home else {
            return false
        }

        state.possession = .none
        state.puck.velocity = homeAimDirection(preferring: input.moveDirection) * state.config.shotSpeed
        return true
    }

    private mutating func carryPuck() {
        let carryDirection = homeAimDirection(preferring: .zero)
        state.puck.position = clampedToRink(
            state.homePlayer.position + carryDirection * state.config.puckCarryOffset
        )
        state.puck.velocity = .zero
    }

    private mutating func tryHomePickup() {
        guard state.possession == PuckPossession.none else {
            return
        }

        if (state.puck.position - state.homePlayer.position).length <= state.config.pickupRadius {
            state.possession = .home
        }
    }

    private func homeAimDirection(preferring preferred: Vector2) -> Vector2 {
        let normalizedPreferred = preferred.normalized
        if normalizedPreferred != .zero {
            return normalizedPreferred
        }

        if state.homePlayer.lastMoveDirection != .zero {
            return state.homePlayer.lastMoveDirection
        }

        let towardGoal = (state.config.awayGoalCenter - state.homePlayer.position).normalized
        return towardGoal != .zero ? towardGoal : Vector2(x: 1, y: 0)
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
