import SpriteKit

final class RinkScene: SKScene {
    // The scene drives a MatchSession (local or, later, online) rather than owning a
    // GameEngine. Home input is set on the session by the SwiftUI layer, not here.
    private let session: MatchSession
    // Handlers are set by the SwiftUI layer after creation; the scene stays free of
    // SwiftUI and holds no game rules.
    var onFinished: ((ScoreState) -> Void)?
    var onHUDChange: ((MatchHUD) -> Void)?
    // App-level pause, set by the match controller. While true the scene keeps
    // rendering the current state but never advances the session; pausing is a
    // presentation/session concern, so no paused flag exists in GameCore.
    var isMatchPaused = false
    private var hasNotifiedFinish = false
    private var lastHUD: MatchHUD?
    private var lastScore: ScoreState?
    private var lastPuckSpeed: Double = 0
    private var lastBoostPhase: SkillPhase = .ready
    private var lastShotPhase: SkillPhase = .ready
    private var lastHomeBlockPhase: SkillPhase = .ready
    private var lastAwayBoostPhase: SkillPhase = .ready
    private var lastAwayShotPhase: SkillPhase = .ready
    private var lastAwayBlockPhase: SkillPhase = .ready
    private var lastUpdateTime: TimeInterval?

    private let rinkNode = SKShapeNode()
    private let iceBandNode = SKShapeNode()
    private let centerLineNode = SKShapeNode()
    private let centerCircleNode = SKShapeNode()
    private let topGoalAreaNode = SKShapeNode()
    private let bottomGoalAreaNode = SKShapeNode()
    private let topGoalBarNode = SKShapeNode()
    private let bottomGoalBarNode = SKShapeNode()
    private let puckShadowNode = SKShapeNode()
    private let homeStrikerNode = SKShapeNode()
    private let homeStrikerInnerNode = SKShapeNode()
    private let homeBoostRingNode = SKShapeNode()
    private let homeShotRingNode = SKShapeNode()
    private let awayStrikerNode = SKShapeNode()
    private let awayStrikerInnerNode = SKShapeNode()
    private let puckNode = SKShapeNode()
    private let puckHighlightNode = SKShapeNode()
    private let homeBlockShieldNode = SKShapeNode()
    private let awayBoostRingNode = SKShapeNode()
    private let awayShotRingNode = SKShapeNode()
    private let awayBlockShieldNode = SKShapeNode()

