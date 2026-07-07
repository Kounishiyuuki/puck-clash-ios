import SwiftUI
import SpriteKit

// Thin wrapper that displays a RinkScene owned by the match controller, so the
// joystick and the SpriteView share the same scene instance.
struct RinkSceneView: View {
    let scene: RinkScene

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}
