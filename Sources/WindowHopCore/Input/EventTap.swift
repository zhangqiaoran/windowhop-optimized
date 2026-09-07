import AppKit
import ApplicationServices

/// Semantic input events the tap produces for the controller (delivered on main).
public enum SwitcherInputEvent: Equatable {
    case trigger(backward: Bool)
    case openPersistent
    case step(backward: Bool)
    case modifierReleased
    case escape
    case returnKey
    case spaceKey
    case arrow(SwitcherState.ArrowDirection)
    case deleteKey
    case openSettings
}

/// What the tap callback is allowed to consume right now. Kept in a tiny
/// lock-protected box because the callback must decide synchronously on its own thread.
public enum TapMode: Equatable {
    /// switcher disabled or permission missing: consume nothing, native Cmd-Tab works
    case off
    /// idle: consume only the two configured trigger chords
    case watching
    /// hold-based session: consume the handled keys; modifier release ends it
    case sessionHeld
    /// persistent session: like sessionHeld, but modifier release is meaningless
    /// and Space also activates
    case sessionSticky
    /// Search field is first responder. Keyboard input belongs to AppKit text
    /// editing, so the global tap must stay transparent until editing ends.
    case sessionSearch
}

enum EventTapDisposition: Equatable {
    case pass
    case consume
}

struct EventTapDecision: Equatable {
    let disposition: EventTapDisposition
    let input: SwitcherInputEvent?

    static let pass = EventTapDecision(disposition: .pass, input: nil)
    static let consume = EventTapDecision(disposition: .consume, input: nil)
}

/// Pure, lock-contained interception state. It owns the complete key sequence:
/// a keyUp remains suppressed even if the main thread already ended the
/// session after its keyDown. That prevents orphaned Tab events from reaching
/// the native switcher during rapid input or cancellation.
struct EventTapInterceptionState {
    var mode: TapMode = .off
    var holdModifier: CGEventFlags = .maskCommand
    var persistentShortcut: PersistentShortcut?

    // macOS virtual key codes used by WindowHop live in 0...127. A two-word
    // bitset keeps the event-tap hot path allocation-free and avoids Set hashing
    // for every keyDown/keyUp pair. The overflow set is a correctness fallback
    // for unusual synthetic key codes and is normally never touched.
    private var suppressedLow: UInt64 = 0
    private var suppressedHigh: UInt64 = 0
    private var suppressedOverflow: Set<Int64> = []

    init(mode: TapMode = .off,
         holdModifier: CGEventFlags = .maskCommand,
         persistentShortcut: PersistentShortcut? = nil) {
        self.mode = mode
        self.holdModifier = holdModifier
        self.persistentShortcut = persistentShortcut
    }

    var suppressedKeyUps: Set<Int64> {
        var result = suppressedOverflow
        for bit in 0..<64 where suppressedLow & (UInt64(1) << UInt64(bit)) != 0 {
            result.insert(Int64(bit))
        }
        for bit in 0..<64 where suppressedHigh & (UInt64(1) << UInt64(bit)) != 0 {
            result.insert(Int64(bit + 64))
        }
        return result
    }

    mutating func reset() {
        mode = .off
        suppressedLow = 0
        suppressedHigh = 0
        suppressedOverflow.removeAll(keepingCapacity: true)
    }

    private mutating func suppressKeyUp(_ keyCode: Int64) {
        switch keyCode {
        case 0..<64:
            suppressedLow |= UInt64(1) << UInt64(keyCode)
        case 64..<128:
            suppressedHigh |= UInt64(1) << UInt64(keyCode - 64)
        default:
            suppressedOverflow.insert(keyCode)
        }
    }

    private mutating func consumeSuppressedKeyUp(_ keyCode: Int64) -> Bool {
        switch keyCode {
        case 0..<64:
            let bit = UInt64(1) << UInt64(keyCode)
            guard suppressedLow & bit != 0 else { return false }
            suppressedLow &= ~bit
            return true
        case 64..<128:
            let bit = UInt64(1) << UInt64(keyCode - 64)
            guard suppressedHigh & bit != 0 else { return false }
            suppressedHigh &= ~bit
            return true
        default:
            return suppressedOverflow.remove(keyCode) != nil
        }
    }

