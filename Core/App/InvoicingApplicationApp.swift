//
//  InvoicingApplicationApp.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI
import AppKit
import EventKit
import SwiftData

// MARK: - App Delegate for managing application lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize any necessary resources here
        print("Application did finish launching")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up any resources if needed
        print("Application will terminate")
    }
}

@main
struct InvoicingApplicationApp: App {

    
    // Add the AppDelegate
    @StateObject private var appDelegateHandler = AppDelegateHandler()
    @StateObject private var eventKitSyncService = EventKitSyncService.shared

    init() {
        // Configure the appearance of NSWindow's titlebar controls
        NSWindow.allowsAutomaticWindowTabbing = false
        DateArrayValueTransformer.register()
        

    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(eventKitSyncService)
                .environment(\.appTheme, AppTheme.default)
            // Attach the app delegate adapter
                .background(NSApplicationDelegateAdapter(appDelegate: appDelegateHandler.appDelegate))
            // No titlebar: handled via window style below
        }
        .modelContainer(for: [
            ClientEntity.self,
            BusinessEntity.self,
            AddressEntity.self,
            InvoiceEntity.self,
            InvoiceItemEntity.self,
            ClientServiceEntity.self,
            PayeeEntity.self,
            PlanManagerEntity.self,
            SessionEntity.self,
            TravelChargeEntity.self,
            TravelChargeAuditLog.self,
            TravelChargeReviewItem.self,
            CreditHistoryEntryEntity.self,
            ExpenseEntity.self,
            ExpenseCategoryEntity.self,
            NDISItemEntity.self,
            RegionalPriceEntity.self,
            ServiceEntity.self
        ])
        .windowStyle(.hiddenTitleBar)
    }
}

// MARK: - Application Delegate Handler (ObservableObject)
class AppDelegateHandler: ObservableObject {
    let appDelegate = AppDelegate()
    
    init() {
        NSApplication.shared.delegate = appDelegate
    }
}

// MARK: - SwiftUI to AppKit Delegate Adapter
struct NSApplicationDelegateAdapter: NSViewRepresentable {
    let appDelegate: NSApplicationDelegate
    
    func makeNSView(context: Context) -> NSView {
        NSView()
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Nothing to update
    }
}

// (Removed old WindowAppearanceModifier; window style handled by Scene modifiers)
