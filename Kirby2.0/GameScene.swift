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
    private var isKirbyInvincible = false
    
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

        // --- ZONE 0 ENEMIES (Right on your starting screen platforms!) ---
        Enemy(at: CGPoint(x: size.width * 0.4 , y: 180))
        Enemy(at: CGPoint(x: size.width * 0.75, y: 290))

        // --- ZONE 1 ENEMIES (Requires 3  | Index 1) ---
        Enemy(at: CGPoint(x: size.width * 1.35, y: 100))
        Enemy(at: CGPoint(x: size.width * 1.5, y: 300))
        Enemy(at: CGPoint(x: size.width * 1.8, y: 200))
        
        // --- Zone 2 Enemies (Requires 4, Index 2) ---
        Enemy(at: CGPoint(x: size.width * 2.22, y: 200))
        Enemy(at: CGPoint(x: size.width * 2.45, y: 340))
        Enemy(at: CGPoint(x: size.width * 2.68, y: 130))
        Enemy(at: CGPoint(x: size.width * 2.88, y: 240))
        
        // --- ZONE 3 ENEMIES (Requires 2 | Index 3) ---
        Enemy(at: CGPoint(x: size.width * 3.3, y: 160))
        Enemy(at: CGPoint(x: size.width * 3.7, y: 270))
        
        // --- ZONE 4 ENEMIES (Requires 5 | Index 4) ---
        Enemy(at: CGPoint(x: size.width * 4.2, y: 150))
        Enemy(at: CGPoint(x: size.width * 4.4, y: 290))
        Enemy(at: CGPoint(x: size.width * 4.5, y: 200))
        Enemy(at: CGPoint(x: size.width * 4.7, y: 260))
        Enemy(at: CGPoint(x: size.width * 4.9, y: 180))
        
        camera = cameraNode
        addChild(cameraNode)
        
        cameraNode.position = CGPoint(
            x: size.width / 2,
            y: size.height / 2
        )

        setupHUD()
        // setupBackground(imageName: "Dreamscape", duration: 5, zPos: 1, scale: 1)
         setupZones()
        
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
        
        
        // If Kirby's vertical speed is 0, he is physically standing flat on something
        if let bodies = player.physicsBody?.allContactedBodies(), let dy = player.physicsBody?.velocity.dy {
            // 1. Scan all active physical point of contact underneath Kirby
            let isTouchingSurface = bodies.contains { body in
                let category = body.categoryBitMask
                if category == groundCategory || category == platformCategory { return true }
                
                if category == dededeCategory {
                    // Kirby is safely grounded on Dedede if his center is above his crown line
                    if let enemyNode = body.node {
                        return player.position.y > (enemyNode.position.y + 15)
                    }
                }
                return false
            }
            
            // 2. Kirby is grounded if touching a valid surface AND not actively blasting upward from a jump
            if isTouchingSurface && dy <= 5.0 {
                isOnGround = true
            } else {
                isOnGround = false
            }
            
            // 3. FORCE CORRECT ANIMATION SYSTEM STATE
            if isOnGround {
                player.removeAction(forKey: "jumping")
                
                if isMoving {
                    if player.action(forKey: "walking") == nil {
                        runAnimation()
                    }
                } else {
                    player.removeAction(forKey: "walking")
                    player.texture = SKTexture(imageNamed: "walking000")
                }
            } else {
                player.removeAction(forKey: "walking")
                if player.action(forKey: "jumping") == nil {
                    jumpAnimation()
                }
            }
        }
      
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
            
            // Read current invicibility status from enemy
            let isInvincible = enemy.userData?.value(forKey: "isInvincible") as? Bool ?? false
            
            // --- STRICT GEOMETRY CHECKS ---
            // 1. Vertical check: Kirby's center must be cleanly above Dedede's upper crown
            let isAboveEnemy = player.position.y > (enemy.position.y + 15)
        
            // 2. Horizontal check: Kirby's center X must align closely to Dedede's center X
            let isSquarelyCentered = abs(player.position.x - enemy.position.x) < 40
            
            
            
            if isAboveEnemy {
                // Only process the stomp if the frame shield is down
                if isSquarelyCentered && !isInvincible {
                    
                    enemy.userData?.setValue(true, forKey: "isInvincible") // Activate shield instantly
                    
                    if let hp = enemy.userData?.value(forKey: "hp") as? Int {
                        let newHP = hp - 10
                        enemy.userData?.setValue(newHP, forKey: "hp")
                        
                        // --- THE VISUAL FLASH FIX ---
                        // 1. Stop the walking texture loop so it doesn't overwrite our color
                        enemy.removeAction(forKey: "enemyWalk")
                                        
                        // 2. Build the flash sequence
                        let flashWhite = SKAction.colorize(with: .white, colorBlendFactor: 0.9, duration: 0.1)
                        let flashNormal = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
                                        
                        // 3. Re-start his walking cycle after the flashing is done
                        let restoreWalking = SKAction.run {
                        var enemyAnimation = [SKTexture]()
                        for i in 0...3 { enemyAnimation.append(SKTexture(imageNamed: "enemyWalk00\(i)")) }
                        enemy.run(SKAction.repeatForever(SKAction.animate(with: enemyAnimation, timePerFrame: 0.15)), withKey: "enemyWalk")
                        }
                        if newHP <= 0 {
                            dropGoldenTrash(at: enemy.position)
                            enemy.removeFromParent()
                            enemiesDefeatedInZone += 1
                            checkZoneProgress()
                        } else {
                            // If still alive, clear the invincibility shield after 0.2 seconds
                            
                            let wait = SKAction.wait(forDuration: 0.2)
                            let turnOffShield = SKAction.run{
                                enemy.userData?.setValue(false, forKey: "isInvincible")
                            }
                            // FIX: Pack the colors, the walk restoration, and the shield toggle into one sequence!
                            let hitSequence = SKAction.sequence([
                                    flashWhite, flashNormal, flashWhite, flashNormal,
                                    restoreWalking,
                                    wait,
                                    turnOffShield
                            ])
                            enemy.run(hitSequence)
                        }
                    }
                    
                    // Mario style bounce for kirby to attack
                    player.physicsBody?.velocity.dy = 350
                    isOnGround = false // Force airborne state instantly on bounce!
                } else {
                    // --- WALKING/RESTING ON DEDEDE'S HEAD ---
                    // If King Dedede is flashing or Kirby is off-center walking on his head, treat it like ground!
                    jumpCount = 0
                    isOnGround = true
                    player.removeAction(forKey: "jumping")
                }
            } else {
                // If hitting from the sides/corners, Kirby takes damage (only if enemy isn't flashing)
                if !isInvincible {
                    takeDamage(amount: 10)
                }
            }
        }
        
        // NOTE: Old conflicting automatic trash opening logic has been completely removed from here!
        
    }

    func didEnd(_ contact: SKPhysicsContact) {
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
        guard jumpCount < 7 else { return }

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
        enemy.userData?.setValue(false, forKey: "isInvincible")
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
        let platformWidth: CGFloat = 220
        let platformHeight: CGFloat = 20
        // Places the ledge surface perfectly matching the feet of King Dedede
        let platformY = position.y - (enemy.size.height / 2) - (platformHeight / 2)
            
        createLedge(at: CGPoint(x: position.x, y: platformY), size: CGSize(width: platformWidth, height: platformHeight))
            
        // --- MARIO-STYLE AUTOMATIC PATROL LOGIC ---
        let patrolDistance: CGFloat = 60   // Caps the travel distance safely inside the 350w platform
        let walkSpeed: TimeInterval = 1.8
            
        let moveLeft  = SKAction.moveBy(x: -patrolDistance, y: 0, duration: walkSpeed)
        let flipRight = SKAction.run { enemy.xScale = 0.8 }
        let moveRight = SKAction.moveBy(x: patrolDistance * 2, y: 0, duration: walkSpeed * 2)
        let flipLeft  = SKAction.run { enemy.xScale = -0.8 }
        let moveBack  = SKAction.moveBy(x: -patrolDistance, y: 0, duration: walkSpeed)
            
        // Stitch it together into a looping routine
        let patrolSequence = SKAction.sequence([moveLeft, flipRight, moveRight, flipLeft, moveBack])
        enemy.run(SKAction.repeatForever(patrolSequence), withKey: "enemyPatrol")
        
        // --- Keep his texture walking animation running concurrently ---
        var enemyAnimation = [SKTexture]()
        for i in 0...3 { enemyAnimation.append(SKTexture(imageNamed: "enemyWalk00\(i)")) }
        if !enemyAnimation.isEmpty {
            enemy.run(SKAction.repeatForever(SKAction.animate(with: enemyAnimation, timePerFrame: 0.15)), withKey: "enemyWalk")
        }
        
        // --- NEW: TRIGGER HAMMER ATTACK EVERY 3.5 SECONDS ---
        let waitAction = SKAction.wait(forDuration: 3.5)
        let attackAction = SKAction.run{ [weak self] in
            self?.executeHammerSlam(on: enemy)
            
        }
        
        enemy.run(SKAction.repeatForever(SKAction.sequence([waitAction, attackAction])), withKey: "enemyAttackLoop")
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
    
    func executeHammerSlam(on enemy: SKSpriteNode){
        // 1. Safety check: make sure Dedede hasn't already been defeated
        guard enemy.parent != nil else { return }
        
        // 2. Freeze his movement actions instantly so he doesn't slide while swinging
        enemy.removeAction(forKey: "enemyPatrol")
        enemy.removeAction(forKey: "enemyWalk")
        
        // 3. Load the sprite sheet frames (0 to 5)
        var slamFrames = [SKTexture]()
        for i in 0...5{
            slamFrames.append(SKTexture(imageNamed: "enemyAttack00\(i)"))
        }
        
        guard slamFrames.count == 6 else { return }
        
        // 4. Split up actions so we can track the exact moment of impact (Frame 4 -> Frame 5 Smear)
        let windUpAnimation = SKAction.animate(with: Array(slamFrames[0...3]), timePerFrame: 0.12)
        let strikeAnimation = SKAction.animate(with: [slamFrames[4]], timePerFrame: 0.10)
        let recoveryAnimation = SKAction.animate(with: [slamFrames[5]], timePerFrame: 0.25)
        
        // 5. This block runs the EXACT millisecond the hammer strikes the platform
        let damageCheck = SKAction.run{ [weak self] in
            guard let self = self else { return }
            
            // Calculate the attack range offset based on which direction Dedede is facing
            let isFacingLeft = enemy.xScale < 0
            let attackReach: CGFloat = 65 // Total horizontal reach of the giant hammer
            
            // The center of the explosion impact zone
            let impactX = isFacingLeft ? (enemy.position.x - attackReach) : (enemy.position.x + attackReach)
            
            // Check the structural distance between Kirby and the impact zone center
            let deltaX = abs(self.player.position.x - impactX)
            let deltaY = abs(self.player.position.y - enemy.position.y)
            
            // Hitbox parameters: within 50 pixels horizontally, and relatively level on Y axis
            if deltaX < 55 && deltaY < 60 {
                self.takeDamage(amount: 20) // The hammer chunks 25 HP
            }
            
            // Juice effect: Shake the camera slightly
            let shakeLeft = SKAction.moveBy(x: -5, y: 0, duration: 0.05)
            let shakeRight = SKAction.moveBy(x: 5, y: 0, duration: 0.05)
            self.cameraNode.run(SKAction.sequence([shakeLeft, shakeRight, shakeLeft, shakeRight]))
            
        }
        
        // 6. This block hooks back into your original system to turn walking back on
        let restorePatrol = SKAction.run{ [weak self] in
            guard let self = self, enemy.parent != nil else { return }
            
            // Re-compile your patrol rules dynamically
            let patrolDistance: CGFloat = 60
            let walkSpeed: TimeInterval = 1.8
            let moveLeft = SKAction.moveBy(x: -patrolDistance, y: 0, duration: walkSpeed)
            let flipRight = SKAction.run { enemy.xScale = 0.8 }
            let moveRight = SKAction.moveBy(x: patrolDistance * 2, y: 0, duration: walkSpeed * 2)
            let flipLeft = SKAction.run{ enemy.xScale = -0.8 }
            let moveBack = SKAction.moveBy(x: -patrolDistance, y: 0, duration: walkSpeed)
            
            let patrolSequence = SKAction.sequence([moveLeft, flipRight, moveRight, flipLeft, moveBack])
            enemy.run(SKAction.repeatForever(patrolSequence), withKey: "enemyPatrol")
            
            var enemyAnimation = [SKTexture]()
            for i in 0...3 { enemyAnimation.append(SKTexture(imageNamed: "enemyWalk00\(i)")) }
            enemy.run(SKAction.repeatForever(SKAction.animate(with: enemyAnimation, timePerFrame: 0.15)), withKey: "enemyWalk")
            
        }
        
        // 7. Piece the entire attack sequence together step-by-step
        let fullAttackSequence = SKAction.sequence([
            windUpAnimation,    // Frames 0-3: Dedede rears back
            strikeAnimation,    // Frame 4: SMASH DOWN
            damageCheck,        // Instant mathematical check + screen shake
            recoveryAnimation,  // Frame 5: Resting/lifting hammer back up
            restorePatrol       // Re-engage movement routines cleanly
        ])
            
        enemy.run(fullAttackSequence)
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
        ground.physicsBody?.collisionBitMask = playerCategory | trashCategory
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
        hudLabel.position = CGPoint(x: -size.width / 2 + 150, y: size.height / 2 - 40)
        hudLabel.zPosition = 10
        
        // Add directly to cameraNode
        cameraNode.addChild(hudLabel)
    }

    private func updateHUD() {
        hudLabel.text = "HP: \(kirbyHealth)  |  ATK: \(kirbyAttack)"
    }

    func takeDamage(amount: Int) {
        
        // 1. Guard check: If Kirby is currently invincible, ignore all incoming hits
        guard !isKirbyInvincible else { return }
        
        // 2. Activate invincibility instantly
        isKirbyInvincible = true
        
        
        // 3. Lower Kirby's health safely
        // (Change 'playerHP' to whatever your health variable is called)
        kirbyHealth -= amount
        if kirbyHealth <= 0 {
            kirbyHealth = 0
            print("Game Over!")
           
        }
        
        hudLabel.text = "HP: \(kirbyHealth) | ATK: \(kirbyAttack)"
        
        // 4. Knockback effect so Kirby physically separates from Dedede
        let pushDirection: CGFloat = (player.position.x < size.width / 2) ? -150 : 150
        player.physicsBody?.velocity = CGVector(dx: pushDirection, dy: 200)
        
        // 5. Visual feedback: Make Kirby blink red and get knocked back slightly
        let fadeOut = SKAction.fadeOut(withDuration: 0.1)
        let fadeIn = SKAction.fadeIn(withDuration: 0.1)
        let flashSequence = SKAction.sequence([fadeOut, fadeIn])
        let repeatFlash = SKAction.repeat(flashSequence, count: 4)
        
        // 6. Turn off invincibility automatically once the flashing actions finish
        player.run(repeatFlash){ [weak self] in
            self?.isKirbyInvincible = false
            
        }
    
    }

    private func createLedge(at pos: CGPoint, size: CGSize) {
        let ledge = SKSpriteNode(color: UIColor.systemPink.withAlphaComponent(0.6), size: size)
        ledge.position = pos
        ledge.zPosition = 3
        ledge.physicsBody = SKPhysicsBody(rectangleOf: size)
        ledge.physicsBody?.isDynamic = false
        ledge.physicsBody?.categoryBitMask = platformCategory
        ledge.physicsBody?.collisionBitMask = playerCategory | trashCategory
        addChild(ledge)
    }

    private func dropGoldenTrash(at pos: CGPoint) {
        print("TRASH DROPPED AT \(pos)")
        
        let trash = SKSpriteNode(imageNamed: "goldenTrash")
        trash.size = CGSize(width: 45, height: 45)
        trash.position = pos
        trash.zPosition = 4
        trash.physicsBody = SKPhysicsBody(rectangleOf: trash.size)
        trash.physicsBody?.isDynamic = true
        trash.physicsBody?.categoryBitMask = trashCategory
        trash.physicsBody?.contactTestBitMask = playerCategory
        trash.physicsBody?.collisionBitMask = groundCategory | platformCategory
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
