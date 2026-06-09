import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var movement = CGSize.zero
    
    // Changing this to a StateObject tells SwiftUI to listen to @Published updates!
    @StateObject private var gameScene: GameScene = {
        let scene = GameScene()
        scene.scaleMode = .resizeFill
        return scene
    }()
    
    var body: some View {
        ZStack {
            // 1. The running game layer
            SpriteView(scene: gameScene)
                .ignoresSafeArea()
            
            // 2. SwiftUI HUD/Button Control Overlays
            HStack(alignment: .bottom) {
                // Left Side: Your movement Joystick!
                Joystick(movement: $movement)
                    .padding(.leading, 40)
                
                Spacer() // Pushes structural blocks apart
                
                // Right Side: Contextual action controls
                HStack(spacing: 20) {
                    // Dynamically pops in and out based on trash proximity
                    EatButton(scene: gameScene)
                    
                    // Connected directly to your unified custom JumpButton component
                    JumpButton(onJump: { gameScene.jump() })
                }
                .padding(.trailing, 40)
            }
    
            .padding(.bottom, 40)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .onChange(of: movement) { _, newValue in
            gameScene.joystickInput = newValue
        }
    }
}

#Preview {
    ContentView()
}
