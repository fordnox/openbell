import AppKit
import SwiftUI

/// Creates the Settings window in AppKit so it can use `.fullSizeContentView`,
/// which macOS 26 needs for liquid glass chrome (a SwiftUI scene can't set the style mask).
///
///     SettingsWindowController.show(tab: .markets)
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: SettingsWindowController?

    /// Shows the window (creating it if needed), optionally jumping to a tab.
    static func show(tab: SettingsTab? = nil) {
        if let tab { SettingsNavigation.shared.selectedTab = tab }
        if shared == nil { shared = SettingsWindowController() }
        shared?.showWindow(nil)
    }

    private init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: CGSize(width: 700, height: 540)),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        configureWindow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configureWindow() {
        guard let window else { return }
        window.title = "Settings"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .automatic
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        // The rest of OpenBell is dark-only; match it.
        window.appearance = NSAppearance(named: .darkAqua)
        window.setFrameAutosaveName("SettingsWindow")
        window.minSize = NSSize(width: 620, height: 460)
        window.center()
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: SettingsView())
    }

    override func showWindow(_ sender: Any?) {
        // Only take the activation-policy reference when the window actually opens,
        // so repeated ⌘, presses don't leave the Dock icon stuck on.
        let opening = !(window?.isVisible ?? false)
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        if opening { AppActivationPolicy.enter() } else { NSApp.activate(ignoringOtherApps: true) }
    }

    func windowWillClose(_ notification: Notification) {
        AppActivationPolicy.leave()
        Self.shared = nil
    }
}

/// "Settings…" button for the main window and menu bar panel.
struct SettingsButton: View {
    var body: some View {
        Button("Settings…") { SettingsWindowController.show() }
    }
}
