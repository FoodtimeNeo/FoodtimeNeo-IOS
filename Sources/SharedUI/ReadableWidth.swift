import SwiftUI

/// Keeps hand-journal pages readable on iPad without changing navigation.
/// iPhone widths are untouched; regular width is centered and capped.
private struct ReadableWidth: ViewModifier {
    var maxWidth: CGFloat
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: horizontalSizeClass == .regular ? maxWidth : .infinity)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func readableWidth(_ maxWidth: CGFloat = 820) -> some View {
        modifier(ReadableWidth(maxWidth: maxWidth))
    }
}
