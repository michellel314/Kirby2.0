//
//  GameScene.swift
//  Kirby2.0
//
//  Created by Student on 5/22/26.
//

import Foundation
import SwiftUI
import SpriteKit
import Combine

class GameScene: SKScene, SKPhysicsContactDelegate, ObservableObject{
    private var player = SKSpriteNode(imageNamed: "tile000")
    private var isJumping = false
    private var jumpCount = 0
    private var isMoving = false
    private var canMove = true
    private var isOnGround = true // Tracks if Kirby is physically on surface
    private let playerCategory: UInt32 = 0x1 << 0
    private let groundCategory: UInt32 = 0x1 << 1
    
    
    // --- New Stats & HUD ---
    private var kirbyHealth = 100
    @Published var showEatButton = false
    private var nearbyTrash: SKSpriteNode? // Tracks the specific trash Kirby is next to
    private var isTouchingTrash = false

    
    private var kirbyAttack = 10
    private var hudLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    
    private var currentZone = 0
    private var enemiesDefeatedInZone = 0
    private let enemiesRequiredPerZone = [2, 3, 4, 2, 5]
    private var cameraNode = SKCameraNode()
    private var canAdvanceToNextZone = false
    private var isZoneLocked = true
    
    // --- New Physics Categories ---
    private let platformCategory: UInt32 = 0x1 << 2
    private let dededeCategory: UInt32   = 0x1 << 3
    private let trashCategory: UInt32    = 0x1 << 4
   
    
    private var zoneBackgrounds: [SKSpriteNode] = []
    
    // Tracks the live joystick state 60 times a second
    var joystickInput: CGSize = .zero
    
    override func didMove(to view: SKView){
        setupScene()
        setupPlayer()
        setupGround()
   
        setupHUD()
        setupPlatforms()
       
       // setupBackground(imageName: "Dreamscape", duration: 5, zPos: 1, scale: 1)
        setupZones()
        
        Enemy(at: CGPoint(x: size.width + 400, y: 180))
        Enemy(at: CGPoint(x: size.width + 800, y: 250))

        Enemy(at: CGPoint(x: size.width * 2 + 300, y: 150))
        Enemy(at: CGPoint(x: size.width * 2 + 700, y: 220))

        Enemy(at: CGPoint(x: size.width * 3 + 500, y: 180))

        Enemy(at: CGPoint(x: size.width * 4 + 600, y: 250))
        
        camera = cameraNode
        addChild(cameraNode)
        
        cameraNode.position = CGPoint(
            x: size.width / 2,
            y: size.height / 2
        )

    }
    
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        movePlayer(joystickInput)
      
    
            if canAdvanceToNextZone {
                let zoneEndX = CGFloat(currentZone + 1) * size.width - 100
                if player.position.x > zoneEndX {
                    moveToNextZone()
                }
            }
        
            let isTouchingTrashNow = isTouchingTrash && nearbyTrash != nil

