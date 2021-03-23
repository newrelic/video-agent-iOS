//
//  ViewController.swift
//  CoreTests
//
//  Created by Andreu Santaren on 18/3/21.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet var textView: UITextView?
    
    let testArray : [TestProtocol] = [Test1(), Test2(), Test3(), Test4(), Test5(), Test6()]

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.textView?.insertText("Running \(self.testArray.count) tests...\n\n\n")
        
        DispatchQueue.global(qos: .background).async {
            self.testArray.forEach { (test) in
                test.doTest(self.testResult)
            }
        }
    }
    
    func testResult(name: String, result: Bool) {
        DispatchQueue.main.async {
            self.textView?.insertText("\(name)\t" + (result ? "✅" : "❌") + "\n\n")
        }
    }
}
