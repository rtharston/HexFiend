//
//  DiffRangeWindowController.swift
//  HexFiend_2
//
//  Created as DiffRangeWindowController.m by Steven Rogers on 03/14/13.
//  Converted to DiffRangeWindowController.swift by Reed Harston on 11/12/22.
//  Copyright © 2013 ridiculous_fish. All rights reserved.
//

import Cocoa

class DiffRangeWindowController: NSWindowController {
    @IBOutlet weak var startOfRange: NSTextField!
    @IBOutlet weak var lengthOfRange: NSTextField!
    
    @IBAction func compareRange(_: Any) {
        let start = UInt64(startOfRange.stringValue) ?? 0
        let len = UInt64(lengthOfRange.stringValue) ?? 1024
        
        let range = HFRangeMake(start, len);
        
        NSApp.stopModal()
        self.close()

        DiffDocument.compareFrontTwoDocuments(using: range)
    }

    @objc func runModal() {
        if let window = self.window {
            self.showWindow(self)
            NSApp.runModal(for: window)
        }
    }
}
