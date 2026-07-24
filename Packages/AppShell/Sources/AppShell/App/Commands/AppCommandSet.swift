//
//  AppCommandSet.swift
//  InvoicingApplication
//
//  App-level menu commands; actions route via focused workspace command context.
//

import SwiftUI
import Core
import InvoiceTableLayoutEditor

struct AppCommandSet: Commands {
    @FocusedValue(\.workspaceCommandActions) var actions
    @FocusedValue(\.invoiceEditorCommandActions) var invoiceEditorActions

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Invoice") {
                let focusedEditor = invoiceEditorActions
                let workspaceActions = actions
                Task { @MainActor in
                    guard await AppInvoiceCommandRoutingPolicy.prepareForCreate(
                        editor: focusedEditor
                    ) else { return }
                    workspaceActions?.createNewInvoice?()
                }
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
            .disabled(
                !AppInvoiceCommandRoutingPolicy.canCreate(
                    editor: invoiceEditorActions,
                    workspaceCanCreate: actions?.canCreateNewInvoice == true
                )
            )

            Button("New Session") {
                actions?.createNewSession?()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(actions?.canCreateNewSession != true)
        }

        CommandMenu("Invoice") {
            if let invoiceEditorActions,
               AppInvoiceCommandRoutingPolicy.showsInvoiceDocumentCommands(invoiceEditorActions) {
                Button("Save Invoice") {
                    invoiceEditorActions.save()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!invoiceEditorActions.canSave)

                Button("Duplicate Invoice") {
                    invoiceEditorActions.duplicate()
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(!invoiceEditorActions.canDuplicate)

                Button("Add Line Item") {
                    invoiceEditorActions.addLineItem()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(!invoiceEditorActions.canAddLineItem)

                Button("Delete Invoice…", role: .destructive) {
                    invoiceEditorActions.requestDelete()
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(!invoiceEditorActions.canDelete)

                Divider()

                Button("Print…") {
                    invoiceEditorActions.print()
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(!AppInvoiceCommandRoutingPolicy.canPrint(editor: invoiceEditorActions))

                Button("Export PDF…") {
                    invoiceEditorActions.exportPDF()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!AppInvoiceCommandRoutingPolicy.canExportPDF(editor: invoiceEditorActions))
            }

            if let invoiceEditorActions {
                Divider()

                Button("Zoom In") {
                    invoiceEditorActions.zoomIn()
                }
                .keyboardShortcut("=", modifiers: .command)
                .disabled(!invoiceEditorActions.canZoomIn)

                Button("Zoom Out") {
                    invoiceEditorActions.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(!invoiceEditorActions.canZoomOut)

                Button("Actual Size") {
                    invoiceEditorActions.setActualSize()
                }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(!invoiceEditorActions.canSetActualSize)

                Button("Fit Width") {
                    invoiceEditorActions.fitWidth()
                }
                .keyboardShortcut("9", modifiers: .command)
                .disabled(!invoiceEditorActions.canFitWidth)
            }
        }

        CommandMenu("Navigate") {
            Button("Back") {
                actions?.navigateBack()
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .disabled(!(actions?.canNavigateBack() ?? false))

            Button("Forward") {
                actions?.navigateForward()
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .disabled(!(actions?.canNavigateForward() ?? false))

            Divider()

            Button("Go to Invoices") {
                actions?.switchToTab(.invoices)
            }
            .keyboardShortcut("1", modifiers: .command)
            .disabled(!(actions?.canSwitchToTab(.invoices) == true))

            Button("Go to Billing Hub") {
                actions?.switchToTab(.billingHub)
            }
            .keyboardShortcut("2", modifiers: .command)
            .disabled(!(actions?.canSwitchToTab(.billingHub) == true))

            Button("Go to Relationships") {
                actions?.switchToTab(.relationships)
            }
            .keyboardShortcut("3", modifiers: .command)
            .disabled(!(actions?.canSwitchToTab(.relationships) == true))

            Button("Go to Calendar") {
                actions?.switchToTab(.calendar)
            }
            .keyboardShortcut("4", modifiers: .command)
            .disabled(!(actions?.canSwitchToTab(.calendar) == true))

            Button("Go to NDIS Catalogue") {
                actions?.switchToTab(.ndisCatalogue)
            }
            .keyboardShortcut("5", modifiers: .command)
            .disabled(!(actions?.canSwitchToTab(.ndisCatalogue) == true))

            Button("Go to Template Editor") {
                actions?.switchToTab(.invoiceTemplateEditor)
            }
            .keyboardShortcut("6", modifiers: .command)
            .disabled(!(actions?.canSwitchToTab(.invoiceTemplateEditor) == true))
        }

        CommandGroup(after: .windowArrangement) {
            Button("Toggle Inspector") {
                if let invoiceEditorActions {
                    invoiceEditorActions.toggleInspector()
                } else {
                    actions?.toggleInspector?()
                }
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(
                !AppInvoiceCommandRoutingPolicy.canToggleInspector(
                    editor: invoiceEditorActions,
                    workspaceCanToggle: actions?.canToggleInspector == true
                )
            )

            WindowVisibilityToggle(windowID: AppSceneID.inspector.rawValue)

            WindowVisibilityToggle(windowID: AppSceneID.activity.rawValue)
                .keyboardShortcut("a", modifiers: [.command, .shift])
        }
    }
}

/// Keeps focused editor commands from falling through to unrelated workspace actions.
///
/// Template Editor intentionally allows global invoice creation, but owns document and
/// inspector command namespaces while focused. Invoice Editor constrains creation while busy,
/// while Feature.Invoices remains sole owner of creation, list publication, and navigation.
enum AppInvoiceCommandRoutingPolicy {
    @MainActor
    static func showsInvoiceDocumentCommands(_ editor: InvoiceEditorCommandActions?) -> Bool {
        editor?.isInvoiceContext == true
    }

    @MainActor
    static func canCreate(
        editor: InvoiceEditorCommandActions?,
        workspaceCanCreate: Bool
    ) -> Bool {
        guard workspaceCanCreate else { return false }
        return editor?.canCreate ?? true
    }

    @MainActor
    static func prepareForCreate(editor: InvoiceEditorCommandActions?) async -> Bool {
        await editor?.prepareForInvoiceCreation() ?? true
    }

    @MainActor
    static func canPrint(
        editor: InvoiceEditorCommandActions?
    ) -> Bool {
        editor?.canPrint == true
    }

    @MainActor
    static func canExportPDF(
        editor: InvoiceEditorCommandActions?
    ) -> Bool {
        editor?.canExportPDF == true
    }

    @MainActor
    static func canToggleInspector(
        editor: InvoiceEditorCommandActions?,
        workspaceCanToggle: Bool
    ) -> Bool {
        editor.map(\.canToggleInspector) ?? workspaceCanToggle
    }
}
