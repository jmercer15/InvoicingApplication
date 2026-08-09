#if DEBUG
import SwiftUI
import SharedUI

#Preview("Address Form Sheet") {
    AddressFormSheet(
        state: AddressFormState(),
        isPresented: .constant(true),
        onCommit: {}
    )
    .frame(width: 420, height: 520)
}
#endif
