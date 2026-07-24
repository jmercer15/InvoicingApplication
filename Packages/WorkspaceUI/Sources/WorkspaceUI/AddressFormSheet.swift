import SwiftUI
import SharedUI

/// Sheet wrapper around ``AddressEditingSheet`` backed by ``SharedUI.AddressFormState``.
public struct AddressFormSheet: View {
    @Bindable public var state: AddressFormState
    @Binding public var isPresented: Bool
    /// When non-`nil`, overrides ``AddressFormState/hasAddressData`` (e.g. existing persisted address).
    public var hasAddressDataOverride: Bool?
    public let onSearchAddressSelected: ((AddressData) -> Void)?
    public let onCommit: () -> Void
    public let onCancel: (() -> Void)?

    public init(
        state: AddressFormState,
        isPresented: Binding<Bool>,
        hasAddressDataOverride: Bool? = nil,
        onSearchAddressSelected: ((AddressData) -> Void)? = nil,
        onCommit: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.state = state
        self._isPresented = isPresented
        self.hasAddressDataOverride = hasAddressDataOverride
        self.onSearchAddressSelected = onSearchAddressSelected
        self.onCommit = onCommit
        self.onCancel = onCancel
    }

    public var body: some View {
        AddressEditingSheet(
            isPresented: $isPresented,
            unitNumber: $state.unitNumber,
            streetNumber: $state.streetNumber,
            streetName: $state.streetName,
            suburb: $state.suburb,
            postcode: $state.postcode,
            state: $state.state,
            country: $state.country,
            poBox: $state.poBox,
            addressSearchText: $state.addressSearchText,
            selectedAddress: $state.selectedAddress,
            hasAddressData: hasAddressDataOverride ?? state.hasAddressData,
            onSearchAddressSelected: onSearchAddressSelected,
            onCommit: onCommit,
            onClear: { state.clear() },
            onCancel: onCancel
        )
    }
}
