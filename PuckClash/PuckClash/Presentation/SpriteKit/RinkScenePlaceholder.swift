import SpriteKit

final class RinkScene: SKScene {
    // The scene drives a MatchSession (local or, later, online) rather than owning a
    // GameEngine. Home input is set on the session by the SwiftUI layer, not here.
    private let session: MatchSession
    // Handlers are set by the SwiftUI layer after creation; the scene stays free of
    // SwiftUI and holds no game rules.
    var onFinished: ((ScoreState) -> Void)?
    var onHUDChange: ((MatchHUD) -> Void)?
    private var hasNotifiedFinish = false
    private var lastHUD: MatchHUD?
    private var lastScore: ScoreState?
    private var lastPuckSpeed: Double = 0
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
    private let awayStrikerNode = SKShapeNode()
    private let awayStrikerInnerNode = SKShapeNode()
    private let puckNode = SKShapeNode()
    private let puckHighlightNode = SKShapeNode()

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
        let snapshot = MatchHUD(
            homeScore: state.score.home,
            awayScore: state.score.away,
            remainingSeconds: Int(state.remainingTime.rounded(.up))
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

        let strikerRadius = config.strikerRadius * scale
        let puckRadius = config.puckRadius * scale

        homeStrikerNode.path = discPath(radius: strikerRadius)
        homeStrikerInnerNode.path = discPath(radius: strikerRadius * 0.55)
        homeStrikerNode.position = scenePoint(for: state.homePlayer.position, config: config, rinkFrame: frame)

        awayStrikerNode.path = discPath(radius: strikerRadius)
        awayStrikerInnerNode.path = discPath(radius: strikerRadius * 0.55)
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

    private func linePath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}
