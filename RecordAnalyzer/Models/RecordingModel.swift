import Foundation
import SwiftUI

/// 輕量級錄音摘要結構，用於列表顯示和性能優化
struct RecordingSummary: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    let title: String
    let duration: TimeInterval?
    let fileSize: Int?
    let status: String?
    let createdAt: Date
    let hasTranscript: Bool
    let hasSummary: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case duration
        case fileSize = "file_size"
        case status
        case createdAt = "created_at"
        case hasTranscript = "has_transcript"
        case hasSummary = "has_summary"
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
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        fileSize = try container.decodeIfPresent(Int.self, forKey: .fileSize)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        hasTranscript = try container.decodeIfPresent(Bool.self, forKey: .hasTranscript) ?? false
        hasSummary = try container.decodeIfPresent(Bool.self, forKey: .hasSummary) ?? false
        
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
    }
    
    /// 轉換為完整的Recording對象，用於詳情顯示
    func toRecording() -> Recording {
        return Recording(
            id: id,
            title: title,
            originalFilename: title + ".m4a", // 暫時使用標題作為文件名
            format: "m4a",
            mimeType: "audio/m4a",
            duration: duration,
            createdAt: createdAt,
            transcription: hasTranscript ? "可用" : nil,
            summary: hasSummary ? "可用" : nil,
            fileURL: nil,
            fileSize: fileSize,
            status: status
        )
    }
    
    // 格式化屬性
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
    
    // MARK: - Equatable 實現
    static func == (lhs: RecordingSummary, rhs: RecordingSummary) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.status == rhs.status &&
               lhs.hasTranscript == rhs.hasTranscript &&
               lhs.hasSummary == rhs.hasSummary
    }
}

