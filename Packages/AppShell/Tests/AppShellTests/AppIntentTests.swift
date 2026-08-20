import AppIntents
import Core
import PersistenceModels
import Data
import Foundation
import SharedUI
import SwiftData
import Testing
import CoreTesting
@testable import AppShell

@MainActor
@Suite(.tags(.integration))
struct AppIntentTests {
    @Test func openWorkspaceTabIntentRunsInForeground() {
        #expect(OpenWorkspaceTabIntent.supportedModes == .foreground)
    }

    @Test func modelAccessFindsExistingClient() async throws {
        let modelAccess = AppIntentModelAccess()
        let container = try ModelContainerFactory.makeInMemoryContainer()
        await modelAccess.adopt(container: container)
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let client = Client()
        client.id = UUID()
        client.fullName = "Alex Example"
        context.insert(client)
        try context.save()

        let exists = try await modelAccess.clientExists(id: client.id)
        #expect(exists)

        let missing = try await modelAccess.clientExists(id: UUID())
        #expect(missing == false)
    }

    @Test func modelAccessWaitsForContainerAdoption() async throws {
        let access = AppIntentModelAccess()
        let container = try ModelContainerFactory.makeInMemoryContainer()

        let readyTask = Task { try await access.requireReadyContainer() }

        try await Task.sleep(for: .milliseconds(25))
        await access.adopt(container: container)

        let resolved = try await readyTask.value
        #expect(resolved === container)
    }

    @Test func modelAccessBootstrapsWithoutSceneAdoption() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let access = AppIntentModelAccess(containerProvider: { container })

        let resolved = try await access.requireReadyContainer()

