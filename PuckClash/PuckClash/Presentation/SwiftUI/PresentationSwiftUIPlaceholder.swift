import SwiftUI
import SpriteKit

// Thin wrapper that displays a RinkScene owned by the match controller. The scene
// size is bound to the actual container size (points) via GeometryReader, because
// SwiftUI's SpriteView does not apply SKSceneScaleMode.resizeFill on its own —
// without this the scene keeps its initial size and the rink renders narrow.
struct RinkSceneView: View {
    let scene: RinkScene

    var body: some View {
        GeometryReader { geometry in
            SpriteView(scene: scene)
                .task(id: geometry.size) {
                    scene.size = geometry.size
                }
        }
        .ignoresSafeArea()
    }
}
