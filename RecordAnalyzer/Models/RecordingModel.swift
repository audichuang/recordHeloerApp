import Foundation

struct Recording: Identifiable, Codable {
    let id = UUID()
    let title: String
    let fileName: String
    let duration: TimeInterval
    let createdAt: Date
    let transcription: String
    let summary: String
    let fileURL: URL?
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: createdAt)
    }
}

struct User: Identifiable, Codable {
    let id = UUID()
    let username: String
    let email: String
    let createdAt: Date
}

struct AnalysisResult: Codable {
    let transcription: String
    let summary: String
    let confidence: Double
    let language: String
} 