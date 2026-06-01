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
    private var jumpCount = 0
    private var isMoving = false
    
    private let playerCategory: UInt32 = 0x1 << 0
    private let groundCategory: UInt32 = 0x1 << 1
    override func didMove(to view: SKView){
        setupScene()
        setupPlayer()
        setupGround()
        //spawnEnemy()
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
        if jumpCount < 2 {
            if player.physicsBody?.velocity.dy == 0 {
                isJumping = true
                jumpCount += 1
                jumpAnimation()
            }
        }
        
    
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?){
        isJumping = false
        // Removed runAnimation() from here so Kirby stays in his jump animation while mid-air
    }
    
    //SKPhysicsContactDelegate delegate method
    func didBegin(_ contact: SKPhysicsContact){
        //Combine the two contacting bodies into a mask
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        //If the player and the ground have officially collided
        if collision == (playerCategory | groundCategory){
            jumpCount = 0 // Reset jumps  back to 0 on landing
            runAnimation() // Kirby has landed safely so resume the walking
        }
    }
    
    
    func movePlayer(_ input: CGSize){
        let deadzone: CGFloat = 5

        if abs(input.width) < deadzone {

            isMoving = false

            player.removeAction(forKey:"walking")

            player.texture =
                SKTexture(imageNamed:"walking000")

            return
        }

        isMoving = true

        let speed: CGFloat = 0.08

        player.position.x += input.width * speed
        player.position.x = max(0, min(player.position.x, size.width))

        if input.width > 0 {

            player.xScale = abs(player.xScale)

        } else {

            player.xScale = -abs(player.xScale)
        }

        if player.action(forKey:"walking") == nil {

            runAnimation()
        }
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

        player.position = CGPoint(x: 200, y: 100) // Spawns cleanly above the floor line
        player.setScale(0.5)
        player.zPosition = 4
        let interactiveRect = CGSize(width: player.size.width / 2, height: player.size.height)
        player.physicsBody = SKPhysicsBody(rectangleOf: interactiveRect)
        player.physicsBody?.isDynamic = true
        player.physicsBody?.allowsRotation = false
        
        //Tell the physics world that this body belongs to the "player"
        player.physicsBody?.categoryBitMask = playerCategory
        //Tell the physics world to alert "didBegin" when touching the ground
        player.physicsBody?.contactTestBitMask = groundCategory
        player.physicsBody?.collisionBitMask = groundCategory
        player.texture = SKTexture(imageNamed: "walking000")
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
        ground.physicsBody = SKPhysicsBody(
            edgeFrom: CGPoint(x: -5000, y: 10),
            to: CGPoint(x: 5000, y: 10)
        )
        ground.physicsBody?.isDynamic = false
        
        //Define the floor physics values
        ground.physicsBody?.categoryBitMask = groundCategory
        ground.physicsBody?.collisionBitMask = playerCategory
        addChild(ground)
    }
    
    private func runAnimation(){
        var playerAnimation = [SKTexture]()

        for i in 0...3 {
            let name = "walking00\(i)"
            playerAnimation.append(SKTexture(imageNamed: name))
        }
        
        // Clear any previous animations to prevent overlaps
        player.removeAllActions()
        
        let animation = SKAction.animate(with: playerAnimation, timePerFrame: 0.15)
        
        player.run(SKAction.repeatForever(animation), withKey: "walking")
    }

    private func jumpAnimation() {
        var playerAnimation = [SKTexture]()
       
        for i in 0...4 {
            let name = "jumping00\(i)"
            playerAnimation.append(SKTexture(imageNamed: name))
        }
        guard !playerAnimation.isEmpty else {
               print("NO JUMP TEXTURES")
               return
        }
        
        player.removeAllActions()
        
        let animation = SKAction.animate(with: playerAnimation, timePerFrame: 0.15)
        let repeatForever = SKAction.repeatForever(animation)
        player.run(repeatForever, withKey: "jumping")
    }
    
    private func spawnEnemy() {
        let enemy = SKSpriteNode(imageNamed: "KingDedede")
        enemy.position = CGPoint(x: size.width + enemy.size.width, y: 11)
        enemy.xScale = -2
        enemy.yScale = 2
        enemy.zPosition = 4
        let interactiveRect = CGSize(width: enemy.size.width / 2, height: enemy.size.height)
        enemy.physicsBody = SKPhysicsBody(rectangleOf: interactiveRect)
        enemy.physicsBody?.isDynamic = true
        enemy.physicsBody?.allowsRotation = false
        enemy.physicsBody?.affectedByGravity = false
        
        let move = SKAction.moveTo(x: -enemy.size.width, duration: 5)
        let remove = SKAction.removeFromParent()
        let sequence = SKAction.sequence([move, remove])
        enemy.run(sequence)
        
        addChild(enemy)
        
        var enemyAnimation = [SKTexture]()
        for i in 0...3{
            let name = "enemyWalk00\(i)"
            enemyAnimation.append(SKTexture(imageNamed: name))
        }
        let animation = SKAction.animate(with: enemyAnimation, timePerFrame: 0.15)
        
        let repeatForever = SKAction.repeatForever(animation)
        enemy.run(repeatForever)
    }


    
}
