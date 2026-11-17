import SwiftUI
import SwiftData

@main
struct AgendaApp: App {
    private let modelContainer = PlannerSchema.makeContainer()

    var body: some Scene {
        WindowGroup {
            Text("Agenda")
        }
        .modelContainer(modelContainer)
    }
}
