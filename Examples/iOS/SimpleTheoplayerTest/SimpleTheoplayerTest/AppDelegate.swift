import UIKit
import NewRelicVideoCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Short harvest cycle for fast NRDB feedback while validating NRTrackerTHEOplayer manually —
        // not a recommended production setting (see NRVAVideoConfigurationBuilder.withHarvestCycle:'s
        // own doc comment: 5-300s is the validated range for real use).
        let videoConfig = NRVAVideoConfiguration.builder()
            .withApplicationToken("YOUR_NEWRELIC_APP_TOKEN")
            .withDebugLogging(true)
            .withHarvestCycle(10)
            .build()
        _ = NRVAVideo.newBuilder()
            .withConfiguration(videoConfig)
            .build()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
