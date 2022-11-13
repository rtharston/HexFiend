//
//  ChooseStringEncodingWindowController.swift
//  HexFiend_2
//
//  Converted to Swift by Reed Harston on 11/12/22.
//  Copyright © 2010 ridiculous_fish. All rights reserved.
//

import Cocoa

class ChooseStringEncodingWindowController: NSWindowController {
    private struct HFEncodingChoice {
        let label: String
        let encoding: HFStringEncoding
        
        init(from encoding: HFNSStringEncoding) {
            if encoding.name == encoding.identifier {
                self.label = encoding.name
            } else {
                self.label = "\(encoding.name) (\(encoding.identifier))"
            }
            self.encoding = encoding
        }
    }
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var searchField: NSSearchField!
    
    private let encodings: [HFEncodingChoice]
    private var activeEncodings: [HFEncodingChoice]
    
    override var windowNibName: String { "ChooseStringEncodingDialog" }
    
    override init(window: NSWindow?) {
        if let systemEncodings = HFEncodingManager.shared().systemEncodings {
            encodings = systemEncodings.map(HFEncodingChoice.init)
                .sorted { $0.label < $1.label }
        } else {
            assertionFailure("Failed to retrieve systemEncodings from shared HFEncodingManager.")
            encodings = []
        }
        activeEncodings = encodings
        
        super.init(window: window)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ChooseStringEncodingWindowController: NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        activeEncodings.count
    }
}

extension NSUserInterfaceItemIdentifier {
    fileprivate static let name = NSUserInterfaceItemIdentifier("name")
    fileprivate static let identifier = NSUserInterfaceItemIdentifier("identifier")
}

extension ChooseStringEncodingWindowController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        switch tableColumn?.identifier {
        case NSUserInterfaceItemIdentifier.name:
            return activeEncodings[row].encoding.name
        case NSUserInterfaceItemIdentifier.identifier:
            return activeEncodings[row].encoding.identifier
        default:
            assertionFailure("ChooseStringEncodingWindow table column identifier not recognized.")
            return nil
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 else {
            return
        }
        // Tell the front document (if any) and the app delegate
        let encoding = activeEncodings[row].encoding
        if let currentDocument = NSDocumentController.shared.currentDocument {
            if let document = currentDocument as? BaseDataDocument {
                document.stringEncoding = encoding
            } else {
                assertionFailure("Current document isn't BaseDataDocument")
            }
        }

        (NSApp.delegate as? AppDelegate)?.setStringEncoding(encoding)
    }
    
    func controlTextDidChange(_ obj: Notification) {
        if searchField.stringValue.isEmpty {
            activeEncodings = encodings
        } else {
            activeEncodings = encodings.filter { $0.encoding.matches(searchTerm: searchField.stringValue) }
        }
        
        tableView.reloadData()
    }
}

private extension HFStringEncoding {
    func matches(searchTerm: String) -> Bool {
        self.name.localizedCaseInsensitiveContains(searchTerm) ||
        self.identifier.localizedCaseInsensitiveContains(searchTerm)
    }
}
