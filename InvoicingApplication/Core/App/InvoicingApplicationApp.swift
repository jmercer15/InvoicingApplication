//
//  InvoicingApplicationApp.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI
import AppKit
import SwiftData
import Data

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

@MainActor
@main
struct InvoicingApplicationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appAssembly: AppAssembly?

    init() {
        // Configure the appearance of NSWindow's titlebar controls
        NSWindow.allowsAutomaticWindowTabbing = false
        DateArrayValueTransformer.register()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let assembly = appAssembly {
                    ContentView()
                        .environmentObject(assembly)
                        .toolbarBackgroundVisibility(.hidden)
                        .modelContainer(assembly.modelContainer)
                } else {
                    VStack {
                        ProgressView("Loading Application...")
                        Text("Initializing Data Layer...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Material.ultraThin)
                    .task {
                        await initializeApp()
                    }
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // Add standard text editing commands
            TextEditingCommands()
            TextFormattingCommands()
        }
    }

    // MARK: - Initialization Logic
    
    @MainActor
    private func initializeApp() async {
        // Ensure the container is ready (this initialization happens on the background actor)
        let container = await BackgroundPersistenceActor.shared.modelContainer
        
        // Run migrations
        await BackgroundPersistenceActor.shared.performMigrations()
        
        #if DEBUG
        let enableMonitoring = true
        let enableIntegrityChecks = true
        #else
        let enableMonitoring = false
        let enableIntegrityChecks = false
        #endif

        // Initialize AppAssembly with the container
        let assembly = AppAssembly(
            modelContainer: container,
            enableMonitoring: enableMonitoring,
            enableIntegrityChecks: enableIntegrityChecks
        )
        
        // Update state with animation
        withAnimation {
            self.appAssembly = assembly
        }
    }

}

// (Removed old WindowAppearanceModifier; window style handled by Scene modifiers)
