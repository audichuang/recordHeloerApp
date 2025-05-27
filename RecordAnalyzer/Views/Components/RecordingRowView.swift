import SwiftUI

struct RecordingRowView: View {
    let recording: Recording
    
    var body: some View {
        HStack(spacing: 16) {
            // 圖標
            Image(systemName: "waveform")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
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
                    
                    Text(recording.fileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
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
}

#Preview {
    VStack(spacing: 12) {
        RecordingRowView(recording: Recording(
            title: "會議記錄 - 項目討論",
            fileName: "meeting_20241201.m4a",
            duration: 1245.0,
            createdAt: Date(),
            transcription: "這是測試逐字稿...",
            summary: "這是測試摘要...",
            fileURL: nil
        ))
        
        RecordingRowView(recording: Recording(
            title: "客戶訪談",
            fileName: "interview.wav",
            duration: 890.0,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            transcription: "這是測試逐字稿...",
            summary: "這是測試摘要...",
            fileURL: nil
        ))
    }
    .padding()
} 