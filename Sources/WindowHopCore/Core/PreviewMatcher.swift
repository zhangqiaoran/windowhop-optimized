import CoreGraphics
import Foundation

/// Pairs the windows WindowHop knows through Accessibility (requests) with the
/// window-server windows a snapshot can be taken from (candidates).
///
/// The two sides describe the same windows with different data:
///
/// - Titles disagree by design. Chromium apps report `"Page – Brave – Profile"`
///   through AX while the window server only knows `"Page"`, so equality alone
///   silently fails for every Brave/Chrome window and used to leave the frame as
///   the only signal.
/// - Frames agree exactly, but they are *not* unique: same-size, stacked,
///   zoomed, or full-screen windows of one app share a frame, and an app also
///   owns invisible helper windows.
///
/// So neither signal decides alone. Every plausible pair is scored, and a pair
/// is only accepted when it is the unambiguous best choice for BOTH sides: the
/// candidate is this request's clear winner *and* the request is that
/// candidate's clear winner. Anything ambiguous stays unassigned — the tile then
/// keeps its placeholder, because a preview of the wrong window is worse than no
/// preview.
enum PreviewMatcher {
    struct Request {
        let id: AnyHashable
        let pid: pid_t
        let title: String
        let frame: CGRect?
    }

    struct Candidate {
        /// Position in the caller's candidate list; returned as the assignment.
        let index: Int
        let pid: pid_t
        let title: String
        let frame: CGRect
    }

    /// Per-edge frame agreement between an AX frame and a window-server frame.
    /// They are normally identical; the tolerance only absorbs rounding and a
    /// window that settled between the two reads.
    private static let frameTolerance: CGFloat = 5
    /// Two candidates whose scores differ by less than this are a tie.
    private static let ambiguityMargin: CGFloat = 0.5

    /// How two titles for the same window can relate once decoration differs.
    enum TitleRelation {
        case equal
        /// One title is the other plus an app/profile/state decoration
        /// (`"Page – Brave – Personal"` vs `"Page"`), or the same title with its
        /// middle elided, which is how the window server reports long titles
        /// (`"A very long page …with an ending"`).
        case compatible
        /// At least one side has no title to compare (helper windows).
        case unknown
        case different
    }

    /// Lower is better: primary tier first, frame distance as the tiebreaker.
    private struct Score: Comparable {
        let tier: Int
        let distance: CGFloat

        static func < (lhs: Score, rhs: Score) -> Bool {
            lhs.tier == rhs.tier ? lhs.distance < rhs.distance : lhs.tier < rhs.tier
        }

        /// A tie means "indistinguishable", which is what makes a pair unusable.
        func isTied(with other: Score) -> Bool {
            tier == other.tier && abs(distance - other.distance) < ambiguityMargin
        }
    }

    /// Unique assignment of candidates to requests. Every candidate is consumed
    /// at most once, so two windows of the same app can never share a preview,
    /// and requests without a clear match are simply absent from the result.
    static func assign(requests: [Request], candidates: [Candidate]) -> [AnyHashable: Int] {
        guard !requests.isEmpty, !candidates.isEmpty else { return [:] }

        // PID is a hard constraint, so comparing windows from different apps can
        // never produce an edge. Partition first instead of paying that cost in
        // every winner scan. On a desktop with many apps this turns one large
        // quadratic search into several tiny per-app searches.
        let requestsByPID = Dictionary(grouping: requests.indices, by: { requests[$0].pid })
        let candidatesByPID = Dictionary(grouping: candidates.indices.filter {
            candidates[$0].frame.width > 1 && candidates[$0].frame.height > 1
        }, by: { candidates[$0].pid })

        var assigned: [AnyHashable: Int] = [:]
        assigned.reserveCapacity(requests.count)
        for (pid, requestIndices) in requestsByPID {
            guard let candidateIndices = candidatesByPID[pid], !candidateIndices.isEmpty else {
                continue
            }
            assignGroup(requestIndices: requestIndices, candidateIndices: candidateIndices,
                        requests: requests, candidates: candidates, into: &assigned)
        }
        return assigned
    }

