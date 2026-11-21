import AppKit
import OutIPCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let selfCheck: Bool
    private var status: Status
    private let calendar: Calendar
    private let locale: Locale
    private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    /// Not `statusItem.menu`, which stays nil so ⌥-click can reach `barClicked` (compact-bar R6).
    private let menu = NSMenu()
    /// Nil in the self-check, which sends no request (menubar-app R22).
    private var checker: Checker?

    /// The two modes differ only here and in `interval`: where the status, the calendar and the locale come from (R20).
    init(selfCheck: Bool) {
        self.selfCheck = selfCheck
        if selfCheck {
            (status, calendar, locale) = (SelfCheck.sample, SelfCheck.calendar, SelfCheck.locale)
        } else {
            (status, calendar, locale) = (.checking, .autoupdatingCurrent, .autoupdatingCurrent)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.autoenablesItems = false
        menu.delegate = self
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(barClicked)
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }
        show(status)
        if selfCheck {
            SelfCheck.run(statusItem, menu: menu)
        } else {
            checker = Checker(show: { [unowned self] in show($0) }, interval: { [unowned self] in interval })
            checker?.start()
        }
    }

    /// Stores a new status and draws the bar; nothing else changes the bar (R9).
    func show(_ status: Status) {
        self.status = status
        guard let button = statusItem.button else { return }
        switch Display.bar(for: status, showAddress: showAddress) {
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

    /// The first stored value, in whole seconds; the self-check uses 30 and never reads `UserDefaults` (R4, R20, R22).
    private var interval: Int {
        selfCheck ? Interval.fallback : Interval.resolve(UserDefaults.standard.object(forKey: "interval") as? Int)
    }

    /// The second stored value; missing or not a `Bool` means true, and the self-check uses true (compact-bar R2, R7).
    private var showAddress: Bool {
        selfCheck || UserDefaults.standard.object(forKey: "showAddress") as? Bool ?? true
    }

    /// ⌥-click switches the mode; any other click opens the menu under the item (compact-bar R5, R6).
    @objc private func barClicked() {
        if NSApp.currentEvent?.modifierFlags.contains(.option) == true {
            toggleShowAddress()
        } else {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        }
    }

    /// Rebuilt from the kept status each time the menu opens; opening it starts no check (R12–R17).
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let info = Display.info(for: status, calendar: calendar, locale: locale)
        menu.addItem(.sectionHeader(title: info.header))
        if let copyTitle = info.copyTitle {
            let copy = item(copyTitle, #selector(copyAddress(_:)))
            copy.representedObject = info.address
            menu.addItem(copy)
        }
        if let detail = info.detail {
            let line = NSMenuItem(title: detail, action: nil, keyEquivalent: "")
            line.isEnabled = false
            menu.addItem(line)
        }

        menu.addItem(.separator())
        let refresh = item("Refresh now", #selector(refreshNow))
        refresh.keyEquivalent = "r"
        menu.addItem(refresh)

        let intervals = NSMenu()
        intervals.autoenablesItems = false
        let current = interval
        for seconds in Interval.options {
            let choice = item(Interval.title(for: seconds), #selector(chooseInterval(_:)))
            choice.tag = seconds
            choice.state = seconds == current ? .on : .off
            intervals.addItem(choice)
        }
        let every = NSMenuItem(title: "Check every", action: nil, keyEquivalent: "")
        every.submenu = intervals
        menu.addItem(every)

        let address = item("Show address in bar", #selector(toggleShowAddress))
        address.state = showAddress ? .on : .off
        menu.addItem(address)

        let login = item("Launch at login", #selector(toggleLaunchAtLogin))
        // The self-check calls no ServiceManagement, so it draws the item unchecked (R18, R22).
        login.state = !selfCheck && SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit OutIP", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    /// Makes the address the only content of the clipboard (R13).
    @objc private func copyAddress(_ sender: NSMenuItem) {
        guard !selfCheck, let address = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
    }

    /// Starts a check now (R14, ip-check R8).
    @objc private func refreshNow() {
        checker?.check()
    }

    /// Stores the chosen interval and reschedules the pending check (R15, ip-check R11).
    @objc private func chooseInterval(_ sender: NSMenuItem) {
        guard !selfCheck, sender.tag != interval else { return }  // R22; the same interval keeps the pending timer
        UserDefaults.standard.set(sender.tag, forKey: "interval")
        checker?.intervalChanged()
    }

    /// Stores the opposite mode and redraws the kept status; starts no check (compact-bar R3, R4).
    @objc private func toggleShowAddress() {
        guard !selfCheck else { return }  // R22
        UserDefaults.standard.set(!showAddress, forKey: "showAddress")
        show(status)
    }

    /// The only place that calls `register()` (R19).
    @objc private func toggleLaunchAtLogin() {
        guard !selfCheck else { return }  // R22
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("OutIP: Launch at login failed: %@", error.localizedDescription)
        }
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