    mutating func decide(type: CGEventType,
                         keyCode: Int64,
                         flags: CGEventFlags) -> EventTapDecision {
        if type == .flagsChanged {
            guard mode == .sessionHeld, !flags.contains(holdModifier) else {
                return .pass
            }
            // End the tap-side held session synchronously. The semantic release
            // still hops to main, but a new Alt/Option+Tab pressed before main
            // catches up must already be recognized as a fresh trigger rather
            // than a stale .step belonging to the previous session.
            mode = .watching
            return EventTapDecision(disposition: .pass, input: .modifierReleased)
        }

        // Consume the matching release even when the controller moved back to
        // watching between the down/up halves of a rapid chord.
        if type == .keyUp, consumeSuppressedKeyUp(keyCode) {
            return .consume
        }

        switch mode {
        case .off:
            return .pass
        case .sessionSearch:
            // Text editing owns ordinary keys, but the configured switcher
            // chord must remain ours or macOS's native app switcher can leak
            // through while the pinned search field is focused.
            guard type == .keyDown else { return .pass }
            if isSwitcherTrigger(keyCode: keyCode, flags: flags) {
                suppressKeyUp(keyCode)
                return EventTapDecision(
                    disposition: .consume,
                    input: .step(backward: flags.contains(.maskShift)))
            }
            if let persistentShortcut,
               persistentShortcut.matches(keyCode: keyCode, flags: flags) {
                suppressKeyUp(keyCode)
                return .consume
            }
            return .pass
        case .watching:
            guard type == .keyDown else { return .pass }
            if isSwitcherTrigger(keyCode: keyCode, flags: flags) {
                mode = .sessionHeld
                suppressKeyUp(keyCode)
                return EventTapDecision(
                    disposition: .consume,
                    input: .trigger(backward: flags.contains(.maskShift)))
            }
            if let persistentShortcut,
               persistentShortcut.matches(keyCode: keyCode, flags: flags) {
                mode = .sessionSticky
                suppressKeyUp(keyCode)
                return EventTapDecision(disposition: .consume, input: .openPersistent)
            }
            return .pass
        case .sessionHeld, .sessionSticky:
            let sticky = mode == .sessionSticky
            if let persistentShortcut,
               persistentShortcut.matches(keyCode: keyCode, flags: flags) {
                if type == .keyDown { suppressKeyUp(keyCode) }
                return .consume
            }
            guard let input = sessionEvent(
                for: keyCode, flags: flags, sticky: sticky) else { return .pass }
            if type == .keyDown {
                suppressKeyUp(keyCode)
                return EventTapDecision(disposition: .consume, input: input)
            }
            return type == .keyUp ? .consume : .pass
        }
    }

    private func isSwitcherTrigger(keyCode: Int64, flags: CGEventFlags) -> Bool {
        keyCode == KeyCode.tab
            && flags.contains(holdModifier)
            && flags.isDisjoint(with: otherModifiers(than: holdModifier))
    }

    private func sessionEvent(for keyCode: Int64,
                              flags: CGEventFlags,
                              sticky: Bool) -> SwitcherInputEvent? {
        switch keyCode {
        case KeyCode.tab:
            return .step(backward: flags.contains(.maskShift))
        case KeyCode.escape:
            return .escape
        case KeyCode.returnKey, KeyCode.keypadEnter:
            return .returnKey
        case KeyCode.space where sticky:
            return .spaceKey
        case KeyCode.upArrow:
            return .arrow(.up)
        case KeyCode.downArrow:
            return .arrow(.down)
        case KeyCode.leftArrow:
            return .arrow(.left)
        case KeyCode.rightArrow:
            return .arrow(.right)
        case KeyCode.delete, KeyCode.forwardDelete:
            return .deleteKey
        case KeyCode.comma where flags.contains(.maskCommand):
            return .openSettings
        default:
            return nil
        }
    }

    private func otherModifiers(than holdModifier: CGEventFlags) -> CGEventFlags {
        var others: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl]
        others.remove(holdModifier)
        return others
    }
}

/// A consuming CGEvent tap. AltTab disables the native Cmd-Tab symbolic hotkey with
/// the private CGSSetSymbolicHotKeyEnabled and restores it on quit; WindowHop instead
/// consumes the chord in the tap. That is inherently fail-safe: if WindowHop is
/// disabled, quits, crashes, loses permission, or the tap is silenced by Secure Input,
/// events flow again and the native macOS switcher is untouched.
public final class EventTap {
    public static let shared = EventTap()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let lock = NSLock()
    private var interception = EventTapInterceptionState()

    /// Called on the main queue with each semantic event.
    public var onEvent: ((SwitcherInputEvent) -> Void)?

