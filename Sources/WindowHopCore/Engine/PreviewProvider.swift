import AppKit
import ScreenCaptureKit

/// Window previews for the optional Window Previews appearance, tuned for an
/// instant-open feel (public APIs only):
///
/// - The cache lives in memory for the app's lifetime, so opening the switcher
///   shows the last known preview of every window IMMEDIATELY.
/// - Session work is cache-aware: fresh thumbnails are reused, missing windows
///   are filled before stale cached ones, and the selected window gets priority.
///   Captures still deliver live so a cached tile can crossfade when refreshed.
///   Nothing is captured while the switcher is closed.
/// - Images are requested already scaled to tile size (no full-resolution
///   retention), never written to disk, never transmitted, and evicted the
///   moment their window disappears — a late capture for a vanished window is
///   discarded (see PreviewLedger).
/// - Public ScreenCaptureKit only. AX windows are matched to SCWindows by
///   `PreviewMatcher` (pid + frame + decoration-tolerant title), and every
///   request receives a DISTINCT window — two windows of the same app can never
///   share a preview. When no unambiguous match exists the tile keeps its
///   placeholder and corner badge; a wrong preview is worse than none.
public final class PreviewProvider {
    public static let shared = PreviewProvider()

    /// Delivered on the main thread for windows of the current session, keyed
    /// by the window's stable id (fill-ins and refreshes of cached snapshots).
    public var onPreview: ((AnyHashable, NSImage) -> Void)?
    /// Delivered on the main thread when no first snapshot can be produced for
    /// an item in the current session. Cached previews remain preferable and
    /// are never replaced by an unavailable state.
    public var onPreviewUnavailable: ((AnyHashable) -> Void)?
    /// One panel-level permission state; never repeated as a per-card action.
    public var onPermissionRequired: ((ScreenRecordingPermission.Status) -> Void)?
    /// A fresh dwell snapshot for the still-targeted window.
    public var onExpandedPreview: ((AnyHashable, NSImage) -> Void)?

    /// Decides what late, out-of-order capture results may do (pure, tested).
    private var ledger = PreviewLedger<AnyHashable>()

    /// Small tile-sized images only. Expanded dwell captures are deliberately not
    /// inserted here; otherwise visiting several windows can retain multi-megabyte
    /// images in a cache whose purpose is instant thumbnail presentation.
    private struct CacheEntry {
        let image: NSImage
        let signature: CaptureSignature
        let capturedAt: TimeInterval
        let byteCost: Int
        var accessSerial: UInt64
    }

    private struct CaptureSignature: Equatable {
        let pid: pid_t
        let title: String
        let frame: CGRect?
    }

    private struct CapturedImage {
        let image: NSImage
        let byteCost: Int
    }

    private var cache: [AnyHashable: CacheEntry] = [:]
    private var cacheByteCost = 0
    private var cacheAccessSerial: UInt64 = 0
    private static let cacheFreshnessInterval: TimeInterval = 2
    private static let maxCacheByteCost = 64 * 1024 * 1024
    private var activeSessionGeneration: Int?
    private var expandedGeneration = 0

    /// IDs already scheduled inside the active session. Window-store updates can
    /// extend the same session several times in a few milliseconds; keeping this
    /// tiny set prevents duplicate ScreenCaptureKit work for the same window.
    /// It is session-local on purpose: a new session may need live delivery even
    /// while a capture from the previous generation is still winding down.
    private var sessionInFlightIDs: Set<AnyHashable> = []

    struct CaptureRequest {
        let id: AnyHashable
        let pid: pid_t
        let title: String
        let frame: CGRect?
    }

    /// Stable IDs are immutable value identities in WindowHop, but
    /// `AnyHashable` predates Sendable conformance. This wrapper limits the
    /// unchecked boundary to transport into the main-actor delivery closure.
    private struct SendableIdentity: @unchecked Sendable {
        let value: AnyHashable
    }

    private init() {}

    // MARK: - Cache (memory-only, app lifetime, evicted with the window)

    public func cachedPreview(for id: AnyHashable) -> NSImage? {
        guard var entry = cache[id] else { return nil }
        cacheAccessSerial &+= 1
        entry.accessSerial = cacheAccessSerial
        cache[id] = entry
        return entry.image
    }

