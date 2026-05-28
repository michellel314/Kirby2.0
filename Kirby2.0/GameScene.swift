//
//  GameScene.swift
//  Kirby2.0
//
//  Created by Student on 5/22/26.
//

import Foundation
import SwiftUI
import SpriteKit


class GameScene: SKScene, SKPhysicsContactDelegate{
    private var player = SKSpriteNode(imageNamed: "tile000")
    private var isJumping = false
    override func didMove(to view: SKView){
        setupScene()
        setupPlayer()
        setupGround()
        spawnEnemy()
        setupBackground(imageName: "Dreamscape", duration: 10, zPos: 1, scale: 1)
        
    }
    
    override func update(_ currentTime: TimeInterval){
        if player.position.y > size.height / 2 {
            isJumping = false
        }
        
        if isJumping {
            player.physicsBody?.velocity = CGVector(dx: 0, dy: 300)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?){
        isJumping = true
        jumpAnimation()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?){
        isJumping = false
        runAnimation()
    }
    
    //SKPhysicsContactDelegate delegate method
    func didBegin(_ contact: SKPhysicsContact){
        print("contact!")
    }
    
    private func setupScene(){
        // set the scene background color to black
        backgroundColor = SKColor(.black)
        
        // make scene full screen
        size = view!.bounds.size
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        physicsWorld.contactDelegate = self
    }
    
    
    private func setupPlayer(){
        
        player.position = CGPoint(x: 200, y: 11)
        player.setScale(1)
        player.zPosition = 4
        
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.isDynamic = true
        player.physicsBody?.allowsRotation = false
        runAnimation()
        addChild(player)
    }
    
    private func setupBackground(imageName : String, duration: Double, zPos: CGFloat, scale: CGFloat){
        let numCopies = determinNumberOfCopies(imageName: imageName, scale: scale)
        for i in 0..<numCopies{
            let layer = SKSpriteNode(imageNamed: imageName)
            
            // calculate scaled size
            let heightRatio = size.height / layer.size.height
            let layerHeight = size.height * scale
            let layerWidth = layer.size.width * heightRatio * scale
            let layerSize = CGSize(width: layerWidth, height: layerHeight)
            layer.size = layerSize
            
            layer.position = CGPoint(x: layerSize.width * CGFloat(i), y: 0)
            layer.anchorPoint = .zero
            layer.zPosition = zPos
            
            //animate layer so it moves off the screen
            let move = SKAction.moveBy(x: -layer.size.width, y: 0, duration: 10)
            let wrap = SKAction.moveBy(x: layer.size.width, y: 0, duration: 0)
            let sequence = SKAction.sequence([move, wrap])
            let moveForever = SKAction.repeatForever(sequence)
            layer.run(moveForever)
            addChild(layer)
        }
        
    }
    
    private func determinNumberOfCopies(imageName: String, scale: CGFloat) -> Int {
        let layer = SKSpriteNode(imageNamed: imageName)
    
        //calculate scaled size
        let heightRatio = size.height / layer.size.height
        let layerHeight = size.height * scale
        let layerWidth = layer.size.width * heightRatio * scale
        let layerSize = CGSize(width: layerWidth, height: layerHeight)
        
        //divide the width of the screen by width of layer, round up to the nearest integer (ceiling) and convert to int
        let howManyPartiallyFit = Int(size.width / layerSize.width)
        
        // we need 1 more than how many partially fit
        let howManyNeeded = howManyPartiallyFit + 1
        return howManyNeeded
        
    }
    
    private func setupGround() {
        let ground = SKSpriteNode()
        ground.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 10), to: CGPoint(x: size.width, y: 10))
        ground.physicsBody?.isDynamic = false
        addChild(ground)
    }
    
    private func runAnimation(){
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
    }

    private func jumpAnimation() {
        let textureAtlas = SKTextureAtlas(named: "Jumping")
        var playerAnimation = [SKTexture]()
        for i in 0..<textureAtlas.textureNames.count {
            let name = "jump00\(i)"
            playerAnimation.append(textureAtlas.textureNamed(name))
        }
        let animation = SKAction.animate(with: playerAnimation, timePerFrame: 0.15)
        let repeatForever = SKAction.repeatForever(animation)
        player.run(repeatForever)
    }
    
    private func spawnEnemy() {
        let enemy = SKSpriteNode(imageNamed: "King DEDEDE")
        enemy.position = CGPoint(x: size.width + enemy.size.width, y: 11)
        enemy.setScale(2)
        enemy.zPosition = 4
        enemy.physicsBody = SKPhysicsBody(rectangleOf: enemy.size)
        enemy.physicsBody?.isDynamic = true
        enemy.physicsBody?.allowsRotation = false
        enemy.physicsBody?.affectedByGravity = false
        let move = SKAction.moveTo(x: -enemy.size.width, duration: 5)
        let remove = SKAction.removeFromParent()
        let sequence = SKAction.sequence([move, remove])
        enemy.run(sequence)
        
        addChild(enemy)
        
        let textureAtlas = SKTextureAtlas(named: "King DEDEDE")
        var enemyAnimation = [SKTexture]()
        for i in 0..<textureAtlas.textureNames.count {
            let name = "tile00\(i)"
            enemyAnimation.append(textureAtlas.textureNamed(name))
        }
        let animation = SKAction.animate(with: enemyAnimation, timePerFrame: 0.15)
        
        let repeatForever = SKAction.repeatForever(animation)
        enemy.run(repeatForever)
    }


    
}
