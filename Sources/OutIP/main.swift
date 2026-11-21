import AppKit

let selfCheck = CommandLine.arguments.contains("--self-check")

// Outside the bundle the login item and the stored interval would hang on the wrong identity (R5).
if !selfCheck && Bundle.main.bundleIdentifier == nil {
    FileHandle.standardError.write(Data("OutIP: start OutIP.app, or pass --self-check\n".utf8))
    exit(64)
}

let app = NSApplication.shared
let delegate = AppDelegate(selfCheck: selfCheck)
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
