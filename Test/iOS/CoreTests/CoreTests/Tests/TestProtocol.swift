//
//  TestProtocol.swift
//  CoreTests
//
//  Created by Andreu Santaren on 18/3/21.
//

import Foundation

protocol TestProtocol {
    func doTest(_ callback: @escaping (String, Bool) -> Void)
}
