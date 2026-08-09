import SwiftUI

extension InvoiceTemplateRibbon {
  @ViewBuilder
  var templateTab: some View {
    ribbonGroup("Templates") {
      ribbonRow {
        ribbonPicker(
          "Preset",
          selected: viewModel.matchingTemplatePreset,
          values: InvoiceTemplatePreset.allCases,
          label: { preset in Label(preset.displayName, systemImage: preset.toolbarIcon) },
          action: applyTemplatePreset
        )
        Button("Reset All", systemImage: "arrow.counterclockwise") {
          showsResetConfirmation = true
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.isUsingDefaultTemplate)
        .help("Restore classic template defaults")
      }
    }
    ribbonGroup("Composition") {
      ribbonRow {
        ribbonPicker(
          "Header", selection: $viewModel.headerStyle, values: InvoiceHeaderStyle.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
      ribbonRow {
        ribbonPicker(
          "Parties", selection: $viewModel.partyLayout, values: InvoicePartyLayout.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
      ribbonRow {
        ribbonPicker(
          "Business Mark", selection: $viewModel.logoPlacement,
          values: InvoiceLogoPlacement.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
    }
  }

  @ViewBuilder
  var layoutTab: some View {
    ribbonGroup("Page Setup") {
      ribbonRow {
        ribbonPicker("Paper", selection: paperSizeBinding, values: PaperSize.allCases) {
          concisePickerOption(
            $0.displayName,
            accessibilityLabel: $0.menuLabel,
            systemImage: $0.toolbarIcon
          )
        }
      }
      ribbonRow {
        ribbonPicker(
          "Orientation", selection: pageOrientationBinding, values: PageOrientation.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
      ribbonRow {
        geometryField(
          "Width",
          value: customPageWidthBinding,
          inputID: InvoiceTemplateGeometryInputID.pageWidth,
          validRange: InvoiceTemplateLayoutLimits.pageDimensionRange
        )
        geometryField(
          "Height",
          value: customPageHeightBinding,
          inputID: InvoiceTemplateGeometryInputID.pageHeight,
          validRange: InvoiceTemplateLayoutLimits.pageDimensionRange
        )
      }
      ribbonRow {
        Button("Use \(viewModel.paperSize.displayName)", systemImage: "arrow.uturn.backward") {
          viewModel.useSelectedPaperSize()
          clearPageSizeDrafts()
        }
        .buttonStyle(.bordered)
        .disabled(!viewModel.hasCustomPageSize)
        .help("Restore selected paper dimensions")
      }
    }
    ribbonGroup("Margins") {
      ribbonRow {
        ribbonPicker(
          "Margins", selection: marginPresetBinding, values: InvoiceMarginPreset.allCases
        ) {
          concisePickerOption(
            $0.displayName,
            accessibilityLabel: $0.menuLabel,
            systemImage: $0.toolbarIcon
          )
        }
      }
      ribbonRow {
        geometryField(
          "Margin",
          value: customMarginBinding,
          inputID: InvoiceTemplateGeometryInputID.margin,
          validRange: 0...InvoiceTemplateLayoutLimits.maximumMargin(for: viewModel.pageSizePoints)
        )
      }
      ribbonRow {
        Button("Use Preset", systemImage: "arrow.uturn.backward") {
          viewModel.useSelectedMarginPreset()
          clearNumericDraft(InvoiceTemplateGeometryInputID.margin)
        }
        .buttonStyle(.bordered)
        .disabled(!viewModel.hasCustomMargin)
        .help("Restore selected margin preset")
      }
    }
  }

  @ViewBuilder
  var designTab: some View {
    ribbonGroup("Accent colour") {
      ribbonRow {
        ribbonPicker("Theme", selection: accentThemeBinding, values: InvoiceAccentTheme.allCases) {
          Label($0.displayName, systemImage: "paintpalette.fill")
        }
      }
      ribbonRow {
        ribbonColorPicker("Custom", selection: customAccentBinding)
      }
      ribbonRow {
        Button("Use Theme", systemImage: "paintpalette") {
          viewModel.customAccentColor = nil
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.customAccentColor == nil)
      }
    }
    ribbonGroup("Typography") {
      ribbonRow {
        ribbonPicker(
          "Font", selection: $viewModel.fontFamily, values: InvoiceFontFamilyPreset.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
      ribbonRow {
        ribbonPicker(
          "Density", selection: typographyDensityBinding, values: InvoiceTypographyDensity.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
      granularControl(
        "Scale",
        value: typographyScaleBinding,
        inputID: InvoiceTemplateGeometryInputID.typographyScale,
        range: 0.75...2,
        step: 0.01,
        suffix: "×",
        resetAvailable: viewModel.customTypographyScale != nil,
        reset: { viewModel.customTypographyScale = nil }
      )
    }
    ribbonGroup("Spacing") {
      ribbonRow {
        ribbonPicker(
          "Spacing", selection: documentSpacingBinding,
          values: InvoiceDocumentSpacingPreset.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
      granularControl(
        "Scale",
        value: spacingScaleBinding,
        inputID: InvoiceTemplateGeometryInputID.spacingScale,
        range: 0.5...1.75,
        step: 0.05,
        suffix: "×",
        resetAvailable: viewModel.customSpacingScale != nil,
        reset: { viewModel.customSpacingScale = nil }
      )
    }
    ribbonGroup("Rules") {
      ribbonRow {
        ribbonPicker(
          "Weight", selection: borderWeightBinding, values: InvoiceBorderWeight.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
        .disabled(viewModel.tableStyle == .borderless)
      }
      granularControl(
        "Width",
        value: borderWidthBinding,
        inputID: InvoiceTemplateGeometryInputID.borderWidth,
        range: 0.25...3,
        step: 0.25,
        suffix: " pt",
        resetAvailable: viewModel.customBorderWidth != nil,
        reset: { viewModel.customBorderWidth = nil }
      )
      .disabled(viewModel.tableStyle == .borderless)
    }
    ribbonGroup("Party cards") {
      ribbonRow {
        toggle("Borders", image: "rectangle.dashed", isOn: $viewModel.showPartyCardBorders)
        toggle("Fill", image: "rectangle.fill", isOn: $viewModel.showPartyCardFill)
      }
    }
    ribbonGroup("Payment cards") {
      ribbonRow {
        toggle(
          "Borders", image: "rectangle.on.rectangle",
          isOn: $viewModel.showPaymentCardBorders)
        toggle(
          "Fill", image: "rectangle.fill.on.rectangle.fill",
          isOn: $viewModel.showPaymentCardFill)
      }
    }
    ribbonGroup("Invoice metadata") {
      ribbonRow {
        toggle(
          "Outline", image: "rectangle.inset.filled",
          isOn: $viewModel.showInvoiceDetailsBorders)
        toggle("Grid", image: "tablecells", isOn: $viewModel.showInvoiceDetailGridLines)
      }
      ribbonRow {
        toggle("Labels", image: "text.alignleft", isOn: $viewModel.showInvoiceDetailLabels)
      }
    }
  }

  @ViewBuilder
  var contentTab: some View {
    ribbonGroup("Header") {
      ribbonRow {
        ribbonPicker(
          "Date", selection: $viewModel.dateFormatStyle,
          values: InvoiceDateFormatStyle.allCases
        ) {
          concisePickerOption(
            $0.styleName,
            accessibilityLabel: $0.menuLabel,
            systemImage: $0.toolbarIcon
          )
        }
        toggle("Title", image: "textformat", isOn: $viewModel.showTitleOnDocument)
      }
      ribbonRow {
        toggle("Number", image: "number", isOn: $viewModel.showInvoiceNumberOnDocument)
        toggle("Issued", image: "calendar", isOn: $viewModel.showIssueDateOnDocument)
      }
      ribbonRow {
        toggle(
          "Due", image: "calendar.badge.exclamationmark",
          isOn: $viewModel.showDueDateOnDocument)
        toggle("Underline", image: "text.underline", isOn: $viewModel.showTitleUnderline)
          .disabled(viewModel.headerStyle == .fullBleed || !viewModel.showTitleOnDocument)
      }
    }
    ribbonGroup("Payments") {
      ribbonRow {
        toggle("Details", image: "banknote", isOn: $viewModel.showPaymentDetails)
        toggle("Terms", image: "calendar.badge.clock", isOn: $viewModel.showPaymentTerms)
      }
      ribbonRow {
        toggle("Labels", image: "text.alignleft", isOn: $viewModel.showPaymentDetailLabels)
          .disabled(!viewModel.showPaymentDetails)
        toggle(
          "Rules", image: "line.3.horizontal",
          isOn: $viewModel.showPaymentDetailRowRules
        )
        .disabled(!viewModel.showPaymentDetails)
      }
    }
    ribbonGroup("Document flow") {
      ribbonRow {
        toggle("Numbers", image: "list.number", isOn: $viewModel.showPageNumbers)
        toggle(
          "Frame", image: "rectangle.inset.filled",
          isOn: $viewModel.showPageNumberChrome
        )
        .disabled(!viewModel.showPageNumbers)
      }
    }
    ribbonGroup("Parties") {
      ribbonRow {
        toggle("Labels", image: "tag", isOn: $viewModel.showPartyLabels)
        toggle("Contacts", image: "text.alignleft", isOn: $viewModel.showPartyContactLabels)
      }
      ribbonRow {
        toggle(
          "Participant", image: "person.crop.circle",
          isOn: $viewModel.showParticipantSection
        )
        .disabled(viewModel.billParticipantDirectly)
      }
    }
    ribbonGroup("Provider details") {
      ribbonRow {
        toggle("Phone", image: "phone", isOn: $viewModel.showProviderPhone)
        toggle("Email", image: "envelope", isOn: $viewModel.showProviderEmail)
      }
      ribbonRow {
        toggle("ABN", image: "number.square", isOn: $viewModel.showProviderTaxID)
      }
    }
  }

  @ViewBuilder
  var lineItemsTab: some View {
    ribbonGroup("Table style") {
      ribbonRow {
        ribbonPicker(
          "Style", selection: $viewModel.tableStyle, values: InvoiceTableStyle.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
        toggle("Grid", image: "tablecells", isOn: $viewModel.showTableGridLines)
          .disabled(viewModel.tableStyle == .borderless)
      }
      ribbonRow {
        toggle("Alternating", image: "rectangle.3.group", isOn: $viewModel.showTableZebraRows)
          .disabled(viewModel.tableStyle != .banded)
        toggle(
          "Header", image: "rectangle.topthird.inset.filled",
          isOn: $viewModel.showTableHeaderFill
        )
        .disabled(!viewModel.tableStyle.showsHeaderFill)
      }
    }
    ribbonGroup("Totals") {
      ribbonRow {
        ribbonPicker(
          "Emphasis", selection: $viewModel.totalsEmphasis, values: InvoiceTotalsEmphasis.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
        toggle(
          "Totals fill", image: "rectangle.bottomthird.inset.filled",
          isOn: $viewModel.showTotalsFill)
      }
    }
    ribbonGroup("Headings") {
      ribbonRow {
        toggle(
          "Section", image: "textformat.size", isOn: $viewModel.showLineItemsSectionTitle)
        toggle(
          "Columns", image: "rectangle.split.1x2", isOn: $viewModel.showLineItemsTableHeader
        )
      }
    }
    ribbonGroup("Columns") {
      ribbonRow {
        toggle("Date", image: "calendar", isOn: $viewModel.showDateColumn)
        toggle("Code", image: "number", isOn: $viewModel.showItemCode)
      }
      ribbonRow {
        toggle("Qty", image: "sum", isOn: $viewModel.showQtyColumn)
        toggle("Unit", image: "ruler", isOn: $viewModel.showUnitColumn)
      }
      ribbonRow {
        toggle("Rate", image: "dollarsign.circle", isOn: $viewModel.showRateColumn)
        toggle(
          "Dates", image: "calendar.day.timeline.left",
          isOn: $viewModel.showServiceDatesInDescription)
      }
    }
    ribbonGroup("Amount format") {
      ribbonRow {
        ribbonPicker(
          "Currency", selection: $viewModel.currencyDisplayStyle,
          values: InvoiceCurrencyDisplayStyle.allCases
        ) {
          concisePickerOption(
            $0.toolbarSummary,
            accessibilityLabel: $0.displayName,
            systemImage: $0.toolbarIcon
          )
        }
      }
      ribbonRow {
        ribbonPicker(
          "Tax", selection: $viewModel.taxLabelStyle, values: InvoiceTaxLabelStyle.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
    }
  }

}
