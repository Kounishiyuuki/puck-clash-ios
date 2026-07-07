import Foundation

struct PlayerInput: Equatable {
    let playerId: PlayerID
    // Velocity-style stick input (home). Magnitude is treated as 0...1 and clamped
    // by GameCore. When present it takes precedence over targetPosition.
    let moveVector: Vector2?
    // Absolute-position input (used by the away CPU and legacy callers).
    let targetPosition: Vector2?
    let timestamp: TimeInterval

    init(
        playerId: PlayerID,
        moveVector: Vector2? = nil,
        targetPosition: Vector2? = nil,
        timestamp: TimeInterval = 0
    ) {
        self.playerId = playerId
        self.moveVector = moveVector
        self.targetPosition = targetPosition
        self.timestamp = timestamp
    }
}
