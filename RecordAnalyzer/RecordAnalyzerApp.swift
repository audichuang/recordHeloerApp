import SwiftUI
import Foundation

@main
struct RecordAnalyzerApp: App {
    // 創建環境對象
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var recordingManager = RecordingManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(recordingManager)
        }
    }
} 