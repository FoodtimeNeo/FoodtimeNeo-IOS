import SwiftUI

struct FormInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Zine.smallRadius)
                    .fill(Zine.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Zine.smallRadius)
                    .stroke(Zine.border, lineWidth: 1)
            )
    }
}