    public func evict(_ id: AnyHashable) {
        if let removed = cache.removeValue(forKey: id) {
            cacheByteCost = max(0, cacheByteCost - removed.byteCost)
        }
        ledger.evict(id)
    }

    /// Used when the user switches back to App Icons: nothing to retain.
    public func evictAll() {
        cache.removeAll(keepingCapacity: false)
        cacheByteCost = 0
        ledger.evictAll()
    }

    // MARK: - Session lifecycle

    /// Starts recapturing previews for the session's items. No-op unless Window
    /// Previews mode is active and Screen Recording is granted.
    public func beginSession(items: [SwitcherItem],
                             selectedID: AnyHashable?,
                             targetSize: CGSize,
                             scale: CGFloat) {
        guard Preferences.shared.appearanceMode == .windowPreviews else { return }
        let permissionStatus = ScreenRecordingPermission.status
        guard permissionStatus.isAuthorized else {
            activeSessionGeneration = nil
            sessionInFlightIDs.removeAll(keepingCapacity: true)
            onPermissionRequired?(permissionStatus)
            return
        }
        let allRequests = items.compactMap(makeCaptureRequest)
        let sessionGeneration = ledger.beginSession(ids: allRequests.map { $0.id })
        activeSessionGeneration = sessionGeneration
        sessionInFlightIDs.removeAll(keepingCapacity: true)
        let refreshRequests = requestsToRefresh(allRequests, selectedID: selectedID)
        guard !refreshRequests.isEmpty else {
            DebugLog.log("preview refresh: 0/\(allRequests.count) captures (fresh cache)")
            return
        }
        DebugLog.log("preview refresh: \(refreshRequests.count)/\(allRequests.count) captures")
        sessionInFlightIDs.formUnion(refreshRequests.map(\.id))
        let pixelTarget = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
        Task { [weak self] in
            await self?.capture(refreshRequests, matchingRequests: allRequests,
                                generation: sessionGeneration, pixelTarget: pixelTarget)
        }
    }

    /// Captures previews for windows that joined the list while the switcher is
    /// open. Scoped to the newcomers and to the session generation already in
    /// flight, so the tiles that are still filling in are left alone. No-op
    /// outside an active Window Previews session.
    public func extendSession(items: [SwitcherItem], targetSize: CGSize, scale: CGFloat) {
        guard Preferences.shared.appearanceMode == .windowPreviews,
              ScreenRecordingPermission.status.isAuthorized,
              let sessionGeneration = activeSessionGeneration else { return }
        let allRequests = items.compactMap(makeCaptureRequest)
        guard !allRequests.isEmpty else { return }
        ledger.extendSession(ids: allRequests.map { $0.id })
        let requests = requestsToRefresh(allRequests, selectedID: nil)
        guard !requests.isEmpty else { return }
        sessionInFlightIDs.formUnion(requests.map(\.id))
        let pixelTarget = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
        Task { [weak self] in
            await self?.capture(requests, matchingRequests: allRequests,
                                generation: sessionGeneration, pixelTarget: pixelTarget)
        }
    }

    /// Stops live delivery; the cache stays warm for an instant next open.
    /// In-flight captures may still finish into the cache (free freshness),
    /// but no further capture work starts while the switcher is closed.
    public func endSession() {
        activeSessionGeneration = nil
        cancelExpandedPreview()
        ledger.endSession()
    }

    /// Requests a larger snapshot for the dwell presentation. It remains fully
    /// session-scoped and only delivers when both the session and target
    /// generation are still current.
    public func requestExpandedPreview(item: SwitcherItem,
                                       targetSize: CGSize,
                                       scale: CGFloat) {
        guard Preferences.shared.appearanceMode == .windowPreviews,
              ScreenRecordingPermission.status.isAuthorized,
              let sessionGeneration = activeSessionGeneration,
              let request = makeCaptureRequest(item) else { return }
        expandedGeneration += 1
        let requestGeneration = expandedGeneration
        let pixelTarget = CGSize(width: targetSize.width * scale,
                                 height: targetSize.height * scale)
        Task { [weak self] in
            await self?.captureExpanded(
                request,
                sessionGeneration: sessionGeneration,
                requestGeneration: requestGeneration,
                pixelTarget: pixelTarget)
        }
    }

