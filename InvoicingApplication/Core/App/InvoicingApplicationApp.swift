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
import Core
import Data
import SharedUI
import Feature_Calendar
import Feature_BillingHub
import Feature_Clients
import Feature_Invoices
import Feature_Settings
import Feature_NDIS
import Feature_InvoiceTemplateEditor

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
    @StateObject private var appAssembly = AppAssembly()

    init() {
        // Configure the appearance of NSWindow's titlebar controls
        NSWindow.allowsAutomaticWindowTabbing = false
        DateArrayValueTransformer.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appAssembly)
            // Attach the app delegate adapter
                .background(NSApplicationDelegateAdapter(appDelegate: appDelegateHandler.appDelegate))
                .toolbarBackgroundVisibility(.hidden)

            // No titlebar: handled via window style below
                // .task {
                //     // Load sample data if no data exists
                //     await loadSampleDataIfNeeded()
                // }
        }
        .modelContainer(appAssembly.modelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
    }
    
    // MARK: - Sample Data Loading
    // @MainActor
    // private func loadSampleDataIfNeeded() async {
    //     // Use the AppAssembly's import service
    //     do {
    //         let result = try await appAssembly.importAllData.callAsFunction()
    //         if result.success {
    //             print("Sample data loaded successfully: \(result.importedCounts)")
    //         } else {
    //             print("Sample data import failed: \(result.errors)")
    //         }
    //     } catch {
    //         print("Failed to load sample data: \(error)")
    //     }
    // }
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
