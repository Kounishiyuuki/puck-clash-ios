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

    // Match winner by final score; nil means a draw. Owned by GameCore so the
    // presentation layer only renders the outcome, never decides it.
    var winner: PlayerSide? {
        if home > away {
            return .home
        }
        if away > home {
            return .away
        }
        return nil
    }
}

enum MatchPhase: Equatable {
    case ready
    case running
    case finished
}

// Vertical air-hockey board: home defends the bottom (y = 0) and attacks the top
// goal (y = rinkSize.y); away is the mirror. Goals are an X-range mouth on the
// top/bottom edges; the left/right edges are always walls.
struct MatchConfig: Equatable {
    let rinkSize: Vector2
    let matchDuration: TimeInterval
    let strikerMaxSpeed: Double
    let goalMouthHalfWidth: Double
    let strikerRadius: Double
    let puckRadius: Double
    let strikerHitRestitution: Double
    let wallRestitution: Double
    let puckDamping: Double
    let puckStopSpeed: Double

    init(
        rinkSize: Vector2,
        matchDuration: TimeInterval,
        strikerMaxSpeed: Double,
        goalMouthHalfWidth: Double? = nil,
        strikerRadius: Double = 26,
        puckRadius: Double = 14,
        strikerHitRestitution: Double = 1.0,
        wallRestitution: Double = 1.0,
        puckDamping: Double = 1.0,
        puckStopSpeed: Double = 0
    ) {
        self.rinkSize = rinkSize
        self.matchDuration = matchDuration
        self.strikerMaxSpeed = strikerMaxSpeed
        self.goalMouthHalfWidth = goalMouthHalfWidth ?? rinkSize.x * 0.3
        self.strikerRadius = strikerRadius
        self.puckRadius = puckRadius
        self.strikerHitRestitution = strikerHitRestitution
        self.wallRestitution = wallRestitution
        self.puckDamping = puckDamping
        self.puckStopSpeed = puckStopSpeed
    }

    var rinkCenter: Vector2 {
        Vector2(x: rinkSize.x * 0.5, y: rinkSize.y * 0.5)
    }

    var bottomGoalBoundaryY: Double {
        0
    }

    var topGoalBoundaryY: Double {
        rinkSize.y
    }

    var goalMouthMinX: Double {
        rinkCenter.x - goalMouthHalfWidth
    }

    var goalMouthMaxX: Double {
        rinkCenter.x + goalMouthHalfWidth
    }

    var homeStartPosition: Vector2 {
        Vector2(x: rinkCenter.x, y: rinkSize.y * 0.2)
    }

    var awayStartPosition: Vector2 {
        Vector2(x: rinkCenter.x, y: rinkSize.y * 0.8)
    }

    static let standard = MatchConfig(
        rinkSize: Vector2(x: 360, y: 640),
        matchDuration: 180,
        strikerMaxSpeed: 750,
        goalMouthHalfWidth: 96,
        strikerRadius: 30,
        puckRadius: 16,
        strikerHitRestitution: 0.85,
        puckDamping: 0.5,
        puckStopSpeed: 6
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
                position: config.homeStartPosition,
                velocity: .zero
            ),
            awayPlayer: PlayerState(
                id: .away,
                side: .away,
                position: config.awayStartPosition,
                velocity: .zero
            ),
            puck: PuckState(
                position: config.rinkCenter,
                velocity: .zero
            )
        )
    }
}
