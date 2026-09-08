import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        // Explicit window/root-VC construction — the implicit storyboard-driven window creation this
        // relied on previously never actually happened (confirmed live: UIApplication.shared.windows was
        // empty, which is why the screen was solid black with nothing rendered at all). ViewController's
        // UI is entirely programmatic anyway, so no storyboard instantiation is needed here either.
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = ViewController()
        self.window = window
        window.makeKeyAndVisible()
    }
}
