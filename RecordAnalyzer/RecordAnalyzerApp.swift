import SwiftUI

@main
struct RecordAnalyzerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AuthenticationManager())
                .environmentObject(RecordingManager())
        }
    }
} 