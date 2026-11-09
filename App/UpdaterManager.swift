import AppKit
import Combine
import Foundation
import Sparkle
import SwiftUI

/// Sparkle auto-updates for the notarized (Developer ID) build.
///
/// Sparkle is linked into every build but stays off when:
/// - it's a DEBUG build (it would try to replace the debug app with a release), or
/// - the app came from the Mac App Store (it has a receipt; the store handles updates).
///
/// Uses ObservableObject (not @Observable) to bridge Sparkle's KVO `canCheckForUpdates` via Combine.
@MainActor
final class UpdaterManager: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
    static let shared = UpdaterManager()

    private var controller: SPUStandardUpdaterController!
    /// Whether this copy of the app is held open (Dock icon shown) for an update session.
    private var holdsActivation = false

    @Published private(set) var canCheckForUpdates = false

    /// False for App Store and debug builds; the UI hides or disables update controls then.
    let isSupported: Bool = {
        #if DEBUG
        return false
        #else
        return !UpdaterManager.isAppStoreBuild
        #endif
    }()

    /// App Store (and TestFlight) installs carry a receipt; Developer ID builds don't.
    nonisolated static var isAppStoreBuild: Bool {
        guard let url = Bundle.main.appStoreReceiptURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            controller.updater.automaticallyChecksForUpdates = newValue
        }
    }

    private override init() {
        super.init()
        // startingUpdater: false — start() runs from applicationDidFinishLaunching.
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self)
        controller.updater.publisher(for: \.canCheckForUpdates)
            .map { [isSupported] in isSupported && $0 }
            .assign(to: &$canCheckForUpdates)
    }

    /// Begins the automatic update schedule. Call from applicationDidFinishLaunching.
    func start() {
        guard isSupported else { return }
        controller.startUpdater()
    }

    /// Manual "Check for Updates…".
    func checkForUpdates() {
        guard isSupported else { return }
        beginUpdateSession()
        controller.checkForUpdates(nil)
    }

    // MARK: Menu bar–only apps

    /// Sparkle's windows only come to the front for a `.regular` app, so show the Dock icon
    /// for the update session and restore the user's preference afterwards.
    private func beginUpdateSession() {
        guard !holdsActivation else { return }
        holdsActivation = true
        AppActivationPolicy.enter()
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        // A background (scheduled) check found an update: bring its window forward.
        MainActor.assumeIsolated { beginUpdateSession() }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated {
            guard holdsActivation else { return }
            holdsActivation = false
            AppActivationPolicy.leave()
        }
    }
}

/// "Check for Updates…" for the app menu; hidden in App Store and debug builds.
struct CheckForUpdatesButton: View {
    @ObservedObject private var updater = UpdaterManager.shared

    var body: some View {
        if updater.isSupported {
            Button("Check for Updates…") { updater.checkForUpdates() }
                .disabled(!updater.canCheckForUpdates)
        }
    }
}
