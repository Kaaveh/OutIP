import AppKit

let selfCheck = CommandLine.arguments.contains("--self-check")

// No status item and no bundle needed: ask every endpoint once, print, exit (ip-check R12).
// The self-check sends nothing, so it wins over --probe (menubar-app R22).
if !selfCheck && CommandLine.arguments.contains("--probe") {
    Task { exit(await Checker.probe()) }
    dispatchMain()
}

// Outside the bundle the login item and the stored interval would hang on the wrong identity (R5).
if !selfCheck && Bundle.main.bundleIdentifier == nil {
    FileHandle.standardError.write(Data("OutIP: start OutIP.app, or pass --self-check or --probe\n".utf8))
    exit(64)
}

let app = NSApplication.shared
let delegate = AppDelegate(selfCheck: selfCheck)
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
