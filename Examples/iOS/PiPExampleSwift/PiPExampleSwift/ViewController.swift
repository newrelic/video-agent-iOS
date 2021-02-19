//
//  ViewController.swift
//  PiPExampleSwift
//
//  Created by Andreu Santaren on 1/2/21.
//

import UIKit
import AVKit
import NewRelicVideoCore
import NRAVPlayerTracker

class ViewController: UIViewController, AVPlayerViewControllerDelegate {
    
    private var playerController: MyAVPlayerViewController?
    private var trackerId: NSNumber?
    private var inPiP: Bool = false
    
    @IBAction func clickPlayBunny(sender: UIButton) {
        playVideo(videoURL: "http://docs.evostream.com/sample_content/assets/hls-bunny-rangerequest/playlist.m3u8")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        NewRelicVideoAgent.sharedInstance().setLogging(true)
    }

    func playVideo(videoURL: String) {
        let player = AVPlayer.init(url: URL.init(string: videoURL)!)
        self.playerController = MyAVPlayerViewController.init()
        self.playerController?.player = player
        self.playerController?.showsPlaybackControls = true
        self.playerController?.allowsPictureInPicturePlayback = true
        self.playerController?.canStartPictureInPictureAutomaticallyFromInline = true
        self.playerController?.delegate = self
        
        trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: NRTrackerAVPlayer.init(avPlayer: player))
        
        present(self.playerController!, animated: true) {
            self.playerController?.player?.play()
        }
    }
    
    func releaseTracker() {
        print("====> RELEASE TRACKER")
        
        if let tracker = NewRelicVideoAgent.sharedInstance().contentTracker(trackerId ?? -1) as? NRVideoTracker {
            tracker.sendEnd()
        }
        NewRelicVideoAgent.sharedInstance().releaseTracker(trackerId ?? -1)
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
