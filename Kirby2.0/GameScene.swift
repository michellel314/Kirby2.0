//
//  GameScene.swift
//  Kirby2.0
//
//  Created by Student on 5/22/26.
//

import Foundation
import SwiftUI
import SpriteKit


class GameScene: SKScene {
    override func didMove(to view: SKView){
        setupScene()
        setupPlayer()
        
    }
    
    
    private func setupScene(){
        // set the scene background color to black
        backgroundColor = SKColor(.black)
        
        // make scene full screen
        size = view!.bounds.size
    }
    
    
    private func setupPlayer(){
        let player = SKSpriteNode(imageNamed: "tile000")
        player.position = CGPoint(x: 50 + player.size.width, y: player.size.height + 20)
        player.setScale(1.5)
        
        // set up animation
        let textureAtlas = SKTextureAtlas(named: "Kirby")
        var playerAnimation = [SKTexture]()
        for i in 0..<textureAtlas.textureNames.count {
            let name = "tile00\(i)"
            playerAnimation.append(textureAtlas.textureNamed(name))
        }
        
        let animation = SKAction.animate(with: playerAnimation, timePerFrame: 0.15)
        let repeatForever = SKAction.repeatForever(animation)
        player.run(repeatForever)
        addChild(player)
    }
}
