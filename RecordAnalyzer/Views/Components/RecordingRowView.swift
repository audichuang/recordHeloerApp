import SwiftUI

// MARK: - 錄音列表項目（簡約版）
struct RecordingRowView: View {
    let recording: Recording
    let showDate: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    init(
        recording: Recording,
        showDate: Bool = true,
        onTap: @escaping () -> Void = {}
    ) {
        self.recording = recording
        self.showDate = showDate
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.m) {
                // 狀態指示器
                statusIndicator
                
                // 內容
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(recording.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: AppTheme.Spacing.s) {
                        // 時長
                        Label(formatDuration(recording.duration ?? 0), systemImage: "clock.fill")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        if showDate {
                            Text("•")
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            // 日期
                            Text(formatDate(recording.createdAt))
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        
                        // 狀態標籤
                        if recording.status == "processing" {
                            statusBadge
                        }
                    }
                }
                
                Spacer()
                
                // 箭頭
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .opacity(0.6)
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.vertical, AppTheme.Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .fill(isPressed ? AppTheme.Colors.surfaceLight : Color.clear)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(AppTheme.Animation.quick) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
    
    // MARK: - 狀態指示器
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.1))
                .frame(width: 40, height: 40)
            
            if recording.status == "processing" {
                // 處理中動畫
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(statusColor, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .rotationEffect(Angle(degrees: isPressed ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 1)
                            .repeatForever(autoreverses: false),
                        value: isPressed
                    )
            } else {
                Image(systemName: statusIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(statusColor)
            }
        }
    }
    
    // MARK: - 狀態標籤
    private var statusBadge: some View {
        Text("處理中")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.Colors.warning)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.warning.opacity(0.1))
            )
    }
    
    // MARK: - 計算屬性
    private var statusIcon: String {
        switch recording.status {
        case "completed":
            return "checkmark"
        case "failed":
            return "exclamationmark"
        case "processing":
            return "arrow.triangle.2.circlepath"
        default:
            return "circle"
        }
    }
    
    private var statusColor: Color {
        switch recording.status {
        case "completed":
            return AppTheme.Colors.success
        case "failed":
            return AppTheme.Colors.error
        case "processing":
            return AppTheme.Colors.warning
        default:
            return AppTheme.Colors.textTertiary
        }
    }
    
    // MARK: - 格式化方法
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 簡化版錄音項目
struct CompactRecordingRow: View {
    let recording: Recording
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            // 小圓點狀態
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            // 標題
            Text(recording.title)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(1)
            
            Spacer()
            
            // 時長
            Text(formatDuration(recording.duration ?? 0))
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }
    
    private var statusColor: Color {
        switch recording.status {
        case "completed":
            return AppTheme.Colors.success
        case "failed":
            return AppTheme.Colors.error
        case "processing":
            return AppTheme.Colors.warning
        default:
            return AppTheme.Colors.textTertiary
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - 預覽
struct RecordingRowView_Previews: PreviewProvider {
    static let sampleRecording = Recording(
        id: UUID(),
        title: "會議錄音 2024-01-15",
        originalFilename: "meeting.m4a",
        format: "m4a",
        mimeType: "audio/m4a",
        duration: 125.5,
        createdAt: Date(),
        transcription: "這是一段測試文字",
        summary: "測試摘要",
        fileURL: URL(string: "https://example.com/meeting.m4a"),
        fileSize: 2048000,
        status: "completed"
    )
    
    static var previews: some View {
        VStack(spacing: AppTheme.Spacing.l) {
            // 標準列表項
            RecordingRowView(recording: sampleRecording) {
                print("Tapped")
            }
            
            // 處理中狀態
            RecordingRowView(
                recording: Recording(
                    id: UUID(),
                    title: "正在處理的錄音",
                    originalFilename: "processing.m4a",
                    format: "m4a",
                    mimeType: "audio/m4a",
                    duration: 60,
                    createdAt: Date(),
                    transcription: nil,
                    summary: nil,
                    fileURL: nil,
                    fileSize: 1024000,
                    status: "processing"
                )
            ) {}
            
            // 失敗狀態
            RecordingRowView(
                recording: Recording(
                    id: UUID(),
                    title: "處理失敗的錄音",
                    originalFilename: "failed.m4a",
                    format: "m4a",
                    mimeType: "audio/m4a",
                    duration: 30,
                    createdAt: Date(),
                    transcription: nil,
                    summary: nil,
                    fileURL: nil,
                    fileSize: 512000,
                    status: "failed"
                )
            ) {}
            
            Divider()
            
            // 精簡版
            CompactRecordingRow(recording: sampleRecording)
        }
        .padding()
        .background(AppTheme.Colors.background)
    }
}