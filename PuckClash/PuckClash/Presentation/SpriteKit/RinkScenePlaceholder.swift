import SpriteKit

final class RinkScene: SKScene {
    private var engine: GameEngine
    private let onFinished: ((ScoreState) -> Void)?
    private var hasNotifiedFinish = false
    private var lastUpdateTime: TimeInterval?
    private var touchScenePoint: CGPoint?

    private let rinkNode = SKShapeNode()
    private let centerLineNode = SKShapeNode()
    private let centerCircleNode = SKShapeNode()
    private let topGoalNode = SKShapeNode()
    private let bottomGoalNode = SKShapeNode()
    private let homeStrikerNode = SKShapeNode()
    private let awayStrikerNode = SKShapeNode()
    private let puckNode = SKShapeNode()
    private let scoreLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let timeLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")

    // SpriteKit owns no match rules; it drives GameCore and reports the final
    // score once the match finishes so SwiftUI can navigate to the result screen.
    init(config: MatchConfig = .standard, onFinished: ((ScoreState) -> Void)? = nil) {
        self.engine = GameEngine(state: .initial(config: config))
        self.onFinished = onFinished
        super.init(size: CGSize(width: config.rinkSize.x, height: config.rinkSize.y))
    }

    required init?(coder aDecoder: NSCoder) {
        self.engine = GameEngine()
        self.onFinished = nil
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.04, green: 0.06, blue: 0.11, alpha: 1)
        scaleMode = .resizeFill
        buildScene()
        render(engine.state)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        render(engine.state)
    }

    override func update(_ currentTime: TimeInterval) {
        let deltaTime = lastUpdateTime.map { currentTime - $0 } ?? 0
        lastUpdateTime = currentTime

        engine.update(deltaTime: min(deltaTime, 1.0 / 30.0), inputs: playerInputs(at: currentTime))
        render(engine.state)
        notifyIfFinished()
    }

    // SKScene.update runs on the main thread, so invoking the SwiftUI-provided
    // closure here is safe. Fire exactly once on the transition to finished.
    private func notifyIfFinished() {
        guard !hasNotifiedFinish, engine.state.phase == .finished else {
            return
        }

        hasNotifiedFinish = true
        onFinished?(engine.state.score)
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

        rinkNode.strokeColor = SKColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1)
        rinkNode.lineWidth = 3
        rinkNode.fillColor = SKColor(red: 0.13, green: 0.24, blue: 0.36, alpha: 1)
        addChild(rinkNode)

        centerLineNode.strokeColor = SKColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 0.5)
        centerLineNode.lineWidth = 2
        addChild(centerLineNode)

        centerCircleNode.strokeColor = SKColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 0.5)
        centerCircleNode.lineWidth = 2
        centerCircleNode.fillColor = .clear
        addChild(centerCircleNode)

        configureGoal(topGoalNode, color: SKColor(red: 0.90, green: 0.30, blue: 0.35, alpha: 1))
        configureGoal(bottomGoalNode, color: SKColor(red: 0.20, green: 0.55, blue: 1.0, alpha: 1))

        homeStrikerNode.fillColor = SKColor(red: 0.16, green: 0.52, blue: 1.0, alpha: 1)
        homeStrikerNode.strokeColor = .white
        homeStrikerNode.lineWidth = 3
        addChild(homeStrikerNode)

        awayStrikerNode.fillColor = SKColor(red: 0.95, green: 0.28, blue: 0.34, alpha: 1)
        awayStrikerNode.strokeColor = .white
        awayStrikerNode.lineWidth = 3
        addChild(awayStrikerNode)

        puckNode.fillColor = SKColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1)
        puckNode.strokeColor = SKColor(red: 0.85, green: 0.90, blue: 1.0, alpha: 1)
        puckNode.lineWidth = 2
        addChild(puckNode)

        scoreLabel.fontSize = 26
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.fontColor = .white
        addChild(scoreLabel)

        timeLabel.fontSize = 16
        timeLabel.verticalAlignmentMode = .top
        timeLabel.fontColor = SKColor(white: 1, alpha: 0.75)
        addChild(timeLabel)
    }

    private func configureGoal(_ node: SKShapeNode, color: SKColor) {
        node.strokeColor = color
        node.lineWidth = 6
        node.lineCap = .round
        addChild(node)
    }

    private func render(_ state: GameState) {
        guard size.width > 0, size.height > 0 else {
            return
        }

        let config = state.config
        let frame = rinkFrame(for: config)
        let scale = frame.width / config.rinkSize.x

        rinkNode.path = CGPath(
            roundedRect: frame,
            cornerWidth: 18,
            cornerHeight: 18,
            transform: nil
        )

        let leftX = frame.minX
        let rightX = frame.maxX
        let midY = scenePoint(for: config.rinkCenter, config: config, rinkFrame: frame).y
        centerLineNode.path = linePath(from: CGPoint(x: leftX, y: midY), to: CGPoint(x: rightX, y: midY))
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
        topGoalNode.path = linePath(from: CGPoint(x: goalMinX, y: frame.maxY), to: CGPoint(x: goalMaxX, y: frame.maxY))
        bottomGoalNode.path = linePath(from: CGPoint(x: goalMinX, y: frame.minY), to: CGPoint(x: goalMaxX, y: frame.minY))

        homeStrikerNode.path = discPath(radius: config.strikerRadius * scale)
        homeStrikerNode.position = scenePoint(for: state.homePlayer.position, config: config, rinkFrame: frame)
        awayStrikerNode.path = discPath(radius: config.strikerRadius * scale)
        awayStrikerNode.position = scenePoint(for: state.awayPlayer.position, config: config, rinkFrame: frame)
        puckNode.path = discPath(radius: config.puckRadius * scale)
        puckNode.position = scenePoint(for: state.puck.position, config: config, rinkFrame: frame)

        scoreLabel.position = CGPoint(x: size.width * 0.5, y: size.height - 12)
        scoreLabel.text = "\(state.score.home) - \(state.score.away)"

        timeLabel.position = CGPoint(x: size.width * 0.5, y: size.height - 44)
        timeLabel.text = "Time \(Int(state.remainingTime.rounded(.up)))"
    }

    private func rinkFrame(for config: MatchConfig) -> CGRect {
        let horizontalPadding: CGFloat = 16
        let topPadding: CGFloat = 76
        let bottomPadding: CGFloat = 24
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
