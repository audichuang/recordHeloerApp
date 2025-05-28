import SwiftUI

struct RecordingRowView: View {
    let recording: Recording
    
    var body: some View {
        HStack(spacing: 16) {
            // 圖標和狀態
            ZStack {
                Image(systemName: "waveform")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                if let status = recording.status, status.lowercased() != "completed" {
                    VStack {
                        Spacer()
                        Text(recording.statusText)
                            .font(.system(size: 8))
                            .padding(2)
                            .background(statusColor)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
            }
            
            // 錄音資訊
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.title)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Text(recording.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Label(recording.formattedDuration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(recording.formattedFileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 右側箭頭
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        guard let status = recording.status else { return .gray }
        
        switch status.lowercased() {
        case "completed":
            return .green
        case "processing":
            return .orange
        case "failed":
            return .red
        case "pending":
            return .blue
        default:
            return .gray
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        RecordingRowView(recording: Recording(
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
} 