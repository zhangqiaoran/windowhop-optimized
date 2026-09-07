import Foundation

/// Allocation-light search index for one open switcher session.
///
/// Window titles/app names are normalized only when the source list changes.
/// Each keystroke normalizes the query once, then performs a single linear scan
/// over the already-normalized strings while preserving MRU/session order.
struct SwitcherSearchIndex {
    private var normalizedByID: [AnyHashable: String] = [:]

    mutating func rebuild(items: [SwitcherItem]) {
        normalizedByID.removeAll(keepingCapacity: true)
        normalizedByID.reserveCapacity(items.count)
        for item in items {
            normalizedByID[item.id] = Self.normalize(item.appName + "\u{0}" + item.title)
        }
    }

    func filter(_ items: [SwitcherItem], query: String) -> [SwitcherItem] {
        filterNormalized(items, normalizedQuery: Self.normalize(query))
    }

    /// Hot path used while typing: caller normalizes the query once per change,
    /// then reuse it across filtering, refresh and capture planning.
    func filterNormalized(_ items: [SwitcherItem],
                          normalizedQuery needle: String) -> [SwitcherItem] {
        guard !needle.isEmpty else { return items }
        var result: [SwitcherItem] = []
        result.reserveCapacity(min(items.count, 16))
        for item in items {
            if normalizedByID[item.id]?.contains(needle) == true {
                result.append(item)
            }
        }
        return result
    }

    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
