import AppKit
import ApplicationServices

/// Animates window snapping with smooth interpolation.
/// All AX calls are dispatched to the main thread (required by macOS Tahoe).
enum WindowAnimator {
    private static let steps = 8
    private static let totalDuration: TimeInterval = 0.15

    /// Smoothly animate a window from its current position/size to a target frame.
    /// `targetNS` is in NSScreen coordinates (bottom-left origin).
    /// Can be called from any thread.
    static func animate(window: AXUIElement, to targetNS: CGRect) {
        let primaryHeight = NSScreen.screens[0].frame.height

        // Get current window frame in AX coords
        guard let currentPos = WindowManager.getPosition(of: window),
              let currentSize = WindowManager.getSize(of: window) else {
            // Fallback: instant snap on main thread
            DispatchQueue.main.async {
                applyAX(window: window, targetNS: targetNS, primaryHeight: primaryHeight)
            }
            return
        }

        // Target in AX coords
        let targetAX = CGPoint(x: targetNS.origin.x, y: primaryHeight - targetNS.origin.y - targetNS.height)
        let targetSize = targetNS.size

        let stepInterval = totalDuration / Double(steps)

        // Schedule each animation step on the main thread
        for i in 1...steps {
            let delay = stepInterval * Double(i - 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let t = easeOutCubic(Double(i) / Double(steps))

                let x = currentPos.x + (targetAX.x - currentPos.x) * t
                let y = currentPos.y + (targetAX.y - currentPos.y) * t
                let w = currentSize.width + (targetSize.width - currentSize.width) * t
                let h = currentSize.height + (targetSize.height - currentSize.height) * t

                let size = CGSize(width: w, height: h)
                let pos = CGPoint(x: x, y: y)

                // Rectangle's approach: SIZE → POSITION → SIZE
                setAX(window, size: size)
                setAX(window, position: pos)
                setAX(window, size: size)
            }
        }
    }

    private static func applyAX(window: AXUIElement, targetNS: CGRect, primaryHeight: CGFloat) {
        let size = CGSize(width: targetNS.width, height: targetNS.height)
        let pos = CGPoint(x: targetNS.origin.x, y: primaryHeight - targetNS.origin.y - targetNS.height)
        setAX(window, size: size)
        setAX(window, position: pos)
        setAX(window, size: size)
    }

    private static func setAX(_ window: AXUIElement, position: CGPoint) {
        var p = position
        if let val = AXValueCreate(.cgPoint, &p) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, val)
        }
    }

    private static func setAX(_ window: AXUIElement, size: CGSize) {
        var s = size
        if let val = AXValueCreate(.cgSize, &s) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, val)
        }
    }

    /// Ease-out cubic: fast start, smooth deceleration.
    private static func easeOutCubic(_ t: Double) -> Double {
        1 - pow(1 - t, 3)
    }
}
