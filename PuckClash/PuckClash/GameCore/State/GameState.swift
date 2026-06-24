import Foundation

enum PlayerID: Equatable {
    case home
    case away
}

enum PlayerSide: Equatable {
    case home
    case away
}

struct PlayerState: Equatable {
    let id: PlayerID
    let side: PlayerSide
    var position: Vector2
    var velocity: Vector2
}

struct PuckState: Equatable {
    var position: Vector2
    var velocity: Vector2
}

struct ScoreState: Equatable {
    var home: Int
    var away: Int

    static let zero = ScoreState(home: 0, away: 0)
}

enum MatchPhase: Equatable {
    case ready
    case running
    case finished
}

struct MatchConfig: Equatable {
    let rinkSize: Vector2
    let matchDuration: TimeInterval
    let playerSpeed: Double
    let goalMouthHalfHeight: Double

    init(
        rinkSize: Vector2,
        matchDuration: TimeInterval,
        playerSpeed: Double,
        goalMouthHalfHeight: Double? = nil
    ) {
        self.rinkSize = rinkSize
        self.matchDuration = matchDuration
        self.playerSpeed = playerSpeed
        self.goalMouthHalfHeight = goalMouthHalfHeight ?? rinkSize.y * 0.2
    }

    var rinkCenter: Vector2 {
        Vector2(x: rinkSize.x * 0.5, y: rinkSize.y * 0.5)
    }

    var leftGoalBoundaryX: Double {
        0
    }

    var rightGoalBoundaryX: Double {
        rinkSize.x
    }

    var goalMouthMinY: Double {
        rinkCenter.y - goalMouthHalfHeight
    }

    var goalMouthMaxY: Double {
        rinkCenter.y + goalMouthHalfHeight
    }

    static let standard = MatchConfig(
        rinkSize: Vector2(x: 640, y: 360),
        matchDuration: 180,
        playerSpeed: 160,
        goalMouthHalfHeight: 72
    )
}

struct GameState: Equatable {
    let config: MatchConfig
    var phase: MatchPhase
    var score: ScoreState
    var remainingTime: TimeInterval
    var homePlayer: PlayerState
    var awayPlayer: PlayerState
    var puck: PuckState

    static func initial(config: MatchConfig = .standard) -> GameState {
        GameState(
            config: config,
            phase: .ready,
            score: .zero,
            remainingTime: config.matchDuration,
            homePlayer: PlayerState(
                id: .home,
                side: .home,
                position: Vector2(x: config.rinkSize.x * 0.25, y: config.rinkSize.y * 0.5),
                velocity: .zero
            ),
            awayPlayer: PlayerState(
                id: .away,
                side: .away,
                position: Vector2(x: config.rinkSize.x * 0.75, y: config.rinkSize.y * 0.5),
                velocity: .zero
            ),
            puck: PuckState(
                position: config.rinkCenter,
                velocity: .zero
            )
        )
    }
}
