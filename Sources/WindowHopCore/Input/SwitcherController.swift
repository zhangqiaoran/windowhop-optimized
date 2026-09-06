import AppKit

/// Orchestrates one switcher session: semantic input events feed the pure
/// SwitcherState; resulting commands drive the panel and window actions. Main
/// thread only.
public final class SwitcherController {
    public static let shared = SwitcherController()

    private var state = SwitcherState()
    /// The session list: seeded at session start and kept in that order while the
    /// switcher is open. Store changes remove or refresh entries in place and append
    /// windows that appeared, but never reorder (see SessionListReconciler).
    private var items: [SwitcherItem] = []
    /// IDs optimistically removed from the open switcher before the window
    /// server finishes sending its destroy notification. Hash membership keeps
    /// refresh filtering average O(1) per item and avoids the old delayed pop.
    private var pendingCloseIDs = Set<AnyHashable>()
    /// Windows whose real AX close has already been sent but whose switcher
    /// card intentionally remains as a visual ghost until dust reaches 80%.
    private var pendingVisualCloseIDs = Set<AnyHashable>()
    private var pendingVisualCloseWorkItems: [AnyHashable: DispatchWorkItem] = [:]
    private let panels = SwitcherPanelGroup()
    private var mouseMonitor: Any?
    private var heldModifierGuard: Timer?
    private var expandedPreview = ExpandedPreviewSession<AnyHashable>()
    private var expandedPreviewTimer: Timer?
    /// AX can deliver several title/move/resize notifications in one run-loop turn.
    /// Coalescing them keeps a live switcher from rebuilding the same tile set
    /// repeatedly without adding a timer or any idle work.
    private var storeRefreshScheduled = false
    private var configuredEnabled = false

    private init() {}

    public func wire() {
        EventTap.shared.onEvent = { [weak self] event in self?.handle(event) }
        WindowStore.shared.onChange = { [weak self] in self?.storeChanged() }
        panels.onItemClicked = { [weak self] index in
            guard let self else { return }
            self.perform(self.state.itemClicked(index: index))
        }
        panels.onItemCloseRequested = { [weak self] index in
            guard let self else { return }
            self.perform(self.state.closeRequested(index: index))
        }
        panels.onSettingsRequested = { [weak self] in
            self?.openSettingsFromSession()
        }
        panels.onPreviewPermissionRequested = { [weak self] in
            self?.openScreenRecordingSettingsFromSession()
        }
        PreviewProvider.shared.onPreview = { [weak self] id, image in
            self?.panels.updatePreview(id: id, image: image)
        }
        PreviewProvider.shared.onPreviewUnavailable = { [weak self] id in
            self?.panels.updatePreviewUnavailable(id: id)
        }
        PreviewProvider.shared.onPermissionRequired = { [weak self] status in
            self?.panels.setPreviewPermissionStatus(status)
        }
        PreviewProvider.shared.onExpandedPreview = { [weak self] id, image in
            self?.panels.updateExpandedPreview(id: id, image: image)
        }
    }

    /// Applies the enabled/permission state: the tap only exists while the switcher
    /// is both enabled and permitted, so a disabled WindowHop adds zero input latency
    /// and native Cmd-Tab behaves exactly as without WindowHop.
    public func applyConfiguration(enabled: Bool, granted: Bool) {
        EventTap.shared.holdModifier = Preferences.shared.shortcut.holdModifier
        EventTap.shared.persistentShortcut = Preferences.shared.persistentShortcut
        configuredEnabled = enabled && granted
        if configuredEnabled {
            if EventTap.shared.start(), !state.isActive {
                EventTap.shared.mode = .watching
            }
        } else {
            if state.isActive {
                perform(state.escape())
            }
            state.reset()
            EventTap.shared.stop()
        }
    }

