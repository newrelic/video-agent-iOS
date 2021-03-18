//
//  ViewController.swift
//  CoreTests
//
//  Created by Andreu Santaren on 18/3/21.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet var textView: UITextView?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let testArray : [TestProtocol] = [Test1(), Test1(), Test1(), Test1(), Test1(), Test1(), Test1(), Test1()]
        
        for (i,test) in testArray.enumerated() {
            textView?.insertText("Test \(i+1)\t" + (test.doTest() ? "✅" : "❌") + "\n\n")
        }
    }
}