           if isTouchingTrashNow {
               if nearbyTrash == nil {
                   if let trash = player.physicsBody?.allContactedBodies().first(where: {
                       $0.categoryBitMask == trashCategory
                   })?.node as? SKSpriteNode {
                       nearbyTrash = trash
                   }
               }

               if !showEatButton {
                   showEatButton = true
               }
           } else {
               nearbyTrash = nil

               if showEatButton {
                   showEatButton = false
               }
           }
    }
    
    
    func checkZoneProgress() {
        guard enemiesDefeatedInZone >= enemiesRequiredPerZone[currentZone] else { return }
        isZoneLocked = false
        showCheckpointMessage()
    }
    
    //SKPhysicsContactDelegate delegate method
    func didBegin(_ contact: SKPhysicsContact) {
        print("CONTACT DETECTED")
        print(contact.bodyA.categoryBitMask)
        print(contact.bodyB.categoryBitMask)
        
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        let a = contact.bodyA
        let b = contact.bodyB

        if (a.categoryBitMask == playerCategory && b.categoryBitMask == trashCategory) ||
           (a.categoryBitMask == trashCategory && b.categoryBitMask == playerCategory) {

            print("KIRBY TOUCHED TRASH")

            isTouchingTrash = true

            if let trashNode = (a.categoryBitMask == trashCategory ? a.node : b.node) as? SKSpriteNode {
                nearbyTrash = trashNode
            }

            DispatchQueue.main.async {
                self.showEatButton = true
            }
        }
        
        let targetNode = (contact.bodyA.categoryBitMask == playerCategory) ? contact.bodyB.node : contact.bodyA.node
        
        // 2. Solid Landings: Kirby hits Ground OR Platforms
        if collision == (playerCategory | groundCategory) || collision == (playerCategory | platformCategory) {
            jumpCount = 0
            isOnGround = true
            player.removeAction(forKey: "jumping")
            if isMoving {
                if player.action(forKey: "walking") == nil { runAnimation() }
            } else {
                player.texture = SKTexture(imageNamed: "walking000")
            }
        }
        
        // 3. Combat Tracking: Kirby encounters King Dedede
        if collision == (playerCategory | dededeCategory) {
            guard let enemy = targetNode as? SKSpriteNode else { return }
            
            let isFalling = (player.physicsBody?.velocity.dy ?? 0) < -20
            let isAboveEnemy = player.position.y > (enemy.position.y + 15)
            
            if isFalling && isAboveEnemy {
                if let currentHP = enemy.userData?.value(forKey: "hp") as? Int {
                    let newHP = currentHP - kirbyAttack
                    
                    if newHP <= 0 {
                        let enemyPosition = enemy.position
                        enemy.removeFromParent()
                        dropGoldenTrash(at: enemyPosition)
                        enemiesDefeatedInZone += 1
                        checkZoneProgress()
                    } else {
                        enemy.userData?.setValue(newHP, forKey: "hp")
                        
                        let flashRed = SKAction.sequence([
                            SKAction.fadeAlpha(to: 0.3, duration: 0.1),
                            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
                        ])
                        enemy.run(flashRed)
                    }
                    
                }
                player.physicsBody?.velocity = CGVector(dx: player.physicsBody?.velocity.dx ?? 0, dy: 320)
            } else {
                let isOnSameLevel = abs(player.position.y - enemy.position.y) < 40
                if isOnSameLevel {
                    kirbyHealth -= 15
                    updateHUD()
                }
            }
        }
        
        // NOTE: Old conflicting automatic trash opening logic has been completely removed from here!
        
    }

    func didEnd(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        if collision == (playerCategory | groundCategory) || collision == (playerCategory | platformCategory) {
            if isOnGround {
                isOnGround = false
                player.removeAction(forKey: "walking")
                jumpAnimation()
            }
        }
        
        let a = contact.bodyA
        let b = contact.bodyB
        
        if (a.categoryBitMask == playerCategory && b.categoryBitMask == trashCategory) ||
           (a.categoryBitMask == trashCategory && b.categoryBitMask == playerCategory) {

            isTouchingTrash = false
            nearbyTrash = nil

            DispatchQueue.main.async {
                self.showEatButton = false
            }
        }
        
    }
    
    func movePlayer(_ input: CGSize){
        
        guard canMove else {
            player.physicsBody?.velocity.dx = 0
            return
        }
        
        let deadzone: CGFloat = 5
        
        if abs(input.width) < deadzone {
            isMoving = false
            player.removeAction(forKey:"walking")
            
            //Stop horizontal movement safely without changing gravity speed
            player.physicsBody?.velocity.dx = 0
            
            //Only show flat idle frame if we aren't mid-air
            if isOnGround {
                player.texture = SKTexture(imageNamed:"walking000")
            }
            return
        }
        
        isMoving = true
        
        // Move via physics velocity instead of altering position.x directly
        let moveSpeed: CGFloat = 5.0
        player.physicsBody?.velocity.dx = input.width * moveSpeed

        // Flip Kirby left/right depending on joystick direction
        if input.width > 0 {
            player.xScale = abs(player.xScale)
        } else {
            player.xScale = -abs(player.xScale)
        }

        // Only loop the walking animation if Kirby is actually on solid ground
        if isOnGround && player.action(forKey:"walking") == nil {
            runAnimation()
        }
    }
    
    func moveToNextZone() {
        guard currentZone < 4 else { return }

        currentZone += 1
        enemiesDefeatedInZone = 0
        canAdvanceToNextZone = false

        let targetX = CGFloat(currentZone) * size.width

        let moveAction = SKAction.moveTo(x: targetX, duration: 1.2)
        cameraNode.run(moveAction)
    }
    
    
    func jump() {
        // Enforce a strict max cap of 2 jumps
        guard jumpCount < 10 else { return }

        jumpCount += 1
        isOnGround = false // Kirby is now AIRBORNE!
        
        // Stop any running animations to clear the frame buffer
        player.removeAction(forKey: "walking")
        player.removeAction(forKey: "jumping")
        jumpAnimation()
        
        // Grab current left/right speed so Kirby can still move sideways while jumping
            let currentXVelocity = player.physicsBody?.velocity.dx ?? 0
            player.physicsBody?.velocity = CGVector(dx: currentXVelocity, dy: 350)
    }
    
    func setupZones() {
        let images = ["Zone1", "Zone2", "Zone3", "Zone4", "Zone5"]

        for i in 0..<images.count {
            let bg = SKSpriteNode(imageNamed: images[i])
            bg.position = CGPoint(
                x: CGFloat(i) * size.width + size.width / 2,
                y: size.height / 2
            )
            bg.size = CGSize(width: size.width, height: size.height)
            bg.zPosition = 0
            addChild(bg)
            zoneBackgrounds.append(bg)
        }
    }
    
    func showCheckpointMessage() {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")

        label.text = "CHECKPOINT CLEARED!"
        label.fontSize = 42
        label.fontColor = .yellow
        label.position = CGPoint(
            x: cameraNode.position.x,
            y: cameraNode.position.y
        )

        label.zPosition = 100

        cameraNode.addChild(label)

        label.run(
            .sequence([
                .wait(forDuration: 2),
                .fadeOut(withDuration: 1),
                .removeFromParent()
            ])
        )
    }
    
    func Enemy(at position: CGPoint) {
        let enemy = SKSpriteNode(imageNamed: "KingDedede")
        enemy.userData = NSMutableDictionary()
        enemy.userData?.setValue(30, forKey: "hp") // Takes 3 stomps to destroy (30 hp in total)
        enemy.position = position
        enemy.xScale = -0.8
        enemy.yScale = 0.8
        enemy.zPosition = 4
        
        let interactiveRect = CGSize(width: enemy.size.width / 2, height: enemy.size.height)
        enemy.physicsBody = SKPhysicsBody(rectangleOf: interactiveRect)
        enemy.physicsBody?.isDynamic = false // Stays perfectly on his platform
        enemy.physicsBody?.allowsRotation = false
        
        enemy.physicsBody?.categoryBitMask = dededeCategory
        enemy.physicsBody?.contactTestBitMask = playerCategory
        addChild(enemy)
        
        // --- MARIO-STYLE AUTOMATIC PATROL LOGIC ---
        let patrolDistance: CGFloat = 130  // Distance to travel left/right from center
        let walkSpeed: TimeInterval = 2.5   // Time it takes to walk one direction
            
        let moveLeft  = SKAction.moveBy(x: -patrolDistance, y: 0, duration: walkSpeed)
        let flipRight = SKAction.run { enemy.xScale = 0.8 }  // Look Right
        let moveRight = SKAction.moveBy(x: patrolDistance * 2, y: 0, duration: walkSpeed * 2)
        let flipLeft  = SKAction.run { enemy.xScale = -0.8 } // Look Left
        let moveBack  = SKAction.moveBy(x: -patrolDistance, y: 0, duration: walkSpeed)
            
        // Stitch it together into a looping routine
        let patrolSequence = SKAction.sequence([moveLeft, flipRight, moveRight, flipLeft, moveBack])
        enemy.run(SKAction.repeatForever(patrolSequence))
        
        // --- Keep his texture walking animation running concurrently ---
        var enemyAnimation = [SKTexture]()
        for i in 0...3 { enemyAnimation.append(SKTexture(imageNamed: "enemyWalk00\(i)")) }
        if !enemyAnimation.isEmpty {
            enemy.run(SKAction.repeatForever(SKAction.animate(with: enemyAnimation, timePerFrame: 0.15)))
        }
    }
    
    func eatTrash() {
        guard let trash = nearbyTrash else { return }
    //    let trashPos = trash.position
        
        // 1. Clean up nodes instantly so the player can't double-tap
        trash.removeFromParent()
        nearbyTrash = nil
        
        DispatchQueue.main.async {
            self.showEatButton = false
        }
        
        // 2. Temporarily stop Kirby from moving while eating
        let originalMovementState = canMove
        canMove = false
        player.physicsBody?.velocity.dx = 0
        player.removeAction(forKey: "walking")
        player.removeAction(forKey: "jumping")
        
        // 3. Build your animation array matching your asset folder names exactly
        var eatingFrames = [SKTexture]()
        for i in 0...4 {
            eatingFrames.append(SKTexture(imageNamed: "eating00\(i)"))
        }
        
        // 4. Run the eating frame actions
        let eatingAnimation = SKAction.animate(with: eatingFrames, timePerFrame: 0.08)
        player.run(eatingAnimation) { [weak self] in
            guard let self = self else { return }
            self.canMove = originalMovementState
            if self.isOnGround {
                self.player.texture = SKTexture(imageNamed: "walking000") // Idle frame
            }
        }
        
        // 5. Probability Roll: 40% Explode (-5 HP), 30% Heal (+10 HP), 30% Attack (+5 ATK)
        let roll = Double.random(in: 0...100)
        
        if roll <= 40.0 {
            // 40% Chance (0.0 to 40.0)
            kirbyHealth -= 10
            let boom = SKShapeNode(circleOfRadius: 40)
            boom.position = player.position
            boom.fillColor = .orange
            boom.strokeColor = .red
            boom.zPosition = 10
            addChild(boom)

            boom.run(.sequence([
                .fadeOut(withDuration: 0.2),
                .removeFromParent()
            ]))
        } else if roll <= 70.0 {
            // 30% heal
            kirbyHealth += 30
        } else {
            // 30% attack boost
            kirbyAttack += 20
        }
        
        // Update your top bar text values
        updateHUD()
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
        player.setScale(0.7)
        player.zPosition = 4
     //   let interactiveRect = CGSize(width: player.size.width / 2, height: player.size.height)
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.isDynamic = true
        player.physicsBody?.affectedByGravity = true
        player.physicsBody?.allowsRotation = false // Prevents kirby from rolling
        
        //Tell the physics world that this body belongs to the "player"
        player.physicsBody?.categoryBitMask = playerCategory
        //Tell the physics world to alert "didBegin" when touching the ground
        player.physicsBody?.contactTestBitMask = groundCategory | platformCategory | dededeCategory | trashCategory
        player.physicsBody?.collisionBitMask = groundCategory | platformCategory | dededeCategory
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
            
            // Uses the actual 'duration' variable passed into the function
            let move = SKAction.moveBy(x: -layer.size.width, y: 0, duration: duration)
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
        let howManyNeeded = howManyPartiallyFit + 2
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
        
        // First play 000 -> 003 once
        var startFrames = [SKTexture]()
        for i in 0...3{
            startFrames.append(
                SKTexture(imageNamed: "walking00\(i)")
            )
        }
        
        // Then loop only 001 --> 003
        var loopFrames = [SKTexture]()
        for i in 1...3{
            loopFrames.append(
                SKTexture(imageNamed: "walking00\(i)")
            )
        }
        
        let startAnimation = SKAction.animate(with: startFrames, timePerFrame: 0.15)
        
        let loopAnimation = SKAction.repeatForever(SKAction.animate(with: loopFrames, timePerFrame: 0.15))
        
        player.removeAction(forKey: "walking")
       
        let sequence = SKAction.sequence([startAnimation, loopAnimation])
        
        player.run(sequence, withKey: "walking")
    }
    
    

    private func jumpAnimation() {
        player.removeAction(forKey: "walking")
        
        var playerAnimation = [SKTexture]()
       
        for i in 0...2 {
            let name = "jumping00\(i)"
            playerAnimation.append(SKTexture(imageNamed: name))
        }
        guard !playerAnimation.isEmpty else {
               print("NO JUMP TEXTURES")
               return
        }
        
     
        let animation = SKAction.animate(with: playerAnimation, timePerFrame: 0.15)
        let repeatForever = SKAction.repeatForever(animation)
        player.run(repeatForever, withKey: "jumping")
    }
    
    

    
    private func setupHUD() {
        hudLabel.text = "HP: \(kirbyHealth)  |  ATK: \(kirbyAttack)"
        hudLabel.fontSize = 18
        hudLabel.fontColor = .white
        hudLabel.position = CGPoint(x: 150, y: size.height - 40)
        hudLabel.zPosition = 10
        addChild(hudLabel)
    }

    private func updateHUD() {
        hudLabel.text = "HP: \(kirbyHealth)  |  ATK: \(kirbyAttack)"
    }

    func setupPlatforms() {
        // Platform 1 (Under Enemy 1)
        let platform1 = SKSpriteNode(color: .brown, size: CGSize(width: 250, height: 20))
        platform1.position = CGPoint(x: 400, y: 120) // Positioned safely under the enemy at 162
        platform1.zPosition = 2
        platform1.physicsBody = SKPhysicsBody(rectangleOf: platform1.size)
        platform1.physicsBody?.isDynamic = false // Stops it from falling down
        platform1.physicsBody?.categoryBitMask = platformCategory
        addChild(platform1)
            
        // Platform 2 (Under Enemy 2)
        let platform2 = SKSpriteNode(color: .brown, size: CGSize(width: 250, height: 20))
        platform2.position = CGPoint(x: 750, y: 230) // Positioned safely under the enemy at 272
        platform2.zPosition = 2
        platform2.physicsBody = SKPhysicsBody(rectangleOf: platform2.size)
        platform2.physicsBody?.isDynamic = false
        platform2.physicsBody?.categoryBitMask = platformCategory
        addChild(platform2)
        
        // Stretched platform widths out to 350
       // createLedge(at: CGPoint(x: 400, y: 120), size: CGSize(width: 350, height: 20))
      //  createLedge(at: CGPoint(x: 750, y: 230), size: CGSize(width: 350, height: 20))
    }

    private func createLedge(at pos: CGPoint, size: CGSize) {
        let ledge = SKSpriteNode(color: UIColor.systemPink.withAlphaComponent(0.6), size: size)
        ledge.position = pos
        ledge.zPosition = 3
        ledge.physicsBody = SKPhysicsBody(rectangleOf: size)
        ledge.physicsBody?.isDynamic = false
        ledge.physicsBody?.categoryBitMask = platformCategory
        ledge.physicsBody?.collisionBitMask = playerCategory
        addChild(ledge)
    }

    private func dropGoldenTrash(at pos: CGPoint) {
        print("TRASH DROPPED AT \(pos)")
        
        let trash = SKSpriteNode(imageNamed: "goldenTrash")
        trash.size = CGSize(width: 45, height: 45)
        trash.position = pos
        trash.zPosition = 4
        trash.physicsBody = SKPhysicsBody(rectangleOf: trash.size)
        trash.physicsBody?.isDynamic = false
        trash.physicsBody?.categoryBitMask = trashCategory
        trash.physicsBody?.contactTestBitMask = playerCategory
        trash.physicsBody?.collisionBitMask = playerCategory
        trash.physicsBody?.usesPreciseCollisionDetection = true
        addChild(trash)
    }

    private func triggerExplosionEffect(at pos: CGPoint) {
        let explosion = SKShapeNode(circleOfRadius: 30)
        explosion.position = pos
        explosion.fillColor = .orange
        explosion.strokeColor = .yellow
        explosion.zPosition = 5
        addChild(explosion)
        explosion.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.2), SKAction.removeFromParent()]))
    }
    

}
