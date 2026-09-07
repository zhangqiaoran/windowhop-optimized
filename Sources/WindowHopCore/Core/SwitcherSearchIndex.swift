import Foundation

/// Allocation-light search index for one open switcher session.
///
/// Window titles/app names are normalized only when the source list changes.
/// The hot path is array-aligned with session order: no per-item Dictionary
/// lookup/hash is needed while typing. Each keystroke normalizes the query once,
/// then performs one cache-friendly linear scan over the pre-normalized strings.
struct SwitcherSearchIndex {
    private var ids: [AnyHashable] = []
    private var normalizedTerms: [String] = []

    mutating func rebuild(items: [SwitcherItem]) {
        ids.removeAll(keepingCapacity: true)
        normalizedTerms.removeAll(keepingCapacity: true)
        ids.reserveCapacity(items.count)
        normalizedTerms.reserveCapacity(items.count)
        for item in items {
            ids.append(item.id)
            normalizedTerms.append(Self.searchableText(for: item))
        }
    }

    func filter(_ items: [SwitcherItem], query: String) -> [SwitcherItem] {
        filterNormalized(items, normalizedQuery: Self.normalize(query))
    }

    /// Hot path used while typing. Fast path assumes the same session list that
    /// built the index; a defensive fallback handles a mismatched caller without
    /// compromising correctness.
    func filterNormalized(_ items: [SwitcherItem],
                          normalizedQuery needle: String) -> [SwitcherItem] {
        guard !needle.isEmpty else { return items }

        if items.count == ids.count {
            var aligned = true
            for index in items.indices where items[index].id != ids[index] {
                aligned = false
                break
            }
            if aligned {
                var result: [SwitcherItem] = []
                result.reserveCapacity(min(items.count, 16))
                for index in items.indices where normalizedTerms[index].contains(needle) {
                    result.append(items[index])
                }
                return result
            }
        }

        // Rare fallback (for ad-hoc subsets such as newly appeared windows).
        var result: [SwitcherItem] = []
        result.reserveCapacity(min(items.count, 8))
        for item in items where Self.matches(item, normalizedQuery: needle) {
            result.append(item)
        }
        return result
    }

    static func matches(_ item: SwitcherItem, normalizedQuery needle: String) -> Bool {
        needle.isEmpty || searchableText(for: item).contains(needle)
    }

    static func searchableText(for item: SwitcherItem) -> String {
        normalize(item.appName + "\u{0}" + item.title)
    }

    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
