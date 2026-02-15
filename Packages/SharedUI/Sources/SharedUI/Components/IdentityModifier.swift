import SwiftUI

struct IdentityModifier: ViewModifier {
    let id: AnyHashable?

    func body(content: Content) -> some View {
        if let id {
            content.id(id)
        } else {
            content
        }
    }
}
