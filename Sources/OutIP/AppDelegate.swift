import AppKit
import OutIPCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let selfCheck: Bool
    private var status: Status = .checking
    private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    init(selfCheck: Bool) {
        self.selfCheck = selfCheck
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        show(status)
        if selfCheck { SelfCheck.run(statusItem) }
    }

    /// Stores a new status and draws the bar; nothing else changes the bar (R9).
    func show(_ status: Status) {
        self.status = status
        guard let button = statusItem.button else { return }
        switch Display.bar(for: status) {
        case .text(let text):
            button.image = nil
            button.title = text
        case .symbol(let name, let description):
            let image = NSImage(systemSymbolName: name, accessibilityDescription: description)
            image?.isTemplate = true
            button.image = image
            button.title = ""
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let quit = NSMenuItem(title: "Quit OutIP", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }
}