    private func handle(_ event: SwitcherInputEvent) {
        switch event {
        case .trigger(let backward):
            let triggerStart = CFAbsoluteTimeGetCurrent()
            pendingCloseIDs.removeAll(keepingCapacity: true)
            items = WindowStore.shared.snapshot()
            perform(state.trigger(backward: backward, itemCount: items.count))
            DebugLog.log("trigger handled: \(items.count) items, phase \(state.phase), "
                + "\(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - triggerStart) * 1000))ms to visible panel")
            if !state.isActive {
                // the tap flipped to .session optimistically; nothing to show after all
                EventTap.shared.mode = configuredEnabled ? .watching : .off
            }
        case .openPersistent:
            let openStart = CFAbsoluteTimeGetCurrent()
            if !state.isActive {
                pendingCloseIDs.removeAll(keepingCapacity: true)
                items = WindowStore.shared.snapshot()
            }
            perform(state.openPersistent(itemCount: items.count))
            DebugLog.log("persistent open handled: \(items.count) items, phase \(state.phase), "
                + "\(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - openStart) * 1000))ms")
            if !state.isActive {
                EventTap.shared.mode = configuredEnabled ? .watching : .off
            }
        case .step(let backward):
            perform(state.step(backward: backward))
        case .modifierReleased:
            // EventTap already moved the interception state back to .watching
            // synchronously on the tap thread. Do not let this delayed main-thread
            // release overwrite a newer rapid trigger that may already be held.
            perform(state.modifierReleased(), tapModeAlreadyReleased: true)
        case .escape:
            perform(state.escape())
        case .returnKey:
            perform(state.returnKey())
        case .spaceKey:
            perform(state.spaceKey())
        case .arrow(let direction):
            perform(state.arrow(direction))
        case .deleteKey:
            perform(state.deleteKey())
        case .openSettings:
            openSettingsFromSession()
        }
    }

    /// Ends the switcher without committing its target, then opens the global
    /// Settings action. Settings intentionally becomes the next active window;
    /// no preview tile click is allowed to leak through.
    private func openSettingsFromSession() {
        let hadActiveSession = state.isActive
        if hadActiveSession {
            state.reset()
            endSession()
            expandedPreview.reset()
        }
        if hadActiveSession {
            WindowActions.afterPendingActions {
                SettingsWindowController.shared.show()
            }
        } else {
            SettingsWindowController.shared.show()
        }
    }

    private func openScreenRecordingSettingsFromSession() {
        let hadActiveSession = state.isActive
        if hadActiveSession {
            state.reset()
            endSession()
            expandedPreview.reset()
        }
        if ScreenRecordingPermission.status == .notDetermined {
            _ = ScreenRecordingPermission.request()
        } else {
            ScreenRecordingPermission.openSystemSettings()
        }
    }

