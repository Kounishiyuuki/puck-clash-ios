import SpriteKit

final class RinkScene: SKScene {
    private var engine: GameEngine
    private let onFinished: ((ScoreState) -> Void)?
    private let onHUDChange: ((MatchHUD) -> Void)?
    private var hasNotifiedFinish = false
    private var lastHUD: MatchHUD?
    private var lastScore: ScoreState?
    private var lastPuckSpeed: Double = 0
    private var lastUpdateTime: TimeInterval?
    private var touchScenePoint: CGPoint?

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

    // SpriteKit owns no match rules; it drives GameCore, reports the final score
    // (onFinished) and, at most once per changed value, the HUD snapshot (onHUDChange).
    init(
        config: MatchConfig = .standard,
        onFinished: ((ScoreState) -> Void)? = nil,
        onHUDChange: ((MatchHUD) -> Void)? = nil
    ) {
        self.engine = GameEngine(state: .initial(config: config))
        self.onFinished = onFinished
        self.onHUDChange = onHUDChange
        super.init(size: CGSize(width: config.rinkSize.x, height: config.rinkSize.y))
    }

    required init?(coder aDecoder: NSCoder) {
        self.engine = GameEngine()
        self.onFinished = nil
        self.onHUDChange = nil
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.03, green: 0.05, blue: 0.09, alpha: 1)
        scaleMode = .resizeFill
        buildScene()
        render(engine.state)
        publishHUD(engine.state, force: true)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        render(engine.state)
    }

    override func update(_ currentTime: TimeInterval) {
        let deltaTime = lastUpdateTime.map { currentTime - $0 } ?? 0
        lastUpdateTime = currentTime

        engine.update(deltaTime: min(deltaTime, 1.0 / 30.0), inputs: playerInputs(at: currentTime))
        render(engine.state)
        applyFeedback(engine.state)
        publishHUD(engine.state, force: false)
        notifyIfFinished()
    }

    // SKScene.update runs on the main thread, so invoking the SwiftUI-provided
    // closures here is safe. Fire onFinished once on the transition to finished.
    private func notifyIfFinished() {
        guard !hasNotifiedFinish, engine.state.phase == .finished else {
            return
        }

        hasNotifiedFinish = true
        onFinished?(engine.state.score)
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

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchScenePoint = touches.first?.location(in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchScenePoint = touches.first?.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchScenePoint = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchScenePoint = nil
    }

    // Finger position becomes the home striker's target; GameCore confines it to
    // the lower half. SpriteKit only translates the touch, it applies no rules.
    private func playerInputs(at timestamp: TimeInterval) -> [PlayerInput] {
        guard let touchScenePoint, size.width > 0, size.height > 0 else {
            return []
        }

        let config = engine.state.config
        let frame = rinkFrame(for: config)
        guard frame.width > 0, frame.height > 0 else {
            return []
        }

        let target = Vector2(
            x: Double((touchScenePoint.x - frame.minX) / frame.width) * config.rinkSize.x,
            y: Double((touchScenePoint.y - frame.minY) / frame.height) * config.rinkSize.y
        )

        return [PlayerInput(playerId: .home, targetPosition: target, timestamp: timestamp)]
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
        // Top padding clears the status bar / HUD; the larger bottom padding
        // reserves a control zone for the skill button row.
        let horizontalPadding: CGFloat = 16
        let topPadding: CGFloat = 112
        let bottomPadding: CGFloat = 172
        let availableSize = CGSize(
            width: max(1, size.width - horizontalPadding * 2),
            height: max(1, size.height - topPadding - bottomPadding)
        )
        let rinkAspect = config.rinkSize.x / config.rinkSize.y
        let availableAspect = availableSize.width / availableSize.height

        let rinkSize: CGSize
        if availableAspect > rinkAspect {
            rinkSize = CGSize(width: availableSize.height * rinkAspect, height: availableSize.height)
        } else {
            rinkSize = CGSize(width: availableSize.width, height: availableSize.width / rinkAspect)
        }

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
