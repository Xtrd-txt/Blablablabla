import SpriteKit

class MenuScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = .white

        // Title
        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        titleLabel.text = "DOT SURVIVAL"
        titleLabel.fontSize = 42
        titleLabel.fontColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.7)
        addChild(titleLabel)

        // Player preview (black dot)
        let playerPreview = SKShapeNode(circleOfRadius: 25)
        playerPreview.fillColor = .black
        playerPreview.strokeColor = .clear
        playerPreview.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        addChild(playerPreview)

        // Enemy preview (red dots)
        for i in 0..<3 {
            let enemyPreview = SKShapeNode(circleOfRadius: 12)
            enemyPreview.fillColor = SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
            enemyPreview.strokeColor = .clear
            let angle = CGFloat(i) * (2 * .pi / 3) - .pi / 2
            enemyPreview.position = CGPoint(
                x: size.width / 2 + cos(angle) * 60,
                y: size.height * 0.55 + sin(angle) * 60
            )
            addChild(enemyPreview)
        }

        // Play button
        let playButton = SKShapeNode(rectOf: CGSize(width: 180, height: 60), cornerRadius: 30)
        playButton.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        playButton.strokeColor = .clear
        playButton.position = CGPoint(x: size.width / 2, y: size.height * 0.35)
        playButton.name = "playButton"
        addChild(playButton)

        let playLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        playLabel.text = "PLAY"
        playLabel.fontSize = 24
        playLabel.fontColor = .white
        playLabel.verticalAlignmentMode = .center
        playLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.35)
        playLabel.name = "playButton"
        addChild(playLabel)

        // Instructions
        let instructionLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        instructionLabel.text = "Tap to move • Avoid red dots"
        instructionLabel.fontSize = 16
        instructionLabel.fontColor = SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        instructionLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.2)
        addChild(instructionLabel)

        let instructionLabel2 = SKLabelNode(fontNamed: "AvenirNext-Regular")
        instructionLabel2.text = "Collect yellow dots for power-ups"
        instructionLabel2.fontSize = 16
        instructionLabel2.fontColor = SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        instructionLabel2.position = CGPoint(x: size.width / 2, y: size.height * 0.16)
        addChild(instructionLabel2)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNodes = nodes(at: location)

        for node in touchedNodes {
            if node.name == "playButton" {
                startGame()
                return
            }
        }
    }

    private func startGame() {
        let gameScene = GameScene(size: size)
        gameScene.scaleMode = .aspectFill
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(gameScene, transition: transition)
    }
}
