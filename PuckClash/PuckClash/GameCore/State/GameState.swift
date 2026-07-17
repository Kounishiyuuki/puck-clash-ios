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

// Deterministic match flow: an opening countdown, normal play, a short pause after
// each goal, and the final buzzer. During countdown / goalPause only
// GameState.phaseRemaining advances (by the fixed step) — the match clock, players,
// puck, skills and the CPU decision timer are all frozen.
enum MatchPhase: Equatable {
    case countdown
    case running
    case goalPause
    case finished
}

// nonisolated because the build default is main-actor isolation: without it SkillID's
// synthesized Hashable conformance would be main-actor-isolated, and hashing Set<SkillID>
// in the nonisolated GameEngine / PlayerInput is an error under the Swift 6 language mode.
// GameCore is pure, isolation-free data, so this is the correct home for the annotation.
nonisolated enum SkillID: CaseIterable, Hashable {
    case boost
    case block
    case shot
}

enum SkillPhase: Equatable {
    case ready
    case active
    case cooldown
}

// Runtime state of a single skill: how long its effect and its cooldown still have to
// run. Advanced by GameEngine each fixed step, so it lives inside GameState and travels
// in MatchSnapshot.state. `ready` is the initial, unused state.
struct SkillState: Equatable {
    var activeRemaining: TimeInterval
    var cooldownRemaining: TimeInterval

    static let ready = SkillState(activeRemaining: 0, cooldownRemaining: 0)

    var phase: SkillPhase {
        if activeRemaining > 0 {
            return .active
        }
        if cooldownRemaining > 0 {
            return .cooldown
        }
        return .ready
    }
}

// Tunable Boost skill parameters. Held by MatchConfig so both sides of a match agree
// on the same values (important for future non-local sessions).
struct BoostConfig: Equatable {
    var speedMultiplier: Double = 1.6
    var duration: TimeInterval = 2.0
    var cooldown: TimeInterval = 6.0
}

// Tunable Shot skill parameters. Like BoostConfig, held by MatchConfig so both sides
// agree on the same values. Shot treats phase == .active as "armed": the first effective
// puck hit within activeDuration is amplified by speedMultiplier, then the skill goes on
// cooldown. If the armed window elapses with no hit, it goes on cooldown unused.
struct ShotConfig: Equatable {
    var speedMultiplier: Double = 1.8
    var activeDuration: TimeInterval = 1.2
    var cooldown: TimeInterval = 7.0
}

// Tunable Block skill parameters. Like the others, held by MatchConfig. Block is a
// duration-type defensive skill (phase == .active means the shield is up): while active a
// horizontal shield sits in front of the defended goal and reflects the puck; it is not
// consumed on a hit, so it can save several pucks before its window elapses into cooldown.
// The shield spans the goal mouth (goalMouthHalfWidth) in x; offsetFromGoal is nil ->
// derived as puckRadius * 4 by the engine so it scales with the puck.
struct BlockConfig: Equatable {
    var duration: TimeInterval = 1.5
    var cooldown: TimeInterval = 8.0
    var offsetFromGoal: Double? = nil
    var restitution: Double = 1.0
}

// Selectable strength of the away CPU. Difficulty only changes how quickly and
// eagerly the CPU decides to use skills (see CPUBehaviorConfig) — never striker
// speed, puck physics, or the skill values themselves. Presentation-facing text
// (display names, descriptions) lives in the UI layer, not here.
enum CPUDifficulty: String, CaseIterable, Equatable {
    case easy
    case normal
    case hard

    var behavior: CPUBehaviorConfig {
        switch self {
        case .easy:
            return .easy
        case .normal:
            return .normal
        case .hard:
            return .hard
        }
    }
}

// Tunable away-CPU skill-decision parameters, held by MatchConfig like the skill
// configs. All values are in simulated time / rink-relative units, so decisions
// stay deterministic and frame-rate independent.
struct CPUBehaviorConfig: Equatable {
    // Seconds of simulated time between CPU skill decisions.
    var decisionInterval: TimeInterval
    // Max predicted time-to-shield (s) the CPU reacts to with Block.
    var blockReactionWindow: TimeInterval
    // Shot contact margin as a multiple of puckRadius.
    var shotContactMarginScale: Double
    // Boost fires when striker-to-puck distance exceeds this fraction of rink height.
    var boostDistanceThresholdFraction: Double

    static let easy = CPUBehaviorConfig(
        decisionInterval: 0.35,
        blockReactionWindow: 0.16,
        shotContactMarginScale: 0.70,
        boostDistanceThresholdFraction: 0.48
    )

    // The default. Softened slightly from the original hardcoded engine values
    // (0.15 / 0.30 / 1.50 / 0.35) so the standard CPU feels less relentless.
    static let normal = CPUBehaviorConfig(
        decisionInterval: 0.18,
        blockReactionWindow: 0.27,
        shotContactMarginScale: 1.35,
        boostDistanceThresholdFraction: 0.38
    )

