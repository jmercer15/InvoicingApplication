import SwiftUI
import SharedUI

extension ClientDetailView {
    var hasAddressData: Bool {
        let hasEditableAddress = !viewModel.editableUnitNumber.isEmpty ||
            !viewModel.editableStreetNumber.isEmpty ||
            !viewModel.editableStreetName.isEmpty ||
            !viewModel.editableSuburb.isEmpty ||
            !viewModel.editableState.isEmpty ||
            !viewModel.editablePostcode.isEmpty ||
            !viewModel.editableCountry.isEmpty ||
            !viewModel.editablePoBox.isEmpty

        let hasExistingAddress = viewModel.client.address != nil && !viewModel.client.address!.fullFormattedAddress.isEmpty

        return hasEditableAddress || hasExistingAddress
    }

    var compactAddressView: some View {
        RelationshipDetailAddressRow(
            maxLabelWidth: maxLabelWidth,
            hasAddressData: hasAddressData,
            addressText: formatAddressForDisplay(),
            showingMapSheet: $showingMapSheet,
            showingAddressEditingSheet: $showingAddressEditingSheet
        )
    }

    func formatAddressForDisplay() -> String {
        var parts: [String] = []

        if !viewModel.editablePoBox.isEmpty {
            parts.append("PO Box \(viewModel.editablePoBox)")
        } else {
            if !viewModel.editableUnitNumber.isEmpty { parts.append("Unit \(viewModel.editableUnitNumber)") }
            if !viewModel.editableStreetNumber.isEmpty { parts.append(viewModel.editableStreetNumber) }
            if !viewModel.editableStreetName.isEmpty { parts.append(viewModel.editableStreetName) }
        }

        if !viewModel.editableSuburb.isEmpty { parts.append(viewModel.editableSuburb) }
        if !viewModel.editableState.isEmpty { parts.append(viewModel.editableState) }
        if !viewModel.editablePostcode.isEmpty { parts.append(viewModel.editablePostcode) }
        if !viewModel.editableCountry.isEmpty { parts.append(viewModel.editableCountry) }

        if parts.isEmpty, let address = viewModel.client.address {
            return address.fullFormattedAddress
        }

        return parts.joined(separator: ", ")
    }

    func getCurrentAddressString() -> String {
        if let address = viewModel.client.address, !address.fullFormattedAddress.isEmpty {
            return address.fullFormattedAddress
        }

        return formatAddressForDisplay()
    }
}
