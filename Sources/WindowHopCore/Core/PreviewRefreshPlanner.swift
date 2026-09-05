import Foundation

/// Pure O(n) scheduling for preview refresh work.
///
/// The visible panel always consumes cached images immediately; this planner only
/// decides which windows need ScreenCaptureKit work for the current session and
/// in what order. Its priorities are deliberately asymmetric:
///
/// 1. the selected window if it has no valid cache;
/// 2. every other uncached/invalid window, preserving MRU order;
/// 3. the selected window if its cache is merely stale;
/// 4. other stale cached windows, preserving MRU order;
/// 5. fresh cached windows are skipped entirely.
///
/// Putting all missing windows ahead of stale cached ones guarantees coverage on
/// large multi-display setups: repeated short switcher sessions progressively fill
/// every tile instead of repeatedly refreshing the same first few windows.
public enum PreviewRefreshPlanner {
    public struct Entry<ID: Hashable> {
        public let id: ID
        public let hasCachedImage: Bool
        public let signatureMatches: Bool
        public let age: TimeInterval?

        public init(id: ID,
                    hasCachedImage: Bool,
                    signatureMatches: Bool,
                    age: TimeInterval?) {
            self.id = id
            self.hasCachedImage = hasCachedImage
            self.signatureMatches = signatureMatches
            self.age = age
        }
    }

    /// Returns entry indices in refresh priority order. The provider uses this
    /// directly so it never has to build a temporary ID→request dictionary just
    /// to recover the original request after planning.
    public static func planIndices<ID: Hashable>(
        entries: [Entry<ID>],
        selectedID: ID?,
        freshnessInterval: TimeInterval
    ) -> [Int] {
        var selectedMissing: Int?
        var missing: [Int] = []
        var selectedStale: Int?
        var stale: [Int] = []
        missing.reserveCapacity(entries.count)
        stale.reserveCapacity(entries.count)

        for (index, entry) in entries.enumerated() {
            let isSelected = entry.id == selectedID
            let invalidOrMissing = !entry.hasCachedImage || !entry.signatureMatches
            if invalidOrMissing {
                if isSelected {
                    selectedMissing = index
                } else {
                    missing.append(index)
                }
                continue
            }

            let isFresh = entry.age.map { $0 >= 0 && $0 < freshnessInterval } ?? false
            guard !isFresh else { continue }
            if isSelected {
                selectedStale = index
            } else {
                stale.append(index)
            }
        }

        var result: [Int] = []
        result.reserveCapacity((selectedMissing == nil ? 0 : 1)
                               + missing.count
                               + (selectedStale == nil ? 0 : 1)
                               + stale.count)
        if let selectedMissing { result.append(selectedMissing) }
        result.append(contentsOf: missing)
        if let selectedStale { result.append(selectedStale) }
        result.append(contentsOf: stale)
        return result
    }

    /// Compatibility/helper API used by pure tests and callers that only care
    /// about IDs. Internally it reuses the index plan above.
    public static func plan<ID: Hashable>(
        entries: [Entry<ID>],
        selectedID: ID?,
        freshnessInterval: TimeInterval
    ) -> [ID] {
        planIndices(entries: entries, selectedID: selectedID,
                    freshnessInterval: freshnessInterval).map { entries[$0].id }
    }

}
