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
    private var timer = Timer()
    private var platformTimer = Timer()
    override func didMove(to view: SKView){
        setupScene()
        setupPlayer()
        setupGround()
        spawnEnemy()
        spawnPlatform()
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
        guard let node1 = contact.bodyA.node else { return }
        guard let node2 = contact.bodyB.node else { return }
        if (node1 == player && node2.name == "enemy") || (node2 == player && node1.name == "enemy"){
            gameOver()
        }
    }
    
    private func setupScene(){
        // set the scene background color to black
        backgroundColor = SKColor(.black)
        
        // make scene full screen
        size = view!.bounds.size
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        physicsWorld.contactDelegate = self
        timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(spawnEnemy), userInfo: nil, repeats: true)
        platformTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(spawnPlatform), userInfo: nil, repeats: true)
        
    }
    
    
    private func setupPlayer(){
        
        player.position = CGPoint(x: 200, y: 11)
        player.setScale(1)
        player.zPosition = 4
        let interactiveRect = CGSize(width: player.size.width / 2, height: player.size.height)
        player.physicsBody = SKPhysicsBody(rectangleOf: interactiveRect)
        player.physicsBody?.isDynamic = true
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.contactTestBitMask = 1
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
    
    @objc private func spawnEnemy() {
        let enemy = SKSpriteNode(imageNamed: "King DEDEDE")
        enemy.position = CGPoint(x: size.width + enemy.size.width, y: 11)
        enemy.setScale(2)
        enemy.zPosition = 4
        let interactiveRect = CGSize(width: enemy.size.width / 2, height: enemy.size.height)
        enemy.physicsBody = SKPhysicsBody(rectangleOf: interactiveRect)
        enemy.physicsBody?.isDynamic = true
        enemy.physicsBody?.allowsRotation = false
        enemy.physicsBody?.affectedByGravity = false
        enemy.physicsBody?.contactTestBitMask = 1
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


    private func gameOver() {
        player.removeFromParent()
        timer.invalidate()
        platformTimer.invalidate()
        
        let gameOverLabel = SKLabelNode(fontNamed: "Chalkduster")
        gameOverLabel.text = "Game Over"
        gameOverLabel.fontColor = .red
        gameOverLabel.fontSize = 48
        gameOverLabel.zPosition = 5
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(gameOverLabel)
    }

    @objc private func spawnPlatform() {
        let platform = SKSpriteNode(color: .red, size: CGSize(width: 200, height: 5))
        platform.position = CGPoint(x: size.width + platform.size.width, y: 100)
        platform.zPosition = 4
        platform.physicsBody = SKPhysicsBody(rectangleOf: platform.size)
        platform.physicsBody?.isDynamic = false
            
        let move = SKAction.moveTo(x: -platform.size.width, duration: 10)
        let remove = SKAction.removeFromParent()
        let sequence = SKAction.sequence([move, remove])
        platform.run(sequence)
            
        addChild(platform)
    }

    
}
