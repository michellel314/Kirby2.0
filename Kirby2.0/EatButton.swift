//
//  EatButton.swift
//  Kirby2.0
//
//  Created by Michelle Lee on 6/2/26.
//

import SwiftUI

struct EatButton: View {
    @ObservedObject var scene: GameScene
    var body: some View {
        Group{
            if scene.showEatButton {
                Button(action: {
                    scene.eatTrash()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.7))
                            .frame(width: 70, height: 70)
                        Text("EAT")
                            .font(.system(.body, design: .rounded))
                            .bold()
                            .foregroundColor(.black)
                    }
                }
                .transition(.scale.combined(with: .opacity))
                .onAppear{
                    print("EAT BUTTON APPEARED")
                }
            }
        }
        // Creates a smooth pop-in/pop-out bounce animation
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: scene.showEatButton)
    }
}