    private func perform(_ command: SwitcherState.Command,
                         tapModeAlreadyReleased: Bool = false) {
        DebugLog.log("perform \(command), phase \(state.phase)")
        switch command {
        case .none:
            break
        case .show(let selectedIndex):
            let request = expandedPreview.begin(targetedWindowID: itemID(at: selectedIndex))
            preparePanels(tileCount: items.count)
            panels.show(
                items: items,
                selectedIndex: selectedIndex,
                presentationMode: state.phase == .sticky ? .persistent : .cycling)
            state.updateColumns(panels.columnsPerRow)
            // EventTap owns held/sticky transitions synchronously on its tap
            // thread. Rewriting the mode here can resurrect an already-released
            // session when the user toggles faster than the main queue drains.
            startSessionSupports()
            panels.setPreviewPermissionStatus(ScreenRecordingPermission.status)
            scheduleExpandedPreview(request)
            // previews (cached ones already showed instantly) refresh live,
            // asynchronously, never gating panel presentation
            PreviewProvider.shared.beginSession(
                items: items,
                selectedID: itemID(at: selectedIndex),
                targetSize: SwitcherPanel.previewContentSize,
                scale: panels.captureScale)
            // a missed destroy notification once produced a duplicate entry;
            // validate the visible windows in the background and prune the dead
            WindowStore.shared.pruneIfDead(items.compactMap { $0.window?.ax })
        case .select(let index):
            panels.select(index)
            targetExpandedPreview(at: index)
        case .activate(let index):
            cancelExpandedPreviewTimer()
            let resolvedIndex = activationIndexSkippingVisualCloses(from: index)
            let item = resolvedIndex.flatMap { resolved in
                resolved >= 0 && resolved < items.count ? items[resolved] : nil
            }
            let window = item?.window.flatMap { candidate in
                WindowStore.shared.windows.contains(where: { $0 === candidate }) ? candidate : nil
            }
            if let window {
                // AX focus notifications arrive asynchronously. Commit the user's
                // choice to MRU immediately so a rapid 1↔2 toggle starts from the
                // window we just requested, not from stale pre-activation order.
                WindowStore.shared.noteCommittedActivation(window)
            }
            endSession(resetTapMode: !tapModeAlreadyReleased)
            if let window {
                WindowActions.activate(window)
            }
            expandedPreview.reset()
        case .cancel:
            endSession(resetTapMode: !tapModeAlreadyReleased)
            expandedPreview.reset()
        case .requestClose(let index):
            guard index >= 0, index < items.count,
                  let window = items[index].window,
                  WindowStore.shared.windows.contains(where: { $0 === window }) else {
                refreshDuringSession()
                break
            }

            let closingID = items[index].id
            guard !pendingVisualCloseIDs.contains(closingID) else { break }

            cancelExpandedPreviewTimer()
            expandedPreview.reset()
            panels.hideExpandedPreview()

            pendingCloseIDs.insert(closingID)
            pendingVisualCloseIDs.insert(closingID)

            // Phase 1: capture and begin erosion while the list geometry remains
            // frozen. The real target window closes immediately; only its
            // switcher representation is retained as a temporary visual ghost.
            panels.playDismissalEffect(at: index)
            WindowActions.close(window)

            // If the closing card was selected, move focus to a live neighbour
            // immediately without changing layout. Releasing the modifier during
            // the 80% dust phase can therefore never activate the closed ghost.
            if state.selectedIndex == index,
               let next = nearestSelectableIndex(around: index) {
                _ = state.listChanged(itemCount: items.count, preferredIndex: next)
                panels.select(state.selectedIndex)
                targetExpandedPreview(at: state.selectedIndex)
            }

            scheduleVisualCloseCompletion(id: closingID, originalIndex: index)
        }
    }

    // MARK: - Store changes while the session is open

