//
//  GameScene.swift
//  DotGame
//
//  Main game scene with all gameplay logic
//

import SpriteKit
import GameplayKit

// MARK: - Physics Categories
struct PhysicsCategory {
    static let none: UInt32 = 0
    static let player: UInt32 = 0b1
    static let enemy: UInt32 = 0b10
    static let powerUp: UInt32 = 0b100
    static let projectile: UInt32 = 0b1000
}

// MARK: - Power-up Types
enum PowerUpType: Int, CaseIterable {
    case health = 0
    case projectileSpeed = 1
    case projectileRange = 2

    var description: String {
        switch self {
        case .health: return "+1 Здоров'я"
        case .projectileSpeed: return "+1 Швидкість"
        case .projectileRange: return "+1 Дальність"
        }
    }

    var icon: String {
        switch self {
        case .health: return "❤️"
        case .projectileSpeed: return "⚡"
        case .projectileRange: return "🎯"
        }
    }
}

// MARK: - Enemy Node
class EnemyNode: SKShapeNode {
    var hitPoints: Int = 2

    static func create(radius: CGFloat) -> EnemyNode {
        let enemy = EnemyNode(circleOfRadius: radius)
        enemy.fillColor = UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
        enemy.strokeColor = UIColor(red: 0.7, green: 0.1, blue: 0.1, alpha: 1.0)
        enemy.lineWidth = 2
        enemy.name = "enemy"
        enemy.hitPoints = 2

        // Physics
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        enemy.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        enemy.physicsBody?.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.projectile
        enemy.physicsBody?.collisionBitMask = PhysicsCategory.none
        enemy.physicsBody?.affectedByGravity = false

        return enemy
    }

    func takeDamage() -> Bool {
        hitPoints -= 1
        if hitPoints <= 0 {
            return true // Should be destroyed
        }
        // Flash effect when hit
        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.05),
            SKAction.fadeAlpha(to: 1.0, duration: 0.05)
        ])
        self.run(flash)
        return false
    }
}