        #expect(resolved === container)
    }

    @Test func clientSearchIncludesMatchesBeyondFormerScanLimit() async throws {
        let modelAccess = AppIntentModelAccess()
        let container = try ModelContainerFactory.makeInMemoryContainer()
        await modelAccess.adopt(container: container)
        let context = ModelContext(container)
        context.autosaveEnabled = false

        for index in 0 ..< 501 {
            let client = Client(fullName: String(format: "A %03d", index))
            context.insert(client)
        }
        let target = Client(fullName: "Zed Target")
        context.insert(target)
        try context.save()

        let matches = try await modelAccess.searchClients(matching: "zed")

        #expect(matches.contains(where: { $0.id == target.id }))
    }

    @Test func deliveryCenterQueuesTabAndClientNavigation() {
        let delivery = WorkspaceIntentDeliveryCenter()
        _ = delivery.consumePending()

        delivery.enqueue(.selectTab(.calendar))
        #expect(delivery.pendingNavigation == .selectTab(.calendar))
        #expect(delivery.consumePending() == .selectTab(.calendar))
        #expect(delivery.pendingNavigation == nil)

        let clientID = UUID()
        delivery.enqueue(.openClient(clientID))
        #expect(delivery.consumePending() == .openClient(clientID))
    }

    @Test func workspaceExternalNavigationAppliesClientRoute() {
        let navigationManager = AppNavigationManager()
        let clientID = UUID()

        WorkspaceExternalNavigation.apply(.openClient(clientID), using: navigationManager)

        #expect(navigationManager.selectedTab == .relationships)
        #expect(navigationManager.navigationContext?.targetEntity == clientID)
        #expect(navigationManager.navigationContext?.targetEntityType == .client)
    }

    @Test func workspaceExternalNavigationSelectsTab() {
        let navigationManager = AppNavigationManager()

        WorkspaceExternalNavigation.apply(.selectTab(.billingHub), using: navigationManager)

        #expect(navigationManager.selectedTab == .billingHub)
    }

    @Test func coldStartReplayConsumesPendingWhenActive() {
        let delivery = WorkspaceIntentDeliveryCenter()
        _ = delivery.consumePending()

        let navigationManager = AppNavigationManager()
        delivery.enqueue(.selectTab(.calendar))

        let consumed = WorkspaceIntentNavigationDelivery.applyPendingIfNeeded(
            delivery: delivery, navigationManager: navigationManager,
            isActiveWorkspace: true)

        #expect(consumed)
        #expect(delivery.pendingNavigation == nil)
        #expect(navigationManager.selectedTab == .calendar)
    }

    @Test func coldStartReplaySkipsWhenSessionNotYetActive() {
        let delivery = WorkspaceIntentDeliveryCenter()
        _ = delivery.consumePending()

        let navigationManager = AppNavigationManager()
        let clientID = UUID()
        delivery.enqueue(.openClient(clientID))

        let consumed = WorkspaceIntentNavigationDelivery.applyPendingIfNeeded(
            delivery: delivery, navigationManager: navigationManager,
            isActiveWorkspace: false)

        #expect(consumed == false)
        #expect(delivery.pendingNavigation == .openClient(clientID))
    }

    @Test func multiWindowOnlyActiveWorkspaceConsumesPending() {
        let delivery = WorkspaceIntentDeliveryCenter()
        _ = delivery.consumePending()

        let activeNavigation = AppNavigationManager()
        let inactiveNavigation = AppNavigationManager()
        let clientID = UUID()
        delivery.enqueue(.openClient(clientID))

        let inactiveConsumed = WorkspaceIntentNavigationDelivery.applyPendingIfNeeded(
            delivery: delivery, navigationManager: inactiveNavigation,
            isActiveWorkspace: false)
        #expect(inactiveConsumed == false)
        #expect(delivery.pendingNavigation == .openClient(clientID))

        let activeConsumed = WorkspaceIntentNavigationDelivery.applyPendingIfNeeded(
            delivery: delivery, navigationManager: activeNavigation,
            isActiveWorkspace: true)
        #expect(activeConsumed)
        #expect(delivery.pendingNavigation == nil)
        #expect(activeNavigation.selectedTab == .relationships)
        #expect(activeNavigation.navigationContext?.targetEntity == clientID)
        #expect(inactiveNavigation.selectedTab != .relationships)
    }

    @Test func openClientIntentPerformEnqueuesNavigation() async throws {
        let modelAccess = AppIntentModelAccess()
        let delivery = WorkspaceIntentDeliveryCenter()
        let container = try ModelContainerFactory.makeInMemoryContainer()
        await modelAccess.adopt(container: container)
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let client = Client()
        client.id = UUID()
        client.fullName = "Jordan Client"
        context.insert(client)
        try context.save()

        _ = delivery.consumePending()

        let target = ClientEntity(id: client.id, displayName: client.fullName)
        try await OpenClientIntentPerforming.perform(
            target: target, modelAccess: modelAccess,
            delivery: delivery)

        #expect(delivery.pendingNavigation == .openClient(client.id))
    }

    @Test func openClientIntentPerformThrowsWhenClientMissing() async throws {
        let modelAccess = AppIntentModelAccess()
        let delivery = WorkspaceIntentDeliveryCenter()
        let container = try ModelContainerFactory.makeInMemoryContainer()
        await modelAccess.adopt(container: container)

        let missingID = UUID()
        let target = ClientEntity(id: missingID, displayName: "Missing")

        await #expect(throws: AppIntentModelAccessError.clientNotFound(missingID)) {
            try await OpenClientIntentPerforming.perform(
                target: target, modelAccess: modelAccess,
                delivery: delivery)
        }
    }

    @Test func openWorkspaceTabIntentPerformEnqueuesTabSelection() {
        let delivery = WorkspaceIntentDeliveryCenter()
        _ = delivery.consumePending()

        OpenWorkspaceTabIntentPerforming.perform(tab: .billingHub, delivery: delivery)

        #expect(delivery.pendingNavigation == .selectTab(.billingHub))
    }

    @Test func openWorkspaceTabIntentPerformSupportsRelationshipsTab() {
        let delivery = WorkspaceIntentDeliveryCenter()
        _ = delivery.consumePending()

        OpenWorkspaceTabIntentPerforming.perform(tab: .relationships, delivery: delivery)

        #expect(delivery.pendingNavigation == .selectTab(.relationships))
    }
}
