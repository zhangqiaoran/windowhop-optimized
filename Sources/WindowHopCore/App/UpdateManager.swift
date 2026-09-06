import AppKit
import Sparkle

/// Sparkle 2 wrapper. Update checks are my-alt-tab's only routine network
/// activity — no telemetry, no analytics, no accounts. The standard Sparkle
/// UI handles the whole experience (prompt with the new version, install,
/// remind-later, skip-this-version — so the same version never nags twice);
/// the updater only starts from a real app bundle (development builds run
/// without it). The Settings Updates pane additionally mirrors the latest
/// known available version, observed through the updater delegate.
public final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    public static let shared = UpdateManager()

    private var controller: SPUStandardUpdaterController?

    /// The newest version the appcast offered, when newer than the running
    /// one; nil while up to date. Set from Sparkle's scheduled background
    /// checks and manual ones alike — check failures just leave it unchanged
    /// and never block anything.
    @Published public private(set) var availableVersion: String?
    @Published public private(set) var isChecking = false
    @Published public private(set) var lastCheckDate: Date?

    override private init() {}

    public var isAvailable: Bool { controller != nil }
    public var canCheckForUpdates: Bool {
        controller?.updater.canCheckForUpdates ?? false
    }

    public var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// Requires the Info.plist SUFeedURL/SUPublicEDKey, so only a bundled,
    /// properly configured my-alt-tab.app starts the updater.
    public func startIfBundled() {
        guard controller == nil,
              Bundle.main.bundleIdentifier == "com.zhangqiaoran.myalttab",
              Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil,
              Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") != nil else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true,
                                                  updaterDelegate: self,
                                                  userDriverDelegate: nil)
        controller?.updater.automaticallyChecksForUpdates =
            Preferences.shared.automaticUpdateChecks
    }

    /// Fetches only update metadata for the custom Settings pane. Sparkle
    /// validates the signed appcast but does not show an "up to date" modal.
    public func probeForUpdateInformation() {
        guard let updater = controller?.updater,
              updater.canCheckForUpdates,
              !updater.sessionInProgress else { return }
        isChecking = true
        updater.checkForUpdateInformation()
    }

    /// User-initiated immediate path. Sparkle foregrounds any existing update
    /// session, or checks/downloads/installs the newest signed release.
    public func checkForUpdates() {
        guard let controller,
              controller.updater.canCheckForUpdates else { return }
        isChecking = true
        controller.checkForUpdates(nil)
    }

    public var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    // MARK: - SPUUpdaterDelegate (main thread, per Sparkle 2)

    public func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        availableVersion = item.displayVersionString
    }

    public func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        availableVersion = nil
    }

    public func updater(_ updater: SPUUpdater,
                        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
                        error: (any Error)?) {
        isChecking = false
        lastCheckDate = Date()
    }

    public func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        isChecking = false
        lastCheckDate = Date()
    }
}
