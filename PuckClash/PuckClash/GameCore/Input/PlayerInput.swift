import Foundation

struct PlayerInput: Equatable {
    let playerId: PlayerID
    // Velocity-style stick input (home). Magnitude is treated as 0...1 and clamped
    // by GameCore. When present it takes precedence over targetPosition.
    let moveVector: Vector2?
    // Absolute-position input (used by the away CPU and legacy callers).
    let targetPosition: Vector2?
    // Skills the player is trying to activate this input (edge-triggered by the caller).
    let activatedSkills: Set<SkillID>
    let timestamp: TimeInterval

    init(
        playerId: PlayerID,
        moveVector: Vector2? = nil,
        targetPosition: Vector2? = nil,
        activatedSkills: Set<SkillID> = [],
        timestamp: TimeInterval = 0
    ) {
        self.playerId = playerId
        self.moveVector = moveVector
        self.targetPosition = targetPosition
        self.activatedSkills = activatedSkills
        self.timestamp = timestamp
    }
}