struct Recording: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    let originalFilename: String
    let format: String
    let mimeType: String
    let duration: TimeInterval?
    let createdAt: Date
    let transcription: String?
    let summary: String?
    let fileURL: URL?
    let fileSize: Int?
    var status: String?
    let timelineTranscript: String?
    let hasTimeline: Bool
    let analysisMetadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case originalFilename = "original_filename"
        case format
        case mimeType = "mime_type"
        case duration
        case createdAt = "created_at"
        case transcription = "transcript"
        case summary
        case fileURL
        case fileSize = "file_size"
        case status
        case timelineTranscript = "timeline_transcript"
        case hasTimeline = "has_timeline"
        case analysisMetadata = "analysis_metadata"
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
        originalFilename = try container.decode(String.self, forKey: .originalFilename)
        format = try container.decode(String.self, forKey: .format)
        mimeType = try container.decode(String.self, forKey: .mimeType)
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
        
        // 處理時間軸相關欄位
        timelineTranscript = try container.decodeIfPresent(String.self, forKey: .timelineTranscript)
        hasTimeline = try container.decodeIfPresent(Bool.self, forKey: .hasTimeline) ?? false
        
        // 處理 analysisMetadata - 由於是 Any 類型，需要特殊處理
        if let metadataDict = try? container.decodeIfPresent([String: String].self, forKey: .analysisMetadata) {
            analysisMetadata = metadataDict
        } else {
            analysisMetadata = nil
        }
    }
    
    init(id: UUID = UUID(), title: String, originalFilename: String, format: String, mimeType: String, duration: TimeInterval? = nil, createdAt: Date, transcription: String? = nil, summary: String? = nil, fileURL: URL? = nil, fileSize: Int? = nil, status: String? = nil, timelineTranscript: String? = nil, hasTimeline: Bool = false, analysisMetadata: [String: String]? = nil) {
        self.id = id
        self.title = title
        self.originalFilename = originalFilename
        self.format = format
        self.mimeType = mimeType
        self.duration = duration
        self.createdAt = createdAt
        self.transcription = transcription
        self.summary = summary
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.status = status
        self.timelineTranscript = timelineTranscript
        self.hasTimeline = hasTimeline
        self.analysisMetadata = analysisMetadata
    }
    
    // 為了向後兼容，保留fileName屬性，但指向originalFilename
    var fileName: String {
        return originalFilename
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
    
    // MARK: - Equatable 實現
    static func == (lhs: Recording, rhs: Recording) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.status == rhs.status &&
               lhs.duration == rhs.duration &&
               lhs.transcription == rhs.transcription &&
               lhs.summary == rhs.summary
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

// MARK: - Analysis History Models
struct AnalysisHistory: Identifiable, Codable, Equatable {
    let id: UUID
    let recordingId: UUID
    let analysisType: AnalysisType
    let content: String
    let status: AnalysisStatus
    let provider: String
    let version: Int
    let isCurrent: Bool
    let errorMessage: String?
    let language: String
    let confidenceScore: Double?
    let processingTime: Double?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case recordingId = "recording_id"
        case analysisType = "analysis_type"
        case content
        case status
        case provider
        case version
        case isCurrent = "is_current"
        case errorMessage = "error_message"
        case language
        case confidenceScore = "confidence_score"
        case processingTime = "processing_time"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // ID處理
        if let uuidString = try? container.decode(String.self, forKey: .id),
           let uuid = UUID(uuidString: uuidString) {
            self.id = uuid
        } else {
            self.id = UUID()
        }
        
        // Recording ID處理
        if let recordingIdString = try? container.decode(String.self, forKey: .recordingId),
           let recordingUuid = UUID(uuidString: recordingIdString) {
            self.recordingId = recordingUuid
        } else {
            self.recordingId = UUID()
        }
        
        // 解析其他字段
        let analysisTypeString = try container.decode(String.self, forKey: .analysisType)
        self.analysisType = AnalysisType(rawValue: analysisTypeString) ?? .transcription
        
        let statusString = try container.decode(String.self, forKey: .status)
        self.status = AnalysisStatus(rawValue: statusString) ?? .processing
        
        self.content = try container.decode(String.self, forKey: .content)
        self.provider = try container.decode(String.self, forKey: .provider)
        self.version = try container.decode(Int.self, forKey: .version)
        self.isCurrent = try container.decode(Bool.self, forKey: .isCurrent)
        self.errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        self.language = try container.decodeIfPresent(String.self, forKey: .language) ?? "zh"
        self.confidenceScore = try container.decodeIfPresent(Double.self, forKey: .confidenceScore)
        self.processingTime = try container.decodeIfPresent(Double.self, forKey: .processingTime)
        
        // 日期處理
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        if let createdDate = dateFormatter.date(from: createdAtString) {
            self.createdAt = createdDate
        } else {
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            self.createdAt = dateFormatter.date(from: createdAtString) ?? Date()
        }
        
        if let updatedDate = dateFormatter.date(from: updatedAtString) {
            self.updatedAt = updatedDate
        } else {
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            self.updatedAt = dateFormatter.date(from: updatedAtString) ?? Date()
        }
    }
    
    // MARK: - Computed Properties
    var formattedCreatedAt: String {
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(createdAt) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return "今天 \(timeFormatter.string(from: createdAt))"
        }
        
        if calendar.isDateInYesterday(createdAt) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return "昨天 \(timeFormatter.string(from: createdAt))"
        }
        
        let daysSinceCreated = calendar.dateComponents([.day], from: createdAt, to: now).day ?? 0
        if daysSinceCreated < 7 {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE HH:mm"
            dayFormatter.locale = Locale(identifier: "zh_TW")
            return dayFormatter.string(from: createdAt)
        }
        
        if calendar.component(.year, from: createdAt) == calendar.component(.year, from: now) {
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "M月d日 HH:mm"
            monthFormatter.locale = Locale(identifier: "zh_TW")
            return monthFormatter.string(from: createdAt)
        }
        
        let fullFormatter = DateFormatter()
        fullFormatter.dateFormat = "yy年M月d日"
        fullFormatter.locale = Locale(identifier: "zh_TW")
        return fullFormatter.string(from: createdAt)
    }
    
    var statusText: String {
        switch status {
        case .processing:
            return "處理中"
        case .completed:
            return "已完成"
        case .failed:
            return "失敗"
        }
    }
    
    var analysisTypeText: String {
        switch analysisType {
        case .transcription:
            return "逐字稿"
        case .summary:
            return "摘要"
        }
    }
    
    // MARK: - Equatable
    static func == (lhs: AnalysisHistory, rhs: AnalysisHistory) -> Bool {
        return lhs.id == rhs.id &&
               lhs.version == rhs.version &&
               lhs.status == rhs.status &&
               lhs.isCurrent == rhs.isCurrent &&
               lhs.language == rhs.language &&
               lhs.confidenceScore == rhs.confidenceScore &&
               lhs.processingTime == rhs.processingTime
    }
}

enum AnalysisType: String, CaseIterable, Codable {
    case transcription = "transcription"
    case summary = "summary"
    
    var displayName: String {
        switch self {
        case .transcription:
            return "逐字稿"
        case .summary:
            return "摘要"
        }
    }
}

enum AnalysisStatus: String, CaseIterable, Codable {
    case processing = "PROCESSING"
    case completed = "COMPLETED"
    case failed = "FAILED"
    
    var displayName: String {
        switch self {
        case .processing:
            return "處理中"
        case .completed:
            return "已完成"
        case .failed:
            return "失敗"
        }
    }
    
    var color: Color {
        switch self {
        case .processing:
            return AppTheme.Colors.warning
        case .completed:
            return AppTheme.Colors.success
        case .failed:
            return AppTheme.Colors.error
        }
    }
}

 