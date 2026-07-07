import Foundation

struct PlayerInput: Equatable {
    let playerId: PlayerID
    let targetPosition: Vector2?
    let timestamp: TimeInterval

    init(
        playerId: PlayerID,
        targetPosition: Vector2? = nil,
        timestamp: TimeInterval = 0
    ) {
        self.playerId = playerId
        self.targetPosition = targetPosition
        self.timestamp = timestamp
    }
}
