import SwiftUI
import AppKit
import SharedUI

public struct AddressEditingSheet: View {
    @Binding public var isPresented: Bool

    // Address Field Bindings
    @Binding public var unitNumber: String
    @Binding public var streetNumber: String
    @Binding public var streetName: String
    @Binding public var suburb: String
    @Binding public var postcode: String
    @Binding public var state: String
    @Binding public var country: String
    @Binding public var poBox: String

    // Search Tracking
    @Binding public var addressSearchText: String
    @Binding public var selectedAddress: AddressData?

    public let hasAddressData: Bool
    /// Called when the user picks a search result (after fields are filled); use to sync properties not bound in the form (e.g. separate `city`). Does not run on Done.
    public let onSearchAddressSelected: ((AddressData) -> Void)?
    public let onCommit: () -> Void
    public let onClear: () -> Void
    /// Called when user taps Cancel before the sheet dismisses (e.g. revert draft edits).
    public let onCancel: (() -> Void)?

    @State private var isManualMode = false

    public init(
        isPresented: Binding<Bool>,
        unitNumber: Binding<String>,
        streetNumber: Binding<String>,
        streetName: Binding<String>,
        suburb: Binding<String>,
        postcode: Binding<String>,
        state: Binding<String>,
        country: Binding<String>,
        poBox: Binding<String>,
        addressSearchText: Binding<String>,
        selectedAddress: Binding<AddressData?>,
        hasAddressData: Bool,
        onSearchAddressSelected: ((AddressData) -> Void)? = nil,
        onCommit: @escaping () -> Void,
        onClear: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._unitNumber = unitNumber
        self._streetNumber = streetNumber
        self._streetName = streetName
        self._suburb = suburb
        self._postcode = postcode
        self._state = state
        self._country = country
        self._poBox = poBox
        self._addressSearchText = addressSearchText
        self._selectedAddress = selectedAddress
        self.hasAddressData = hasAddressData
        self.onSearchAddressSelected = onSearchAddressSelected
        self.onCommit = onCommit
        self.onClear = onClear
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Address")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("Text", bundle: .sharedUI))

                Text("Find a match, review the fields below, then tap Done — or enter details manually.")
                    .font(.subheadline)
                    .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Content
            ScrollView {
                VStack(spacing: 16) {
                    if !isManualMode {
                        VStack(spacing: 12) {
                            NativeAddressSearchField(
                                searchText: $addressSearchText,
                                selectedAddress: $selectedAddress,
                                unitNumber: $unitNumber,
                                streetNumber: $streetNumber,
                                streetName: $streetName,
                                suburb: $suburb,
                                postcode: $postcode,
                                state: $state,
                                country: $country,
                                poBox: $poBox
                            )
                            .onChange(of: selectedAddress) { _, newValue in
                                guard let address = newValue else { return }
                                onSearchAddressSelected?(address)
                                isManualMode = true
                                selectedAddress = nil
                            }

                            Text("Pick a result to fill the form. You can edit fields before tapping Done.")
                                .font(.caption)
                                .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack {
                                Spacer()
                                Button("Skip search — enter manually") {
                                    isManualMode = true
                                }
                                .buttonStyle(.glass)
                                .controlSize(.small)
                            }
                        }
                    }

                    if isManualMode {
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Address details")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(Color("Text", bundle: .sharedUI))

                                    Spacer()

                                    Button("Search again") {
                                        isManualMode = false
                                    }
                                    .buttonStyle(.glass)
                                    .controlSize(.small)
                                }

                                Text("Edit any field, then tap Done.")
                                    .font(.caption)
                                    .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                            }
                            .padding(.bottom, 4)

                            manualAddressFields
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()

            // Footer
            HStack {
                Button("Cancel") {
                    onCancel?()
                    isPresented = false
                }
                .buttonStyle(.glass)

                Spacer()

                if hasAddressData {
                    Button("Done") {
                        onCommit()
                        isPresented = false
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .glassEffect(.regular, in: .rect())
        .frame(minWidth: 500, minHeight: 400)
        .onChange(of: isPresented) { _, isOpen in
            if isOpen { isManualMode = false }
        }
    }

    private var manualAddressFields: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()

                Button("Clear") {
                    onClear()
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .foregroundStyle(Color(nsColor: NSColor.systemRed))
            }
            .padding(.bottom, 4)

            // Unit Number
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Unit:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundStyle(Color(nsColor: NSColor.labelColor))

                TextField("Unit number (optional)", text: $unitNumber)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color(nsColor: NSColor.labelColor))
                    .tint(Color(nsColor: NSColor.systemBlue))
            }

            // Street Number and Name
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Street:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundStyle(Color(nsColor: NSColor.labelColor))

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("Number", text: $streetNumber)
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(Color(nsColor: NSColor.labelColor))
                        .tint(Color(nsColor: NSColor.systemBlue))
                        .frame(width: 80)

                    TextField("Street name", text: $streetName)
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(Color(nsColor: NSColor.labelColor))
                        .tint(Color(nsColor: NSColor.systemBlue))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Suburb
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Suburb:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundStyle(Color(nsColor: NSColor.labelColor))

                TextField("Enter suburb", text: $suburb)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color(nsColor: NSColor.labelColor))
                    .tint(Color(nsColor: NSColor.systemBlue))
            }

            // State and Postcode
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("State:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundStyle(Color(nsColor: NSColor.labelColor))

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    TextField("State", text: $state)
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(Color(nsColor: NSColor.labelColor))
                        .tint(Color(nsColor: NSColor.systemBlue))

                    TextField("Postcode", text: $postcode)
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(Color(nsColor: NSColor.labelColor))
                        .tint(Color(nsColor: NSColor.systemBlue))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Country
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Country:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundStyle(Color(nsColor: NSColor.labelColor))

                TextField("Enter country", text: $country)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color(nsColor: NSColor.labelColor))
                    .tint(Color(nsColor: NSColor.systemBlue))
            }

            // PO Box
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("PO Box:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundStyle(Color(nsColor: NSColor.labelColor))

                TextField("PO Box number (optional)", text: $poBox)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color(nsColor: NSColor.labelColor))
                    .tint(Color(nsColor: NSColor.systemBlue))
            }
        }
    }
}
