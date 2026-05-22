//
//  ContentView.swift
//  Kirby2.0
//
//  Created by Student on 5/22/26.
//

import SwiftUI
import SpriteKit
struct ContentView: View {
    private let gameScene = GameScene()
    var body: some View {
        VStack {
            SpriteView(scene: gameScene)
                .ignoresSafeArea()
        }
        
    }
}

#Preview {
    ContentView()
}
