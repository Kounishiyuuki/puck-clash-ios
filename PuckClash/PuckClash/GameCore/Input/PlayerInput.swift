import Foundation

struct PlayerInput: Equatable {
    let playerId: PlayerID
    let moveDirection: Vector2
    let isShooting: Bool
    let timestamp: TimeInterval

    init(
        playerId: PlayerID,
        moveDirection: Vector2 = .zero,
        isShooting: Bool = false,
        timestamp: TimeInterval = 0
    ) {
        self.playerId = playerId
        self.moveDirection = moveDirection
        self.isShooting = isShooting
        self.timestamp = timestamp
    }
}