    private let homeColor = SKColor(red: 0.16, green: 0.52, blue: 1.0, alpha: 1)
    private let awayColor = SKColor(red: 0.95, green: 0.28, blue: 0.34, alpha: 1)
    private let lineColor = SKColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1)

    // SpriteKit owns no match rules; it drives a MatchSession, reports the final score
    // (onFinished) and, at most once per changed value, the HUD snapshot (onHUDChange).
    init(session: MatchSession) {
        self.session = session
        let rinkSize = session.config.rinkSize
        super.init(size: CGSize(width: rinkSize.x, height: rinkSize.y))
    }

    required init?(coder aDecoder: NSCoder) {
        self.session = LocalMatchSession(config: .standard)
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.03, green: 0.05, blue: 0.09, alpha: 1)
        scaleMode = .resizeFill
        buildScene()
        render(session.state)
        publishHUD(session.state, force: true)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        render(session.state)
    }

    override func update(_ currentTime: TimeInterval) {
        let deltaTime = lastUpdateTime.map { currentTime - $0 } ?? 0
        lastUpdateTime = currentTime

        // Paused: keep drawing the current state without advancing the simulation.
        // lastUpdateTime still updates every frame above, so resuming produces a
        // normal one-frame delta instead of the whole paused span as catch-up.
        if isMatchPaused {
            render(session.state)
            return
        }

        // Pass the raw frame delta: the session owns time management now, running the
        // simulation in fixed steps and capping catch-up so a hitch cannot tunnel the
        // puck or trigger a runaway burst of steps. Only the snapshot's state is
        // rendered; the tick is not needed by the scene.
        let state = session.advance(deltaTime: deltaTime).state
        render(state)
        applyFeedback(state)
        publishHUD(state, force: false)
        notifyIfFinished(state)
    }

    // SKScene.update runs on the main thread, so invoking the SwiftUI-provided
    // closures here is safe. Fire onFinished once on the transition to finished.
    private func notifyIfFinished(_ state: GameState) {
        guard !hasNotifiedFinish, state.phase == .finished else {
            return
        }

        hasNotifiedFinish = true
        onFinished?(state.score)
    }

    // Only push a HUD snapshot when a displayed value actually changed, so SwiftUI
    // is not re-rendered every frame.
    private func publishHUD(_ state: GameState, force: Bool) {
        // Derive the home Boost button state from the simulation. A coarse whole-second
        // value keeps the HUD publishing at the same low frequency as the score/clock.
        let boost = state.homeBoost
        let boostRemainingSeconds: Int
        switch boost.phase {
        case .active:
            boostRemainingSeconds = Int(boost.activeRemaining.rounded(.up))
        case .cooldown:
            boostRemainingSeconds = Int(boost.cooldownRemaining.rounded(.up))
        case .ready:
            boostRemainingSeconds = 0
        }

        // Same coarse whole-second derivation for the Shot button.
        let shot = state.homeShot
        let shotRemainingSeconds: Int
        switch shot.phase {
        case .active:
            shotRemainingSeconds = Int(shot.activeRemaining.rounded(.up))
        case .cooldown:
            shotRemainingSeconds = Int(shot.cooldownRemaining.rounded(.up))
        case .ready:
            shotRemainingSeconds = 0
        }

        // Same coarse whole-second derivation for the Block button.
        let block = state.homeBlock
        let blockRemainingSeconds: Int
        switch block.phase {
        case .active:
            blockRemainingSeconds = Int(block.activeRemaining.rounded(.up))
        case .cooldown:
            blockRemainingSeconds = Int(block.cooldownRemaining.rounded(.up))
        case .ready:
            blockRemainingSeconds = 0
        }

        let snapshot = MatchHUD(
            homeScore: state.score.home,
            awayScore: state.score.away,
            remainingSeconds: Int(state.remainingTime.rounded(.up)),
            matchPhase: state.phase,
            phaseRemainingSeconds: Int(state.phaseRemaining.rounded(.up)),
            lastScorer: state.lastScorer,
            boostPhase: boost.phase,
            boostRemainingSeconds: boostRemainingSeconds,
            shotPhase: shot.phase,
            shotRemainingSeconds: shotRemainingSeconds,
            blockPhase: block.phase,
            blockRemainingSeconds: blockRemainingSeconds
        )
        if force || snapshot != lastHUD {
            lastHUD = snapshot
            onHUDChange?(snapshot)
        }
    }

    // Lightweight, render-only feedback derived from observed state changes.
    // No rule state is added to GameCore.
    private func applyFeedback(_ state: GameState) {
        if let previous = lastScore {
            if state.score.home > previous.home {
                flash(topGoalAreaNode)
                flash(topGoalBarNode)
            }
            if state.score.away > previous.away {
                flash(bottomGoalAreaNode)
                flash(bottomGoalBarNode)
            }
        }
        lastScore = state.score

        let speed = state.puck.velocity.length
        if speed > lastPuckSpeed + 40 {
            puckNode.run(
                .sequence([.scale(to: 1.35, duration: 0.06), .scale(to: 1.0, duration: 0.12)]),
                withKey: "hitPulse"
            )
        }
        lastPuckSpeed = speed

        // Boost feedback on the home striker: a ring while active, a pulse when it
        // starts. Driven entirely by observed phase transitions, no rule state here.
        let boostPhase = state.homeBoost.phase
        if boostPhase == .active, lastBoostPhase != .active {
            homeStrikerNode.run(
                .sequence([.scale(to: 1.18, duration: 0.08), .scale(to: 1.0, duration: 0.14)]),
                withKey: "boostPulse"
            )
            homeBoostRingNode.removeAction(forKey: "boostRing")
            homeBoostRingNode.run(.fadeAlpha(to: 0.9, duration: 0.12), withKey: "boostRing")
        } else if boostPhase != .active, lastBoostPhase == .active {
            homeBoostRingNode.removeAction(forKey: "boostRing")
            homeBoostRingNode.run(.fadeAlpha(to: 0, duration: 0.18), withKey: "boostRing")
        }
        lastBoostPhase = boostPhase

        // Shot feedback: an aim ring while armed, faded out once it fires or expires. Uses
        // its own node/key so it never fights the boost ring; the extra punch on a landed
        // shot comes for free from the puck speed-jump pulse above.
        let shotPhase = state.homeShot.phase
        if shotPhase == .active, lastShotPhase != .active {
            homeShotRingNode.removeAction(forKey: "shotRing")
            homeShotRingNode.run(.fadeAlpha(to: 0.85, duration: 0.12), withKey: "shotRing")
        } else if shotPhase != .active, lastShotPhase == .active {
            homeShotRingNode.removeAction(forKey: "shotRing")
            homeShotRingNode.run(.fadeAlpha(to: 0, duration: 0.18), withKey: "shotRing")
        }
        lastShotPhase = shotPhase

        // Block feedback: the home goal shield is shown while defending and faded out when
        // it ends. Its own node/key keeps it independent of the boost/shot rings.
        let homeBlockPhase = state.homeBlock.phase
        if homeBlockPhase == .active, lastHomeBlockPhase != .active {
            homeBlockShieldNode.removeAction(forKey: "blockShield")
            homeBlockShieldNode.run(.fadeAlpha(to: 0.85, duration: 0.12), withKey: "blockShield")
        } else if homeBlockPhase != .active, lastHomeBlockPhase == .active {
            homeBlockShieldNode.removeAction(forKey: "blockShield")
            homeBlockShieldNode.run(.fadeAlpha(to: 0, duration: 0.18), withKey: "blockShield")
        }
        lastHomeBlockPhase = homeBlockPhase

        // Away CPU skill feedback: render-only mirrors of the home effects, driven the
        // same way by observed phase transitions. Each has its own node and action key,
        // so a state change on one never cancels another (Boost and Shot can be active
        // at the same time under the CPU's decision rules).
        let awayBoostPhase = state.awayBoost.phase
        if awayBoostPhase == .active, lastAwayBoostPhase != .active {
            awayStrikerNode.run(
                .sequence([.scale(to: 1.18, duration: 0.08), .scale(to: 1.0, duration: 0.14)]),
                withKey: "awayBoostPulse"
            )
            awayBoostRingNode.removeAction(forKey: "awayBoostRing")
            awayBoostRingNode.run(.fadeAlpha(to: 0.9, duration: 0.12), withKey: "awayBoostRing")
        } else if awayBoostPhase != .active, lastAwayBoostPhase == .active {
            awayBoostRingNode.removeAction(forKey: "awayBoostRing")
            awayBoostRingNode.run(.fadeAlpha(to: 0, duration: 0.18), withKey: "awayBoostRing")
        }
        lastAwayBoostPhase = awayBoostPhase

        let awayShotPhase = state.awayShot.phase
        if awayShotPhase == .active, lastAwayShotPhase != .active {
            awayShotRingNode.removeAction(forKey: "awayShotPulse")
            awayShotRingNode.run(
                .sequence([.scale(to: 1.12, duration: 0.08), .scale(to: 1.0, duration: 0.14)]),
                withKey: "awayShotPulse"
            )
            awayShotRingNode.removeAction(forKey: "awayShotRing")
            awayShotRingNode.run(.fadeAlpha(to: 0.85, duration: 0.12), withKey: "awayShotRing")
        } else if awayShotPhase != .active, lastAwayShotPhase == .active {
            awayShotRingNode.removeAction(forKey: "awayShotRing")
            awayShotRingNode.run(.fadeAlpha(to: 0, duration: 0.18), withKey: "awayShotRing")
        }
        lastAwayShotPhase = awayShotPhase

        let awayBlockPhase = state.awayBlock.phase
        if awayBlockPhase == .active, lastAwayBlockPhase != .active {
            awayBlockShieldNode.removeAction(forKey: "awayBlockShield")
            awayBlockShieldNode.run(.fadeAlpha(to: 0.85, duration: 0.12), withKey: "awayBlockShield")
        } else if awayBlockPhase != .active, lastAwayBlockPhase == .active {
            awayBlockShieldNode.removeAction(forKey: "awayBlockShield")
            awayBlockShieldNode.run(.fadeAlpha(to: 0, duration: 0.18), withKey: "awayBlockShield")
        }
        lastAwayBlockPhase = awayBlockPhase
    }

    private func flash(_ node: SKShapeNode) {
        node.removeAction(forKey: "flash")
        let base = node.alpha
        node.run(
            .sequence([.fadeAlpha(to: 1.0, duration: 0.06), .fadeAlpha(to: base, duration: 0.22)]),
            withKey: "flash"
        )
    }

    private func buildScene() {
        removeAllChildren()

        rinkNode.strokeColor = lineColor.withAlphaComponent(0.9)
        rinkNode.lineWidth = 3
        rinkNode.fillColor = SKColor(red: 0.10, green: 0.20, blue: 0.32, alpha: 1)
        addChild(rinkNode)

        iceBandNode.strokeColor = .clear
        iceBandNode.fillColor = SKColor(red: 0.16, green: 0.28, blue: 0.42, alpha: 0.5)
        addChild(iceBandNode)

        bottomGoalAreaNode.strokeColor = .clear
        bottomGoalAreaNode.fillColor = homeColor.withAlphaComponent(0.16)
        addChild(bottomGoalAreaNode)

        topGoalAreaNode.strokeColor = .clear
        topGoalAreaNode.fillColor = awayColor.withAlphaComponent(0.16)
        addChild(topGoalAreaNode)

        centerLineNode.strokeColor = lineColor.withAlphaComponent(0.45)
        centerLineNode.lineWidth = 2
        addChild(centerLineNode)

        centerCircleNode.strokeColor = lineColor.withAlphaComponent(0.5)
        centerCircleNode.lineWidth = 2
        centerCircleNode.fillColor = lineColor.withAlphaComponent(0.06)
        addChild(centerCircleNode)

        configureBar(bottomGoalBarNode, color: homeColor)
        configureBar(topGoalBarNode, color: awayColor)

        puckShadowNode.strokeColor = .clear
        puckShadowNode.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.35)
        addChild(puckShadowNode)

        configureStriker(homeStrikerNode, inner: homeStrikerInnerNode, color: homeColor)
        configureStriker(awayStrikerNode, inner: awayStrikerInnerNode, color: awayColor)

        // Hidden until Boost is active; a glowing ring around the home striker.
        homeBoostRingNode.strokeColor = homeColor
        homeBoostRingNode.lineWidth = 3
        homeBoostRingNode.fillColor = .clear
        homeBoostRingNode.alpha = 0
        homeStrikerNode.addChild(homeBoostRingNode)

        // Hidden until Shot is armed; an outer aim ring in the attacking (away) colour.
        // A larger radius than the boost ring so the two can show at once without merging.
        homeShotRingNode.strokeColor = awayColor
        homeShotRingNode.lineWidth = 3
        homeShotRingNode.fillColor = .clear
        homeShotRingNode.alpha = 0
        homeStrikerNode.addChild(homeShotRingNode)

        // Hidden until the away CPU's Boost is active; a glowing ring around the away
        // striker, mirroring the home boost ring but as its own node.
        awayBoostRingNode.strokeColor = awayColor
        awayBoostRingNode.lineWidth = 3
        awayBoostRingNode.fillColor = .clear
        awayBoostRingNode.alpha = 0
        awayStrikerNode.addChild(awayBoostRingNode)

        // Hidden until the away CPU's Shot is armed; a ticked reticle (ring + four
        // marks), thinner and larger than the boost ring so the two read as distinct
        // even when both are active at once.
        awayShotRingNode.strokeColor = awayColor
        awayShotRingNode.lineWidth = 2
        awayShotRingNode.fillColor = .clear
        awayShotRingNode.alpha = 0
        awayStrikerNode.addChild(awayShotRingNode)

        // Hidden until Block is active; a home-colour bar in front of the bottom goal.
        homeBlockShieldNode.strokeColor = homeColor
        homeBlockShieldNode.lineWidth = 6
        homeBlockShieldNode.lineCap = .round
        homeBlockShieldNode.alpha = 0
        addChild(homeBlockShieldNode)

        // Hidden until the away CPU's Block is active; an away-colour bar in front of
        // the top goal, mirroring the home shield.
        awayBlockShieldNode.strokeColor = awayColor
        awayBlockShieldNode.lineWidth = 6
        awayBlockShieldNode.lineCap = .round
        awayBlockShieldNode.alpha = 0
        addChild(awayBlockShieldNode)

        puckNode.fillColor = SKColor(red: 0.10, green: 0.11, blue: 0.15, alpha: 1)
        puckNode.strokeColor = SKColor(red: 0.85, green: 0.90, blue: 1.0, alpha: 1)
        puckNode.lineWidth = 2.5
        addChild(puckNode)

        puckHighlightNode.strokeColor = .clear
        puckHighlightNode.fillColor = SKColor(white: 1, alpha: 0.35)
        puckNode.addChild(puckHighlightNode)
    }

    private func configureBar(_ node: SKShapeNode, color: SKColor) {
        node.strokeColor = color
        node.lineWidth = 7
        node.lineCap = .round
        addChild(node)
    }

    private func configureStriker(_ node: SKShapeNode, inner: SKShapeNode, color: SKColor) {
        node.fillColor = color
        node.strokeColor = .white
        node.lineWidth = 3
        addChild(node)

        inner.strokeColor = SKColor(white: 1, alpha: 0.7)
        inner.lineWidth = 2
        inner.fillColor = .clear
        node.addChild(inner)
    }

    private func render(_ state: GameState) {
        guard size.width > 0, size.height > 0 else {
            return
        }

        let config = state.config
        let frame = rinkFrame(for: config)
        let scale = frame.width / config.rinkSize.x

        rinkNode.path = CGPath(roundedRect: frame, cornerWidth: 20, cornerHeight: 20, transform: nil)
        iceBandNode.path = CGPath(
            roundedRect: frame.insetBy(dx: frame.width * 0.06, dy: frame.height * 0.03),
            cornerWidth: 16,
            cornerHeight: 16,
            transform: nil
        )

        let midY = scenePoint(for: config.rinkCenter, config: config, rinkFrame: frame).y
        centerLineNode.path = linePath(from: CGPoint(x: frame.minX, y: midY), to: CGPoint(x: frame.maxX, y: midY))
        centerCircleNode.path = CGPath(
            ellipseIn: CGRect(
                x: frame.midX - frame.width * 0.18,
                y: midY - frame.width * 0.18,
                width: frame.width * 0.36,
                height: frame.width * 0.36
            ),
            transform: nil
        )

        let goalMinX = scenePoint(for: Vector2(x: config.goalMouthMinX, y: 0), config: config, rinkFrame: frame).x
        let goalMaxX = scenePoint(for: Vector2(x: config.goalMouthMaxX, y: 0), config: config, rinkFrame: frame).x
        let areaHeight = frame.height * 0.06
        topGoalBarNode.path = linePath(from: CGPoint(x: goalMinX, y: frame.maxY), to: CGPoint(x: goalMaxX, y: frame.maxY))
        bottomGoalBarNode.path = linePath(from: CGPoint(x: goalMinX, y: frame.minY), to: CGPoint(x: goalMaxX, y: frame.minY))
        topGoalAreaNode.path = CGPath(
            rect: CGRect(x: goalMinX, y: frame.maxY - areaHeight, width: goalMaxX - goalMinX, height: areaHeight),
            transform: nil
        )
        bottomGoalAreaNode.path = CGPath(
            rect: CGRect(x: goalMinX, y: frame.minY, width: goalMaxX - goalMinX, height: areaHeight),
            transform: nil
        )

        // Block shield: a bar across the goal mouth at the home shield line (matches the
        // engine's offsetFromGoal / goalMouthHalfWidth). Visibility is driven by alpha.
        let blockOffset = config.block.offsetFromGoal ?? config.puckRadius * 4
        let shieldY = scenePoint(for: Vector2(x: 0, y: blockOffset), config: config, rinkFrame: frame).y
        homeBlockShieldNode.path = linePath(from: CGPoint(x: goalMinX, y: shieldY), to: CGPoint(x: goalMaxX, y: shieldY))

        // Away shield: the engine's line mirrored to the top goal (rinkSize.y - offset),
        // spanning the same goal mouth, so the visual matches the actual reflection line.
        let awayShieldY = scenePoint(
            for: Vector2(x: 0, y: config.rinkSize.y - blockOffset),
            config: config,
            rinkFrame: frame
        ).y
        awayBlockShieldNode.path = linePath(from: CGPoint(x: goalMinX, y: awayShieldY), to: CGPoint(x: goalMaxX, y: awayShieldY))

        let strikerRadius = config.strikerRadius * scale
        let puckRadius = config.puckRadius * scale

        homeStrikerNode.path = discPath(radius: strikerRadius)
        homeStrikerInnerNode.path = discPath(radius: strikerRadius * 0.55)
        homeBoostRingNode.path = discPath(radius: strikerRadius * 1.35)
        homeShotRingNode.path = discPath(radius: strikerRadius * 1.55)
        homeStrikerNode.position = scenePoint(for: state.homePlayer.position, config: config, rinkFrame: frame)

        awayStrikerNode.path = discPath(radius: strikerRadius)
        awayStrikerInnerNode.path = discPath(radius: strikerRadius * 0.55)
        awayBoostRingNode.path = discPath(radius: strikerRadius * 1.35)
        awayShotRingNode.path = reticlePath(radius: strikerRadius * 1.6)
        awayStrikerNode.position = scenePoint(for: state.awayPlayer.position, config: config, rinkFrame: frame)

        let puckPoint = scenePoint(for: state.puck.position, config: config, rinkFrame: frame)
        puckShadowNode.path = discPath(radius: puckRadius * 1.05)
        puckShadowNode.position = CGPoint(x: puckPoint.x, y: puckPoint.y - puckRadius * 0.35)
        puckNode.path = discPath(radius: puckRadius)
        puckNode.position = puckPoint
        puckHighlightNode.path = CGPath(
            ellipseIn: CGRect(
                x: -puckRadius * 0.5,
                y: puckRadius * 0.1,
                width: puckRadius * 0.6,
                height: puckRadius * 0.45
            ),
            transform: nil
        )
    }

    private func rinkFrame(for config: MatchConfig) -> CGRect {
        // Minimal side padding pushes the rink close to the screen edges; the top
        // clears the HUD and the bottom reserves the joystick / skill control zone.
        let horizontalPadding: CGFloat = 4
        let topPadding: CGFloat = 92
        let bottomPadding: CGFloat = 172
        let availableSize = CGSize(
            width: max(1, size.width - horizontalPadding * 2),
            height: max(1, size.height - topPadding - bottomPadding)
        )
        let rinkAspect = config.rinkSize.x / config.rinkSize.y

        // Width-first: fill the available width, and only shrink if the resulting
        // height would exceed the available height (then it is height-bound).
        var rinkWidth = availableSize.width
        var rinkHeight = rinkWidth / rinkAspect
        if rinkHeight > availableSize.height {
            rinkHeight = availableSize.height
            rinkWidth = rinkHeight * rinkAspect
        }
        let rinkSize = CGSize(width: rinkWidth, height: rinkHeight)

        return CGRect(
            x: (size.width - rinkSize.width) * 0.5,
            y: bottomPadding + (availableSize.height - rinkSize.height) * 0.5,
            width: rinkSize.width,
            height: rinkSize.height
        )
    }

    private func scenePoint(for position: Vector2, config: MatchConfig, rinkFrame: CGRect) -> CGPoint {
        CGPoint(
            x: rinkFrame.minX + rinkFrame.width * (position.x / config.rinkSize.x),
            y: rinkFrame.minY + rinkFrame.height * (position.y / config.rinkSize.y)
        )
    }

    private func discPath(radius: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
    }

    // A ring with four short tick marks (top/bottom/left/right), used for the away
    // Shot so it reads as "aiming" and stays distinguishable from the plain boost ring.
    private func reticlePath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        let tickInner = radius * 0.82
        let tickOuter = radius * 1.14
        for (dx, dy) in [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)] {
            path.move(to: CGPoint(x: dx * tickInner, y: dy * tickInner))
            path.addLine(to: CGPoint(x: dx * tickOuter, y: dy * tickOuter))
        }
        return path
    }

    private func linePath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}
