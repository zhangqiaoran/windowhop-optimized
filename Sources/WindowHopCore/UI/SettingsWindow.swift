import AppKit
import SwiftUI

/// The Settings window: a native multi-pane layout (toolbar-style
/// NSTabViewController, exactly like classic System Settings panes) hosting
/// SwiftUI content. Every pane is the same size, so selecting one never resizes
/// or re-centers the window.
public final class SettingsWindowController {
    public static let shared = SettingsWindowController()

    /// The switcher-entry title; the window's visible title follows the pane name.
    public static let switcherEntryTitle = "my-alt-tab Settings"

    private var window: NSWindow?

    /// The settings UI, also used by the debug render harness.
    public static func makeContentViewController() -> NSViewController {
        SettingsTabViewController()
    }

    /// Individual panes for the render harness (the toolbar lives on the window
    /// and cannot be rasterized offscreen).
    public static func makePaneViewControllers() -> [(name: String, viewController: NSViewController)] {
        SettingsPane.allCases.map { ($0.rawValue, $0.makeViewController()) }
    }

    public func show() {
        if window == nil {
            let newWindow = NSWindow(contentViewController: Self.makeContentViewController())
            newWindow.styleMask = [.titled, .closable, .miniaturizable]
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            window = newWindow
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        // the Settings window is a normal switcher entry while open (the one
        // sanctioned exception to the own-window exclusion)
        if let window {
            WindowStore.shared.registerOwnWindow(window)
        }
    }
}

/// The Settings panes, in presentation order. Splitting shortcuts and window
/// filters out of General keeps every pane scannable at a glance and close to
/// the same length, instead of one pane taller than a laptop display.
enum SettingsPane: String, CaseIterable {
    case general
    case shortcuts
    case windows
    case appearance
    case updates
    case about

    var title: String {
        switch self {
        case .general: "General"
        case .shortcuts: "Shortcuts"
        case .windows: "Windows"
        case .appearance: "Appearance"
        case .updates: "Updates"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .shortcuts: "keyboard"
        case .windows: "macwindow.on.rectangle"
        case .appearance: "rectangle.grid.1x2"
        case .updates: "arrow.triangle.2.circlepath"
        case .about: "info.circle"
        }
    }

    @ViewBuilder private var content: some View {
        switch self {
        case .general: GeneralPane()
        case .shortcuts: ShortcutsPane()
        case .windows: WindowsPane()
        case .appearance: AppearancePane()
        case .updates: UpdatesPane()
        case .about: AboutPane()
        }
    }

    func makeViewController() -> NSHostingController<AnyView> {
        let hosting = NSHostingController(rootView: AnyView(content))
        hosting.title = title
        hosting.sizingOptions = .preferredContentSize
        return hosting
    }
}

/// Toolbar-style panes with SF Symbols; the selected pane persists across launches.
final class SettingsTabViewController: NSTabViewController {
    /// Stores the pane's stable identifier, so adding or reordering panes never
    /// reopens Settings on a different one.
    private static let selectedPaneKey = "settingsSelectedPaneIdentifier"