    /// Settles one application's bipartite matching problem. Pair scores are
    /// computed once, then reused across elimination rounds; removals can make an
    /// ambiguous edge unique without re-normalizing titles or re-measuring frames.
    private static func assignGroup(requestIndices: [Int],
                                    candidateIndices: [Int],
                                    requests: [Request],
                                    candidates: [Candidate],
                                    into assigned: inout [AnyHashable: Int]) {
        // Keep local indices dense so one flat optional-Score buffer replaces a
        // dictionary-of-dictionaries. Browser/IDE processes can own dozens of
        // windows; contiguous storage is both faster to scan and far cheaper in
        // allocator/hash-table overhead.
        let requestOrder = requestIndices.sorted()
        let candidateOrder = candidateIndices.sorted()
        let requestCount = requestOrder.count
        let candidateCount = candidateOrder.count
        var scores = Array<Score?>(repeating: nil,
                                   count: requestCount * candidateCount)
        @inline(__always) func scoreIndex(_ request: Int, _ candidate: Int) -> Int {
            request * candidateCount + candidate
        }

        for requestLocal in 0..<requestCount {
            let requestIndex = requestOrder[requestLocal]
            for candidateLocal in 0..<candidateCount {
                let candidateIndex = candidateOrder[candidateLocal]
                scores[scoreIndex(requestLocal, candidateLocal)] =
                    score(requests[requestIndex], candidates[candidateIndex])
            }
        }

        // Local indices are already dense. Boolean activity masks are cheaper
        // than Set<Int> here: no hashing, no node allocation, and every winner
        // scan walks contiguous memory beside the contiguous score matrix. This
        // matters most for browser/IDE processes with dozens of windows.
        var openRequests = Array(repeating: true, count: requestCount)
        var openCandidates = Array(repeating: true, count: candidateCount)
        var openRequestCount = requestCount
        var openCandidateCount = candidateCount
        var requestWinners = Array(repeating: -1, count: requestCount)
        var candidateWinners = Array(repeating: -1, count: candidateCount)

        while openRequestCount > 0, openCandidateCount > 0 {
            for requestLocal in 0..<requestCount where openRequests[requestLocal] {
                requestWinners[requestLocal] = clearWinner(
                    active: openCandidates,
                    scoredBy: { scores[scoreIndex(requestLocal, $0)] }) ?? -1
            }

            for candidateLocal in 0..<candidateCount where openCandidates[candidateLocal] {
                candidateWinners[candidateLocal] = clearWinner(
                    active: openRequests,
                    scoredBy: { scores[scoreIndex($0, candidateLocal)] }) ?? -1
            }

            var resolvedThisRound = 0
            for requestLocal in 0..<requestCount where openRequests[requestLocal] {
                let candidateLocal = requestWinners[requestLocal]
                guard candidateLocal >= 0,
                      openCandidates[candidateLocal],
                      candidateWinners[candidateLocal] == requestLocal else { continue }

                let requestIndex = requestOrder[requestLocal]
                let candidateIndex = candidateOrder[candidateLocal]
                assigned[requests[requestIndex].id] = candidates[candidateIndex].index
                openRequests[requestLocal] = false
                openCandidates[candidateLocal] = false
                openRequestCount -= 1
                openCandidateCount -= 1
                resolvedThisRound += 1
            }
            guard resolvedThisRound > 0 else { break }
        }
    }

    /// The single best element, or nil when nothing scores or the best two are
    /// indistinguishable. The active mask is dense and read-only, so this stays
    /// allocation-free inside the matching loop.
    private static func clearWinner(active: [Bool],
                                    scoredBy score: (Int) -> Score?) -> Int? {
        var best: (index: Int, score: Score)?
        var runnerUp: Score?

        for index in active.indices where active[index] {
            guard let candidateScore = score(index) else { continue }
            guard let currentBest = best else {
                best = (index, candidateScore)
                continue
            }
            if candidateScore < currentBest.score {
                runnerUp = currentBest.score
                best = (index, candidateScore)
            } else if runnerUp == nil || candidateScore < runnerUp! {
                runnerUp = candidateScore
            }
        }

        guard let best else { return nil }
        if let runnerUp, best.score.isTied(with: runnerUp) { return nil }
        return best.index
    }

    /// Nil when the pair is impossible (different apps, or neither the frame nor
    /// the title supports it).
    private static func score(_ request: Request, _ candidate: Candidate) -> Score? {
        guard request.pid == candidate.pid else { return nil }
        let distance = request.frame.map { frameDistance($0, candidate.frame) }
        let framesAgree = request.frame.map { framesMatch($0, candidate.frame) } ?? false
        let relation = titleRelation(request.title, candidate.title)
        let tier: Int
        switch (framesAgree, relation) {
        case (true, .equal): tier = 0
        case (true, .compatible): tier = 1
        case (true, .unknown): tier = 2
        case (false, .equal): tier = 3
        case (false, .compatible): tier = 4
        // same frame but a conflicting title: the title changed between the two
        // reads (a tab switched, a document was edited) — still the same window
        case (true, .different): tier = 5
        case (false, .unknown), (false, .different): return nil
        }
        return Score(tier: tier, distance: distance ?? 0)
    }

    private static func framesMatch(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.origin.x - b.origin.x) < frameTolerance
            && abs(a.origin.y - b.origin.y) < frameTolerance
            && abs(a.width - b.width) < frameTolerance
            && abs(a.height - b.height) < frameTolerance
    }

    private static func frameDistance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        abs(a.origin.x - b.origin.x) + abs(a.origin.y - b.origin.y)
            + abs(a.width - b.width) + abs(a.height - b.height)
    }

    /// Separators apps use between the window title and whatever they append to
    /// it (app name, profile, state).
    private static let titleSeparators = [" - ", " – ", " — ", " | ", " · "]

    static func titleRelation(_ lhs: String, _ rhs: String) -> TitleRelation {
        let left = normalized(lhs)
        let right = normalized(rhs)
        if left.isEmpty || right.isEmpty { return .unknown }
        if left == right { return .equal }
        if isDecorated(left, of: right) || isDecorated(right, of: left) { return .compatible }
        if isElided(left, of: right) || isElided(right, of: left) { return .compatible }
        return .different
    }

    private static func normalized(_ title: String) -> String {
        title.precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// True when `decorated` is `core` with a separated addition on either end.
    private static func isDecorated(_ decorated: String, of core: String) -> Bool {
        titleSeparators.contains {
            decorated.hasPrefix(core + $0) || decorated.hasSuffix($0 + core)
        }
    }

    /// The window server reports long titles with their middle elided, so the
    /// kept head and tail must both still line up with the full title — and
    /// together be specific enough to mean something.
    private static let minimumElidedEvidence = 8

    private static func isElided(_ elided: String, of full: String) -> Bool {
        guard let ellipsis = elided.range(of: "…") else { return false }
        let head = elided[elided.startIndex..<ellipsis.lowerBound]
        let tail = elided[ellipsis.upperBound...]
        guard head.count + tail.count >= minimumElidedEvidence,
              full.hasPrefix(head) else { return false }
        return tail.isEmpty || full.dropFirst(head.count).contains(tail)
    }
}
