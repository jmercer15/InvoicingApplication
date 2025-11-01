import SwiftUI
import Core

struct TableLayoutSectionContent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument

    var body: some View {
        PropertyGrid {
            ModernPickerEditor(
                title: "Direction",
                selection: component.style.tableDirection,
                onChange: { document.updateTableDirection(for: component.id, direction: $0) }
            )
        }
    }
}

struct TableFillSectionContent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument

    var body: some View {
        PropertyGrid {
            ModernColorEditor(
                title: "Header Fill",
                color: component.style.tableHeaderColorSwiftUI,
                hexColor: component.style.tableHeaderColor,
                onChange: { document.updateTableHeaderColor(for: component.id, color: $0) }
            )

            ModernColorEditor(
                title: "Row Fill",
                color: component.style.tableRowColorSwiftUI,
                hexColor: component.style.tableRowColor,
                onChange: { document.updateTableRowColor(for: component.id, color: $0) }
            )

            ModernColorEditor(
                title: "Alt Row Fill",
                color: component.style.tableRowAltColorSwiftUI,
                hexColor: component.style.tableRowAltColor,
                onChange: { document.updateTableRowAltColor(for: component.id, color: $0) }
            )

            ModernToggleEditor(
                title: "Alternating Rows",
                isOn: component.style.useAlternatingRows,
                onChange: { document.updateUseAlternatingRows(for: component.id, use: $0) }
            )
        }
    }
}

struct TableStrokeSectionContent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument

    var body: some View {
        PropertyGrid {
            ModernToggleEditor(
                title: "Show Borders",
                isOn: component.style.showTableBorders,
                onChange: { document.updateShowTableBorders(for: component.id, show: $0) }
            )

            if component.style.showTableBorders {
                ModernColorEditor(
                    title: "Border Color",
                    color: component.style.tableBorderColorSwiftUI,
                    hexColor: component.style.tableBorderColor,
                    onChange: { document.updateTableBorderColor(for: component.id, color: $0) }
                )

                ModernSliderEditor(
                    title: "Border Width",
                    value: component.style.tableBorderWidth,
                    range: 0...5,
                    step: 0.5,
                    formatter: "%.1f",
                    onChange: { document.updateTableBorderWidth(for: component.id, width: $0) }
                )
            }

            ModernToggleEditor(
                title: "Header Borders",
                isOn: component.style.showHeaderBorder,
                onChange: { document.updateShowHeaderBorder(for: component.id, show: $0) }
            )

            ModernToggleEditor(
                title: "Row Borders",
                isOn: component.style.showRowBorders,
                onChange: { document.updateShowRowBorders(for: component.id, show: $0) }
            )

            ModernToggleEditor(
                title: "Cell Borders",
                isOn: component.style.showCellBorders,
                onChange: { document.updateShowCellBorders(for: component.id, show: $0) }
            )
        }
    }
}

struct TableSpacingSectionContent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument

    var body: some View {
        PropertyGrid {
            ModernSliderEditor(
                title: "Cell Padding",
                value: component.style.tableCellPadding,
                range: 0...20,
                step: 1,
                formatter: "%.0f",
                onChange: { document.updateTableCellPadding(for: component.id, padding: $0) }
            )

            ModernSliderEditor(
                title: "Header Padding",
                value: component.style.tableHeaderPadding,
                range: 0...20,
                step: 1,
                formatter: "%.0f",
                onChange: { document.updateTableHeaderPadding(for: component.id, padding: $0) }
            )
        }
    }
}

struct TableContentSectionContent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument

    var body: some View {
        PropertyGrid {
            ModernToggleEditor(
                title: "Show Header",
                isOn: component.style.showTableHeader,
                onChange: { document.updateShowTableHeader(for: component.id, show: $0) }
            )

            ModernColorEditor(
                title: "Text Color",
                color: component.style.tableTextColorSwiftUI,
                hexColor: component.style.tableTextColor,
                onChange: { document.updateTableTextColor(for: component.id, color: $0) }
            )
        }
    }
}

