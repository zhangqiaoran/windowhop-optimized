import Foundation

/// Constant-time motion planning for the shared selection lens.
///
/// The duration adapts to grid distance without sorting, searching, or
/// allocating. Adjacent Cmd-Tab steps stay immediate; longer arrow-key jumps
/// get slightly more travel time so the user's eye can follow the focus.
public enum SelectionMotion {
    public static let minimumDuration: TimeInterval = 0.075
    public static let maximumDuration: TimeInterval = 0.155

    public static func duration(from oldIndex: Int,
                                to newIndex: Int,
                                columns: Int) -> TimeInterval {
        guard oldIndex >= 0, newIndex >= 0, oldIndex != newIndex else { return 0 }
        let columnCount = max(1, columns)
        let oldRow = oldIndex / columnCount
        let oldColumn = oldIndex % columnCount
        let newRow = newIndex / columnCount
        let newColumn = newIndex % columnCount

        let dx = Double(newColumn - oldColumn)
        let dy = Double(newRow - oldRow)
        let distance = sqrt(dx * dx + dy * dy)
        let adaptive = minimumDuration + min(distance, 5) * 0.014
        return min(maximumDuration, adaptive)
    }
}
