import AppKit
import ApplicationServices

enum WindowManager {

    /// Undo stack per window (key = window hash). Each entry is a frame before a snap.
    private static var undoStacks: [Int: [CGRect]] = [:]
    /// Redo stack per window.
    private static var redoStacks: [Int: [CGRect]] = [:]
    private static let maxUndoDepth = 20

    // MARK: - Public

    static func snap(to position: SnapPosition) {
        guard AccessibilityChecker.isGranted else { return }
        guard let window = getFocusedWindow() else { return }

        let screen = screenForWindow(window) ?? NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame

        // Handle dynamic positions
        switch position {
        case .restore:
            restoreWindow(window, screen: screen)
            return
        case .makeSmaller:
            resizeWindow(window, screen: screen, factor: 0.9)
            return
        case .makeLarger:
            resizeWindow(window, screen: screen, factor: 1.1)
            return
        case .maximizeHeight:
            maximizeHeight(window, screen: screen)
            return
        default:
            break
        }

        // Flow through monitors: if already at this position on the current screen,
        // move to the adjacent monitor in the snap direction.
        if NSScreen.screens.count > 1, let currentFrame = currentNSFrame(of: window) {
            let targetNS = position.frame(in: visibleFrame)
            if framesMatch(currentFrame, targetNS, tolerance: 15) {
                if let nextScreen = adjacentScreen(from: screen, direction: position.flowDirection) {
                    saveFrame(of: window)
                    let arrivalPosition = position.arrivalPosition
                    let arrivalNS = arrivalPosition.frame(in: nextScreen.visibleFrame)
                    applyFrame(arrivalNS, to: window)
                    return
                }
            }
        }

        // Save current frame for restore
        saveFrame(of: window)

        let targetNS = position.frame(in: visibleFrame)
        applyFrame(targetNS, to: window)
    }

    static func snap(to zone: Zone) {
        guard AccessibilityChecker.isGranted else { return }
        guard let window = getFocusedWindow() else { return }

        let screen = screenForWindow(window) ?? NSScreen.main ?? NSScreen.screens[0]
        saveFrame(of: window)
        let gap = AppSettings.shared.zoneGap
        let targetNS = zone.rect.frame(in: screen.visibleFrame, gap: gap)
        applyFrame(targetNS, to: window)
    }

    static func snapToActiveZone(index: Int) {
        guard AccessibilityChecker.isGranted else { return }
        guard let window = getFocusedWindow() else { return }
        let screen = screenForWindow(window) ?? NSScreen.main ?? NSScreen.screens[0]
        snapToActiveZone(index: index, on: screen)
    }

    static func snapToActiveZone(index: Int, on screen: NSScreen, animated: Bool = true) {
        guard AccessibilityChecker.isGranted else { return }
        guard let window = getFocusedWindow() else { return }
        guard let layout = LayoutStore.shared.activeLayout(for: screen),
              index < layout.zones.count else { return }

        saveFrame(of: window)
        let gap = AppSettings.shared.zoneGap
        let zone = layout.zones[index]
        let targetNS = zone.rect.frame(in: screen.visibleFrame, gap: gap)
        applyFrame(targetNS, to: window, animated: animated)
        WindowPersistence.record(window: window, zoneIndex: index, screen: screen, layoutID: layout.id)
    }

    // MARK: - Dynamic Positions

    private static func restoreWindow(_ window: AXUIElement, screen: NSScreen) {
        let key = windowHash(window)
        guard var stack = undoStacks[key], let prev = stack.popLast() else { return }
        undoStacks[key] = stack

        // Save current frame to redo stack before restoring
        if let currentFrame = currentNSFrame(of: window) {
            redoStacks[key, default: []].append(currentFrame)
        }
        applyFrame(prev, to: window)
    }

    /// Redo: re-apply the last undone snap.
    static func redoSnap() {
        guard AccessibilityChecker.isGranted else { return }
        guard let window = getFocusedWindow() else { return }
        let key = windowHash(window)
        guard var stack = redoStacks[key], let next = stack.popLast() else { return }
        redoStacks[key] = stack

        // Save current frame to undo stack
        if let currentFrame = currentNSFrame(of: window) {
            undoStacks[key, default: []].append(currentFrame)
        }
        applyFrame(next, to: window)
    }

    private static func resizeWindow(_ window: AXUIElement, screen: NSScreen, factor: Double) {
        guard let axPos = getPosition(of: window),
              let axSize = getSize(of: window) else { return }

        let primaryHeight = NSScreen.screens[0].frame.height
        let nsX = axPos.x
        let nsY = primaryHeight - axPos.y - axSize.height

        let newW = axSize.width * factor
        let newH = axSize.height * factor
        // Keep centered
        let newX = nsX - (newW - axSize.width) / 2
        let newY = nsY - (newH - axSize.height) / 2

        let targetNS = CGRect(x: newX, y: newY, width: newW, height: newH)
        applyFrame(targetNS, to: window)
    }