    public var mode: TapMode {
        get { lock.lock(); defer { lock.unlock() }; return interception.mode }
        set { lock.lock(); interception.mode = newValue; lock.unlock() }
    }

    public var holdModifier: CGEventFlags {
        get { lock.lock(); defer { lock.unlock() }; return interception.holdModifier }
        set { lock.lock(); interception.holdModifier = newValue; lock.unlock() }
    }

    /// The optional "Open WindowHop" chord; nil when unassigned.
    public var persistentShortcut: PersistentShortcut? {
        get { lock.lock(); defer { lock.unlock() }; return interception.persistentShortcut }
        set { lock.lock(); interception.persistentShortcut = newValue; lock.unlock() }
    }

    /// Creates the tap on the dedicated tap thread. Returns false when tap creation
    /// fails (no Accessibility permission).
    @discardableResult
    public func start() -> Bool {
        if let eventTap {
            if CFMachPortIsValid(eventTap) {
                if !CGEvent.tapIsEnabled(tap: eventTap) {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
                if CGEvent.tapIsEnabled(tap: eventTap) { return true }
            }
            // A valid-looking tap that still refuses to enable is just as dead
            // to the user as an invalid Mach port. Rebuild it in either case.
            tearDownTap(resetInterception: false)
        }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, _ in EventTap.shared.handle(type: type, event: event) },
            userInfo: nil) else { return false }
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(BackgroundWork.eventTapThread.runLoop, source, .commonModes)
        CFRunLoopWakeUp(BackgroundWork.eventTapThread.runLoop)
        if !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    public func stop() {
        tearDownTap(resetInterception: true)
    }

    private func tearDownTap(resetInterception: Bool) {
        if let eventTap {
            if CFMachPortIsValid(eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: false)
            }
            if let runLoopSource {
                CFRunLoopRemoveSource(BackgroundWork.eventTapThread.runLoop, runLoopSource, .commonModes)
            }
            CFMachPortInvalidate(eventTap)
        }
        eventTap = nil
        runLoopSource = nil
        if resetInterception {
            lock.lock()
            interception.reset()
            lock.unlock()
        }
    }

    /// macOS can disable or invalidate taps after sleep/wake, login-session
    /// changes, or long stalls. Re-enable a healthy tap and rebuild an invalid
    /// one while preserving the configured shortcut and current interception mode.
    @discardableResult
    public func reEnableIfNeeded() -> Bool {
        // When WindowHop is disabled there is intentionally no tap at all.
        // Wake/session notifications must not recreate one in that state.
        guard eventTap != nil else { return false }
        if let eventTap, CFMachPortIsValid(eventTap) {
            if !CGEvent.tapIsEnabled(tap: eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            if CGEvent.tapIsEnabled(tap: eventTap) { return true }
        }
        if eventTap != nil {
            tearDownTap(resetInterception: false)
        }
        return start()
    }

    // MARK: - Callback (runs on the tap thread; must stay small and non-blocking)

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            // Keep the callback tiny. If a plain re-enable was insufficient,
            // rebuild from the main side rather than doing lifecycle work here.
            if eventTap.map({ !CGEvent.tapIsEnabled(tap: $0) }) ?? true {
                DispatchQueue.main.async {
                    _ = EventTap.shared.reEnableIfNeeded()
                }
            }
            return Unmanaged.passUnretained(event)
        }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        lock.lock()
        let decision = interception.decide(type: type, keyCode: keyCode, flags: event.flags)
        lock.unlock()
        if let input = decision.input {
            DebugLog.log("tap: consumed \(input)")
            post(input)
        }
        return decision.disposition == .consume
            ? nil
            : Unmanaged.passUnretained(event)
    }

    private func post(_ inputEvent: SwitcherInputEvent) {
        let postedAt = DebugLog.enabled ? CFAbsoluteTimeGetCurrent() : 0
        DispatchQueue.main.async { [weak self] in
            if DebugLog.enabled {
                DebugLog.log("input \(inputEvent) (+\(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - postedAt) * 1000))ms hop)")
            }
            self?.onEvent?(inputEvent)
        }
    }
}

/// Prints diagnostics when WINDOWHOP_DEBUG=1; inert otherwise.
public enum DebugLog {
    public static let enabled = ProcessInfo.processInfo.environment["WINDOWHOP_DEBUG"] == "1"

    public static func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        print("[\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] \(message())")
        fflush(stdout)
    }
}