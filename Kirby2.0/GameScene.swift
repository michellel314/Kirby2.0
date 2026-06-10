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
   
       
       // setupBackground(imageName: "Dreamscape", duration: 5, zPos: 1, scale: 1)
        setupZones()
        
        // --- ZONE 0 ENEMIES (Right on your starting screen platforms!) ---
            Enemy(at: CGPoint(x: 400, y: 180))
            Enemy(at: CGPoint(x: 750, y: 290))

        // --- FUTURE ZONE ENEMIES (Waiting off-screen) ---
        Enemy(at: CGPoint(x: size.width + 300, y: 150))
        Enemy(at: CGPoint(x: size.width + 700, y: 220))
        Enemy(at: CGPoint(x: size.width * 2 + 500, y: 180))
        Enemy(at: CGPoint(x: size.width * 3 + 600, y: 250))
        camera = cameraNode
        addChild(cameraNode)
        
        cameraNode.position = CGPoint(
            x: size.width / 2,
            y: size.height / 2
        )

        // Activate the screen boundaries
        updateMovementConstraints()
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateMovementConstraints()
    }
    
    
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        movePlayer(joystickInput)
      
        // --- 1. ZONE ADVANCEMENT CHECK ---
        if canAdvanceToNextZone {
            let zoneEndX = CGFloat(currentZone + 1) * size.width - 100
            if player.position.x > zoneEndX {
                moveToNextZone()
            }
        }
        
        // --- 2. TRASH EAT BUTTON DETECTION ---
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
        canAdvanceToNextZone = true // FIX: Allows the update loop to trigger moveToNextZone()!
        
        // Refresh constraints so the right wall opens up!
        updateMovementConstraints()
        showCheckpointMessage()
    }
    
    //SKPhysicsContactDelegate delegate method
    func didBegin(_ contact: SKPhysicsContact) {
       
        
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        let a = contact.bodyA
        let b = contact.bodyB

        if (a.categoryBitMask == playerCategory && b.categoryBitMask == trashCategory) ||
           (a.categoryBitMask == trashCategory && b.categoryBitMask == playerCategory) {

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
            
            // Identify exactly which node is the player and which is King Dedede
            let enemyNode = (contact.bodyA.categoryBitMask == dededeCategory) ? contact.bodyA.node as? SKSpriteNode : contact.bodyB.node as? SKSpriteNode
            
            guard let enemy = enemyNode else { return }
            
            let isFalling = (player.physicsBody?.velocity.dy ?? 0) < -20
            let isAboveEnemy = player.position.y > (enemy.position.y + 15)
            
            // CHECKS IF KIRBY'S CENTER Y IS SAFELY ABOVE DEDEDE'S LOWER HALF
            if player.position.y > (enemy.position.y - 10){
                // 1. Deal damage to King Dedede
                if let hp = enemy.userData?.value(forKey: "hp") as? Int {
                    let newHP = hp - 10 // Atk values from Kirby
                    enemy.userData?.setValue(newHP, forKey: "hp")
                    
                    // Classic arcade white flash effect when hit
                    let flash = SKAction.sequence([
                        SKAction.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.1),
                        SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
                    ])
                    enemy.run(flash)
                    
                    if newHP <= 0 {
                        enemy.removeFromParent()
                        enemiesDefeatedInZone += 1
                        checkZoneProgress()
                    }
                }
                
                // 2. Mario Style Bounce for Kirby to attack
                // this launches Kirby up, breaking him out of any stuck animation state
                player.physicsBody?.velocity.dy = 350
                
            } else {
                // Kirby ran into Dedede from the side -> Kirby takes damage instead
                takeDamage(amount: 10)
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
        isZoneLocked = true // Lock the new zone behind him

        // Refresh constraints for the new zone boundary box
        updateMovementConstraints()
        
        // Move camera center to the middle of the new screen space
        let targetX = (CGFloat(currentZone) * size.width) + (size.width / 2)
        let moveAction = SKAction.moveTo(x: targetX, duration: 1.2)
        cameraNode.run(moveAction)
    }
    
    
    func jump() {
        // Enforce a strict max cap of 12 jumps
        guard jumpCount < 12 else { return }

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
        
        // Change from enemy.size.width / 2 to a full, comfortable stomp width
        let interactiveRect = CGSize(width: enemy.size.width * 0.8, height: enemy.size.height)
        enemy.physicsBody = SKPhysicsBody(rectangleOf: interactiveRect)
        enemy.physicsBody?.isDynamic = false // Stays perfectly on his platform
        enemy.physicsBody?.allowsRotation = false
        
        enemy.physicsBody?.categoryBitMask = dededeCategory
        enemy.physicsBody?.contactTestBitMask = playerCategory
        addChild(enemy)
        
        // --- FIX: AUTOMATIC PLATFORM GENERATION ---
        let platformWidth: CGFloat = 350
        let platformHeight: CGFloat = 20
        // Places the ledge surface perfectly matching the feet of King Dedede
        let platformY = position.y - (enemy.size.height / 2) - (platformHeight / 2)
            
        createLedge(at: CGPoint(x: position.x, y: platformY), size: CGSize(width: platformWidth, height: platformHeight))
            
        // --- MARIO-STYLE AUTOMATIC PATROL LOGIC ---
        let patrolDistance: CGFloat = 110   // Caps the travel distance safely inside the 350w platform
        let walkSpeed: TimeInterval = 2.5
            
        let moveLeft  = SKAction.moveBy(x: -patrolDistance, y: 0, duration: walkSpeed)
        let flipRight = SKAction.run { enemy.xScale = 0.8 }
        let moveRight = SKAction.moveBy(x: patrolDistance * 2, y: 0, duration: walkSpeed * 2)
        let flipLeft  = SKAction.run { enemy.xScale = -0.8 }
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
    
    func updateMovementConstraints() {
        // Left Wall
        let minX = CGFloat(currentZone) * size.width + player.size.width / 2
        
        // Right Wall (Locks to current screen if zone is locked, otherwise lets him roam)
        let maxX = isZoneLocked ?
            (CGFloat(currentZone + 1) * size.width - player.size.width / 2) :
            (CGFloat(5) * size.width - player.size.width / 2)
        
        let rangeX = SKRange(lowerLimit: minX, upperLimit: maxX)
        let constraint = SKConstraint.positionX(rangeX)
        
        // Apply natively to the player node
        player.constraints = [constraint]
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
        player = SKSpriteNode(imageNamed: "walking000")
        
        // FIX: Raise the starting Y coordinate (e.g., from 100 to 180)
        // so he drops cleanly onto the floor without clipping into it
        player.position = CGPoint(x: 150, y: 180)
        player.setScale(1)
        player.zPosition = 5
        
        // let interactiveRect = CGSize(width: player.size.width / 2, height: player.size.height)
        player.physicsBody = SKPhysicsBody(circleOfRadius: player.size.width / 2)
        player.physicsBody?.isDynamic = true
        player.physicsBody?.affectedByGravity = true
        player.physicsBody?.allowsRotation = false // Prevents kirby from rolling
        player.physicsBody?.restitution = 0.0 // Prevents bouncy floor glitching
        player.physicsBody?.friction = 0.2
        
        // FIX: Explicitly zero out any ghost velocities on spawn
        player.physicsBody?.velocity = .zero
        player.physicsBody?.angularVelocity = 0
        
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

    func takeDamage(amount: Int) {
        // 1. Lower Kirby's health variable
        // (Change 'playerHP' to whatever your health variable is called)
        kirbyHealth -= amount
        if kirbyHealth <= 0 {
            kirbyHealth = 0
            print("Game Over!")
            // Trigger your game over logic here later!
        }
        
        // 2. Update your HUD text immediately so the player sees the change
        // (Change 'hudLabel' to whatever your SKLabelNode variable name is)
        hudLabel.text = "HP: \(kirbyHealth) | ATK: 10"
        
        // 3. Visual feedback: Make Kirby blink red and get knocked back slightly
        let turnRed = SKAction.colorize(with: .red, colorBlendFactor: 0.7, duration: 0.1)
        let turnNormal = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
        let blinkSequence = SKAction.sequence([turnRed, turnNormal, turnRed, turnNormal])
        player.run(blinkSequence)
        
        // Slight knockback so he doesn't instantly take damage again on the next frame
        let pushDirection: CGFloat = (player.position.x < size.width / 2) ? -150 : 150
        player.physicsBody?.velocity = CGVector(dx: pushDirection, dy: 200)
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
