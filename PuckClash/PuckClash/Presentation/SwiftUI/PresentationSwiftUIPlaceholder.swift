import SwiftUI
import SpriteKit

struct RinkSceneView: View {
    private let scene: SKScene = {
        let scene = RinkScene()
        scene.size = CGSize(width: 640, height: 360)
        return scene
    }()

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}