    private func storeChanged() {
        guard state.isActive, !storeRefreshScheduled else { return }
        storeRefreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.storeRefreshScheduled = false
            guard self.state.isActive else { return }
            self.refreshDuringSession()
        }
    }

    private func refreshDuringSession() {
        guard state.isActive else { return }
        let selectedId = state.selectedIndex < items.count ? items[state.selectedIndex].id : nil
        let liveSnapshot = WindowStore.shared.snapshot()

        // Retire pending IDs as soon as the window server confirms they are
        // gone, and suppress still-pending windows from reappearing meanwhile.
        // One pass builds the live ID set; filtering is average O(1) per item.
        var liveIDs = Set<AnyHashable>()
        liveIDs.reserveCapacity(liveSnapshot.count)
        for item in liveSnapshot { liveIDs.insert(item.id) }
        pendingCloseIDs.formIntersection(liveIDs)
        let fresh = pendingCloseIDs.isEmpty
            ? liveSnapshot
            : liveSnapshot.filter { !pendingCloseIDs.contains($0.id) }

        // This path can run repeatedly while Chrome/IDE/Finder are changing
        // windows. Build IDs and lookup tables in one pass instead of creating
        // temporary map arrays for Dictionary initializers on every refresh.
        var freshById: [AnyHashable: SwitcherItem] = [:]
        var freshIds: [AnyHashable] = []
        freshById.reserveCapacity(fresh.count)
        freshIds.reserveCapacity(fresh.count)
        for item in fresh {
            freshIds.append(item.id)
            if freshById[item.id] == nil { freshById[item.id] = item }
        }

        var sessionById: [AnyHashable: SwitcherItem] = [:]
        var sessionIds: [AnyHashable] = []
        sessionById.reserveCapacity(items.count)
        sessionIds.reserveCapacity(items.count)
        for item in items {
            sessionIds.append(item.id)
            if sessionById[item.id] == nil { sessionById[item.id] = item }
        }

        var preserved = Set<AnyHashable>()
        preserved.reserveCapacity(items.count)
        for item in items {
            if pendingVisualCloseIDs.contains(item.id) {
                // The AX window may already be gone, but its switcher card is a
                // deliberate dust-animation ghost until the 80% hand-off.
                preserved.insert(item.id)
            } else if freshById[item.id] == nil
                        && shouldPreserveAcrossLocationRefresh(item) {
                preserved.insert(item.id)
            }
        }

        let previousItemCount = items.count
        let plan = SessionListReconciler.reconcile(sessionIds: sessionIds,
                                                   freshIds: freshIds,
                                                   preserving: preserved)
        var reconciled: [SwitcherItem] = []
        reconciled.reserveCapacity(plan.ids.count)
        for id in plan.ids {
            if let item = freshById[id] ?? sessionById[id] { reconciled.append(item) }
        }
        items = reconciled
        // a window that appeared mid-session has no capture in flight yet; without
        // this its tile would stay a placeholder for the rest of the session
        if !plan.appeared.isEmpty {
            DebugLog.log("session list grew by \(plan.appeared.count): now \(items.count) items")
            PreviewProvider.shared.extendSession(
                items: plan.appeared.compactMap { freshById[$0] },
                targetSize: SwitcherPanel.previewContentSize,
                scale: panels.captureScale)
        }
        var availableIDs = Set<AnyHashable>()
        availableIDs.reserveCapacity(items.count)
        for item in items { availableIDs.insert(item.id) }
        expandedPreview.retainAvailable(availableIDs)
        let preferredIndex = selectedId.flatMap { id in
            items.firstIndex { $0.id == id }
        } ?? state.selectedIndex
        let command = state.listChanged(itemCount: items.count, preferredIndex: preferredIndex)
        if state.isActive {
            panels.update(items: items,
                          selectedIndex: state.selectedIndex,
                          animatedLayout: items.count < previousItemCount)
            state.updateColumns(panels.columnsPerRow)
            targetExpandedPreview(at: state.selectedIndex)
        }
        if case .cancel = command {
            perform(command)
        }
    }

    /// Frozen-session entries may briefly disappear from location metadata while
    /// Spaces update. Preserve only windows that still satisfy every non-location
    /// invariant; the external window is never activated by dwell preview.
    private func shouldPreserveAcrossLocationRefresh(_ item: SwitcherItem) -> Bool {
        guard let window = item.window,
              window.isActual,
              WindowStore.shared.windows.contains(where: { $0 === window }) else { return false }
        let state = WindowDisplayState(
            isMinimized: window.isMinimized,
            isAppHidden: window.app?.isHidden ?? false,
            isOwnWindow: window.isOwnSettingsEntry,
            isOwnSettingsWindow: window.isOwnSettingsEntry,
            isTabbed: window.isTabbed,
            isPictureInPicture: window.isPictureInPicture ?? false,
            // This fallback exists specifically for transient location metadata;
            // all non-location rules still flow through the shared policy.
            isOnCurrentSpace: true,
            isOnActiveDisplay: true)
        return WindowEligibility.shouldDisplay(
            state, policy: Preferences.shared.effectiveWindowInclusionPolicy)
    }

    // MARK: - Two-phase close choreography

    private func scheduleVisualCloseCompletion(id: AnyHashable, originalIndex: Int) {
        pendingVisualCloseWorkItems[id]?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.finalizeVisualClose(id: id, originalIndex: originalIndex)
        }
        pendingVisualCloseWorkItems[id] = work

        let delay: CFTimeInterval = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? 0
            : WindowDismissalEffectView.listReflowDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Phase 2 begins only after the particle system has reached 80% progress:
    /// remove the ghost from the logical list, then let the existing synchronized
    /// 0.42 s panel/tile reflow animate the smaller geometry.
    private func finalizeVisualClose(id: AnyHashable, originalIndex: Int) {
        pendingVisualCloseWorkItems[id] = nil
        guard pendingVisualCloseIDs.remove(id) != nil else { return }
        pendingCloseIDs.remove(id)
        guard state.isActive,
              let removalIndex = items.firstIndex(where: { $0.id == id }) else { return }

        let selectedID = state.selectedIndex >= 0 && state.selectedIndex < items.count
            ? items[state.selectedIndex].id
            : nil
        items.remove(at: removalIndex)

        let preferredIndex: Int?
        if let selectedID,
           let retained = items.firstIndex(where: {
               $0.id == selectedID && !pendingVisualCloseIDs.contains($0.id)
           }) {
            preferredIndex = retained
        } else {
            preferredIndex = nearestSelectableIndex(
                around: min(originalIndex, max(0, items.count - 1)))
                ?? (items.isEmpty ? nil : min(removalIndex, items.count - 1))
        }

        let command = state.listChanged(
            itemCount: items.count,
            preferredIndex: preferredIndex)

        if state.isActive {
            panels.update(items: items,
                          selectedIndex: state.selectedIndex,
                          animatedLayout: true)
            state.updateColumns(panels.columnsPerRow)
            targetExpandedPreview(at: state.selectedIndex)
        }
        if case .cancel = command {
            perform(command)
        }
    }

    private func nearestSelectableIndex(around index: Int) -> Int? {
        guard !items.isEmpty else { return nil }

        for distance in 1...items.count {
            let right = index + distance
            if right < items.count,
               !pendingVisualCloseIDs.contains(items[right].id) {
                return right
            }

            let left = index - distance
            if left >= 0,
               !pendingVisualCloseIDs.contains(items[left].id) {
                return left
            }
        }
        return nil
    }

    private func activationIndexSkippingVisualCloses(from index: Int) -> Int? {
        guard index >= 0, index < items.count else { return nil }
        if !pendingVisualCloseIDs.contains(items[index].id) { return index }
        return nearestSelectableIndex(around: index)
    }

    private func cancelPendingVisualCloses() {
        for work in pendingVisualCloseWorkItems.values { work.cancel() }
        pendingVisualCloseWorkItems.removeAll(keepingCapacity: true)
        pendingVisualCloseIDs.removeAll(keepingCapacity: true)
    }

    // MARK: - Session support

    private func startSessionSupports() {
        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                guard let self else { return }

                // A nonactivating NSPanel must not infer "outside" merely from
                // this callback firing. Classify the pointer geometrically first:
                // clicks inside any visible switcher panel belong to that panel's
                // normal AppKit/root routing and must never cancel the session.
                let screenPoint = NSEvent.mouseLocation
                guard !self.panels.containsScreenPoint(screenPoint) else { return }

                self.perform(self.state.outsideClick())
            }
        }
        // fail-safe for missed flagsChanged events (unusual event order, sleep, secure
        // input): while held, verify the modifier is really still down. Session-scoped;
        // never runs while idle, and not at all for persistent sessions.
        guard state.phase == .held, heldModifierGuard == nil else { return }
        heldModifierGuard = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.state.phase == .held else { return }
            let flags = NSEvent.modifierFlags
            if !flags.contains(self.nsModifier(of: EventTap.shared.holdModifier)) {
                self.perform(self.state.modifierReleased())
            }
        }
    }

    /// Resolves this session's target displays and rebuilds the panel set.
    ///
    /// Displays are read live at session start: nothing is cached, and nothing
    /// observes them while WindowHop is idle. A display unplugged between two
    /// sessions is therefore accounted for by the next open, with no invalidation
    /// path to get wrong.
    private func preparePanels(tileCount: Int) {
        let connected = DisplayRegistry.connectedDisplays()
        let pointer = DisplayRegistry.pointerDisplay(in: connected)
        let focusedMode = Preferences.shared.focusedMultiDisplayMode
        let targetIDs = Set(PanelDisplayResolver.targets(
            focusedMultiDisplayMode: focusedMode,
            placement: Preferences.shared.switcherDisplayPlacement,
            chosenDisplayID: Preferences.shared.switcherDisplayID,
            available: connected.map(\.descriptor),
            pointerDisplayID: pointer?.descriptor.id).map(\.id))
        let targets = connected.filter { targetIDs.contains($0.descriptor.id) }
        let metrics = SwitcherTileView.Metrics.metrics(
            for: Preferences.shared.appearanceMode,
            showTabCounts: Preferences.shared.showTabCounts)
        panels.prepare(for: targets, tileCount: tileCount, tileSize: metrics.tileSize)
        DebugLog.log("panels prepared: \(targets.count) display(s), focused multi-display "
            + "\(focusedMode ? "on" : "off")")
    }

    private func sessionTapMode() -> TapMode {
        state.phase == .held ? .sessionHeld : .sessionSticky
    }

    private func endSession(resetTapMode: Bool = true) {
        storeRefreshScheduled = false
        pendingCloseIDs.removeAll(keepingCapacity: true)
        cancelPendingVisualCloses()
        cancelExpandedPreviewTimer()
        panels.hideExpandedPreview()
        panels.hide()
        // capture is session-scoped: pending results stop delivering live, but
        // the memory-only cache remains warm for the next instant open
        PreviewProvider.shared.endSession()
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
        heldModifierGuard?.invalidate()
        heldModifierGuard = nil
        if resetTapMode {
            EventTap.shared.mode = configuredEnabled ? .watching : .off
        }
    }

    // MARK: - Non-activating expanded preview

    private func itemID(at index: Int) -> AnyHashable? {
        index >= 0 && index < items.count ? items[index].id : nil
    }

    private func targetExpandedPreview(at index: Int) {
        cancelExpandedPreviewTimer()
        panels.hideExpandedPreview()
        PreviewProvider.shared.cancelExpandedPreview()
        scheduleExpandedPreview(expandedPreview.target(itemID(at: index)))
    }

    private func scheduleExpandedPreview(
        _ request: ExpandedPreviewSession<AnyHashable>.Request?
    ) {
        guard Preferences.shared.appearanceMode == .windowPreviews,
              let request,
              let delay = Preferences.shared.expandedPreviewDelay.duration else { return }
        let timer = Timer(timeInterval: delay,
                          repeats: false) { [weak self] _ in
            self?.presentExpandedPreview(request)
        }
        expandedPreviewTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func presentExpandedPreview(
        _ request: ExpandedPreviewSession<AnyHashable>.Request
    ) {
        expandedPreviewTimer = nil
        guard state.isActive,
              let id = expandedPreview.settle(
                request, availableWindowIDs: Set(items.map(\.id))),
              let item = items.first(where: { $0.id == id }),
              item.window != nil else { return }
        if let image = PreviewProvider.shared.cachedPreview(for: id) {
            panels.showExpandedPreview(id: id, image: image)
        }
        PreviewProvider.shared.requestExpandedPreview(
            item: item,
            targetSize: SwitcherPanel.expandedPreviewContentSize,
            scale: panels.captureScale)
    }

    private func cancelExpandedPreviewTimer() {
        expandedPreviewTimer?.invalidate()
        expandedPreviewTimer = nil
    }

    private func nsModifier(of flags: CGEventFlags) -> NSEvent.ModifierFlags {
        if flags.contains(.maskAlternate) { return .option }
        if flags.contains(.maskControl) { return .control }
        return .command
    }
}
