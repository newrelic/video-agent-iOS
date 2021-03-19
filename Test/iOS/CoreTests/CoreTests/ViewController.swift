//
//  ViewController.swift
//  CoreTests
//
//  Created by Andreu Santaren on 18/3/21.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet var textView: UITextView?
    
    let testArray : [TestProtocol] = [Test1(), Test2()]

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        for test in testArray {
            test.doTest(testResult)
        }
    }
    
    func testResult(name: String, result: Bool) {
        textView?.insertText("\(name)\t" + (result ? "✅" : "❌") + "\n\n")
    }
}