    private static func maximizeHeight(_ window: AXUIElement, screen: NSScreen) {
        guard let axPos = getPosition(of: window),
              let axSize = getSize(of: window) else { return }

        saveFrame(of: window)
        let vf = screen.visibleFrame

        // Keep X and width, maximize height to visible frame
        let targetNS = CGRect(
            x: axPos.x,
            y: vf.origin.y,
            width: axSize.width,
            height: vf.height
        )
        applyFrame(targetNS, to: window)
    }

    static func saveFrame(of window: AXUIElement) {
        guard let frame = currentNSFrame(of: window) else { return }
        let key = windowHash(window)
        undoStacks[key, default: []].append(frame)
        if undoStacks[key]!.count > maxUndoDepth {
            undoStacks[key]!.removeFirst()
        }
        // Clear redo stack on new action
        redoStacks[key] = nil
    }

    private static func currentNSFrame(of window: AXUIElement) -> CGRect? {
        guard let axPos = getPosition(of: window),
              let axSize = getSize(of: window) else { return nil }
        let primaryHeight = NSScreen.screens[0].frame.height
        return CGRect(
            x: axPos.x,
            y: primaryHeight - axPos.y - axSize.height,
            width: axSize.width,
            height: axSize.height
        )
    }

    private static func windowHash(_ window: AXUIElement) -> Int {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        // Combine PID with window title for uniqueness
        var title: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
        let titleStr = (title as? String) ?? ""
        var hasher = Hasher()
        hasher.combine(pid)
        hasher.combine(titleStr)
        return hasher.finalize()
    }

    // MARK: - Monitor Flow Helpers

    enum FlowDirection {
        case left, right, up, down, none
    }

    private static func framesMatch(_ a: CGRect, _ b: CGRect, tolerance: CGFloat) -> Bool {
        abs(a.origin.x - b.origin.x) < tolerance &&
        abs(a.origin.y - b.origin.y) < tolerance &&
        abs(a.width - b.width) < tolerance &&
        abs(a.height - b.height) < tolerance
    }

    /// Find the adjacent screen in a spatial direction based on screen arrangement.
    private static func adjacentScreen(from screen: NSScreen, direction: FlowDirection) -> NSScreen? {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return nil }

        let frame = screen.frame

