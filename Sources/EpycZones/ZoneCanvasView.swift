import SwiftUI

/// Interactive canvas for editing zones within a layout.
struct ZoneCanvasView: View {
    @Binding var zones: [Zone]
    @Binding var selectedZoneID: UUID?

    @State private var interaction: Interaction = .idle
    @State private var dragOrigin: CGPoint = .zero
    @State private var originalRect: RelativeRect = .zero

    private let gridDivisions = 12
    private let handleSize: CGFloat = 10

    private let zoneColors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint, .cyan, .red,
    ]

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack(alignment: .topLeading) {
                // Background + grid
                canvas(size: size)

                // Zones
                ForEach(Array(zones.enumerated()), id: \.element.id) { index, zone in
                    zoneView(zone: zone, index: index, size: size)
                }

                // Handles for selected zone
                if let selID = selectedZoneID, let zone = zones.first(where: { $0.id == selID }) {
                    handlesOverlay(for: zone, size: size)
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { location in
                // Tap background to deselect
                if hitTestZone(at: location, canvasSize: size) == nil {
                    selectedZoneID = nil
                }
            }
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    // MARK: - Canvas Background

    private func canvas(size: CGSize) -> some View {
        Canvas { context, drawSize in
            // Grid lines
            let color = Color(nsColor: .separatorColor).opacity(0.3)
            for i in 1..<gridDivisions {
                let fraction = CGFloat(i) / CGFloat(gridDivisions)
                // Vertical
                let vx = fraction * drawSize.width
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: vx, y: 0))
                    p.addLine(to: CGPoint(x: vx, y: drawSize.height))
                }, with: .color(color), lineWidth: 0.5)
                // Horizontal
                let hy = fraction * drawSize.height
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: 0, y: hy))
                    p.addLine(to: CGPoint(x: drawSize.width, y: hy))
                }, with: .color(color), lineWidth: 0.5)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Zone View

    private func zoneView(zone: Zone, index: Int, size: CGSize) -> some View {
        let rect = canvasRect(for: zone.rect, in: size)
        let color = zoneColors[index % zoneColors.count]
        let isSelected = zone.id == selectedZoneID

        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(isSelected ? 0.35 : 0.2))
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.accentColor : color, lineWidth: isSelected ? 2.5 : 1.5)
            Text("\(index + 1)")
                .font(.system(size: min(rect.width, rect.height) * 0.3, weight: .bold, design: .rounded))
                .foregroundStyle(color.opacity(0.7))
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .onTapGesture {
            selectedZoneID = zone.id
        }
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    if case .idle = interaction {
                        guard let idx = zones.firstIndex(where: { $0.id == zone.id }) else { return }
                        selectedZoneID = zone.id
                        interaction = .moving(idx)
                        dragOrigin = value.startLocation
                        originalRect = zones[idx].rect
                    }
                    if case .moving(let idx) = interaction {
                        let dx = (value.location.x - dragOrigin.x) / size.width
                        let dy = (value.location.y - dragOrigin.y) / size.height
                        zones[idx].rect.x = originalRect.x + dx
                        zones[idx].rect.y = originalRect.y + dy
                        zones[idx].rect.snapToGrid(divisions: gridDivisions)
                    }
                }
                .onEnded { _ in
                    interaction = .idle
                }
        )
    }

    // MARK: - Resize Handles

    private func handlesOverlay(for zone: Zone, size: CGSize) -> some View {
        let rect = canvasRect(for: zone.rect, in: size)

        return ForEach(Corner.allCases, id: \.self) { corner in
            let pos = handlePosition(corner: corner, rect: rect)
            Circle()
                .fill(Color.accentColor)
                .frame(width: handleSize, height: handleSize)
                .position(pos)
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            guard let idx = zones.firstIndex(where: { $0.id == zone.id }) else { return }
                            if case .idle = interaction {
                                interaction = .resizing(idx, corner)
                                dragOrigin = value.startLocation
                                originalRect = zones[idx].rect
                            }
                            if case .resizing(let rIdx, let rCorner) = interaction {
                                applyResize(
                                    index: rIdx,
                                    corner: rCorner,
                                    delta: CGSize(
                                        width: (value.location.x - dragOrigin.x) / size.width,
                                        height: (value.location.y - dragOrigin.y) / size.height
                                    )
                                )
                            }
                        }
                        .onEnded { _ in interaction = .idle }
                )
        }
    }

    // MARK: - Resize Logic

    private func applyResize(index: Int, corner: Corner, delta: CGSize) {
        var r = originalRect
        switch corner {
        case .topLeft:
            r.x += delta.width
            r.y += delta.height
            r.width -= delta.width
            r.height -= delta.height
        case .topRight:
            r.y += delta.height
            r.width += delta.width
            r.height -= delta.height
        case .bottomLeft:
            r.x += delta.width
            r.width -= delta.width
            r.height += delta.height
        case .bottomRight:
            r.width += delta.width
            r.height += delta.height
        }
        r.snapToGrid(divisions: gridDivisions)
        zones[index].rect = r
    }

    // MARK: - Helpers

    private func canvasRect(for relative: RelativeRect, in size: CGSize) -> CGRect {
        CGRect(
            x: relative.x * size.width,
            y: relative.y * size.height,
            width: relative.width * size.width,
            height: relative.height * size.height
        )
    }

    private func handlePosition(corner: Corner, rect: CGRect) -> CGPoint {
        switch corner {
        case .topLeft:     return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight:    return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft:  return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    private func hitTestZone(at point: CGPoint, canvasSize: CGSize) -> Int? {
        for (i, zone) in zones.enumerated().reversed() {
            if canvasRect(for: zone.rect, in: canvasSize).contains(point) {
                return i
            }
        }
        return nil
    }

    // MARK: - Types

    enum Interaction: Equatable {
        case idle
        case moving(Int)
        case resizing(Int, Corner)
    }

    enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }
}
