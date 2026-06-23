import SwiftUI
import SwiftData

@main
struct DevStreakApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: CodingSession.self)
        }
    }
}
