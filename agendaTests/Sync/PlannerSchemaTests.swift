import Foundation
import SwiftData
import Testing
@testable import agenda

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

    @Test func testHostUsesAnInMemoryStore() {
        #expect(PlannerSchema.isRunningTests)
    }
}
