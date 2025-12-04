import UIKit
import SpriteKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        if let view = self.view as? SKView ?? SKView(frame: view.bounds) {
            if !(self.view is SKView) {
                self.view = view
            }

            let scene = MenuScene(size: view.bounds.size)
            scene.scaleMode = .aspectFill

            view.presentScene(scene)
            view.ignoresSiblingOrder = true

            #if DEBUG
            view.showsFPS = true
            view.showsNodeCount = true
            #endif
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
