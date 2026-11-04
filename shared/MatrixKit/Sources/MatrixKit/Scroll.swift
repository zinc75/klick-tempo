// SPDX-License-Identifier: MIT

import SwiftUI
import AppKit

extension View {
    /// A hairline on the left of a column of the matrix.
    public func columnRule() -> some View {
        overlay(alignment: .leading) { Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 0.5) }
    }
}


/// Where the dots of the matrix are scrolled to. Only `ScrollFollower` reads it.
@MainActor @Observable
public final class MatrixScroll {
    public private(set) var x: CGFloat = 0
    public private(set) var y: CGFloat = 0

    public init() {}

    public func move(to point: CGPoint) {
        if abs(point.x - x) > 0.01 { x = point.x }
        if abs(point.y - y) > 0.01 { y = point.y }
    }
}

/// Shifts its content with the scroll of the dots, along one axis: the frozen panes of a spreadsheet.
public struct ScrollFollower<Content: View>: View {
    let scroll: MatrixScroll
    let axis: Axis
    let content: Content

    public init(scroll: MatrixScroll, axis: Axis, @ViewBuilder content: () -> Content) {
        self.scroll = scroll
        self.axis = axis
        self.content = content()
    }

    public var body: some View {
        content.offset(x: axis == .horizontal ? -scroll.x : 0, y: axis == .vertical ? -scroll.y : 0)
    }
}

/// Widths of texts in the title font, measured once.
@MainActor
public enum TextWidth {
    private static var cache: [String: CGFloat] = [:]

    private static var titleCache: [String: CGFloat] = [:]

    /// The width of a client name in the matrix: the subheadline style, semibold.
    public static func title(_ text: String) -> CGFloat {
        if let hit = titleCache[text] { return hit }
        let font = NSFont.systemFont(ofSize: NSFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: .semibold)
        let width = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        titleCache[text] = width
        return width
    }

    public static func headline(_ text: String) -> CGFloat {
        if let hit = cache[text] { return hit }
        let font = NSFont.preferredFont(forTextStyle: .headline)
        let width = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        cache[text] = width
        return width
    }
}

/// Lets the frozen panes (the names on the left, the heads on top) scroll the matrix: it finds the scroll view
/// of the dots it sits in, and hands it the wheel events that happen over the panes.
public struct WheelBridge: NSViewRepresentable {
    let namesWidth: CGFloat
    let headsHeight: CGFloat

    public init(namesWidth: CGFloat, headsHeight: CGFloat) {
        self.namesWidth = namesWidth
        self.headsHeight = headsHeight
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.anchor = view
        context.coordinator.start()
        return view
    }

    public func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.namesWidth = namesWidth
        context.coordinator.headsHeight = headsHeight
    }

    public static func dismantleNSView(_ view: NSView, coordinator: Coordinator) { coordinator.stop() }

    @MainActor
    public final class Coordinator {
        weak var anchor: NSView?
        var namesWidth: CGFloat = 0
        var headsHeight: CGFloat = 0
        private var monitor: Any?

        func start() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.forward(event) ?? event
            }
        }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        private func forward(_ event: NSEvent) -> NSEvent? {
            guard let anchor, let scrollView = anchor.enclosingScrollView, event.window === anchor.window else { return event }
            // The scroll view in window coordinates (y points up).
            let frame = scrollView.convert(scrollView.bounds, to: nil)
            let p = event.locationInWindow
            let overNames = p.x >= frame.minX - namesWidth && p.x < frame.minX && p.y >= frame.minY && p.y <= frame.maxY
            let overHeads = p.x >= frame.minX && p.x <= frame.maxX && p.y > frame.maxY && p.y <= frame.maxY + headsHeight
            guard overNames || overHeads else { return event }

            let k: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
            let clip = scrollView.contentView
            guard let document = scrollView.documentView else { return event }
            var origin = clip.bounds.origin
            origin.x -= event.scrollingDeltaX * k
            origin.y -= event.scrollingDeltaY * k * (document.isFlipped ? 1 : -1)
            origin.x = min(max(origin.x, 0), max(document.frame.width - clip.bounds.width, 0))
            origin.y = min(max(origin.y, 0), max(document.frame.height - clip.bounds.height, 0))
            clip.scroll(to: origin)
            scrollView.reflectScrolledClipView(clip)
            return nil
        }
    }
}

/// The point of the matrix under the pointer. Only `HoverReader`s read it, so that moving over the dots does
/// not rebuild the sheet.
@MainActor @Observable
public final class MatrixHover {
    public private(set) var row: String?
    public private(set) var client: String?
    public private(set) var column: Int?

    public init() {}

    public func set(row: String, client: String, column: Int) {
        self.row = row; self.client = client; self.column = column
    }

    /// Leaving a point clears the state only if no other point took it over in the meantime.
    public func clear(row: String, column: Int) {
        if self.row == row && self.column == column { self.row = nil; self.client = nil; self.column = nil }
    }
}

/// A view that reads the hover state, and is the only one to be rebuilt when it changes.
public struct HoverReader<Content: View>: View {
    let hover: MatrixHover
    @ViewBuilder let content: (MatrixHover) -> Content

    public init(_ hover: MatrixHover, @ViewBuilder content: @escaping (MatrixHover) -> Content) {
        self.hover = hover
        self.content = content
    }

    public var body: some View { content(hover) }
}

