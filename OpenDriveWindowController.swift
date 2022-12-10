//
//  OpenDriveWindowController.swift
//  HexFiend_2
//
//  Created as OpenDriveWindowController.m by Richard D. Guzman on 1/8/12.
//  Converted to OpenDriveWindowController.swift by Reed Harston on 11/12/22.
//  Copyright (c) 2012 ridiculous_fish. All rights reserved.
//

import Cocoa
import CoreFoundation
import DiskArbitration

class OpenDriveWindowController: NSWindowController {
    @IBOutlet weak var table: NSTableView! {
        didSet {
            table.doubleAction = #selector(selectDrive(_:))
            table.target = self
        }
    }
//    let selectButton: NSButton
//    let cancelButton: NSButton
    // TODO: Consider using OrderedSet to get the remove method and keep order
    private var driveList = [NSDictionary]()
        
    // A key used to store the new URL for recovery suggestions for certain errors
    private static let kNewURLErrorKey = "NewURL"
    
    override var windowNibName: NSNib.Name? { "OpenDriveDialog" }
    
    // init(windowNibName:) isn't a designated initializer in Swift, so we can't call it like we can in Obj-C
    // https://stackoverflow.com/a/37443281/4013587
    init() {
        super.init(window: nil)
        Thread.detachNewThreadSelector(#selector(refreshDriveList), toTarget: self, with: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static let addDiskCallback: DADiskAppearedCallback = { disk, context in
        autoreleasepool {
            // TODO: See if I can get this into a Swift dictionary
            guard let diskDesc: NSDictionary = DADiskCopyDescription(disk) else {
                return
            }
            
//            print("🥁 add callback")
            print("🥁 \(diskDesc)")
            // TODO: See if I can cast straight to Bool here
            if let isNetwork = diskDesc[kDADiskDescriptionVolumeNetworkKey] as? NSNumber,
               isNetwork.boolValue {
                // Don't add disks that represent a network volume
                print("🥁🥁 skipping network volume: \(diskDesc.bsdName ?? "unknown")")
            } else {
                let bsdName = diskDesc.bsdName
                print("🥁🥁 adding non network volume: \(bsdName ?? "unknown")")
                if let bsdName = bsdName {
                    DispatchQueue.main.async {
                        print("🥁🥁 here 1: \(bsdName)")
                        if let context = context {
                            print("🥁🥁 here 2: \(bsdName)")
                            let controller = Unmanaged<OpenDriveWindowController>.fromOpaque(context)
                            controller.takeUnretainedValue().addToDriveList(diskDesc)
//                            controller.takeRetainedValue().addToDriveList(diskDesc)
                            print("🥁🥁 here 3: \(bsdName)")
                        }
                    }
                }
            }
        }
    }
    
    private static let removeDiskCallback: DADiskDisappearedCallback = { disk, context in
        autoreleasepool {
            guard let cBsdName = DADiskGetBSDName(disk)
//                  let nsbsdName = NSString(cString: bsdName, encoding: String.Encoding.utf8.rawValue)
            else {
                return
            }
            
            print("🥁 add callback")
            let bsdName = String(cString: cBsdName)
            
            DispatchQueue.main.async {
                let controller = context?.assumingMemoryBound(to: OpenDriveWindowController.self)
                controller?.pointee.removeDrive(bsdName: bsdName)
            }
        }
    }
    
    @objc private func refreshDriveList() {
        autoreleasepool {
            if let runLoop = CFRunLoopGetCurrent(),
               let session = DASessionCreate(kCFAllocatorDefault) {
                // The DARegister***Callback methods take a void* context so we have to
                // get an opaque pointer to self that can be passed in safely.
                let selfPointer = Unmanaged.passUnretained(self).toOpaque()
//                let selfPointer = Unmanaged.passRetained(self).toOpaque()
                DARegisterDiskAppearedCallback(session, nil, Self.addDiskCallback, selfPointer)
//                DARegisterDiskAppearedCallback(session, nil, addDiskCallback, nil)
                DARegisterDiskDisappearedCallback(session, nil, Self.removeDiskCallback, selfPointer)
                
                DASessionScheduleWithRunLoop(session, runLoop, CFRunLoopMode.defaultMode.rawValue)
                CFRunLoopRun();
                DASessionUnscheduleFromRunLoop(session, runLoop, CFRunLoopMode.defaultMode.rawValue)
                
                // DAUnregisterCallback takes a void* to the callback so it can accept any callback type,
                // so we have to cast the specific callbacks to a void* equivelant in Swift
                // (We can't use Unmanaged.passUnretained() here because it only works on class types.)
                let r = unsafeBitCast(Self.removeDiskCallback, to: UnsafeMutableRawPointer.self)
                DAUnregisterCallback(session, r, selfPointer)
                DAUnregisterCallback(session, unsafeBitCast(Self.addDiskCallback, to: UnsafeMutableRawPointer.self), selfPointer)
            }
        }
    }

    
    @IBAction func selectDrive(_ sender: Any) {
        selectDrive()
    }
    
    static func copyCharacterDevicePathForPossibleBlockDevice(url: URL) -> URL? {
        var cpath = [CChar](repeating: 0, count: Int(PATH_MAX) + 1)
        
        guard let path = CFURLCopyFileSystemPath(url as CFURL, CFURLPathStyle.cfurlposixPathStyle),
              CFStringGetFileSystemRepresentation(path, &cpath, cpath.count) else {
            return nil
        }
        
        // TODO: See what prints, and if there is a way to get the same thing without CF
        print("🥁 path \(path)")
        
        //        cpath.withUnsafeMutableBufferPointer { cpathBuffer in
        //                if (CFStringGetFileSystemRepresentation(path, cpathBuffer.baseAddress, cpath.count)) {
        
        // TODO: See what prints, and if there is a way to get the same thing without CF
        print("🥁 cpath \(cpath)")
        
        var sb = stat()
        if (stat(cpath, &sb) != 0), let errmsg = strerror(errno) {
            // TODO: Test this print statement
            print("stat('\(cpath)') returned error \(errno) (\(errmsg)\n")
            return nil
        }
        else if (sb.st_mode & S_IFMT) == S_IFBLK {
            // It's a block file, so try getting the corresponding character file.  The device number that corresponds to this path is sb.st_rdev (not sb.st_dev, which is the device of this inode, which is the device filesystem itself)
            var deviceName = [CChar](repeating: 0, count: Int(PATH_MAX) + 1)
            //                    char deviceName[PATH_MAX + 1] = {0};
            if (devname_r(sb.st_rdev, S_IFCHR, &deviceName, Int32(deviceName.count)) != nil)
            {
                if let deviceNameString = String(cString: deviceName, encoding: .ascii) {
                    // We got the device name.  Prepend /dev/ and then return the URL
                    return URL(fileURLWithPath: "/dev/" + deviceNameString, isDirectory: false)
                }
            }
        }
        
        
        return nil
    }
    
    /// Given that a URL 'url' could not be opened because it referenced a block device, construct an error that offers to open the corresponding character device at 'newURL'
    private func makeBlockToCharacterDeviceErrorForOriginal(url: URL, newURL: URL, underlyingError: NSError) -> NSError {
        let failureReason = NSLocalizedString("The file is busy.", comment: "Failure reason for opening a file that's busy")
        let descriptionFormatString = NSLocalizedString("The file at path '%@' could not be opened because it is busy.",
                                                        comment: "Error description for opening a file that's busy");
        let recoverySuggestionFormatString = NSLocalizedString("Do you want to open the corresponding character device at path '%@'?",
                                                               comment: "Recovery suggestion for opening a character device at a given path");
        let recoveryOption = NSLocalizedString("Open character device",
                                               comment: "Recovery option for opening a character device at a given path");
        let cancel = NSLocalizedString("Cancel", comment: "Cancel");
        
        let description = String(format: descriptionFormatString, arguments: [url.path])
        
        let recoverySuggestion = String(format: recoverySuggestionFormatString, [newURL.path])
        let recoveryOptions = [recoveryOption, cancel]
        let userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: description,
            NSLocalizedFailureReasonErrorKey: failureReason,
            NSLocalizedRecoverySuggestionErrorKey: recoverySuggestion,
            NSLocalizedRecoveryOptionsErrorKey: recoveryOptions,
            NSUnderlyingErrorKey: underlyingError,
            NSRecoveryAttempterErrorKey: self,
            NSURLErrorKey: url,
            NSFilePathErrorKey: url.path,
            Self.kNewURLErrorKey: newURL
        ]
        
        return NSError(domain: NSPOSIXErrorDomain, code: Int(EBUSY), userInfo: userInfo)
    }

    
    func selectDrive() {
        guard table.numberOfSelectedRows == 1,
           let bsdName = driveList[table.selectedRow].bsdName else {
            return
        }
        
        // Try making the document
        // TODO: Test if this is right; may actually want (string:)
        let url = URL(fileURLWithPath: "/dev/\(bsdName)", isDirectory: false)
        self.openURL(url) { document, error in
            if document == nil, let error = error {
                if error.domain == NSPOSIXErrorDomain, error.code == EBUSY,
                    // If this is a block device, try getting the corresponding character device, and offer to open that.
                   let newURL = Self.copyCharacterDevicePathForPossibleBlockDevice(url: url) {
                    let charDeviceError = self.makeBlockToCharacterDeviceErrorForOriginal(url: url, newURL: newURL, underlyingError: error)
                    NSApp.presentError(charDeviceError)
                }
                NSApp.presentError(error)
            }
        }
    }

