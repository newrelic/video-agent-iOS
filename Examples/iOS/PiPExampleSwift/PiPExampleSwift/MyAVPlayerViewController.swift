//
//  MyAVPlayerViewController.swift
//  PiPExampleSwift
//
//  Created by Andreu Santaren on 5/2/21.
//

import Foundation
import AVKit

class MyAVPlayerViewController: AVPlayerViewController {
    
    private(set) var playerVisible = false
    
    override func viewWillAppear(_ animated: Bool) {
        print("====> MYAVP VIEW WILL APPEAR")
        
        super.viewWillAppear(animated)
        playerVisible = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        print("====> MYAVP VIEW DID DISAPPEAR")
        
        super.viewDidDisappear(animated)
        playerVisible = false
    }
}
