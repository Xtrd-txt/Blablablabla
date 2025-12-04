import SpriteKit

// MARK: - Physics Categories
struct PhysicsCategory {
    static let none: UInt32 = 0
    static let player: UInt32 = 0b1
    static let enemy: UInt32 = 0b10
    static let projectile: UInt32 = 0b100
    static let powerUp: UInt32 = 0b1000
}

// MARK: - Enemy Node
class EnemyNode: SKShapeNode {
    var hitCount: Int = 0
    let maxHits: Int = 2

    func takeDamage() -> Bool {
        hitCount += 1
        // Flash effect
        let fadeOut = SKAction.fadeAlpha(to: 0.5, duration: 0.1)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        run(SKAction.sequence([fadeOut, fadeIn]))
        return hitCount >= maxHits
    }
}

// MARK: - GameScene
class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Properties

    // Player
    private var player: SKShapeNode!
    private var targetPosition: CGPoint?
    private let playerSpeed: CGFloat = 200
    private let playerRadius: CGFloat = 20

    // Health
    private var health: Int = 3 {
        didSet {
            updateHealthDisplay()
            if health <= 0 {
                gameOver()
            }
        }
    }
    private var healthLabel: SKLabelNode!
    private var healthIcons: [SKShapeNode] = []

    // Enemies
    private var enemies: [EnemyNode] = []
    private let enemyRadius: CGFloat = 15
    private let enemySpeed: CGFloat = 80
    private var enemySpawnCount: Int = 3
    private var enemySpawnTimer: TimeInterval = 0
    private let enemySpawnInterval: TimeInterval = 5.0
    private let minSpawnDistance: CGFloat = 150

    // Power-ups
    private var powerUps: [SKShapeNode] = []
    private let powerUpRadius: CGFloat = 12
    private var powerUpTimer: TimeInterval = 0
    private let powerUpInterval: TimeInterval = 10.0

    // Projectiles
    private var projectiles: [SKShapeNode] = []
    private let projectileRadius: CGFloat = 6
    private var projectileSpeed: CGFloat = 150
    private var projectileRange: CGFloat = 120
    private var shootCooldown: TimeInterval = 0
    private let shootInterval: TimeInterval = 0.5

    // Stats
    private var projectileSpeedLevel: Int = 1
    private var projectileRangeLevel: Int = 1

    // UI
    private var scoreLabel: SKLabelNode!
    private var score: Int = 0
    private var gameTime: TimeInterval = 0
    private var isGameOver: Bool = false
    private var isPaused: Bool = false

    // Buff selection UI
    private var buffSelectionActive: Bool = false
    private var buffPanel: SKNode?

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .white
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        setupPlayer()
        setupUI()
        spawnEnemies()
    }

    // MARK: - Setup

    private func setupPlayer() {
        player = SKShapeNode(circleOfRadius: playerRadius)
        player.fillColor = .black
        player.strokeColor = .clear
        player.position = CGPoint(x: size.width / 2, y: size.height / 2)
        player.zPosition = 10
        player.name = "player"

        player.physicsBody = SKPhysicsBody(circleOfRadius: playerRadius)
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.powerUp
        player.physicsBody?.collisionBitMask = PhysicsCategory.none
        player.physicsBody?.isDynamic = true

        addChild(player)
    }

    private func setupUI() {
        // Health display
        let healthContainer = SKNode()
        healthContainer.position = CGPoint(x: 20, y: size.height - 50)
        healthContainer.zPosition = 100
        addChild(healthContainer)

        healthLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        healthLabel.text = "HP:"
        healthLabel.fontSize = 18
        healthLabel.fontColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        healthLabel.horizontalAlignmentMode = .left
        healthLabel.position = .zero
        healthContainer.addChild(healthLabel)

        updateHealthDisplay()

        // Score/Time display
        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLabel.fontSize = 18
        scoreLabel.fontColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(x: size.width - 20, y: size.height - 50)
        scoreLabel.zPosition = 100
        addChild(scoreLabel)
        updateScoreDisplay()

        // Stats display
        let statsLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        statsLabel.fontSize = 14
        statsLabel.fontColor = SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        statsLabel.horizontalAlignmentMode = .left
        statsLabel.position = CGPoint(x: 20, y: size.height - 80)
        statsLabel.zPosition = 100
        statsLabel.name = "statsLabel"
        addChild(statsLabel)
        updateStatsDisplay()
    }

    private func updateHealthDisplay() {
        // Remove old health icons
        healthIcons.forEach { $0.removeFromParent() }
        healthIcons.removeAll()

        // Create new health icons
        for i in 0..<health {
            let heart = SKShapeNode(circleOfRadius: 8)
            heart.fillColor = SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
            heart.strokeColor = .clear
            heart.position = CGPoint(x: 60 + CGFloat(i) * 25, y: size.height - 50)
            heart.zPosition = 100
            addChild(heart)
            healthIcons.append(heart)
        }
    }

    private func updateScoreDisplay() {
        let minutes = Int(gameTime) / 60
        let seconds = Int(gameTime) % 60
        scoreLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }

    private func updateStatsDisplay() {
        if let statsLabel = childNode(withName: "statsLabel") as? SKLabelNode {
            statsLabel.text = "SPD: \(projectileSpeedLevel) | RNG: \(projectileRangeLevel)"
        }
    }

    // MARK: - Enemy Spawning

    private func spawnEnemies() {
        for _ in 0..<enemySpawnCount {
            spawnEnemy()
        }
    }

    private func spawnEnemy() {
        let enemy = EnemyNode(circleOfRadius: enemyRadius)
        enemy.fillColor = SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        enemy.strokeColor = .clear
        enemy.name = "enemy"
        enemy.zPosition = 5

        // Find valid spawn position
        var spawnPosition: CGPoint
        repeat {
            spawnPosition = CGPoint(
                x: CGFloat.random(in: enemyRadius...(size.width - enemyRadius)),
                y: CGFloat.random(in: enemyRadius...(size.height - enemyRadius))
            )
        } while distance(from: spawnPosition, to: player.position) < minSpawnDistance

        enemy.position = spawnPosition

        enemy.physicsBody = SKPhysicsBody(circleOfRadius: enemyRadius)
        enemy.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        enemy.physicsBody?.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.projectile
        enemy.physicsBody?.collisionBitMask = PhysicsCategory.none
        enemy.physicsBody?.isDynamic = true

        addChild(enemy)
        enemies.append(enemy)

        // Spawn animation
        enemy.setScale(0)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
        scaleUp.timingMode = .easeOut
        enemy.run(scaleUp)
    }

    // MARK: - Power-up Spawning

    private func spawnPowerUp() {
        let powerUp = SKShapeNode(circleOfRadius: powerUpRadius)
        powerUp.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
        powerUp.strokeColor = SKColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1.0)
        powerUp.lineWidth = 2
        powerUp.name = "powerUp"
        powerUp.zPosition = 5

        // Find valid spawn position
        var spawnPosition: CGPoint
        repeat {
            spawnPosition = CGPoint(
                x: CGFloat.random(in: powerUpRadius * 2...(size.width - powerUpRadius * 2)),
                y: CGFloat.random(in: powerUpRadius * 2...(size.height - powerUpRadius * 2))
            )
        } while distance(from: spawnPosition, to: player.position) < 100

        powerUp.position = spawnPosition

        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: powerUpRadius)
        powerUp.physicsBody?.categoryBitMask = PhysicsCategory.powerUp
        powerUp.physicsBody?.contactTestBitMask = PhysicsCategory.player
        powerUp.physicsBody?.collisionBitMask = PhysicsCategory.none
        powerUp.physicsBody?.isDynamic = false

        addChild(powerUp)
        powerUps.append(powerUp)

        // Glow animation
        let glowUp = SKAction.fadeAlpha(to: 0.7, duration: 0.5)
        let glowDown = SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        let glowSequence = SKAction.sequence([glowUp, glowDown])
        powerUp.run(SKAction.repeatForever(glowSequence))

        // Spawn animation
        powerUp.setScale(0)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
        scaleUp.timingMode = .easeOut
        powerUp.run(scaleUp)
    }

    // MARK: - Projectile System

    private func shootAtEnemy(_ enemy: EnemyNode) {
        let projectile = SKShapeNode(circleOfRadius: projectileRadius)
        projectile.fillColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        projectile.strokeColor = .clear
        projectile.position = player.position
        projectile.zPosition = 8
        projectile.name = "projectile"

        projectile.physicsBody = SKPhysicsBody(circleOfRadius: projectileRadius)
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.projectile
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.enemy
        projectile.physicsBody?.collisionBitMask = PhysicsCategory.none
        projectile.physicsBody?.isDynamic = true

        addChild(projectile)
        projectiles.append(projectile)

        // Calculate direction
        let direction = CGVector(
            dx: enemy.position.x - player.position.x,
            dy: enemy.position.y - player.position.y
        )
        let length = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
        let normalizedDirection = CGVector(
            dx: direction.dx / length,
            dy: direction.dy / length
        )

        // Calculate actual range based on level
        let actualRange = projectileRange + CGFloat(projectileRangeLevel - 1) * 30
        let actualSpeed = projectileSpeed + CGFloat(projectileSpeedLevel - 1) * 50

        let targetPoint = CGPoint(
            x: player.position.x + normalizedDirection.dx * actualRange,
            y: player.position.y + normalizedDirection.dy * actualRange
        )

        let duration = TimeInterval(actualRange / actualSpeed)

        let moveAction = SKAction.move(to: targetPoint, duration: duration)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let remove = SKAction.run { [weak self, weak projectile] in
            if let proj = projectile {
                self?.removeProjectile(proj)
            }
        }

        projectile.run(SKAction.sequence([moveAction, fadeOut, remove]))
    }

    private func removeProjectile(_ projectile: SKShapeNode) {
        if let index = projectiles.firstIndex(of: projectile) {
            projectiles.remove(at: index)
        }
        projectile.removeFromParent()
    }

    // MARK: - Buff Selection

    private func showBuffSelection() {
        buffSelectionActive = true
        isPaused = true

        // Dim background
        let dimOverlay = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        dimOverlay.fillColor = SKColor(white: 0, alpha: 0.5)
        dimOverlay.strokeColor = .clear
        dimOverlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        dimOverlay.zPosition = 200
        dimOverlay.name = "dimOverlay"

        // Panel
        let panel = SKNode()
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        panel.zPosition = 210
        panel.name = "buffPanel"

        let panelBg = SKShapeNode(rectOf: CGSize(width: 280, height: 350), cornerRadius: 20)
        panelBg.fillColor = .white
        panelBg.strokeColor = SKColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        panelBg.lineWidth = 2
        panel.addChild(panelBg)

        // Title
        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "CHOOSE BUFF"
        title.fontSize = 22
        title.fontColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        title.position = CGPoint(x: 0, y: 130)
        panel.addChild(title)

        // Buff options
        let buffs = [
            ("❤️ +1 Health", "buff_health"),
            ("⚡ +1 Speed", "buff_speed"),
            ("🎯 +1 Range", "buff_range")
        ]

        for (index, buff) in buffs.enumerated() {
            let yPos = 50 - CGFloat(index) * 80

            let button = SKShapeNode(rectOf: CGSize(width: 240, height: 60), cornerRadius: 12)
            button.fillColor = SKColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
            button.strokeColor = SKColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
            button.lineWidth = 1
            button.position = CGPoint(x: 0, y: yPos)
            button.name = buff.1
            panel.addChild(button)

            let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
            label.text = buff.0
            label.fontSize = 18
            label.fontColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: yPos)
            label.name = buff.1
            panel.addChild(label)
        }

        addChild(dimOverlay)
        addChild(panel)
        buffPanel = panel

        // Animate in
        panel.setScale(0.5)
        panel.alpha = 0
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        scaleUp.timingMode = .easeOut
        panel.run(SKAction.group([scaleUp, fadeIn]))
    }

    private func selectBuff(_ buffType: String) {
        switch buffType {
        case "buff_health":
            health += 1
        case "buff_speed":
            projectileSpeedLevel += 1
        case "buff_range":
            projectileRangeLevel += 1
        default:
            break
        }

        updateStatsDisplay()
        hideBuffSelection()
    }

    private func hideBuffSelection() {
        buffSelectionActive = false
        isPaused = false

        childNode(withName: "dimOverlay")?.removeFromParent()
        buffPanel?.removeFromParent()
        buffPanel = nil
    }

    // MARK: - Game Over

    private func gameOver() {
        guard !isGameOver else { return }
        isGameOver = true

        // Stop all enemies
        enemies.forEach { $0.removeAllActions() }

        // Game over panel
        let panel = SKNode()
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        panel.zPosition = 300

        let panelBg = SKShapeNode(rectOf: CGSize(width: 280, height: 250), cornerRadius: 20)
        panelBg.fillColor = .white
        panelBg.strokeColor = SKColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        panelBg.lineWidth = 2
        panel.addChild(panelBg)

        let gameOverLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        gameOverLabel.text = "GAME OVER"
        gameOverLabel.fontSize = 28
        gameOverLabel.fontColor = SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        gameOverLabel.position = CGPoint(x: 0, y: 60)
        panel.addChild(gameOverLabel)

        let timeLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        let minutes = Int(gameTime) / 60
        let seconds = Int(gameTime) % 60
        timeLabel.text = String(format: "Survived: %02d:%02d", minutes, seconds)
        timeLabel.fontSize = 20
        timeLabel.fontColor = SKColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        timeLabel.position = CGPoint(x: 0, y: 20)
        panel.addChild(timeLabel)

        // Restart button
        let restartButton = SKShapeNode(rectOf: CGSize(width: 180, height: 50), cornerRadius: 25)
        restartButton.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        restartButton.strokeColor = .clear
        restartButton.position = CGPoint(x: 0, y: -50)
        restartButton.name = "restartButton"
        panel.addChild(restartButton)

        let restartLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        restartLabel.text = "RESTART"
        restartLabel.fontSize = 18
        restartLabel.fontColor = .white
        restartLabel.verticalAlignmentMode = .center
        restartLabel.position = CGPoint(x: 0, y: -50)
        restartLabel.name = "restartButton"
        panel.addChild(restartLabel)

        addChild(panel)

        // Animate
        panel.setScale(0.5)
        panel.alpha = 0
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        panel.run(SKAction.group([scaleUp, fadeIn]))
    }

    private func restartGame() {
        let newScene = GameScene(size: size)
        newScene.scaleMode = .aspectFill
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(newScene, transition: transition)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNodes = nodes(at: location)

        // Check for restart button
        if isGameOver {
            for node in touchedNodes {
                if node.name == "restartButton" {
                    restartGame()
                    return
                }
            }
            return
        }

        // Check for buff selection
        if buffSelectionActive {
            for node in touchedNodes {
                if let name = node.name, name.hasPrefix("buff_") {
                    selectBuff(name)
                    return
                }
            }
            return
        }

        targetPosition = location
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameOver && !buffSelectionActive else { return }
        guard let touch = touches.first else { return }
        targetPosition = touch.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Keep moving to last target
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver && !isPaused else { return }

        let deltaTime = 1.0 / 60.0 // Approximate frame time
        gameTime += deltaTime

        updateScoreDisplay()
        updatePlayerMovement(deltaTime: deltaTime)
        updateEnemies(deltaTime: deltaTime)
        updateSpawning(deltaTime: deltaTime)
        updateShooting(deltaTime: deltaTime)
    }

    private func updatePlayerMovement(deltaTime: TimeInterval) {
        guard let target = targetPosition else { return }

        let dx = target.x - player.position.x
        let dy = target.y - player.position.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist > 5 {
            let moveX = (dx / dist) * playerSpeed * CGFloat(deltaTime)
            let moveY = (dy / dist) * playerSpeed * CGFloat(deltaTime)

            var newX = player.position.x + moveX
            var newY = player.position.y + moveY

            // Keep player in bounds
            newX = max(playerRadius, min(size.width - playerRadius, newX))
            newY = max(playerRadius, min(size.height - playerRadius, newY))

            player.position = CGPoint(x: newX, y: newY)
        }
    }

    private func updateEnemies(deltaTime: TimeInterval) {
        for enemy in enemies {
            let dx = player.position.x - enemy.position.x
            let dy = player.position.y - enemy.position.y
            let dist = sqrt(dx * dx + dy * dy)

            if dist > 0 {
                let moveX = (dx / dist) * enemySpeed * CGFloat(deltaTime)
                let moveY = (dy / dist) * enemySpeed * CGFloat(deltaTime)
                enemy.position = CGPoint(
                    x: enemy.position.x + moveX,
                    y: enemy.position.y + moveY
                )
            }
        }
    }

    private func updateSpawning(deltaTime: TimeInterval) {
        // Enemy spawning
        enemySpawnTimer += deltaTime
        if enemySpawnTimer >= enemySpawnInterval {
            enemySpawnTimer = 0
            enemySpawnCount += 1
            spawnEnemies()
        }

        // Power-up spawning
        powerUpTimer += deltaTime
        if powerUpTimer >= powerUpInterval {
            powerUpTimer = 0
            spawnPowerUp()
        }
    }

    private func updateShooting(deltaTime: TimeInterval) {
        shootCooldown -= deltaTime

        if shootCooldown <= 0 {
            // Find closest enemy in range
            let actualRange = projectileRange + CGFloat(projectileRangeLevel - 1) * 30

            var closestEnemy: EnemyNode?
            var closestDistance: CGFloat = actualRange

            for enemy in enemies {
                let dist = distance(from: player.position, to: enemy.position)
                if dist < closestDistance {
                    closestDistance = dist
                    closestEnemy = enemy
                }
            }

            if let enemy = closestEnemy {
                shootAtEnemy(enemy)
                shootCooldown = shootInterval
            }
        }
    }

    // MARK: - Physics Contact

    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        // Player hit by enemy
        if collision == PhysicsCategory.player | PhysicsCategory.enemy {
            let enemyNode = (contact.bodyA.categoryBitMask == PhysicsCategory.enemy ? contact.bodyA.node : contact.bodyB.node) as? EnemyNode
            if let enemy = enemyNode {
                playerHitByEnemy(enemy)
            }
        }

        // Projectile hits enemy
        if collision == PhysicsCategory.projectile | PhysicsCategory.enemy {
            let projectileNode = contact.bodyA.categoryBitMask == PhysicsCategory.projectile ? contact.bodyA.node : contact.bodyB.node
            let enemyNode = (contact.bodyA.categoryBitMask == PhysicsCategory.enemy ? contact.bodyA.node : contact.bodyB.node) as? EnemyNode

            if let projectile = projectileNode as? SKShapeNode, let enemy = enemyNode {
                projectileHitEnemy(projectile: projectile, enemy: enemy)
            }
        }

        // Player collects power-up
        if collision == PhysicsCategory.player | PhysicsCategory.powerUp {
            let powerUpNode = contact.bodyA.categoryBitMask == PhysicsCategory.powerUp ? contact.bodyA.node : contact.bodyB.node
            if let powerUp = powerUpNode as? SKShapeNode {
                collectPowerUp(powerUp)
            }
        }
    }

    private func playerHitByEnemy(_ enemy: EnemyNode) {
        // Remove enemy
        if let index = enemies.firstIndex(of: enemy) {
            enemies.remove(at: index)
        }
        enemy.removeFromParent()

        // Damage player
        health -= 1

        // Flash player red
        let originalColor = player.fillColor
        player.fillColor = SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        let wait = SKAction.wait(forDuration: 0.2)
        let restore = SKAction.run { [weak self] in
            self?.player.fillColor = originalColor
        }
        player.run(SKAction.sequence([wait, restore]))
    }

    private func projectileHitEnemy(projectile: SKShapeNode, enemy: EnemyNode) {
        // Remove projectile
        removeProjectile(projectile)

        // Damage enemy
        if enemy.takeDamage() {
            // Enemy destroyed
            if let index = enemies.firstIndex(of: enemy) {
                enemies.remove(at: index)
            }

            // Death animation
            let fadeOut = SKAction.fadeOut(withDuration: 0.2)
            let scaleDown = SKAction.scale(to: 0.5, duration: 0.2)
            let remove = SKAction.removeFromParent()
            enemy.run(SKAction.sequence([SKAction.group([fadeOut, scaleDown]), remove]))

            score += 10
        }
    }

    private func collectPowerUp(_ powerUp: SKShapeNode) {
        // Remove power-up
        if let index = powerUps.firstIndex(of: powerUp) {
            powerUps.remove(at: index)
        }
        powerUp.removeFromParent()

        // Show buff selection
        showBuffSelection()
    }

    // MARK: - Helpers

    private func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        let dx = to.x - from.x
        let dy = to.y - from.y
        return sqrt(dx * dx + dy * dy)
    }
}