    init() {
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        // no crossfade/slide: pane switches are instant (Reduce Motion friendly)
        transitionOptions = []
        for pane in SettingsPane.allCases {
            let item = NSTabViewItem(viewController: pane.makeViewController())
            item.identifier = pane.rawValue
            item.label = pane.title
            item.image = NSImage(systemSymbolName: pane.symbol,
                                 accessibilityDescription: pane.title)
            addTabViewItem(item)
        }
        if let saved = UserDefaults.standard.string(forKey: Self.selectedPaneKey),
           let index = SettingsPane.allCases.firstIndex(where: { $0.rawValue == saved }) {
            selectedTabViewItemIndex = index
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        guard let identifier = tabViewItem?.identifier as? String else { return }
        UserDefaults.standard.set(identifier, forKey: Self.selectedPaneKey)
    }
}

private extension View {
    /// One canvas for every pane: identical size, content anchored at the top,
    /// scrollable when it outgrows the canvas.
    func settingsPane() -> some View {
        formStyle(.grouped)
            .frame(width: DesignTokens.settingsPaneWidth,
                   height: DesignTokens.settingsPaneHeight)
    }
}

// MARK: - General

struct GeneralPane: View {
    @ObservedObject private var preferences = Preferences.shared
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var launchAtLoginFailed = false
    @State private var restoreConfirmationShown = false
    @State private var restoreFailed = false
    @State private var quitConfirmationShown = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable my-alt-tab", isOn: $preferences.switcherEnabled)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        let succeeded = LoginItem.set(newValue)
                        launchAtLoginFailed = !succeeded
                        if succeeded {
                            preferences.launchAtLogin = newValue
                        } else {
                            launchAtLogin = LoginItem.isEnabled
                        }
                    }
                if launchAtLoginFailed {
                    Text("Launch at login could not be configured. Run my-alt-tab from the Applications folder and try again.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Disabling my-alt-tab hands ⌘⇥ back to the native app switcher without quitting.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Show menu bar item", isOn: $preferences.showMenuBarItem)
                Toggle("Show Dock icon", isOn: $preferences.showDockIcon)
            } header: {
                Text("Appears in")
            }
            Section {
                Button("Restore Defaults…") {
                    restoreConfirmationShown = true
                }
                .confirmationDialog("Restore all my-alt-tab settings?",
                                    isPresented: $restoreConfirmationShown) {
                    Button("Restore Defaults") {
                        restoreFailed = !SettingsDefaultsRestorer.shared.restore()
                        launchAtLogin = LoginItem.isEnabled
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Shortcuts, appearance, window filters, update checks, and app visibility return to their original values. macOS permissions and cached previews are unchanged.")
                }
                if restoreFailed {
                    Text("Defaults could not be restored because Launch at Login is unavailable. Run my-alt-tab from Applications and try again.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                // macOS Form buttons ignore the destructive role's tint; make the
                // destructive intent visible explicitly
                Button(role: .destructive) {
                    quitConfirmationShown = true
                } label: {
                    Text("Quit my-alt-tab…")
                        .foregroundStyle(.red)
                }
                .confirmationDialog("Quit my-alt-tab?",
                                    isPresented: $quitConfirmationShown) {
                    Button("Quit my-alt-tab", role: .destructive) {
                        NSApp.terminate(nil)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The native ⌘⇥ app switcher takes over until you open my-alt-tab again.")
                }
            }
        }
        .settingsPane()
    }
}

// MARK: - Shortcuts

struct ShortcutsPane: View {
    @ObservedObject private var preferences = Preferences.shared
    @State private var shortcutValidationMessage: String?

    var body: some View {
        Form {
            Section {
                Picker("Switcher shortcut", selection: $preferences.shortcut) {
                    ForEach(ShortcutSpec.allCases) { spec in
                        Text(spec.displayName).tag(spec)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: preferences.shortcut) { _, newValue in
                    // a switcher-shortcut change can invalidate the persistent chord
                    if let current = preferences.persistentShortcut,
                       let error = current.validate(against: newValue) {
                        preferences.persistentShortcut = nil
                        shortcutValidationMessage = error.explanation
                    }
                }
                LabeledContent("Open my-alt-tab") {
                    ShortcutRecorderField(shortcut: $preferences.persistentShortcut,
                                          validationMessage: $shortcutValidationMessage,
                                          switcherShortcut: preferences.shortcut)
                }
                if let shortcutValidationMessage {
                    Text(shortcutValidationMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("The switcher shortcut cycles while you hold the modifier (add ⇧ to go backward); releasing it switches windows. Open my-alt-tab keeps the switcher open without holding anything: ⇥ and arrows navigate, ↩ or Space switches, ⎋ cancels, ⌫ closes the selected window directly.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .settingsPane()
        // the message explains the change that just happened here; leaving the
        // pane (to restore defaults, for instance) makes it obsolete
        .onDisappear { shortcutValidationMessage = nil }
    }
}

// MARK: - Windows

struct WindowsPane: View {
    @ObservedObject private var preferences = Preferences.shared
    @StateObject private var connectedDisplays = ConnectedDisplaysModel()

    /// One entry per selectable display. A chosen display that is currently
    /// disconnected stays in the list, named as such: dropping it would destroy
    /// the user's choice every time a monitor is unplugged.
    private struct DisplayOption: Identifiable, Hashable {
        let id: String
        let label: String
    }

    private var displayOptions: [DisplayOption] {
        var options = connectedDisplays.displays.map {
            DisplayOption(id: $0.id, label: $0.name)
        }
        if let chosen = preferences.switcherDisplayID,
           !connectedDisplays.displays.contains(where: { $0.id == chosen }) {
            options.append(DisplayOption(id: chosen, label: "Selected display (disconnected)"))
        }
        return options
    }

    /// UserDefaults cannot hold nil, and a Picker cannot select it either; the
    /// empty string is the single representation of "no display chosen".
    private var chosenDisplay: Binding<String> {
        Binding(get: { preferences.switcherDisplayID ?? "" },
                set: { preferences.switcherDisplayID = $0.isEmpty ? nil : $0 })
    }

    var body: some View {
        Form {
            Section {
                Toggle("Focused multi-display mode",
                       isOn: $preferences.focusedMultiDisplayMode)
                Toggle("Include windows from other Spaces", isOn: $preferences.includeOtherSpaces)
                if !preferences.focusedMultiDisplayMode {
                    Toggle("Include windows from other displays",
                           isOn: $preferences.includeOtherDisplays)
                }
                Toggle("Include minimized windows", isOn: $preferences.includeMinimizedWindows)
                Toggle("Include windows from hidden applications",
                       isOn: $preferences.includeHiddenApplicationWindows)
                Toggle("Include Picture-in-Picture windows",
                       isOn: $preferences.includePictureInPictureWindows)
            } header: {
                Text("Windows shown")
            } footer: {
                Text(preferences.focusedMultiDisplayMode
                     ? "Focused multi-display mode shows one switcher on the display with the pointer while loading windows from every display. Other window filters still apply."
                     : "my-alt-tab shows a curated set of normal windows by default. Additional categories are opt-in and update the switcher immediately. Menus, tooltips, tab siblings, and system overlays are never listed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if !preferences.focusedMultiDisplayMode {
                Section {
                    Picker("Show the switcher on",
                           selection: $preferences.switcherDisplayPlacement) {
                        ForEach(SwitcherDisplayPlacement.allCases) { placement in
                            Text(placement.displayName).tag(placement)
                        }
                    }
                    if preferences.switcherDisplayPlacement == .specificDisplay {
                        Picker("Display", selection: chosenDisplay) {
                            ForEach(displayOptions) { option in
                                Text(option.label).tag(option.id)
                            }
                        }
                    }
                } header: {
                    Text("Switcher placement")
                } footer: {
                    Text("Legacy placement options are available when focused multi-display mode is off. The display with the pointer is the one you are looking at, which is not always the one holding keyboard focus.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .settingsPane()
        .onAppear { connectedDisplays.startObserving() }
        .onDisappear { connectedDisplays.stopObserving() }
        .onChange(of: preferences.switcherDisplayPlacement) { _, placement in
            // choosing "a specific display" with nothing stored would show an
            // empty picker; preselect the display the pointer is on
            guard placement == .specificDisplay, preferences.switcherDisplayID == nil else { return }
            preferences.switcherDisplayID = DisplayRegistry.pointerDisplayID()
                ?? connectedDisplays.displays.first?.id
        }
    }
}

// MARK: - Appearance

struct AppearancePane: View {
    @ObservedObject private var preferences = Preferences.shared
    @State private var screenRecordingStatus = ScreenRecordingPermission.status

    private var previewsSelected: Bool { preferences.appearanceMode == .windowPreviews }

    var body: some View {
        Form {
            Section {
                Picker("Switcher shows", selection: $preferences.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: preferences.appearanceMode) { _, newValue in
                    // ask for the permission only when the user opts into previews
                    if newValue == .windowPreviews, !ScreenRecordingPermission.isGranted {
                        _ = ScreenRecordingPermission.request()
                        screenRecordingStatus = ScreenRecordingPermission.status
                    }
                    if newValue == .appIcons {
                        // back to icons: no reason to retain any snapshot
                        PreviewProvider.shared.evictAll()
                    }
                }
                Toggle("Show tab counts", isOn: $preferences.showTabCounts)
                Picker("Preview row alignment",
                       selection: $preferences.previewRowAlignment) {
                    ForEach(PreviewRowAlignment.allCases) { alignment in
                        Text(alignment.displayName).tag(alignment)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!previewsSelected)
            } footer: {
                Text("App Icons shows each window as a large application icon. Window Previews shows a snapshot of each window instead. Preview row alignment controls how an incomplete thumbnail row is placed; Center preserves the original layout.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section {
                Picker("Show an expanded preview after pausing",
                       selection: $preferences.expandedPreviewDelay) {
                    ForEach(ExpandedPreviewDelay.allCases) { delay in
                        Text(delay.displayName).tag(delay)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Expanded Preview")
            } footer: {
                Text("After you pause, my-alt-tab enlarges the latest snapshot inside the switcher. The real window is not activated until you confirm; cancelling leaves the desktop unchanged. The default delay is 3 seconds.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            // this section is always present so the window height never jumps
            // when the appearance mode changes
            Section {
                if !previewsSelected {
                    Label("App Icons never needs any extra permission.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                    Text("Window Previews will ask for Screen Recording when you select it — macOS requires that permission for window snapshots.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if screenRecordingStatus.isAuthorized {
                    Label("Screen Recording access is granted.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Snapshots are captured only while the switcher is open.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Window Previews needs Screen Recording access.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Until it is granted, cached previews remain visible and other cards use a static fallback instead of an indefinite loading animation.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button(screenRecordingStatus == .notDetermined
                           ? "Grant Permission"
                           : "Open System Settings") {
                        if screenRecordingStatus == .notDetermined {
                            _ = ScreenRecordingPermission.request()
                            screenRecordingStatus = ScreenRecordingPermission.status
                        } else {
                            ScreenRecordingPermission.openSystemSettings()
                        }
                    }
                }
            } header: {
                Text("Screen Recording")
            } footer: {
                Text("Captures run only while the switcher is open. Recent tile-sized previews may remain in memory for the next open; they are never written to disk or transmitted.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .settingsPane()
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in
            screenRecordingStatus = ScreenRecordingPermission.status
        }
    }
}

// MARK: - Updates

struct UpdatesPane: View {
    @ObservedObject private var preferences = Preferences.shared
    @ObservedObject private var updateManager = UpdateManager.shared

    var body: some View {
        Form {
            if let availableVersion = updateManager.availableVersion {
                Section {
                    // mirrors Sparkle's own prompt: installing (or postponing/
                    // skipping) continues in the standard Sparkle dialog
                    LabeledContent {
                        Button("Install Update…") {
                            UpdateManager.shared.checkForUpdates()
                        }
                    } label: {
                        Label("my-alt-tab \(availableVersion) is available",
                              systemImage: "arrow.down.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
            }
            Section {
                Toggle("Automatically check for updates",
                       isOn: $preferences.automaticUpdateChecks)
                    .onChange(of: preferences.automaticUpdateChecks) { _, newValue in
                        UpdateManager.shared.automaticallyChecksForUpdates = newValue
                    }
                    .disabled(!UpdateManager.shared.isAvailable)
                LabeledContent("Version \(UpdateManager.shared.currentVersion)") {
                    Button("Check for Updates…") {
                        UpdateManager.shared.checkForUpdates()
                    }
                    .disabled(!UpdateManager.shared.isAvailable)
                }
                if !UpdateManager.shared.isAvailable {
                    Text("Automatic updates are disabled in this community build. Install releases from the zhangqiaoran GitHub repository or build from source.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("This build performs no automatic update checks. No telemetry, no accounts. Releases are published through the project GitHub repository.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .settingsPane()
    }
}

// MARK: - About

struct AboutPane: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.zhangqiaoran.myalttab"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: DesignTokens.settingsAboutHeaderSpacing) {
                    Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                        .resizable()
                        .frame(width: DesignTokens.settingsAboutIconSize,
                               height: DesignTokens.settingsAboutIconSize)
                        .accessibilityLabel("my-alt-tab application icon")
                    VStack(alignment: .leading, spacing: DesignTokens.settingsAboutTitleSpacing) {
                        Text("my-alt-tab")
                            .font(.title2.weight(.semibold))
                        Text("Switch between windows, not just apps.")
                            .foregroundStyle(.secondary)
                        Text("Developed & maintained by zhangqiaoran")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.top, DesignTokens.settingsAboutTitleSpacing)
                    }
                }
                .padding(.vertical, DesignTokens.settingsAboutHeaderPadding)
                LabeledContent("Version", value: "\(version) (build \(build))")
                LabeledContent("Bundle identifier", value: bundleIdentifier)
            }
            Section {
                Link("Project Website", destination: ProjectLinks.website)
                Link("Source on GitHub",
                     destination: ProjectLinks.repository)
                Link("Report an issue",
                     destination: ProjectLinks.issues)
            }
            Section {
                LabeledContent("License", value: "GPL-3.0")
                Text("my-alt-tab is developed, maintained, and released by zhangqiaoran. GPL-3.0 upstream attribution is preserved in the source repository.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Link("AltTab on GitHub",
                     destination: ProjectLinks.altTabRepository)
            } footer: {
                Text("© 2026 zhangqiaoran and my-alt-tab contributors. Free software under the GNU GPL-3.0.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .settingsPane()
    }
}
