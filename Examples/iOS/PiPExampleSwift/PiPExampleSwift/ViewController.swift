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

class ViewController: UIViewController {
    
    private var playerController: AVPlayerViewController?
    private var trackerId: NSNumber?
    
    @IBAction func clickPlayBunny(sender: UIButton) {
        playVideo(videoURL: "http://docs.evostream.com/sample_content/assets/hls-bunny-rangerequest/playlist.m3u8")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        NewRelicVideoAgent.sharedInstance().setLogging(true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let controller = self.playerController, controller.isBeingDismissed {
            if let tracker = NewRelicVideoAgent.sharedInstance().contentTracker(trackerId ?? -1) as? NRVideoTracker {
                tracker.sendEnd()
            }
            NewRelicVideoAgent.sharedInstance().releaseTracker(trackerId ?? -1)
        }
    }

    func playVideo(videoURL: String) {
        let player = AVPlayer.init(url: URL.init(string: videoURL)!)
        self.playerController = AVPlayerViewController.init()
        self.playerController?.player = player
        self.playerController?.showsPlaybackControls = true
        
        trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: NRTrackerAVPlayer.init(avPlayer: player))
        
        present(self.playerController!, animated: true) {
            self.playerController?.player?.play()
        }
    }
}

