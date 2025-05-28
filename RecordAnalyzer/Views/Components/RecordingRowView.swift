import SwiftUI

struct RecordingRowView: View {
    let recording: Recording
    var showFullDetails: Bool = true
    
    var body: some View {
        HStack(spacing: 16) {
            // 狀態圖標
            statusIcon
            
            // 錄音信息
            VStack(alignment: .leading, spacing: 6) {
                Text(recording.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if showFullDetails {
                    // 詳細信息
                    HStack(spacing: 12) {
                        // 日期
                        Label(formatDate(recording.createdAt), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // 時長
                        if let duration = recording.duration, duration > 0 {
                            Label(formatDuration(duration), systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // 檔案大小
                        if let fileSize = recording.fileSize, fileSize > 0 {
                            Label(formatFileSize(fileSize), systemImage: "doc")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    // 簡略信息
                    Text(formatDate(recording.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.card.opacity(0.7))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // 根據錄音狀態顯示不同的圖標
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 50, height: 50)
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: statusImage)
                    .font(.system(size: 22))
                    .foregroundColor(statusColor)
            }
        }
    }
    
    // 根據錄音狀態返回適當的顏色
    private var statusColor: Color {
        guard let status = recording.status?.lowercased() else {
            return recording.transcription != nil ? .green : .blue
        }
        
        switch status {
        case "completed":
            return .green
        case "failed", "error":
            return .red
        case "processing", "uploading":
            return .orange
        default:
            return .blue
        }
    }
    
    // 根據錄音狀態返回適當的圖標
    private var statusImage: String {
        guard let status = recording.status?.lowercased() else {
            return recording.transcription != nil ? "checkmark" : "waveform"
        }
        
        switch status {
        case "completed":
            return "checkmark"
        case "failed", "error":
            return "exclamationmark.triangle"
        case "processing", "uploading":
            return "arrow.clockwise"
        default:
            return "waveform"
        }
    }
    
    // 檢查錄音是否正在處理中
    private var isProcessing: Bool {
        guard let status = recording.status?.lowercased() else {
            return false
        }
        return ["processing", "uploading"].contains(status)
    }
    
    // 格式化日期顯示
    private func formatDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "今天 \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if calendar.dateComponents([.day], from: date, to: now).day! < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            formatter.locale = Locale(identifier: "zh_TW")
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
    }
    
    // 格式化時長顯示
    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // 格式化檔案大小顯示
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    VStack(spacing: 12) {
        RecordingRowView(recording: Recording(
            id: UUID(),
            title: "會議記錄 - 項目討論",
            originalFilename: "meeting_20241201.m4a",
            format: "m4a",
            mimeType: "audio/m4a",
            duration: 1245.0,
            createdAt: Date(),
            transcription: "這是測試逐字稿...",
            summary: "這是測試摘要...",
            fileURL: nil,
            fileSize: 1024 * 1024,
            status: "completed"
        ))
        
        RecordingRowView(recording: Recording(
            id: UUID(),
            title: "客戶訪談",
            originalFilename: "interview.wav",
            format: "wav",
            mimeType: "audio/wav",
            duration: 890.0,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            transcription: "這是測試逐字稿...",
            summary: "這是測試摘要...",
            fileURL: nil,
            fileSize: 512 * 1024,
            status: "processing"
        ))
        
        RecordingRowView(recording: Recording(
            id: UUID(),
            title: "失敗的錄音",
            originalFilename: "failed.wav",
            format: "wav",
            mimeType: "audio/wav",
            duration: nil,
            createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            transcription: nil,
            summary: nil,
            fileURL: nil,
            fileSize: 256 * 1024,
            status: "failed"
        ))
    }
    .padding()
    .background(AppTheme.Colors.background)
} 