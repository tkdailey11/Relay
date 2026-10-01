import SwiftUI

extension Array where Element: Identifiable {
    /// Moves the element with `id` so it ends up at `destination`, clamped to the array.
    mutating func move(_ id: Element.ID, to destination: Int) {
        guard let source = firstIndex(where: { $0.id == id }) else { return }
        let target = Swift.min(Swift.max(destination, 0), count - 1)
        guard source != target else { return }
        insert(remove(at: source), at: target)
    }

    /// Whether a step left (negative) or right (positive) stays inside the array.
    func canMove(_ id: Element.ID, by offset: Int) -> Bool {
        guard offset != 0, let index = firstIndex(where: { $0.id == id }) else { return false }
        return indices.contains(index + offset)
    }
}

/// Drag-to-reorder for a horizontal row, such as the session cards or the focus tabs.
///
/// This is a gesture inside the row rather than system drag and drop. A system drag has to put
/// something on the pasteboard, and the terminal accepts dropped text and files, so a card let
/// go over it would type its payload into the shell. Staying in the row also lets neighbours
/// slide aside while the dragged item follows the pointer, as Safari's tabs do.
@Observable
final class HorizontalReorder {
    let coordinateSpace: String
    let spacing: CGFloat
    fileprivate(set) var draggingID: UUID?
    /// Where each item is laid out, in the row's coordinate space.
    fileprivate var frames: [UUID: CGRect] = [:]
    fileprivate var startMinX: CGFloat = 0
    fileprivate var translation: CGFloat = 0
    /// How far the dragged item's slot has moved since the drag began. Tracked as moves happen
    /// instead of measured, so the item never jumps for a frame while the row re-lays out.
    fileprivate var slotShift: CGFloat = 0

    init(coordinateSpace: String, spacing: CGFloat) {
        self.coordinateSpace = coordinateSpace
        self.spacing = spacing
    }

    fileprivate var dragOffset: CGFloat { translation - slotShift }
}

extension View {
    /// Makes one item of a row draggable within it. `order` is the row's current ids, and
    /// `move` is asked to put an id at a new index whenever the pointer passes a neighbour.
    func horizontallyReorderable(_ id: UUID, order: [UUID], using reorder: HorizontalReorder,
                                 move: @escaping (UUID, Int) -> Void) -> some View {
        modifier(HorizontalReorderItem(id: id, order: order, reorder: reorder, move: move))
    }
}

private struct HorizontalReorderItem: ViewModifier {
    let id: UUID
    let order: [UUID]
    let reorder: HorizontalReorder
    let move: (UUID, Int) -> Void

    func body(content: Content) -> some View {
        let isDragging = reorder.draggingID == id
        content
            // Measured before the offset, so this is the slot rather than where it is drawn.
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .named(reorder.coordinateSpace))
            } action: {
                reorder.frames[id] = $0
            }
            .offset(x: isDragging ? reorder.dragOffset : 0)
            .zIndex(isDragging ? 1 : 0)
            .shadow(color: .black.opacity(isDragging ? 0.18 : 0), radius: 8, y: 3)
            // The dragged item follows the pointer exactly; only its neighbours animate.
            .transaction { if isDragging { $0.animation = nil } }
            // Simultaneous, so a plain click still reaches the button underneath. The minimum
            // distance keeps a slightly shaky click from starting a drag.
            .simultaneousGesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .named(reorder.coordinateSpace))
                    .onChanged { value in
                        if reorder.draggingID != id {
                            reorder.draggingID = id
                            reorder.startMinX = reorder.frames[id]?.minX ?? 0
                            reorder.slotShift = 0
                        }
                        reorder.translation = value.translation.width
                        swapWithNeighbourIfPassed()
                    }
                    .onEnded { _ in
                        withAnimation(.snappy) {
                            reorder.draggingID = nil
                            reorder.translation = 0
                            reorder.slotShift = 0
                        }
                    }
            )
    }

    /// Moves one slot at a time once the dragged item's centre crosses a neighbour's centre.
    private func swapWithNeighbourIfPassed() {
        guard let width = reorder.frames[id]?.width, let index = order.firstIndex(of: id) else { return }
        let center = reorder.startMinX + reorder.translation + width / 2
        if index + 1 < order.count, let next = reorder.frames[order[index + 1]], center > next.midX {
            reorder.slotShift += next.width + reorder.spacing
            withAnimation(.snappy) { move(id, index + 1) }
        } else if index > 0, let previous = reorder.frames[order[index - 1]], center < previous.midX {
            reorder.slotShift -= previous.width + reorder.spacing
            withAnimation(.snappy) { move(id, index - 1) }
        }
    }
}
