import Cocoa

class FiendlingExample: NSObject {
    @objc dynamic let label: String
    @objc dynamic let explanation: String

    init(label: String, explanation: String) {
        self.label = label
        self.explanation = explanation
    }
}

class FiendlingAppDelegate2: NSObject, NSApplicationDelegate {

    @objc dynamic var examples: [FiendlingExample] = []

    /* The tab view in our nib */
    @IBOutlet var tabView: NSTabView?

    /**** FIRST TAB ****/
    /* Data bound to by both the NSTextView and HFTextView */
    @IBOutlet var boundDataTextView: HFTextView?
    @objc dynamic var textViewBoundData = Data()

    /**** THIRD TAB ****/
    @IBOutlet var externalDataTextView: NSTextView?
    @objc dynamic var externalData = Data()

    /* Explanatory texts */
    @IBOutlet var explanatoryTextField: NSTextField?

    var rtfSampleData: Data {
        get throws {
            guard let url = Bundle.main.url(forResource: "sampleData.rtf", withExtension: nil) else {
                fatalError()
            }
            return try Data(contentsOf: url)
        }
    }

    func setUpBoundDataHexView() throws {
        /* Bind our text view to our bound data */
        boundDataTextView?.bind(NSBindingName("data"), to: self, withKeyPath: "textViewBoundData")
        setValue(try rtfSampleData, forKey: "textViewBoundData")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.examples = [
            FiendlingExample(label: "Bound HFTextView", explanation: "This example demonstrates showing and editing data via the \"data\" binding on both NSTextView and HFTextView."),
            FiendlingExample(label: "In-Memory Data", explanation: "This example demonstrates showing in-memory data in a hex view."),
            FiendlingExample(label: "File Data, Multiple Views", explanation: "This example demonstrates showing file data in three coherent views (a hex view, an ASCII view, and a scroll bar)."),
            FiendlingExample(label: "External Data", explanation: "This example demonstrates showing data from an external source."),
        ]
        do {
            try setUpBoundDataHexView()
            //[self setUpInMemoryHexViewIntoView:[self viewForIdentifier:@"in_memory_hex_view"]];
            //[self setUpFileMultipleViewIntoView:[self viewForIdentifier:@"file_data_multiple_views"]];
            //[self setUpExternalDataView:[self viewForIdentifier:@"external_data"]];
        } catch {
            NSApp.presentError(error)
        }
    }

}
