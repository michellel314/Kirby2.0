//
//  ContentView.swift
//  Kirby2.0
//
//  Created by Student on 5/22/26.
//

import SwiftUI
import SpriteKit
struct ContentView: View {
    @State private var movement = CGSize.zero
    private let gameScene = GameScene()
    var body: some View {
        ZStack {
            SpriteView(scene: gameScene)
                .ignoresSafeArea()
            
            VStack{
                Spacer()
                HStack{
                    Joystick(movement: $movement)
                    Spacer()
                    JumpButton{
                        gameScene.jump()
                    }
                }
                .padding()
            }
        }
        .onChange(of: movement){_, newValue in
            gameScene.movePlayer(newValue)
        }
        
    }
}

#Preview {
    ContentView()
}