    typealias OpenURLCompletionHandler = (_ document: NSDocument?, _ error: NSError?) -> Void
    
    func openURL(_ url: URL, completionHandler: OpenURLCompletionHandler) {
        
    }

    @IBAction func cancelDriveSelection(_: Any) {
        self.close()
    }

    private func addToDriveList(_ dict: NSDictionary)    {
        driveList.append(dict)
        driveList.sort { $0.bsdName ?? "" < $1.bsdName ?? "" }
//        table?.reloadData()
    }

    private func removeDrive(bsdName: String)
    {
        driveList = driveList.filter { $0.bsdName != bsdName }
        
        table.reloadData()
    }
}

// NSMenuItemValidation conformance is required for validateMenuItem(_:) to be called
extension OpenDriveWindowController: NSMenuItemValidation {
    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Hide Open Drive if we are sandboxed
        if menuItem.action == #selector(showWindow(_:)) && isSandboxed() {
            menuItem.isHidden = true
            return false
        }
        return true
    }

}

extension NSUserInterfaceItemIdentifier {
    fileprivate static let bsdName = NSUserInterfaceItemIdentifier("BSD Name")
    fileprivate static let bus = NSUserInterfaceItemIdentifier("Bus")
    fileprivate static let label = NSUserInterfaceItemIdentifier("Label")
}

extension OpenDriveWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        driveList.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard let identifier = tableColumn?.identifier,
              row < driveList.count else {
            return nil
        }
        
        let drive = driveList[row]
        
        switch identifier {
        case NSUserInterfaceItemIdentifier.bsdName:
            return drive.bsdName
        case NSUserInterfaceItemIdentifier.bus:
            return drive[kDADiskDescriptionBusNameKey]
        case NSUserInterfaceItemIdentifier.label:
            // TODO: See if I can cast straight to Bool here
            if let whole = drive[kDADiskDescriptionMediaWholeKey] as? NSNumber,
               whole.boolValue {
                return drive[kDADiskDescriptionMediaNameKey]
            } else {
                return drive[kDADiskDescriptionVolumeNameKey]
            }
        default: return nil
        }
    }
}

extension NSDictionary {
    var bsdName: String? {
        self[kDADiskDescriptionMediaBSDNameKey] as? String
    }
}
