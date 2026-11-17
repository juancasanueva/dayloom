import Foundation
import SwiftData
import Testing
@testable import agenda

@MainActor
@Suite("Store configuration")
struct PlannerSchemaTests {
    @Test func onDiskStoreSyncsThroughThePrivateContainer() {
        let configuration = PlannerSchema.configuration(inMemory: false)

        #expect(configuration.cloudKitContainerIdentifier == "iCloud.com.juancasanueva.agenda")
        #expect(!configuration.isStoredInMemoryOnly)
    }

    @Test func inMemoryStoreNeverSyncs() {
        let configuration = PlannerSchema.configuration(inMemory: true)

        #expect(configuration.cloudKitContainerIdentifier == nil)
        #expect(configuration.isStoredInMemoryOnly)
    }

    @Test func localFallbackNeverSyncs() {
        let configuration = PlannerSchema.configuration(inMemory: false, syncs: false)

        #expect(configuration.cloudKitContainerIdentifier == nil)
        #expect(!configuration.isStoredInMemoryOnly)
    }

    @Test func appStoreUnderTestsIsInMemoryAndNeverSyncs() {
        #expect(PlannerSchema.isRunningTests)

        let store = PlannerSchema.openAppStore()

        #expect(!store.syncs)
        #expect(store.container.configurations.allSatisfy { $0.isStoredInMemoryOnly && $0.cloudKitContainerIdentifier == nil })
    }

    @Test func storeOpensLocallyWhenICloudCannotStart() {
        var requested: [String?] = []

        let store = PlannerSchema.openStore(inMemory: false, canUseICloud: true) { configuration in
            requested.append(configuration.cloudKitContainerIdentifier)
            if configuration.cloudKitContainerIdentifier != nil {
                throw CocoaError(.featureUnsupported)
            }
            return try ModelContainer(for: PlannerSchema.schema, configurations: [PlannerSchema.configuration(inMemory: true)])
        }

        #expect(requested == ["iCloud.com.juancasanueva.agenda", nil])
        #expect(!store.syncs)
        #expect(store.syncError != nil)
    }

    @Test func storeSyncsWhenICloudStarts() {
        var requested: [String?] = []

        let store = PlannerSchema.openStore(inMemory: false, canUseICloud: true) { configuration in
            requested.append(configuration.cloudKitContainerIdentifier)
            return try ModelContainer(for: PlannerSchema.schema, configurations: [PlannerSchema.configuration(inMemory: true)])
        }

        #expect(requested == ["iCloud.com.juancasanueva.agenda"])
        #expect(store.syncs)
        #expect(store.syncError == nil)
    }

    /// Without the entitlement, SwiftData opens the iCloud store without throwing and Core Data
    /// then traps during CloudKit setup, so the iCloud configuration must not be tried at all.
    @Test func storeNeverTriesICloudWithoutTheEntitlement() {
        var requested: [String?] = []

        let store = PlannerSchema.openStore(inMemory: false, canUseICloud: false) { configuration in
            requested.append(configuration.cloudKitContainerIdentifier)
            return try ModelContainer(for: PlannerSchema.schema, configurations: [PlannerSchema.configuration(inMemory: true)])
        }

        #expect(requested == [nil])
        #expect(!store.syncs)
        #expect(store.syncError == "This copy of Dayloom isn't signed for iCloud.")
    }

    @Test func entitlementCheckRunsWithoutCrashing() {
        // Test builds may or may not carry the entitlement; reading it must simply not trap.
        _ = PlannerSchema.hasICloudEntitlement
    }
}
