import CoreGraphics
import Testing
@testable import agenda

@MainActor
@Suite("Flow layout")
struct FlowLayoutTests {
    @Test func itemsThatFitShareOneLine() {
        let arrangement = FlowLayout.arrange(
            sizes: [CGSize(width: 40, height: 20), CGSize(width: 30, height: 24)],
            maxWidth: 100, spacing: 6, lineSpacing: 8
        )

        #expect(arrangement.origins == [CGPoint(x: 0, y: 0), CGPoint(x: 46, y: 0)])
        #expect(arrangement.size == CGSize(width: 76, height: 24))
    }

    @Test func anItemThatDoesNotFitWrapsBelowTheTallestOfTheLine() {
        let arrangement = FlowLayout.arrange(
            sizes: [CGSize(width: 50, height: 20), CGSize(width: 40, height: 24), CGSize(width: 30, height: 20)],
            maxWidth: 100, spacing: 6, lineSpacing: 8
        )

        #expect(arrangement.origins == [CGPoint(x: 0, y: 0), CGPoint(x: 56, y: 0), CGPoint(x: 0, y: 32)])
        #expect(arrangement.size == CGSize(width: 96, height: 52))
    }

    @Test func anItemWiderThanTheLineSitsAloneOnItsLine() {
        let arrangement = FlowLayout.arrange(
            sizes: [CGSize(width: 20, height: 10), CGSize(width: 150, height: 10), CGSize(width: 20, height: 10)],
            maxWidth: 100, spacing: 4, lineSpacing: 4
        )

        #expect(arrangement.origins == [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 14), CGPoint(x: 0, y: 28)])
        #expect(arrangement.size == CGSize(width: 150, height: 38))
    }

    @Test func noItemsTakeNoSpace() {
        let arrangement = FlowLayout.arrange(sizes: [], maxWidth: 100, spacing: 6, lineSpacing: 8)

        #expect(arrangement.origins.isEmpty)
        #expect(arrangement.size == .zero)
    }
}