        switch direction {
        case .right:
            // Find screen whose left edge is at or near our right edge
            return screens.filter { $0 != screen }
                .filter { $0.frame.origin.x >= frame.origin.x + frame.width - 50 }
                .min(by: { $0.frame.origin.x < $1.frame.origin.x })
        case .left:
            // Find screen whose right edge is at or near our left edge
            return screens.filter { $0 != screen }
                .filter { $0.frame.origin.x + $0.frame.width <= frame.origin.x + 50 }
                .max(by: { $0.frame.origin.x + $0.frame.width < $1.frame.origin.x + $1.frame.width })
        case .up:
            // NSScreen: higher Y = higher on screen
            return screens.filter { $0 != screen }
                .filter { $0.frame.origin.y >= frame.origin.y + frame.height - 50 }
                .min(by: { $0.frame.origin.y < $1.frame.origin.y })
        case .down:
            return screens.filter { $0 != screen }
                .filter { $0.frame.origin.y + $0.frame.height <= frame.origin.y + 50 }
                .max(by: { $0.frame.origin.y + $0.frame.height < $1.frame.origin.y + $1.frame.height })
        case .none:
            return nil
        }
    }

    // MARK: - Move Between Monitors

    static func moveToNextScreen() { moveToScreen(offset: 1) }
    static func moveToPreviousScreen() { moveToScreen(offset: -1) }

    private static func moveToScreen(offset: Int) {
        guard AccessibilityChecker.isGranted else { return }
        guard let window = getFocusedWindow() else { return }
        let screens = NSScreen.screens
        guard screens.count > 1 else { return }

        let currentScreen = screenForWindow(window) ?? NSScreen.main ?? screens[0]
        guard let currentIndex = screens.firstIndex(where: { $0 == currentScreen }) else { return }

        let nextIndex = (currentIndex + offset + screens.count) % screens.count
        let targetScreen = screens[nextIndex]

        guard let axPos = getPosition(of: window),
              let axSize = getSize(of: window) else { return }

        let primaryHeight = screens[0].frame.height
        let srcVF = currentScreen.visibleFrame
        let dstVF = targetScreen.visibleFrame

        let nsX = axPos.x
        let nsY = primaryHeight - axPos.y - axSize.height

        let relX = (nsX - srcVF.origin.x) / srcVF.width
        let relY = (nsY - srcVF.origin.y) / srcVF.height
        let relW = axSize.width / srcVF.width
        let relH = axSize.height / srcVF.height

        let targetNS = CGRect(
            x: dstVF.origin.x + relX * dstVF.width,
            y: dstVF.origin.y + relY * dstVF.height,
            width: relW * dstVF.width,
            height: relH * dstVF.height
        )
        applyFrame(targetNS, to: window)
    }


    // MARK: - Apply

    static func applyFrame(_ targetNS: CGRect, to window: AXUIElement, animated: Bool = true) {
        let primaryHeight = NSScreen.screens[0].frame.height
        let targetPos = CGPoint(x: targetNS.origin.x, y: primaryHeight - targetNS.origin.y - targetNS.height)

        // Disable AXEnhancedUserInterface (used by Terminal, Xcode, etc.)
        // which blocks programmatic resize when enabled (e.g. for VoiceOver).
        let appElement = getAppElement(for: window)
        let hadEnhancedUI = getEnhancedUI(appElement)
        if hadEnhancedUI {
            setEnhancedUI(appElement, enabled: false)
        }

        if animated && AppSettings.shared.animateSnap {
            WindowAnimator.animate(window: window, to: targetNS)
        } else {
            // Rectangle's approach: SIZE → POSITION → SIZE.
            // macOS enforces sizes that fit the current display position.
            // First SIZE shrinks the window so POSITION doesn't get clamped.
            // Second SIZE corrects any size constraint from the old position.
            setSize(of: window, to: targetNS.size)
            setPosition(of: window, to: targetPos)
            setSize(of: window, to: targetNS.size)
        }

        // Re-enable AXEnhancedUserInterface if it was on
        if hadEnhancedUI {
            setEnhancedUI(appElement, enabled: true)
        }
    }

    // MARK: - Enhanced UI Helpers

    private static let kAXEnhancedUserInterface = "AXEnhancedUserInterface" as CFString

    private static func getAppElement(for window: AXUIElement) -> AXUIElement? {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        guard pid != 0 else { return nil }
        return AXUIElementCreateApplication(pid)
    }

    private static func getEnhancedUI(_ app: AXUIElement?) -> Bool {
        guard let app = app else { return false }
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXEnhancedUserInterface, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    private static func setEnhancedUI(_ app: AXUIElement?, enabled: Bool) {
        guard let app = app else { return }
        AXUIElementSetAttributeValue(app, kAXEnhancedUserInterface, enabled as CFBoolean)
    }

    // MARK: - AX Helpers

    static func getFocusedWindow() -> AXUIElement? {
        // Primary approach: system-wide focused app → focused window
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: AnyObject?
        if AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        ) == .success {
            var focusedWindow: AnyObject?
            if AXUIElementCopyAttributeValue(
                focusedApp as! AXUIElement,
                kAXFocusedWindowAttribute as CFString,
                &focusedWindow
            ) == .success {
                return (focusedWindow as! AXUIElement)
            }
        }

        // Fallback: NSWorkspace frontmost app PID (fixes Electron apps like Termius
        // where the launcher PID differs from the window-owning PID)
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        // Try focused window first
        var focusedWindow: AnyObject?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success {
            return (focusedWindow as! AXUIElement)
        }

        // Last resort: first window in the windows list
        var windows: AnyObject?
        if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windows) == .success,
           let winArray = windows as? [AXUIElement],
           let first = winArray.first {
            return first
        }

        return nil
    }

    static func setPositionPublic(of window: AXUIElement, to point: CGPoint) {
        setPosition(of: window, to: point)
    }

    private static func setPosition(of window: AXUIElement, to point: CGPoint) {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    private static func setSize(of window: AXUIElement, to size: CGSize) {
        var s = size
        guard let value = AXValueCreate(.cgSize, &s) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    }

    static func getPosition(of window: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value) == .success else {
            return nil
        }
        var point = CGPoint.zero
        AXValueGetValue(value as! AXValue, .cgPoint, &point)
        return point
    }

    static func getSize(of window: AXUIElement) -> CGSize? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value) == .success else {
            return nil
        }
        var size = CGSize.zero
        AXValueGetValue(value as! AXValue, .cgSize, &size)
        return size
    }

    static func screenForWindow(_ window: AXUIElement) -> NSScreen? {
        guard let axPos = getPosition(of: window),
              let axSize = getSize(of: window) else { return nil }

        let centerAX = CGPoint(x: axPos.x + axSize.width / 2, y: axPos.y + axSize.height / 2)
        let primaryHeight = NSScreen.screens[0].frame.height
        let centerNS = NSPoint(x: centerAX.x, y: primaryHeight - centerAX.y)

        for screen in NSScreen.screens {
            if screen.frame.contains(centerNS) {
                return screen
            }
        }
        return nil
    }
}
