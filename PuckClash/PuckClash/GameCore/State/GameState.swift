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
    // Simulation step rate (Hz). The engine still updates one variable step at a
    // time; sessions convert real frame time into fixed steps of 1/tickRate so the
    // simulation is frame-rate independent, in preparation for online play.
    let tickRate: Double

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
        puckStopSpeed: Double = 0,
        tickRate: Double = 60
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
        self.tickRate = tickRate
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

    // Wide board (500x640) so a width-first layout fills the screen width while
    // leaving vertical room for the HUD / control bands; goal mouth keeps its ratio.
    static let standard = MatchConfig(
        rinkSize: Vector2(x: 500, y: 640),
        matchDuration: 180,
        strikerMaxSpeed: 700,
        goalMouthHalfWidth: 133,
        strikerRadius: 30,
        puckRadius: 16,
        strikerHitRestitution: 0.75,
        puckDamping: 0.62,
        puckStopSpeed: 7
    )
}

enum MapID: String, CaseIterable, Equatable {
    case classic
    case wide
    case speed
}

// A selectable map is just a named MatchConfig preset. All values are symmetric
// (MatchConfig has no per-side fields), so no map favors one player — important
// for future online fairness. Shared by CPU and (later) online match flows.
struct MapDefinition: Equatable, Identifiable {
    let id: MapID
    let displayName: String
    let summary: String
    let config: MatchConfig

    static let classic = MapDefinition(
        id: .classic,
        displayName: "Classic",
        summary: "Balanced standard rink",
        config: .standard
    )

    static let wide = MapDefinition(
        id: .wide,
        displayName: "Wide",
        summary: "Wider board, more shooting angles",
        config: MatchConfig(
            rinkSize: Vector2(x: 560, y: 640),
            matchDuration: 180,
            strikerMaxSpeed: 700,
            goalMouthHalfWidth: 150,
            strikerRadius: 30,
            puckRadius: 16,
            strikerHitRestitution: 0.75,
            puckDamping: 0.62,
            puckStopSpeed: 7
        )
    )

    static let speed = MapDefinition(
        id: .speed,
        displayName: "Speed",
        summary: "Faster strikers and a livelier puck",
        config: MatchConfig(
            rinkSize: Vector2(x: 500, y: 640),
            matchDuration: 180,
            strikerMaxSpeed: 820,
            goalMouthHalfWidth: 133,
            strikerRadius: 28,
            puckRadius: 15,
            strikerHitRestitution: 0.85,
            puckDamping: 0.72,
            puckStopSpeed: 6
        )
    )

    static let all: [MapDefinition] = [.classic, .wide, .speed]
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

// One simulation frame handed from a MatchSession to the presentation layer. `state`
// is what gets rendered; `tick` is how many fixed steps the simulation has advanced
// (see LocalMatchSession); `isAuthoritative` marks whether this is confirmed
// truth for the current session.
// No transport/timing fields live here, so GameCore stays Foundation-only.
struct MatchSnapshot: Equatable {
    let tick: Int
    let state: GameState
    let isAuthoritative: Bool
}