    static let hard = CPUBehaviorConfig(
        decisionInterval: 0.12,
        blockReactionWindow: 0.34,
        shotContactMarginScale: 1.80,
        boostDistanceThresholdFraction: 0.31
    )
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
    // Boost skill tuning, agreed by both sides of the match.
    let boost: BoostConfig
    // Shot skill tuning, agreed by both sides of the match.
    let shot: ShotConfig
    // Block skill tuning, agreed by both sides of the match.
    let block: BlockConfig
    // Away-CPU skill-decision tuning; Normal by default so existing configs keep
    // the original CPU behaviour.
    let cpuBehavior: CPUBehaviorConfig
    // Opening countdown before play starts. 0 disables it (the match starts running
    // immediately), which is what most engine tests use.
    let openingCountdownDuration: TimeInterval
    // Freeze after each goal before play resumes. 0 disables it (scoring keeps the
    // match running, the pre-phase behaviour).
    let goalPauseDuration: TimeInterval
    // Per-side striker speed multipliers on strikerMaxSpeed (1.0 = the map's base
    // speed). Sides are all GameCore knows: who drives each side (human, CPU,
    // remote player) is decided by whoever builds the config.
    let homeStrikerSpeedScale: Double
    let awayStrikerSpeedScale: Double

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
        tickRate: Double = 60,
        boost: BoostConfig = BoostConfig(),
        shot: ShotConfig = ShotConfig(),
        block: BlockConfig = BlockConfig(),
        cpuBehavior: CPUBehaviorConfig = .normal,
        openingCountdownDuration: TimeInterval = 3.0,
        goalPauseDuration: TimeInterval = 1.0,
        homeStrikerSpeedScale: Double = 1.0,
        awayStrikerSpeedScale: Double = 1.0
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
        self.boost = boost
        self.shot = shot
        self.block = block
        self.cpuBehavior = cpuBehavior
        self.openingCountdownDuration = openingCountdownDuration
        self.goalPauseDuration = goalPauseDuration
        self.homeStrikerSpeedScale = homeStrikerSpeedScale
        self.awayStrikerSpeedScale = awayStrikerSpeedScale
    }

    // The same match with per-side striker speed multipliers replaced; everything
    // else (map geometry, physics, skills, CPU behaviour) is untouched.
    func withStrikerSpeedScales(home: Double, away: Double) -> MatchConfig {
        MatchConfig(
            rinkSize: rinkSize,
            matchDuration: matchDuration,
            strikerMaxSpeed: strikerMaxSpeed,
            goalMouthHalfWidth: goalMouthHalfWidth,
            strikerRadius: strikerRadius,
            puckRadius: puckRadius,
            strikerHitRestitution: strikerHitRestitution,
            wallRestitution: wallRestitution,
            puckDamping: puckDamping,
            puckStopSpeed: puckStopSpeed,
            tickRate: tickRate,
            boost: boost,
            shot: shot,
            block: block,
            cpuBehavior: cpuBehavior,
            openingCountdownDuration: openingCountdownDuration,
            goalPauseDuration: goalPauseDuration,
            homeStrikerSpeedScale: home,
            awayStrikerSpeedScale: away
        )
    }

    // The same match tuned for a CPU difficulty: geometry, physics and skill values
    // unchanged, only the CPU's decision behaviour replaced.
    func withCPUBehavior(_ cpuBehavior: CPUBehaviorConfig) -> MatchConfig {
        MatchConfig(
            rinkSize: rinkSize,
            matchDuration: matchDuration,
            strikerMaxSpeed: strikerMaxSpeed,
            goalMouthHalfWidth: goalMouthHalfWidth,
            strikerRadius: strikerRadius,
            puckRadius: puckRadius,
            strikerHitRestitution: strikerHitRestitution,
            wallRestitution: wallRestitution,
            puckDamping: puckDamping,
            puckStopSpeed: puckStopSpeed,
            tickRate: tickRate,
            boost: boost,
            shot: shot,
            block: block,
            cpuBehavior: cpuBehavior,
            openingCountdownDuration: openingCountdownDuration,
            goalPauseDuration: goalPauseDuration,
            homeStrikerSpeedScale: homeStrikerSpeedScale,
            awayStrikerSpeedScale: awayStrikerSpeedScale
        )
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
        goalMouthHalfWidth: 118,
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
        displayName: "クラシック",
        summary: "標準的な広さとスピードの基本マップ",
        config: .standard
    )

    static let wide = MapDefinition(
        id: .wide,
        displayName: "ワイド",
        summary: "横幅が広く、角度を使った打ち返しがしやすいマップ",
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
        displayName: "スピード",
        summary: "パックとストライカーの反応が速いテンポ重視のマップ",
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
    var homeBoost: SkillState
    var awayBoost: SkillState
    var homeShot: SkillState
    var awayShot: SkillState
    var homeBlock: SkillState
    var awayBlock: SkillState
    // Countdown until the away CPU next re-evaluates which skill to use. Lives in GameState
    // (not the engine) so the CPU decision cadence is reproducible from a snapshot and stays
    // deterministic; advanced by GameEngine each fixed step. Not a wall-clock time.
    var awaySkillDecisionRemaining: TimeInterval
    // Time left in the current countdown / goalPause phase; 0 while running or finished.
    // The only value the engine advances during those freeze phases.
    var phaseRemaining: TimeInterval
    // Which side scored most recently; nil until the first goal. Lets the presentation
    // layer attribute a goal pause without diffing scores.
    var lastScorer: PlayerSide?

    static func initial(config: MatchConfig = .standard) -> GameState {
        GameState(
            config: config,
            phase: config.openingCountdownDuration > 0 ? .countdown : .running,
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
            ),
            homeBoost: .ready,
            awayBoost: .ready,
            homeShot: .ready,
            awayShot: .ready,
            homeBlock: .ready,
            awayBlock: .ready,
            awaySkillDecisionRemaining: 0,
            phaseRemaining: config.openingCountdownDuration,
            lastScorer: nil
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