    public func cancelExpandedPreview() {
        expandedGeneration += 1
    }

    // MARK: - Refresh planning / bounded cache

    private func requestsToRefresh(_ requests: [CaptureRequest],
                                   selectedID: AnyHashable?) -> [CaptureRequest] {
        let now = ProcessInfo.processInfo.systemUptime
        var entries: [PreviewRefreshPlanner.Entry<AnyHashable>] = []
        entries.reserveCapacity(requests.count)
        for request in requests {
            let entry = cache[request.id]
            entries.append(PreviewRefreshPlanner.Entry(
                id: request.id,
                hasCachedImage: entry != nil,
                signatureMatches: entry.map { $0.signature == signature(for: request) } ?? false,
                age: entry.map { max(0, now - $0.capturedAt) }))
        }

        let orderedIndices = PreviewRefreshPlanner.planIndices(
            entries: entries, selectedID: selectedID,
            freshnessInterval: Self.cacheFreshnessInterval)
        var result: [CaptureRequest] = []
        result.reserveCapacity(orderedIndices.count)
        for index in orderedIndices {
            let request = requests[index]
            guard !sessionInFlightIDs.contains(request.id) else { continue }
            result.append(request)
        }
        return result
    }

    private func signature(for request: CaptureRequest) -> CaptureSignature {
        CaptureSignature(pid: request.pid, title: request.title, frame: request.frame)
    }

    private func storeCachedPreview(_ captured: CapturedImage,
                                    for request: CaptureRequest) {
        if let previous = cache.removeValue(forKey: request.id) {
            cacheByteCost = max(0, cacheByteCost - previous.byteCost)
        }
        cacheAccessSerial &+= 1
        cache[request.id] = CacheEntry(
            image: captured.image,
            signature: signature(for: request),
            capturedAt: ProcessInfo.processInfo.systemUptime,
            byteCost: captured.byteCost,
            accessSerial: cacheAccessSerial)
        cacheByteCost += captured.byteCost
        trimCache(protecting: request.id)
    }

    /// LRU is intentionally bounded by bytes rather than entry count because
    /// Retina captures cost roughly four times as much as 1x captures. Eviction
    /// affects only the next session's instant cache; the currently visible tile
    /// already owns its NSImage and remains rendered.
    private func trimCache(protecting protectedID: AnyHashable) {
        while cacheByteCost > Self.maxCacheByteCost, cache.count > 1 {
            guard let victim = cache.lazy
                .filter({ $0.key != protectedID })
                .min(by: { $0.value.accessSerial < $1.value.accessSerial }) else { break }
            cache.removeValue(forKey: victim.key)
            cacheByteCost = max(0, cacheByteCost - victim.value.byteCost)
        }
    }

    // MARK: - Capture

