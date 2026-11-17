import AppKit
import SwiftUI

/// Hides the line between the content and the panel this sits in. SwiftUI has no setting for it:
/// AppKit draws it with a divider view inside the enclosing split view, so that view is made fully
/// transparent. The split view still handles dragging, so the panel stays resizable.
struct HiddenSplitDivider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Probe() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // The split view finishes assembling after this view joins the window.
            DispatchQueue.main.async { [weak self] in self?.hideDividers() }
        }

        override func layout() {
            super.layout()
            // AppKit can rebuild its divider views when the panel opens or resizes.
            hideDividers()
        }

        private func hideDividers() {
            var view = superview
            while let current = view {
                if let split = current as? NSSplitView {
                    for divider in split.subviews where String(describing: type(of: divider)) == "NSSplitDividerView" {
                        if divider.alphaValue != 0 { divider.alphaValue = 0 }
                    }
                }
                view = current.superview
            }
        }
    }
}
