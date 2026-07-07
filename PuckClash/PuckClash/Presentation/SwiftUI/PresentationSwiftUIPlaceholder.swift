import SwiftUI
import SpriteKit

struct RinkSceneView: View {
    // @State keeps one scene per view identity; a new identity (via .id on retry)
    // rebuilds the scene, which recreates the underlying GameEngine for a fresh match.
    @State private var scene: RinkScene

    init(config: MatchConfig = .standard, onFinished: ((ScoreState) -> Void)? = nil) {
        _scene = State(initialValue: RinkScene(config: config, onFinished: onFinished))
    }

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}
