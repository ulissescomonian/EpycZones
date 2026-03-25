import Cocoa
import ApplicationServices

/// Detects window dragging + Shift key to show zone overlays.
///
/// Uses NSEvent global + local monitors.
/// Global monitors track events to other apps; local monitors track events to our app
/// (needed when overlay panels are showing and our app receives focus).
final class DragDetector {
    private let overlay = ZoneOverlayController()

    private var globalMouseDownMonitor: Any?
    private var globalMouseDragMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var localMouseDragMonitor: Any?
    private var localMouseUpMonitor: Any?
    private var localFlagsMonitor: Any?

    private var isMouseDown = false
    private var isDragging = false
    private var isOverlayVisible = false
    private var dragStartPos: NSPoint = .zero

    /// The window being dragged — captured before overlay appears so we don't lose the reference.
    private var draggedWindow: AXUIElement?

    /// Timer for edge snap delay.
    private var edgeSnapTimer: Timer?
    private var isWaitingForEdgeSnap = false

    private let dragThreshold: CGFloat = 5.0

    // MARK: - Lifecycle

    func start() {
        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.onMouseDown()
        }
        globalMouseDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
            self?.onMouseDragged()
        }
        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.onMouseUp()
        }
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.onFlagsChanged(flags: event.modifierFlags)
        }

        localMouseDragMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.onMouseDragged()
            return event
        }
        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.onMouseUp()
            return event
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.onFlagsChanged(flags: event.modifierFlags)
            return event
        }
    }

    func stop() {
        for m in [globalMouseDownMonitor, globalMouseDragMonitor, globalMouseUpMonitor,
                   globalFlagsMonitor, localMouseDragMonitor, localMouseUpMonitor, localFlagsMonitor] {
            if let m = m { NSEvent.removeMonitor(m) }
        }
    }

    // MARK: - Event Handlers

    private func onMouseDown() {
        isMouseDown = true
        isDragging = false
        draggedWindow = nil
        dragStartPos = NSEvent.mouseLocation
    }

    private func onMouseDragged() {
        let currentPos = NSEvent.mouseLocation

        if isMouseDown && !isDragging {
            let distance = hypot(currentPos.x - dragStartPos.x, currentPos.y - dragStartPos.y)
            if distance > dragThreshold {
                isDragging = true
                draggedWindow = getFocusedWindow()
            }
        }

        guard isDragging else { return }

        let shiftHeld = NSEvent.modifierFlags.contains(.shift)
        let nearEdge = AppSettings.shared.edgeSnapEnabled && isNearScreenEdge(currentPos)

        if shiftHeld && !isOverlayVisible {
            // Shift: show immediately
            cancelEdgeSnapTimer()
            showOverlay()
        } else if nearEdge && !isOverlayVisible && !shiftHeld {
            // Edge: show after delay
            if !isWaitingForEdgeSnap {
                startEdgeSnapTimer()
            }
        } else if !shiftHeld && !nearEdge && isOverlayVisible {
            cancelEdgeSnapTimer()
            hideOverlay(snap: false)
        } else if !nearEdge && isWaitingForEdgeSnap {
            cancelEdgeSnapTimer()
        }

        if isOverlayVisible {
            updateHighlight(at: currentPos)
        }
    }

    private func onMouseUp() {
        if isOverlayVisible {
            // Re-evaluate zones at the final mouse position
            updateHighlight(at: NSEvent.mouseLocation)

            // Capture state before hiding overlay
            let zoneIndices = overlay.highlightedZoneIndices
            let screen = overlay.highlightedScreen

            // Hide overlay immediately (visual feedback)
            isOverlayVisible = false
            overlay.hide()

            // After a drag, the window is at the cursor's drop position.
            // Move it to the top-left of the screen first so SIZE → POSITION → SIZE
            // doesn't get clamped by macOS (bottom zones would extend off-screen).
            if let w = WindowManager.getFocusedWindow() {
                let vf = screen?.visibleFrame ?? .zero
                let primaryHeight = NSScreen.screens[0].frame.height
                let safeY = primaryHeight - vf.origin.y - vf.height  // top of visible area in AX coords
                WindowManager.setPositionPublic(of: w, to: CGPoint(x: vf.origin.x, y: safeY))
            }

            if let screen = screen, !zoneIndices.isEmpty,
               let layout = LayoutStore.shared.activeLayout(for: screen) {
                let validIndices = zoneIndices.filter { $0 < layout.zones.count }
                if validIndices.count == 1, let index = validIndices.first {
                    WindowManager.snapToActiveZone(index: index, on: screen, animated: false)
                } else if !validIndices.isEmpty {
                    let zones = validIndices.map { layout.zones[$0] }
                    self.snapWindow(nil, toZones: zones, on: screen)
                }
            }
        }
        isMouseDown = false
        isDragging = false
        draggedWindow = nil
    }

    private func onFlagsChanged(flags: NSEvent.ModifierFlags) {
        let shiftHeld = flags.contains(.shift)

        if shiftHeld && isDragging && !isOverlayVisible {
            showOverlay()
            updateHighlight(at: NSEvent.mouseLocation)
        } else if !shiftHeld && isOverlayVisible {
            hideOverlay(snap: false)
        }
    }

    // MARK: - Overlay

    private func showOverlay() {
        guard !isOverlayVisible else { return }
        // Check that at least one screen has a layout with zones
        let store = LayoutStore.shared
        guard NSScreen.screens.contains(where: { screen in
            let l = store.activeLayout(for: screen)
            return l != nil && !l!.zones.isEmpty
        }) else { return }
        isOverlayVisible = true
        overlay.show { screen in store.activeLayout(for: screen) }
    }

    private func updateHighlight(at nsPoint: NSPoint) {
        let (indices, screen) = zoneIndices(at: nsPoint)
        overlay.updateHighlight(zoneIndices: indices, on: screen)
    }

    private func hideOverlay(snap: Bool) {
        let zoneIndices = overlay.highlightedZoneIndices
        let screen = overlay.highlightedScreen
        isOverlayVisible = false
        overlay.hide()

        if snap, !zoneIndices.isEmpty, let window = draggedWindow,
           let screen = screen,
           let layout = LayoutStore.shared.activeLayout(for: screen) {
            let validIndices = zoneIndices.filter { $0 < layout.zones.count }
            guard !validIndices.isEmpty else { return }
            let zones = validIndices.map { layout.zones[$0] }
            snapWindow(window, toZones: zones, on: screen)
            if let first = validIndices.sorted().first {
                WindowPersistence.record(window: window, zoneIndex: first, screen: screen, layoutID: layout.id)
            }
        }
    }

    // MARK: - Window Snapping

    /// Snap window to combined bounding rect of one or more zones (spanning).
    private func snapWindow(_ window: AXUIElement?, toZones zones: [Zone], on screen: NSScreen) {
        guard let w = window ?? WindowManager.getFocusedWindow() else { return }
        let gap = AppSettings.shared.zoneGap
        let combined = combinedRect(of: zones)
        let targetNS = combined.frame(in: screen.visibleFrame, gap: gap)
        WindowManager.saveFrame(of: w)
        WindowManager.applyFrame(targetNS, to: w, animated: false)
    }

    /// Compute bounding RelativeRect that encompasses all given zones.
    private func combinedRect(of zones: [Zone]) -> RelativeRect {
        guard let first = zones.first else { return .zero }
        var minX = first.rect.x
        var minY = first.rect.y
        var maxX = first.rect.x + first.rect.width
        var maxY = first.rect.y + first.rect.height
        for zone in zones.dropFirst() {
            minX = min(minX, zone.rect.x)
            minY = min(minY, zone.rect.y)
            maxX = max(maxX, zone.rect.x + zone.rect.width)
            maxY = max(maxY, zone.rect.y + zone.rect.height)
        }
        return RelativeRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: - AX Helpers

    private func getFocusedWindow() -> AXUIElement? {
        return WindowManager.getFocusedWindow()
    }

    // MARK: - Edge Snap Timer

    private func startEdgeSnapTimer() {
        isWaitingForEdgeSnap = true
        edgeSnapTimer = Timer.scheduledTimer(withTimeInterval: AppSettings.shared.edgeSnapDelay, repeats: false) { [weak self] _ in
            guard let self = self, self.isWaitingForEdgeSnap, self.isDragging else { return }
            self.isWaitingForEdgeSnap = false
            self.showOverlay()
            self.updateHighlight(at: NSEvent.mouseLocation)
        }
    }

    private func cancelEdgeSnapTimer() {
        edgeSnapTimer?.invalidate()
        edgeSnapTimer = nil
        isWaitingForEdgeSnap = false
    }

    // MARK: - Edge Detection

    private func isNearScreenEdge(_ point: NSPoint) -> Bool {
        let threshold = AppSettings.shared.edgeSnapThreshold
        for screen in NSScreen.screens {
            let f = screen.frame
            if point.x <= f.minX + threshold || point.x >= f.maxX - threshold ||
               point.y <= f.minY + threshold || point.y >= f.maxY - threshold {
                if f.insetBy(dx: -threshold, dy: -threshold).contains(point) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Zone Hit-Testing

    /// Returns the set of zone indices the cursor is over (may be >1 near boundaries)
    /// and the screen the cursor is on.
    private func zoneIndices(at nsPoint: NSPoint) -> (Set<Int>, NSScreen?) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(nsPoint) }),
              let layout = LayoutStore.shared.activeLayout(for: screen) else { return ([], nil) }

        let vf = screen.visibleFrame
        let relX = (nsPoint.x - vf.origin.x) / vf.width
        let relY = 1.0 - (nsPoint.y - vf.origin.y) / vf.height

        // Zone boundary threshold in relative coords (~20px)
        let threshold = 20.0 / max(vf.width, vf.height)

        // First, find exact zone hit
        var exactHit: Int?
        for (index, zone) in layout.zones.enumerated() {
            let r = zone.rect
            if relX >= r.x && relX < r.x + r.width && relY >= r.y && relY < r.y + r.height {
                exactHit = index
                break
            }
        }

        guard let primary = exactHit else { return ([], screen) }

        // Find all adjacent zones that share a border with the primary zone near the cursor.
        // This allows selecting 2 zones (edge), 3 zones (T-junction), or all 4 (center of grid).
        var result: Set<Int> = [primary]
        let pz = layout.zones[primary].rect

        // Is cursor near each edge of the primary zone?
        let nearRight  = abs(relX - (pz.x + pz.width))  < threshold
        let nearLeft   = abs(relX - pz.x)               < threshold
        let nearBottom = abs(relY - (pz.y + pz.height)) < threshold
        let nearTop    = abs(relY - pz.y)               < threshold

        guard nearRight || nearLeft || nearBottom || nearTop else {
            return (result, screen)
        }

        for (index, zone) in layout.zones.enumerated() where index != primary {
            let r = zone.rect

            // Check vertical shared edge (left/right) — zones must overlap on Y axis
            let yOverlap = max(0, min(pz.y + pz.height, r.y + r.height) - max(pz.y, r.y))
            // Check horizontal shared edge (top/bottom) — zones must overlap on X axis
            let xOverlap = max(0, min(pz.x + pz.width, r.x + r.width) - max(pz.x, r.x))

            let isAdjacent =
                // Right edge: cursor near right of primary & zone starts there
                (nearRight  && yOverlap > 0.01 && abs(r.x - (pz.x + pz.width)) < threshold) ||
                // Left edge: cursor near left of primary & zone ends there
                (nearLeft   && yOverlap > 0.01 && abs((r.x + r.width) - pz.x) < threshold) ||
                // Bottom edge: cursor near bottom of primary & zone starts there
                (nearBottom && xOverlap > 0.01 && abs(r.y - (pz.y + pz.height)) < threshold) ||
                // Top edge: cursor near top of primary & zone ends there
                (nearTop    && xOverlap > 0.01 && abs((r.y + r.height) - pz.y) < threshold)

            if isAdjacent {
                result.insert(index)
            }
        }

        // If we found adjacent zones, also check if THEIR neighbors should be included.
        // E.g., in a 2x2 grid at the center: primary=topLeft finds right+bottom adjacent,
        // but the diagonal (bottomRight) is adjacent to both of those, not directly to primary.
        if result.count > 1 {
            let directAdjacent = result.subtracting([primary])
            for adjIdx in directAdjacent {
                let az = layout.zones[adjIdx].rect
                for (index, zone) in layout.zones.enumerated() where !result.contains(index) {
                    let r = zone.rect
                    // Check if this zone shares a border with the adjacent zone near the cursor
                    let yOvr = max(0, min(az.y + az.height, r.y + r.height) - max(az.y, r.y))
                    let xOvr = max(0, min(az.x + az.width, r.x + r.width) - max(az.x, r.x))

                    let isDiagonal =
                        (nearRight  && yOvr > 0.01 && abs(r.x - (az.x + az.width)) < threshold) ||
                        (nearLeft   && yOvr > 0.01 && abs((r.x + r.width) - az.x) < threshold) ||
                        (nearBottom && xOvr > 0.01 && abs(r.y - (az.y + az.height)) < threshold) ||
                        (nearTop    && xOvr > 0.01 && abs((r.y + r.height) - az.y) < threshold)

                    if isDiagonal {
                        result.insert(index)
                    }
                }
            }
        }

        return (result, screen)
    }
}
