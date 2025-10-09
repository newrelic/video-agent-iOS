//
//  ViewController.swift
//  PiPExampleSwift
//
//  Created by Andreu Santaren on 1/2/21.
//

import UIKit
import AVKit
import NewRelicVideoCore
import GoogleInteractiveMediaAds

class ViewController: UIViewController, AVPlayerViewControllerDelegate {

    private var playerController: MyAVPlayerViewController?
    private var trackerId: Int = 0
    private var inPiP: Bool = false

    // IMA Ad Properties
    private var adsLoader: IMAAdsLoader?
    private var adsManager: IMAAdsManager?
    private var contentPlayhead: IMAAVPlayerContentPlayhead?
    private let adTagURL = "https://pubads.g.doubleclick.net/gampad/ads?sz=640x480&iu=/124319096/external/ad_rule_samples&ciu_szs=300x250&ad_rule=1&impl=s&gdfp_req=1&env=vp&output=xml_vmap1&unviewed_position_start=1&cust_params=sample_ar%3Dpremidpostpod%26deployment%3Dgmf-js&cmsid=496&vid=short_onecue&correlator="

    @IBAction func clickPlayBunny(sender: UIButton) {
        playVideo(videoURL: "http://docs.evostream.com/sample_content/assets/hls-bunny-rangerequest/playlist.m3u8")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    func playVideo(videoURL: String) {
        guard let url = URL(string: videoURL) else {
            print("Invalid video URL")
            return
        }

        let player = AVPlayer(url: url)
        self.playerController = MyAVPlayerViewController()
        self.playerController?.player = player
        self.playerController?.showsPlaybackControls = true
        self.playerController?.allowsPictureInPicturePlayback = true
        self.playerController?.canStartPictureInPictureAutomaticallyFromInline = true
        self.playerController?.delegate = self

        // ✅ MODERN API: Use NRVAVideo with configuration and ads enabled
        let playerConfig = NRVAVideoPlayerConfiguration(
            playerName: "PiPPlayer",
            player: player,
            adEnabled: true,
            customAttributes: [
                "videoURL": videoURL,
                "supportsPiP": true,
                "playerType": "AVPlayer",
                "adTagURL": adTagURL
            ]
        )

        trackerId = NRVAVideo.addPlayer(playerConfig)

        // ✅ GLOBAL custom event (trackerId = nil sends to ALL trackers)
        NRVAVideo.recordCustomEvent(
            "PLAYER_SETUP_COMPLETE",
            trackerId: nil,
            attributes: [
                "setupMethod": "configuration-based",
                "hasAds": true
            ]
        )

        // ✅ TRACKER-SPECIFIC custom event
        NRVAVideo.recordCustomEvent(
            "VIDEO_STARTED",
            trackerId: NSNumber(value: trackerId),
            attributes: [
                "url": videoURL,
                "isPiP": false,
                "hasAds": true
            ]
        )

        // Setup IMA ads
        setupAds(player: player)

        present(self.playerController!, animated: true) {
            self.playerController?.player?.play()
            self.requestAds()
        }
    }

    private func setupAds(player: AVPlayer) {
        contentPlayhead = IMAAVPlayerContentPlayhead(avPlayer: player)
        adsLoader = IMAAdsLoader(settings: nil)
        adsLoader?.delegate = self
    }

    private func requestAds() {
        guard let playerVC = playerController,
              let contentPlayhead = contentPlayhead else {
            return
        }

        let adDisplayContainer = IMAAdDisplayContainer(
            adContainer: playerVC.view!,
            viewController: playerVC
        )

        let request = IMAAdsRequest(
            adTagUrl: adTagURL,
            adDisplayContainer: adDisplayContainer,
            contentPlayhead: contentPlayhead,
            userContext: nil
        )

        adsLoader?.requestAds(with: request)
    }

    private func releaseAds() {
        adsLoader?.contentComplete()
        if let manager = adsManager {
            manager.destroy()
            adsManager = nil
        }
        adsLoader = nil
    }

    func releaseTracker() {
        print("====> RELEASE TRACKER")
        NRVAVideo.releaseTracker(trackerId)
        releaseAds()
    }
    
    func playerViewController(_ playerViewController: AVPlayerViewController,
                              restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        present(playerViewController, animated: true) {
            completionHandler(false)
        }
    }
    
    func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        print("====> WILL END PRESENTATION, inPiP = \(inPiP)")
        
        if !inPiP {
            releaseTracker()
        }
    }
    
    func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("====> Start PiP")
        
        inPiP = true
    }
    
    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("====> End PiP")

        inPiP = false

        if let controller = self.playerController, !controller.playerVisible {
            releaseTracker()
        }
    }
}

// MARK: - IMA Ads Loader Delegate
extension ViewController: IMAAdsLoaderDelegate {
    func adsLoader(_ loader: IMAAdsLoader, adsLoadedWith adsLoadedData: IMAAdsLoadedData) {
        adsManager = adsLoadedData.adsManager
        adsManager?.delegate = self
        adsManager?.initialize(with: nil)
        print("Ads Loader Loaded Data")
    }

    func adsLoader(_ loader: IMAAdsLoader, failedWith adErrorData: IMAAdLoadingErrorData) {
        print("Error loading ads: \(adErrorData.adError.message ?? "Unknown error")")

        NRVAVideo.handleAdError(NSNumber(value: trackerId), error: adErrorData.adError)

        // Continue with content
        playerController?.player?.play()
    }
}

// MARK: - IMA Ads Manager Delegate
extension ViewController: IMAAdsManagerDelegate {
    func adsManager(_ adsManager: IMAAdsManager, didReceive event: IMAAdEvent) {
        print("Ads Manager did receive event = \(event.typeString ?? "Unknown")")

        NRVAVideo.handleAdEvent(NSNumber(value: trackerId), event: event, adsManager: adsManager)

        // Handle specific events
        if event.type == .LOADED {
            print("Ads Manager call start()")
            adsManager.start()
        }
    }

    func adsManager(_ adsManager: IMAAdsManager, didReceive error: IMAAdError) {
        print("Ads Manager received error = \(error.message ?? "Unknown error")")

        NRVAVideo.handleAdError(NSNumber(value: trackerId), error: error, adsManager: adsManager)

        // Continue with content
        playerController?.player?.play()
    }

    func adsManagerDidRequestContentPause(_ adsManager: IMAAdsManager) {
        print("Ads request pause")

        NRVAVideo.sendAdBreakStart(NSNumber(value: trackerId))
        playerController?.player?.pause()
    }

    func adsManagerDidRequestContentResume(_ adsManager: IMAAdsManager) {
        print("Ads request resume")

        NRVAVideo.sendAdBreakEnd(NSNumber(value: trackerId))
        playerController?.player?.play()
    }
}
