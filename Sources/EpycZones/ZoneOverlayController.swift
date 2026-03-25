import AppKit

/// Manages transparent overlay panels that show zone regions on screen.
final class ZoneOverlayController {
    private var panels: [NSPanel] = []
    private var overlayViews: [ZoneOverlayNSView] = []
    private(set) var highlightedZoneIndex: Int?

    /// Show overlay on all screens using a per-screen layout provider.
    func show(layoutProvider: (NSScreen) -> Layout?) {
        hide()

        for screen in NSScreen.screens {
            guard let layout = layoutProvider(screen) else { continue }

            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let view = ZoneOverlayNSView(
                layout: layout,
                screenFrame: screen.frame,
                visibleFrame: screen.visibleFrame
            )
            panel.contentView = view
            panel.orderFrontRegardless()

            panels.append(panel)
            overlayViews.append(view)
        }
    }

    func updateHighlight(zoneIndex: Int?) {
        guard zoneIndex != highlightedZoneIndex else { return }
        highlightedZoneIndex = zoneIndex
        for view in overlayViews {
            view.highlightedZoneIndex = zoneIndex
            view.needsDisplay = true
        }
    }

    func hide() {
        highlightedZoneIndex = nil
        for panel in panels {
            panel.orderOut(nil)
        }
        panels.removeAll()
        overlayViews.removeAll()
    }
}

// MARK: - Overlay NSView

final class ZoneOverlayNSView: NSView {
    let layout: Layout
    let screenFrame: NSRect
    let visibleFrame: NSRect
    var highlightedZoneIndex: Int?

    private let zoneColors: [NSColor] = [
        .systemBlue, .systemGreen, .systemOrange, .systemPurple,
        .systemPink, .systemTeal, .systemIndigo, .systemMint,
        .systemCyan, .systemRed,
    ]

    init(layout: Layout, screenFrame: NSRect, visibleFrame: NSRect) {
        self.layout = layout
        self.screenFrame = screenFrame
        self.visibleFrame = visibleFrame
        super.init(frame: NSRect(origin: .zero, size: screenFrame.size))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.15).setFill()
        bounds.fill()

        let vfLocal = NSRect(
            x: visibleFrame.origin.x - screenFrame.origin.x,
            y: visibleFrame.origin.y - screenFrame.origin.y,
            width: visibleFrame.width,
            height: visibleFrame.height
        )

        let gap: CGFloat = 4

        for (index, zone) in layout.zones.enumerated() {
            let isHighlighted = index == highlightedZoneIndex
            let color = zoneColors[index % zoneColors.count]

            let rect = NSRect(
                x: vfLocal.origin.x + zone.rect.x * vfLocal.width + gap,
                y: vfLocal.origin.y + (1.0 - zone.rect.y - zone.rect.height) * vfLocal.height + gap,
                width: zone.rect.width * vfLocal.width - gap * 2,
                height: zone.rect.height * vfLocal.height - gap * 2
            )

            let fillColor = isHighlighted
                ? color.withAlphaComponent(0.35)
                : NSColor.white.withAlphaComponent(0.08)
            fillColor.setFill()
            let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
            path.fill()

            let borderColor = isHighlighted
                ? color.withAlphaComponent(0.9)
                : NSColor.white.withAlphaComponent(0.3)
            borderColor.setStroke()
            path.lineWidth = isHighlighted ? 3 : 1.5
            path.stroke()

            let fontSize = max(20, min(rect.width, rect.height) * 0.25)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: isHighlighted
                    ? NSColor.white.withAlphaComponent(0.9)
                    : NSColor.white.withAlphaComponent(0.4),
            ]
            let label = NSAttributedString(string: "\(index + 1)", attributes: attrs)
            let labelSize = label.size()
            label.draw(at: NSPoint(
                x: rect.midX - labelSize.width / 2,
                y: rect.midY - labelSize.height / 2
            ))
        }
    }
}
