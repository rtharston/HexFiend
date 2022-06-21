import Cocoa

class FiendlingExample: NSObject {
    @objc dynamic let label: String
    @objc dynamic let explanation: String

    init(label: String, explanation: String) {
        self.label = label
        self.explanation = explanation
    }
}

@NSApplicationMain
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

    func setUpFileMultipleViewIntoView(containerView: NSView) throws {
        /* We're going to show the contents of our Info.plist */
        let infoplist = Bundle.main.bundleURL.appendingPathComponent("Contents/Info.plist")
        let reference = try HFFileReference(path: infoplist.path)

        /* Make a controller to hook everything up, and then configure it a bit. */
        fileController = HFController()
        fileController?.bytesPerColumn = 1

        /* Put our data in a byte slice. */
        let byteSlice = HFFileByteSlice(file: reference)
        let byteArray = HFBTreeByteArray()
        byteArray.insertByteSlice(byteSlice, in: HFRangeMake(0, 0))
        fileController?.byteArray = byteArray

        /* Here we're going to make three representers - one for the hex, one for the ASCII, and one for the scrollbar.  To lay these all out properly, we'll use a fourth HFLayoutRepresenter. */
        let layoutRep = HFLayoutRepresenter()
        let hexRep = HFHexTextRepresenter()
        let asciiRep = HFStringEncodingTextRepresenter()
        let scrollRep = HFVerticalScrollerRepresenter()

        /* Add all our reps to the controller. */
        fileController?.addRepresenter(layoutRep)
        fileController?.addRepresenter(hexRep)
        fileController?.addRepresenter(asciiRep)
        fileController?.addRepresenter(scrollRep)

        /* Tell the layout rep which reps it should lay out. */
        layoutRep.addRepresenter(hexRep)
        layoutRep.addRepresenter(asciiRep)
        layoutRep.addRepresenter(scrollRep)

        /* Grab the layout rep's view and stick it into our container. */
        let layoutView = layoutRep.view()
        layoutView.frame = containerView.bounds
        layoutView.autoresizingMask = [.width, .height]
        containerView.addSubview(layoutView)
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
            try setUpFileMultipleViewIntoView(containerView: viewForIdentifier("file_data_multiple_views"))
            //[self setUpExternalDataView:[self viewForIdentifier:@"external_data"]];
        } catch {
            NSApp.presentError(error)
        }
    }

}
