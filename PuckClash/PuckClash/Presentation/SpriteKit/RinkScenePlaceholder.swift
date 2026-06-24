import SpriteKit

final class RinkScene: SKScene {
    private var engine = GameEngine()
    private var lastUpdateTime: TimeInterval?

    private let rinkNode = SKShapeNode()
    private let leftGoalMouthNode = SKShapeNode()
    private let rightGoalMouthNode = SKShapeNode()
    private let homePlayerNode = SKShapeNode(circleOfRadius: 12)
    private let awayPlayerNode = SKShapeNode(circleOfRadius: 12)
    private let puckNode = SKShapeNode(circleOfRadius: 6)
    private let scoreLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let timeLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.08, green: 0.17, blue: 0.24, alpha: 1)
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

        engine.update(deltaTime: min(deltaTime, 1.0 / 30.0), inputs: [])
        render(engine.state)
    }

    private func buildScene() {
        removeAllChildren()

        rinkNode.strokeColor = .white
        rinkNode.lineWidth = 3
        rinkNode.fillColor = SKColor(red: 0.70, green: 0.90, blue: 0.96, alpha: 1)
        addChild(rinkNode)

        configureGoalMouth(leftGoalMouthNode)
        configureGoalMouth(rightGoalMouthNode)

        homePlayerNode.fillColor = SKColor(red: 0.12, green: 0.35, blue: 0.95, alpha: 1)
        homePlayerNode.strokeColor = .white
        homePlayerNode.lineWidth = 2
        addChild(homePlayerNode)

        awayPlayerNode.fillColor = SKColor(red: 0.90, green: 0.18, blue: 0.18, alpha: 1)
        awayPlayerNode.strokeColor = .white
        awayPlayerNode.lineWidth = 2
        addChild(awayPlayerNode)

        puckNode.fillColor = .black
        puckNode.strokeColor = .white
        puckNode.lineWidth = 1
        addChild(puckNode)

        scoreLabel.fontSize = 24
        scoreLabel.verticalAlignmentMode = .top
        addChild(scoreLabel)

        timeLabel.fontSize = 18
        timeLabel.verticalAlignmentMode = .top
        addChild(timeLabel)
    }

    private func configureGoalMouth(_ node: SKShapeNode) {
        node.strokeColor = SKColor(red: 1.0, green: 0.83, blue: 0.25, alpha: 1)
        node.lineWidth = 5
        addChild(node)
    }

    private func render(_ state: GameState) {
        guard size.width > 0, size.height > 0 else {
            return
        }

        let rinkFrame = rinkFrame(for: state.config)
        rinkNode.path = CGPath(rect: rinkFrame, transform: nil)

        updateGoalMouths(config: state.config, rinkFrame: rinkFrame)
        homePlayerNode.position = scenePoint(for: state.homePlayer.position, config: state.config, rinkFrame: rinkFrame)
        awayPlayerNode.position = scenePoint(for: state.awayPlayer.position, config: state.config, rinkFrame: rinkFrame)
        puckNode.position = scenePoint(for: state.puck.position, config: state.config, rinkFrame: rinkFrame)

        scoreLabel.position = CGPoint(x: size.width * 0.5, y: size.height - 12)
        scoreLabel.text = "\(state.score.home) - \(state.score.away)"

        timeLabel.position = CGPoint(x: size.width * 0.5, y: size.height - 42)
        timeLabel.text = "Time \(Int(state.remainingTime.rounded(.up)))"
    }

    private func updateGoalMouths(config: MatchConfig, rinkFrame: CGRect) {
        let leftStart = scenePoint(
            for: Vector2(x: config.leftGoalBoundaryX, y: config.goalMouthMinY),
            config: config,
            rinkFrame: rinkFrame
        )
        let leftEnd = scenePoint(
            for: Vector2(x: config.leftGoalBoundaryX, y: config.goalMouthMaxY),
            config: config,
            rinkFrame: rinkFrame
        )
        leftGoalMouthNode.path = linePath(from: leftStart, to: leftEnd)

        let rightStart = scenePoint(
            for: Vector2(x: config.rightGoalBoundaryX, y: config.goalMouthMinY),
            config: config,
            rinkFrame: rinkFrame
        )
        let rightEnd = scenePoint(
            for: Vector2(x: config.rightGoalBoundaryX, y: config.goalMouthMaxY),
            config: config,
            rinkFrame: rinkFrame
        )
        rightGoalMouthNode.path = linePath(from: rightStart, to: rightEnd)
    }

    private func rinkFrame(for config: MatchConfig) -> CGRect {
        let horizontalPadding: CGFloat = 24
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

    private func linePath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}
