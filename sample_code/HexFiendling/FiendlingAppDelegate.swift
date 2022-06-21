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

    /**** SECOND TAB ****/
    var inMemoryController: HFController?
    var fileController: HFController?

    /**** THIRD TAB ****/
    @IBOutlet var externalDataTextView: NSTextView?
    @objc dynamic var externalData = Data()

    /* Explanatory texts */
    @IBOutlet var explanatoryTextField: NSTextField?

    var rtfSampleData: Data {
        get throws {
            guard let url = Bundle.main.url(forResource: "sampleData.rtf", withExtension: nil) else { fatalError() }
            return try Data(contentsOf: url)
        }
    }

    func setUpBoundDataHexView() throws {
        /* Bind our text view to our bound data */
        boundDataTextView?.bind(NSBindingName("data"), to: self, withKeyPath: "textViewBoundData")
        setValue(try rtfSampleData, forKey: "textViewBoundData")
    }

    func setUpInMemoryHexViewIntoView(containerView: NSView) {
        /* Get some random data to display */
        let dataSize = 1024
        guard let data = NSMutableData(length: dataSize) else { fatalError() }
        let fd = open("/dev/random", O_RDONLY)
        read(fd, data.mutableBytes, dataSize)
        close(fd)

        /* Make a controller to hook everything up, and then configure it a bit. */
        inMemoryController = HFController()
        inMemoryController?.bytesPerColumn = 4

        /* Put that data in a byte slice.  Here we use initWithData:, which causes the byte slice to take ownership of the data (and may modify it).  If we want to prevent our data from being modified, we would use initWithUnsharedData: */
        let byteSlice = HFSharedMemoryByteSlice(data: data)
        let byteArray = HFBTreeByteArray()
        byteArray.insertByteSlice(byteSlice, in: HFRangeMake(0, 0))
        inMemoryController?.byteArray = byteArray

        /* Make an HFHexTextRepresenter. */
        let hexRep = HFHexTextRepresenter()
        hexRep.rowBackgroundColors = [] //An empty array means don't draw a background.
        inMemoryController?.addRepresenter(hexRep)

        /* Grab its view and stick it into our container. */
        let hexView = hexRep.view()
        hexView.frame = containerView.bounds
        hexView.autoresizingMask = [.width, .height]
        containerView.addSubview(hexView)
    }

    func viewForIdentifier(_ ident: String) -> NSView {
        guard let tabView = tabView else { fatalError() }
        let index = tabView.indexOfTabViewItem(withIdentifier: ident)
        if index == NSNotFound { fatalError() }
        guard let view = tabView.tabViewItem(at: index).view else { fatalError() }
        return view
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
            setUpInMemoryHexViewIntoView(containerView: viewForIdentifier("in_memory_hex_view"))
            //[self setUpFileMultipleViewIntoView:[self viewForIdentifier:@"file_data_multiple_views"]];
            //[self setUpExternalDataView:[self viewForIdentifier:@"external_data"]];
        } catch {
            NSApp.presentError(error)
        }
    }

}
