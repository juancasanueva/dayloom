import AppKit
import SwiftUI

/// A right-click menu for an empty part of the week grid, built from the click's own position.
/// SwiftUI's `contextMenu` has no click location, and a position remembered from hovering lags
/// behind a quick move, so the menu could offer the wrong half hour. Left clicks pass through.
struct SlotMenuArea: NSViewRepresentable {
    /// The menu item title for a click this many points from the top.
    var title: (CGFloat) -> String
    /// Runs when the item is chosen, with the same distance from the top.
    var action: (CGFloat) -> Void

    func makeNSView(context: Context) -> MenuView {
        MenuView()
    }

    func updateNSView(_ view: MenuView, context: Context) {
        view.title = title
        view.action = action
    }

    final class MenuView: NSView {
        var title: (CGFloat) -> String = { _ in "" }
        var action: (CGFloat) -> Void = { _ in }
        private var clickY: CGFloat = 0

        override var isFlipped: Bool { true }

        /// Only right-clicks and Control-clicks land here; everything else reaches the SwiftUI views.
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent else { return nil }
            let isMenuClick = event.type == .rightMouseDown
                || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
            return isMenuClick ? super.hitTest(point) : nil
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            clickY = convert(event.locationInWindow, from: nil).y
            let menu = NSMenu()
            let item = NSMenuItem(title: title(clickY), action: #selector(choose), keyEquivalent: "")
            item.target = self
            item.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
            menu.addItem(item)
            return menu
        }

        @objc private func choose() {
            action(clickY)
        }
    }
}
