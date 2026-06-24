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
        let awayInput = latestInput(for: .away, in: inputs)

        state.homePlayer = updatedPlayer(state.homePlayer, input: homeInput, deltaTime: deltaTime)
        state.awayPlayer = updatedPlayer(state.awayPlayer, input: awayInput, deltaTime: deltaTime)

        state.puck.position = clampedToRink(state.puck.position + state.puck.velocity * deltaTime)

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
        updatedPlayer.velocity = direction * state.config.playerSpeed
        updatedPlayer.position = clampedToRink(updatedPlayer.position + updatedPlayer.velocity * deltaTime)
        return updatedPlayer
    }

    private func clampedToRink(_ position: Vector2) -> Vector2 {
        Vector2(
            x: min(max(position.x, 0), state.config.rinkSize.x),
            y: min(max(position.y, 0), state.config.rinkSize.y)
        )
    }
}
