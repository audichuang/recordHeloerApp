import SwiftUI

struct RecordingDetailView: View {
    let recording: Recording
    @State private var selectedTab = 0
    @State private var showingShareSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 錄音資訊卡片
            recordingInfoCard
            
            // 標籤切換
            tabSelector
            
            // 內容區域
            TabView(selection: $selectedTab) {
                transcriptionView
                    .tag(0)
                
                summaryView
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle(recording.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                shareButton
            }
        }
    }
    
    private var recordingInfoCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    
                    Text(recording.fileName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                InfoItem(icon: "clock", title: "時長", value: recording.formattedDuration)
                InfoItem(icon: "calendar", title: "日期", value: recording.formattedDate)
                InfoItem(icon: "doc", title: "大小", value: recording.formattedFileSize)
                if let status = recording.status {
                    InfoItem(icon: statusIcon, title: "狀態", value: recording.statusText)
                        .foregroundColor(statusColor)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(15)
        .padding(.horizontal)
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            Button(action: { selectedTab = 0 }) {
                VStack(spacing: 8) {
                    Text("逐字稿")
                        .font(.headline)
                        .fontWeight(selectedTab == 0 ? .bold : .medium)
                    
                    Rectangle()
                        .frame(height: 3)
                        .foregroundColor(selectedTab == 0 ? Color.blue : Color.clear)
                }
            }
            .foregroundColor(selectedTab == 0 ? .blue : .secondary)
            .frame(maxWidth: .infinity)
            
            Button(action: { selectedTab = 1 }) {
                VStack(spacing: 8) {
                    Text("摘要")
                        .font(.headline)
                        .fontWeight(selectedTab == 1 ? .bold : .medium)
                    
                    Rectangle()
                        .frame(height: 3)
                        .foregroundColor(selectedTab == 1 ? Color.blue : Color.clear)
                }
            }
            .foregroundColor(selectedTab == 1 ? .blue : .secondary)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var transcriptionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(.blue)
                    Text("完整逐字稿")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                
                if let transcription = recording.transcription, !transcription.isEmpty {
                    Text(transcription)
                        .font(.body)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                } else {
                    notAvailableMessage(
                        title: "逐字稿尚未生成",
                        message: "該錄音的逐字稿尚未生成或處理中，請稍後再查看。",
                        icon: "doc.text.magnifyingglass",
                        color: .blue
                    )
                }
            }
            .padding()
        }
    }
    
    private var summaryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "list.bullet.clipboard")
                        .foregroundColor(.green)
                    Text("智能摘要")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                
                if let summary = recording.summary, !summary.isEmpty {
                    // 使用MarkdownText組件渲染摘要
                    MarkdownText(content: summary)
                        .textSelection(.enabled)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                                )
                        )
                    
                    // 統計資訊
                    if let transcription = recording.transcription, !transcription.isEmpty {
                        VStack(spacing: 12) {
                            HStack {
                                Text("分析統計")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            
                            HStack(spacing: 16) {
                                StatCard(title: "原文字數", value: "\(transcription.count)", icon: "textformat.123")
                                StatCard(title: "摘要字數", value: "\(summary.count)", icon: "doc.text")
                                StatCard(title: "壓縮比", value: String(format: "%.1f%%", Double(summary.count) / Double(transcription.count) * 100), icon: "arrow.down.circle")
                            }
                        }
                        .padding(.top)
                    }
                } else {
                    notAvailableMessage(
                        title: "摘要尚未生成",
                        message: "該錄音的智能摘要尚未生成或處理中，請稍後再查看。",
                        icon: "doc.text.viewfinder",
                        color: .green
                    )
                }
            }
            .padding()
        }
    }
    
    private func notAvailableMessage(title: String, message: String, icon: String, color: Color) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .padding(.horizontal)
        .background(color.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var shareButton: some View {
        Button(action: {
            showingShareSheet = true
        }) {
            Image(systemName: "square.and.arrow.up")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [
                "錄音分析結果",
                "標題: \(recording.title)",
                "逐字稿: \(recording.transcription ?? "尚未生成")",
                "摘要: \(recording.summary ?? "尚未生成")"
            ])
        }
    }
    
    private var statusIcon: String {
        guard let status = recording.status else { return "questionmark.circle" }
        
        switch status.lowercased() {
        case "completed":
            return "checkmark.circle"
        case "processing":
            return "gear"
        case "failed":
            return "exclamationmark.triangle"
        case "pending":
            return "clock"
        default:
            return "questionmark.circle"
        }
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

struct InfoItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationView {
        RecordingDetailView(recording: Recording(
            title: "會議記錄 - 項目進度討論",
            fileName: "meeting_20241201.m4a",
            duration: 1245.0,
            createdAt: Date(),
            transcription: "今天的會議主要討論了項目的進度情況。我們已經完成了第一階段的開發工作，目前正在進行測試階段。預計下週可以完成所有測試工作，然後進入第二階段的開發。在討論過程中，我們也識別了一些潛在的風險和挑戰，需要在接下來的工作中特別注意。團隊成員都表示對目前的進度感到滿意，並且對後續的工作安排有清晰的了解。",
            summary: "會議摘要：討論項目進度，第一階段開發完成，正在測試中，預計下週完成測試並進入第二階段。識別了風險和挑戰，團隊對進度滿意。",
            fileURL: nil,
            fileSize: 2048000,
            status: "completed"
        ))
    }
} 