// MARK: - Game Scene
class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Properties

    // Player
    private var player: SKShapeNode!
    private var playerHealth: Int = 3
    private var targetPosition: CGPoint?

    // Stats
    private var projectileSpeed: CGFloat = 150
    private var projectileRange: CGFloat = 120
    private let baseProjectileSpeed: CGFloat = 150
    private let baseProjectileRange: CGFloat = 120

    // Enemy spawning
    private var enemySpawnTimer: TimeInterval = 0
    private var enemySpawnInterval: TimeInterval = 5.0
    private var enemyCount: Int = 3
    private var waveNumber: Int = 0

    // Power-up spawning
    private var powerUpSpawnTimer: TimeInterval = 0
    private var powerUpSpawnInterval: TimeInterval = 10.0

    // Shooting
    private var shootTimer: TimeInterval = 0
    private var shootInterval: TimeInterval = 0.5

    // UI
    private var healthLabel: SKLabelNode!
    private var statsLabel: SKLabelNode!
    private var gameOverNode: SKNode?
    private var abilitySelectionNode: SKNode?

    // Game state
    private var isGameOver = false
    private var isPaused = false
    private var score: Int = 0
    private var scoreLabel: SKLabelNode!

    // Constants
    private let playerRadius: CGFloat = 20
    private let enemyRadius: CGFloat = 15
    private let powerUpRadius: CGFloat = 12
    private let projectileRadius: CGFloat = 5
    private let playerSpeed: CGFloat = 200
    private let enemySpeed: CGFloat = 80
    private let minSpawnDistance: CGFloat = 150

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        setupScene()
        setupPlayer()
        setupUI()
        setupPhysics()
    }

    private func setupScene() {
        backgroundColor = .white
    }

    private func setupPlayer() {
        player = SKShapeNode(circleOfRadius: playerRadius)
        player.fillColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        player.strokeColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        player.lineWidth = 3
        player.position = CGPoint(x: size.width / 2, y: size.height / 2)
        player.name = "player"
        player.zPosition = 10

        // Add subtle shadow
        let shadow = SKShapeNode(circleOfRadius: playerRadius + 2)
        shadow.fillColor = UIColor(white: 0.0, alpha: 0.1)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 3, y: -3)
        shadow.zPosition = -1
        player.addChild(shadow)

        // Physics
        player.physicsBody = SKPhysicsBody(circleOfRadius: playerRadius)
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.powerUp
        player.physicsBody?.collisionBitMask = PhysicsCategory.none
        player.physicsBody?.affectedByGravity = false

        addChild(player)
    }

    private func setupUI() {
        // Health display
        healthLabel = SKLabelNode(fontNamed: "Helvetica Neue Bold")
        healthLabel.fontSize = 24
        healthLabel.fontColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        healthLabel.horizontalAlignmentMode = .left
        healthLabel.position = CGPoint(x: 20, y: size.height - 50)
        healthLabel.zPosition = 100
        addChild(healthLabel)

        // Stats display
        statsLabel = SKLabelNode(fontNamed: "Helvetica Neue")
        statsLabel.fontSize = 16
        statsLabel.fontColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        statsLabel.horizontalAlignmentMode = .left
        statsLabel.position = CGPoint(x: 20, y: size.height - 80)
        statsLabel.zPosition = 100
        addChild(statsLabel)

        // Score display
        scoreLabel = SKLabelNode(fontNamed: "Helvetica Neue Bold")
        scoreLabel.fontSize = 20
        scoreLabel.fontColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(x: size.width - 20, y: size.height - 50)
        scoreLabel.zPosition = 100
        addChild(scoreLabel)

        updateUI()
    }

    private func setupPhysics() {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
    }

    private func updateUI() {
        // Health hearts
        var hearts = ""
        for _ in 0..<playerHealth {
            hearts += "❤️"
        }
        for _ in 0..<max(0, 3 - playerHealth) {
            hearts += "🖤"
        }
        healthLabel.text = hearts

        // Stats
        let speedBonus = Int((projectileSpeed - baseProjectileSpeed) / 30)
        let rangeBonus = Int((projectileRange - baseProjectileRange) / 30)
        statsLabel.text = "⚡\(speedBonus)  🎯\(rangeBonus)"

        // Score
        scoreLabel.text = "Рахунок: \(score)"
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameOver, !isPaused else { return }

        if let touch = touches.first {
            let location = touch.location(in: self)

            // Check if touching ability button
            if let abilityNode = abilitySelectionNode {
                handleAbilitySelection(at: location)
                return
            }

            targetPosition = location
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameOver, !isPaused, abilitySelectionNode == nil else { return }

        if let touch = touches.first {
            targetPosition = touch.location(in: self)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if abilitySelectionNode == nil {
            targetPosition = nil
        }

        // Check for restart
        if isGameOver {
            if let touch = touches.first {
                let location = touch.location(in: self)
                let nodes = self.nodes(at: location)
                for node in nodes {
                    if node.name == "restartButton" {
                        restartGame()
                        return
                    }
                }
            }
        }
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver, !isPaused else { return }

        let deltaTime = 1.0 / 60.0 // Assume 60fps

        updatePlayerMovement(deltaTime: deltaTime)
        updateEnemies(deltaTime: deltaTime)
        updateSpawning(deltaTime: deltaTime)
        updateShooting(deltaTime: deltaTime)
    }

    private func updatePlayerMovement(deltaTime: TimeInterval) {
        guard let target = targetPosition else { return }

        let dx = target.x - player.position.x
        let dy = target.y - player.position.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance > 5 {
            let moveDistance = playerSpeed * CGFloat(deltaTime)
            let ratio = min(moveDistance / distance, 1.0)

            var newX = player.position.x + dx * ratio
            var newY = player.position.y + dy * ratio

            // Keep player in bounds
            newX = max(playerRadius, min(size.width - playerRadius, newX))
            newY = max(playerRadius, min(size.height - playerRadius, newY))

            player.position = CGPoint(x: newX, y: newY)
        }
    }

    private func updateEnemies(deltaTime: TimeInterval) {
        enumerateChildNodes(withName: "enemy") { [weak self] node, _ in
            guard let self = self else { return }

            let dx = self.player.position.x - node.position.x
            let dy = self.player.position.y - node.position.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance > 1 {
                let moveDistance = self.enemySpeed * CGFloat(deltaTime)
                let ratio = moveDistance / distance

                node.position.x += dx * ratio
                node.position.y += dy * ratio
            }
        }
    }

    private func updateSpawning(deltaTime: TimeInterval) {
        // Enemy spawning
        enemySpawnTimer += deltaTime
        if enemySpawnTimer >= enemySpawnInterval {
            enemySpawnTimer = 0
            waveNumber += 1
            spawnEnemyWave()
        }

        // Power-up spawning
        powerUpSpawnTimer += deltaTime
        if powerUpSpawnTimer >= powerUpSpawnInterval {
            powerUpSpawnTimer = 0
            spawnPowerUp()
        }
    }

    private func updateShooting(deltaTime: TimeInterval) {
        shootTimer += deltaTime
        if shootTimer >= shootInterval {
            shootTimer = 0
            tryShootAtNearestEnemy()
        }
    }

    // MARK: - Spawning

    private func spawnEnemyWave() {
        let enemiesToSpawn = enemyCount + waveNumber - 1

        for _ in 0..<enemiesToSpawn {
            spawnEnemy()
        }
    }

    private func spawnEnemy() {
        let enemy = EnemyNode.create(radius: enemyRadius)

        // Find random position away from player
        var position: CGPoint
        var attempts = 0
        repeat {
            position = CGPoint(
                x: CGFloat.random(in: enemyRadius...(size.width - enemyRadius)),
                y: CGFloat.random(in: enemyRadius...(size.height - enemyRadius))
            )
            attempts += 1
        } while distanceFrom(position, to: player.position) < minSpawnDistance && attempts < 50

        enemy.position = position
        enemy.alpha = 0
        enemy.setScale(0.3)

        addChild(enemy)

        // Spawn animation
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
        enemy.run(SKAction.group([fadeIn, scaleUp]))
    }

    private func spawnPowerUp() {
        let powerUp = SKShapeNode(circleOfRadius: powerUpRadius)
        powerUp.fillColor = UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0)
        powerUp.strokeColor = UIColor(red: 0.9, green: 0.7, blue: 0.0, alpha: 1.0)
        powerUp.lineWidth = 2
        powerUp.name = "powerUp"
        powerUp.zPosition = 5

        // Glow effect
        let glow = SKShapeNode(circleOfRadius: powerUpRadius + 4)
        glow.fillColor = UIColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 0.3)
        glow.strokeColor = .clear
        glow.zPosition = -1
        powerUp.addChild(glow)

        // Pulsing animation for glow
        let pulseUp = SKAction.scale(to: 1.3, duration: 0.5)
        let pulseDown = SKAction.scale(to: 1.0, duration: 0.5)
        let pulse = SKAction.repeatForever(SKAction.sequence([pulseUp, pulseDown]))
        glow.run(pulse)

        // Find random position
        var position: CGPoint
        var attempts = 0
        repeat {
            position = CGPoint(
                x: CGFloat.random(in: powerUpRadius * 2...(size.width - powerUpRadius * 2)),
                y: CGFloat.random(in: powerUpRadius * 2...(size.height - powerUpRadius * 2))
            )
            attempts += 1
        } while distanceFrom(position, to: player.position) < minSpawnDistance / 2 && attempts < 50

        powerUp.position = position

        // Physics
        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: powerUpRadius)
        powerUp.physicsBody?.categoryBitMask = PhysicsCategory.powerUp
        powerUp.physicsBody?.contactTestBitMask = PhysicsCategory.player
        powerUp.physicsBody?.collisionBitMask = PhysicsCategory.none
        powerUp.physicsBody?.affectedByGravity = false

        powerUp.alpha = 0
        addChild(powerUp)

        // Spawn animation
        powerUp.run(SKAction.fadeIn(withDuration: 0.3))
    }

    // MARK: - Shooting

    private func tryShootAtNearestEnemy() {
        var nearestEnemy: SKNode?
        var nearestDistance: CGFloat = projectileRange

        enumerateChildNodes(withName: "enemy") { [weak self] node, stop in
            guard let self = self else { return }
            let distance = self.distanceFrom(self.player.position, to: node.position)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestEnemy = node
            }
        }

        if let enemy = nearestEnemy {
            shootProjectile(at: enemy.position)
        }
    }

    private func shootProjectile(at target: CGPoint) {
        let projectile = SKShapeNode(circleOfRadius: projectileRadius)
        projectile.fillColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        projectile.strokeColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        projectile.lineWidth = 1
        projectile.position = player.position
        projectile.name = "projectile"
        projectile.zPosition = 8

        // Physics
        projectile.physicsBody = SKPhysicsBody(circleOfRadius: projectileRadius)
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.projectile
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.enemy
        projectile.physicsBody?.collisionBitMask = PhysicsCategory.none
        projectile.physicsBody?.affectedByGravity = false

        addChild(projectile)

        // Calculate direction and velocity
        let dx = target.x - player.position.x
        let dy = target.y - player.position.y
        let distance = sqrt(dx * dx + dy * dy)

        let normalizedDx = dx / distance
        let normalizedDy = dy / distance

        let velocity = CGVector(dx: normalizedDx * projectileSpeed, dy: normalizedDy * projectileSpeed)
        projectile.physicsBody?.velocity = velocity

        // Remove after traveling max range
        let travelTime = TimeInterval(projectileRange / projectileSpeed)
        let remove = SKAction.sequence([
            SKAction.wait(forDuration: travelTime),
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.removeFromParent()
        ])
        projectile.run(remove)
    }

    // MARK: - Physics Contact

    func didBegin(_ contact: SKPhysicsContact) {
        let firstBody = contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask ? contact.bodyA : contact.bodyB
        let secondBody = contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask ? contact.bodyB : contact.bodyA

        // Player hit by enemy
        if firstBody.categoryBitMask == PhysicsCategory.player &&
            secondBody.categoryBitMask == PhysicsCategory.enemy {
            if let enemy = secondBody.node {
                enemyHitPlayer(enemy: enemy)
            }
        }

        // Player collects power-up
        if firstBody.categoryBitMask == PhysicsCategory.player &&
            secondBody.categoryBitMask == PhysicsCategory.powerUp {
            if let powerUp = secondBody.node {
                collectPowerUp(powerUp: powerUp)
            }
        }

        // Projectile hits enemy
        if firstBody.categoryBitMask == PhysicsCategory.enemy &&
            secondBody.categoryBitMask == PhysicsCategory.projectile {
            if let enemy = firstBody.node as? EnemyNode,
               let projectile = secondBody.node {
                projectileHitEnemy(projectile: projectile, enemy: enemy)
            }
        }
    }

    private func enemyHitPlayer(enemy: SKNode) {
        // Destroy enemy
        let explosion = createExplosion(at: enemy.position, color: .red)
        addChild(explosion)
        enemy.removeFromParent()

        // Damage player
        playerHealth -= 1
        updateUI()

        // Player hit effect
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in self?.player.fillColor = UIColor.red },
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in self?.player.fillColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0) }
        ])
        player.run(SKAction.repeat(flash, count: 3))

        // Check game over
        if playerHealth <= 0 {
            gameOver()
        }
    }

    private func collectPowerUp(powerUp: SKNode) {
        // Remove power-up with effect
        let collect = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.5, duration: 0.1),
                SKAction.fadeOut(withDuration: 0.1)
            ]),
            SKAction.removeFromParent()
        ])
        powerUp.run(collect)

        // Show ability selection
        showAbilitySelection()
    }

    private func projectileHitEnemy(projectile: SKNode, enemy: EnemyNode) {
        // Remove projectile
        projectile.removeFromParent()

        // Damage enemy
        if enemy.takeDamage() {
            // Destroy enemy
            let explosion = createExplosion(at: enemy.position, color: .red)
            addChild(explosion)
            enemy.removeFromParent()
            score += 10
            updateUI()
        }
    }

    // MARK: - Ability Selection

    private func showAbilitySelection() {
        isPaused = true

        let container = SKNode()
        container.zPosition = 200
        container.name = "abilitySelection"

        // Background overlay
        let overlay = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        overlay.fillColor = UIColor(white: 1.0, alpha: 0.9)
        overlay.strokeColor = .clear
        overlay.zPosition = -1
        container.addChild(overlay)

        // Title
        let title = SKLabelNode(fontNamed: "Helvetica Neue Bold")
        title.text = "Оберіть здібність"
        title.fontSize = 28
        title.fontColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        title.position = CGPoint(x: size.width / 2, y: size.height / 2 + 120)
        container.addChild(title)

        // Generate 3 random abilities
        let abilities = PowerUpType.allCases.shuffled()
        let buttonWidth: CGFloat = 200
        let buttonHeight: CGFloat = 60
        let spacing: CGFloat = 20

        for (index, ability) in abilities.enumerated() {
            let buttonY = size.height / 2 + 30 - CGFloat(index) * (buttonHeight + spacing)

            let button = SKShapeNode(rect: CGRect(x: -buttonWidth / 2, y: -buttonHeight / 2, width: buttonWidth, height: buttonHeight), cornerRadius: 12)
            button.fillColor = getAbilityColor(ability)
            button.strokeColor = getAbilityBorderColor(ability)
            button.lineWidth = 2
            button.position = CGPoint(x: size.width / 2, y: buttonY)
            button.name = "ability_\(ability.rawValue)"
            container.addChild(button)

            let label = SKLabelNode(fontNamed: "Helvetica Neue Bold")
            label.text = "\(ability.icon) \(ability.description)"
            label.fontSize = 18
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: size.width / 2, y: buttonY)
            label.name = "ability_\(ability.rawValue)"
            container.addChild(label)
        }

        abilitySelectionNode = container
        addChild(container)
    }

    private func getAbilityColor(_ ability: PowerUpType) -> UIColor {
        switch ability {
        case .health: return UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        case .projectileSpeed: return UIColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1.0)
        case .projectileRange: return UIColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1.0)
        }
    }

    private func getAbilityBorderColor(_ ability: PowerUpType) -> UIColor {
        switch ability {
        case .health: return UIColor(red: 0.7, green: 0.1, blue: 0.1, alpha: 1.0)
        case .projectileSpeed: return UIColor(red: 0.1, green: 0.4, blue: 0.7, alpha: 1.0)
        case .projectileRange: return UIColor(red: 0.1, green: 0.6, blue: 0.2, alpha: 1.0)
        }
    }

    private func handleAbilitySelection(at location: CGPoint) {
        let nodes = self.nodes(at: location)

        for node in nodes {
            if let name = node.name, name.hasPrefix("ability_") {
                let abilityRaw = Int(name.replacingOccurrences(of: "ability_", with: "")) ?? 0
                if let ability = PowerUpType(rawValue: abilityRaw) {
                    applyAbility(ability)

                    // Remove selection UI
                    abilitySelectionNode?.removeFromParent()
                    abilitySelectionNode = nil
                    isPaused = false
                    return
                }
            }
        }
    }

    private func applyAbility(_ ability: PowerUpType) {
        switch ability {
        case .health:
            playerHealth += 1
        case .projectileSpeed:
            projectileSpeed += 30
        case .projectileRange:
            projectileRange += 30
        }
        updateUI()

        // Visual feedback
        let feedback = SKLabelNode(fontNamed: "Helvetica Neue Bold")
        feedback.text = ability.description
        feedback.fontSize = 24
        feedback.fontColor = getAbilityColor(ability)
        feedback.position = CGPoint(x: player.position.x, y: player.position.y + 50)
        feedback.zPosition = 150
        addChild(feedback)

        let float = SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 30, duration: 1.0),
                SKAction.fadeOut(withDuration: 1.0)
            ]),
            SKAction.removeFromParent()
        ])
        feedback.run(float)
    }

    // MARK: - Game Over

    private func gameOver() {
        isGameOver = true

        let container = SKNode()
        container.zPosition = 200

        // Background overlay
        let overlay = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        overlay.fillColor = UIColor(white: 0.0, alpha: 0.7)
        overlay.strokeColor = .clear
        overlay.zPosition = -1
        container.addChild(overlay)

        // Game Over text
        let gameOverLabel = SKLabelNode(fontNamed: "Helvetica Neue Bold")
        gameOverLabel.text = "Гру закінчено"
        gameOverLabel.fontSize = 42
        gameOverLabel.fontColor = .white
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 60)
        container.addChild(gameOverLabel)

        // Score
        let finalScore = SKLabelNode(fontNamed: "Helvetica Neue")
        finalScore.text = "Рахунок: \(score)"
        finalScore.fontSize = 28
        finalScore.fontColor = .white
        finalScore.position = CGPoint(x: size.width / 2, y: size.height / 2)
        container.addChild(finalScore)

        // Wave reached
        let waveLabel = SKLabelNode(fontNamed: "Helvetica Neue")
        waveLabel.text = "Хвиля: \(waveNumber)"
        waveLabel.fontSize = 22
        waveLabel.fontColor = UIColor(white: 0.8, alpha: 1.0)
        waveLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 40)
        container.addChild(waveLabel)

        // Restart button
        let buttonWidth: CGFloat = 180
        let buttonHeight: CGFloat = 50
        let restartButton = SKShapeNode(rect: CGRect(x: -buttonWidth / 2, y: -buttonHeight / 2, width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        restartButton.fillColor = UIColor(red: 0.3, green: 0.7, blue: 0.4, alpha: 1.0)
        restartButton.strokeColor = UIColor(red: 0.2, green: 0.5, blue: 0.3, alpha: 1.0)
        restartButton.lineWidth = 2
        restartButton.position = CGPoint(x: size.width / 2, y: size.height / 2 - 110)
        restartButton.name = "restartButton"
        container.addChild(restartButton)

        let restartLabel = SKLabelNode(fontNamed: "Helvetica Neue Bold")
        restartLabel.text = "Грати знову"
        restartLabel.fontSize = 20
        restartLabel.fontColor = .white
        restartLabel.verticalAlignmentMode = .center
        restartLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 110)
        restartLabel.name = "restartButton"
        container.addChild(restartLabel)

        gameOverNode = container
        addChild(container)
    }

    private func restartGame() {
        // Remove game over UI
        gameOverNode?.removeFromParent()
        gameOverNode = nil

        // Remove all enemies, projectiles, and power-ups
        enumerateChildNodes(withName: "enemy") { node, _ in node.removeFromParent() }
        enumerateChildNodes(withName: "projectile") { node, _ in node.removeFromParent() }
        enumerateChildNodes(withName: "powerUp") { node, _ in node.removeFromParent() }

        // Reset player
        player.position = CGPoint(x: size.width / 2, y: size.height / 2)
        playerHealth = 3

        // Reset stats
        projectileSpeed = baseProjectileSpeed
        projectileRange = baseProjectileRange

        // Reset spawning
        enemySpawnTimer = 0
        powerUpSpawnTimer = 0
        waveNumber = 0

        // Reset score
        score = 0

        // Reset state
        isGameOver = false
        isPaused = false
        targetPosition = nil

        updateUI()
    }

    // MARK: - Helpers

    private func distanceFrom(_ point1: CGPoint, to point2: CGPoint) -> CGFloat {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return sqrt(dx * dx + dy * dy)
    }

    private func createExplosion(at position: CGPoint, color: UIColor) -> SKNode {
        let container = SKNode()
        container.position = position
        container.zPosition = 50

        for _ in 0..<8 {
            let particle = SKShapeNode(circleOfRadius: 4)
            particle.fillColor = color
            particle.strokeColor = .clear

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 20...40)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance

            container.addChild(particle)

            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.3)
            let fade = SKAction.fadeOut(withDuration: 0.3)
            let remove = SKAction.removeFromParent()

            particle.run(SKAction.sequence([SKAction.group([move, fade]), remove]))
        }

        let containerRemove = SKAction.sequence([
            SKAction.wait(forDuration: 0.4),
            SKAction.removeFromParent()
        ])
        container.run(containerRemove)

        return container
    }
}
