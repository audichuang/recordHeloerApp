import Foundation

struct Recording: Identifiable, Codable {
    var id: UUID
    let title: String
    let fileName: String
    let duration: TimeInterval
    let createdAt: Date
    let transcription: String
    let summary: String
    let fileURL: URL?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case fileName
        case duration
        case createdAt
        case transcription
        case summary
        case fileURL
    }
    
    init(id: UUID = UUID(), title: String, fileName: String, duration: TimeInterval, createdAt: Date, transcription: String, summary: String, fileURL: URL?) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.duration = duration
        self.createdAt = createdAt
        self.transcription = transcription
        self.summary = summary
        self.fileURL = fileURL
    }
    
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
    let id: String
    let username: String
    let email: String
    let isActive: Bool
    let profileData: [String: String]
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case isActive = "is_active"
        case profileData = "profile_data"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        profileData = try container.decode([String: String].self, forKey: .profileData)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }
    
    // 提供編碼功能
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(email, forKey: .email)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(profileData, forKey: .profileData)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

struct AnalysisResult: Codable {
    let transcription: String
    let summary: String
    let confidence: Double
    let language: String
} 