    private func capture(_ requests: [CaptureRequest],
                         matchingRequests: [CaptureRequest],
                         generation sessionGeneration: Int,
                         pixelTarget: CGSize) async {
        let scheduledIDs = requests.map(\.id)
        defer {
            // Session extensions can arrive while a batch is still running. Clear
            // only the generation that scheduled these IDs; a newer session owns
            // its own in-flight set and must never be mutated by this late task.
            Task { @MainActor [weak self] in
                guard let self, self.activeSessionGeneration == sessionGeneration else { return }
                self.sessionInFlightIDs.subtract(scheduledIDs)
            }
        }
        guard let content = try? await SCShareableContent
            .excludingDesktopWindows(false, onScreenWindowsOnly: false) else {
            for request in requests {
                await markUnavailable(request.id, generation: sessionGeneration)
            }
            return
        }
        // Match with the complete session inventory even when fresh cached windows
        // do not need recapture. Their presence can disambiguate same-app windows
        // that share a title or frame, while capture work remains limited to the
        // refresh plan.
        var requestPIDs = Set<pid_t>()
        requestPIDs.reserveCapacity(matchingRequests.count)
        for request in matchingRequests { requestPIDs.insert(request.pid) }
        let assignments = PreviewMatcher.assign(
            requests: matchingRequests.map(Self.matchRequest),
            candidates: Self.matchCandidates(in: content.windows, allowedPIDs: requestPIDs))
        // Build the capture queue in refresh priority order. No secondary Set is
        // needed: failed matches are reported while walking the same request list.
        var assigned: [(CaptureRequest, SCWindow)] = []
        assigned.reserveCapacity(requests.count)
        for request in requests {
            if let index = assignments[request.id] {
                assigned.append((request, content.windows[index]))
            } else {
                await markUnavailable(request.id, generation: sessionGeneration)
            }
        }
        var waveStart = 0
        while waveStart < assigned.count {
            let staleBeforeWave = await MainActor.run {
                self.ledger.generation != sessionGeneration
            }
            if staleBeforeWave { return }
            await withTaskGroup(of: Void.self) { group in
                let waveEnd = min(waveStart + 4, assigned.count)
                for index in waveStart..<waveEnd {
                    let (request, scWindow) = assigned[index]
                    group.addTask { [weak self] in
                        await self?.captureOne(request, scWindow, generation: sessionGeneration,
                                               pixelTarget: pixelTarget)
                    }
                }
            }
            // once the session ended, finish the current wave into the cache but
            // start no further capture work
            let staleAfterWave = await MainActor.run {
                self.ledger.generation != sessionGeneration
            }
            if staleAfterWave { return }
            waveStart += 4
        }
    }

    private func captureOne(_ request: CaptureRequest, _ scWindow: SCWindow,
                            generation sessionGeneration: Int,
                            pixelTarget: CGSize) async {
        guard let captured = await captureImage(scWindow, pixelTarget: pixelTarget) else {
            await markUnavailable(request.id, generation: sessionGeneration)
            return
        }
        await MainActor.run {
            // the ledger is the single authority on what a late result may do:
            // nothing for vanished windows, cache-only for ended sessions
            guard self.ledger.shouldStore(request.id) else { return }
            self.storeCachedPreview(captured, for: request)
            if self.ledger.shouldDeliver(request.id, capturedIn: sessionGeneration) {
                self.onPreview?(request.id, captured.image)
            }
        }
    }

    private func captureExpanded(_ request: CaptureRequest,
                                 sessionGeneration: Int,
                                 requestGeneration: Int,
                                 pixelTarget: CGSize) async {
        guard let content = try? await SCShareableContent
            .excludingDesktopWindows(false, onScreenWindowsOnly: false) else { return }
        guard let candidateIndex = PreviewMatcher.assign(
            requests: [Self.matchRequest(request)],
            candidates: Self.matchCandidates(in: content.windows, allowedPIDs: Set([request.pid])))[request.id],
              let captured = await captureImage(content.windows[candidateIndex],
                                                pixelTarget: pixelTarget) else { return }
        let identity = SendableIdentity(value: request.id)
        await MainActor.run {
            guard self.activeSessionGeneration == sessionGeneration,
                  self.ledger.shouldDeliver(identity.value,
                                            capturedIn: sessionGeneration),
                  self.expandedGeneration == requestGeneration else { return }
            // Expanded captures are transient presentation assets. Keeping them out
            // of the thumbnail cache prevents large dwell images from accumulating.
            self.onExpandedPreview?(identity.value, captured.image)
        }
    }

