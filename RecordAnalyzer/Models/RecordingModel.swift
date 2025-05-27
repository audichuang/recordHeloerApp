import Foundation

struct Recording: Identifiable, Codable {
    var id: UUID
    let title: String
    let fileName: String
    let duration: TimeInterval?
    let createdAt: Date
    let transcription: String?
    let summary: String?
    let fileURL: URL?
    let fileSize: Int?
    var status: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case fileName = "file_path"
        case duration
        case createdAt = "created_at"
        case transcription = "transcript"
        case summary
        case fileURL
        case fileSize = "file_size"
        case status
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // ID可能是UUID字符串
        if let uuidString = try? container.decode(String.self, forKey: .id),
           let uuid = UUID(uuidString: uuidString) {
            self.id = uuid
        } else {
            self.id = UUID()
        }
        
        title = try container.decode(String.self, forKey: .title)
        fileName = try container.decode(String.self, forKey: .fileName)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        fileSize = try container.decodeIfPresent(Int.self, forKey: .fileSize)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        
        // 處理日期格式
        let dateString = try container.decode(String.self, forKey: .createdAt)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        if let date = dateFormatter.date(from: dateString) {
            self.createdAt = date
        } else {
            // 嘗試另一種日期格式
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            if let date = dateFormatter.date(from: dateString) {
                self.createdAt = date
            } else {
                self.createdAt = Date()
                print("⚠️ 無法解析日期: \(dateString)")
            }
        }
        
        // 處理可空字段
        transcription = try container.decodeIfPresent(String.self, forKey: .transcription)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        fileURL = nil // API 不返回完整URL，需要在顯示時構建
    }
    
    init(id: UUID = UUID(), title: String, fileName: String, duration: TimeInterval? = nil, createdAt: Date, transcription: String? = nil, summary: String? = nil, fileURL: URL? = nil, fileSize: Int? = nil, status: String? = nil) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.duration = duration
        self.createdAt = createdAt
        self.transcription = transcription
        self.summary = summary
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.status = status
    }
    
    var formattedDuration: String {
        guard let duration = duration, duration > 0 else { return "--:--" }
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedFileSize: String {
        guard let size = fileSize, size > 0 else { return "-- MB" }
        
        let kb = Double(size) / 1024.0
        let mb = kb / 1024.0
        
        if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        } else if kb >= 1.0 {
            return String(format: "%.0f KB", kb)
        } else {
            return "< 1 KB"
        }
    }
    
    var formattedDate: String {
        let now = Date()
        let calendar = Calendar.current
        
        // 檢查是否是今天
        if calendar.isDateInToday(createdAt) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return "今天 \(timeFormatter.string(from: createdAt))"
        }
        
        // 檢查是否是昨天
        if calendar.isDateInYesterday(createdAt) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return "昨天 \(timeFormatter.string(from: createdAt))"
        }
        
        // 檢查是否是本週
        let daysSinceCreated = calendar.dateComponents([.day], from: createdAt, to: now).day ?? 0
        if daysSinceCreated < 7 {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE HH:mm"
            dayFormatter.locale = Locale(identifier: "zh_TW")
            return dayFormatter.string(from: createdAt)
        }
        
        // 檢查是否是本年
        if calendar.component(.year, from: createdAt) == calendar.component(.year, from: now) {
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "M月d日 HH:mm"
            monthFormatter.locale = Locale(identifier: "zh_TW")
            return monthFormatter.string(from: createdAt)
        }
        
        // 其他情況顯示完整日期
        let fullFormatter = DateFormatter()
        fullFormatter.dateFormat = "yy年M月d日"
        fullFormatter.locale = Locale(identifier: "zh_TW")
        return fullFormatter.string(from: createdAt)
    }
    
    var statusText: String {
        guard let status = status else { return "未知" }
        
        switch status.lowercased() {
        case "completed":
            return "已完成"
        case "processing":
            return "處理中"
        case "failed":
            return "失敗"
        case "pending":
            return "等待中"
        default:
            return status
        }
    }
}

// 重命名為 UserProfile 以避免和 Models/User.swift 中的 User 結構體衝突
struct UserProfile: Identifiable, Codable {
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