    private func captureImage(_ scWindow: SCWindow,
                              pixelTarget: CGSize) async -> CapturedImage? {
        let windowSize = scWindow.frame.size
        guard windowSize.width > 1, windowSize.height > 1 else { return nil }
        let configuration = SCStreamConfiguration()
        let fit = min(pixelTarget.width / windowSize.width,
                      pixelTarget.height / windowSize.height, 2)
        configuration.width = max(1, Int(windowSize.width * fit))
        configuration.height = max(1, Int(windowSize.height * fit))
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        guard let cgImage = try? await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: configuration) else { return nil }
        // Preserve pixel-native logical dimensions instead of assuming every
        // target display is 2x Retina. The previous hard-coded /2 made a 1x
        // external display treat a correctly sized capture as half-size and
        // then upscale it inside the preview canvas, which looked soft/broken.
        // NSImageView will downscale these pixels to the target canvas as needed.
        let image = NSImage(cgImage: cgImage,
                            size: NSSize(width: CGFloat(cgImage.width),
                                         height: CGFloat(cgImage.height)))
        // bytesPerRow includes row padding and therefore gives a safer memory
        // estimate than width * height * 4. The cache cap remains conservative.
        let byteCost = max(1, cgImage.bytesPerRow * cgImage.height)
        return CapturedImage(image: image, byteCost: byteCost)
    }

    private func makeCaptureRequest(_ item: SwitcherItem) -> CaptureRequest? {
        guard let window = item.window else { return nil }
        if let native = window.nativeWindow, let primary = NSScreen.screens.first {
            let frame = native.frame
            return CaptureRequest(id: item.id,
                                  pid: ProcessInfo.processInfo.processIdentifier,
                                  title: item.title,
                                  frame: CGRect(x: frame.origin.x,
                                                y: primary.frame.maxY - frame.maxY,
                                                width: frame.width,
                                                height: frame.height))
        }
        guard let app = window.app else { return nil }
        return CaptureRequest(id: item.id, pid: app.pid,
                              title: item.title, frame: window.frame)
    }

    private func markUnavailable(_ id: AnyHashable, generation sessionGeneration: Int) async {
        let identity = SendableIdentity(value: id)
        await MainActor.run {
            let status = ScreenRecordingPermission.status
            if !status.isAuthorized {
                self.onPermissionRequired?(status)
                return
            }
            guard self.cache[identity.value] == nil,
                  self.ledger.shouldDeliver(identity.value,
                                            capturedIn: sessionGeneration) else { return }
            self.onPreviewUnavailable?(identity.value)
        }
    }

    // MARK: - Diagnostics

    /// Reports the pairing the next session would use, for the `--dump-previews`
    /// harness flag: no capture is requested, so no image is produced, cached, or
    /// written anywhere. Window titles are printed for the person running it.
    public func dumpMatching(items: [SwitcherItem],
                             completion: @escaping ([String]) -> Void) {
        let requests = items.compactMap(makeCaptureRequest)
        Task {
            guard let content = try? await SCShareableContent
                .excludingDesktopWindows(false, onScreenWindowsOnly: false) else {
                await MainActor.run { completion(["dump-previews: no shareable content"]) }
                return
            }
            let candidates = Self.matchCandidates(
                in: content.windows, allowedPIDs: Set(requests.map(\.pid)))
            let assignments = PreviewMatcher.assign(requests: requests.map(Self.matchRequest),
                                                    candidates: candidates)
            let lines = requests.map { request -> String in
                guard let index = assignments[request.id] else {
                    return "· \(request.title) [pid \(request.pid)] → no unambiguous window (placeholder)"
                }
                let window = content.windows[index]
                return "✓ \(request.title) [pid \(request.pid)] → \"\(window.title ?? "")\" \(window.frame)"
            }
            await MainActor.run { completion(lines) }
        }
    }

    // MARK: - Matching

    /// SCWindows are paired with switcher entries by `PreviewMatcher` (pure,
    /// unit-tested): a unique, unambiguous assignment, never a guess.
    private static func matchCandidates(
        in windows: [SCWindow],
        allowedPIDs: Set<pid_t>
    ) -> [PreviewMatcher.Candidate] {
        var candidates: [PreviewMatcher.Candidate] = []
        candidates.reserveCapacity(min(windows.count, allowedPIDs.count * 4))
        for (index, window) in windows.enumerated() {
            let pid = window.owningApplication?.processID ?? -1
            guard allowedPIDs.contains(pid) else { continue }
            candidates.append(PreviewMatcher.Candidate(
                index: index, pid: pid, title: window.title ?? "", frame: window.frame))
        }
        return candidates
    }

    private static func matchRequest(_ request: CaptureRequest) -> PreviewMatcher.Request {
        PreviewMatcher.Request(id: request.id, pid: request.pid,
                               title: request.title, frame: request.frame)
    }
}
