import SwiftUI

struct AnalysisHistoryView: View {
    let recordingId: String
    let analysisType: AnalysisType
    
    @State private var historyItems: [AnalysisHistory] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var selectedItem: AnalysisHistory?
    @State private var showDetailSheet = false
    
    @Environment(\.dismiss) private var dismiss
    private let networkService = NetworkService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                if isLoading {
                    ModernLoadingView(
                        title: "載入中",
                        message: "正在獲取歷史記錄",
                        icon: "clock.arrow.circlepath",
                        gradient: analysisType == .transcription ? AppTheme.Gradients.primary : AppTheme.Gradients.success
                    )
                } else if let error = loadError {
                    ModernErrorView(error: error) {
                        Task {
                            await loadHistory()
                        }
                    }
                } else if historyItems.isEmpty {
                    ModernEmptyStateView(
                        title: "無歷史記錄",
                        message: "尚未有任何\(analysisType.displayName)的歷史版本",
                        icon: "clock.badge.xmark",
                        gradient: analysisType == .transcription ? AppTheme.Gradients.primary : AppTheme.Gradients.success
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(historyItems) { item in
                                HistoryItemCard(
                                    item: item,
                                    analysisType: analysisType
                                ) {
                                    selectedItem = item
                                    showDetailSheet = true
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("\(analysisType.displayName)歷史記錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadHistory()
        }
        .sheet(isPresented: $showDetailSheet) {
            if let item = selectedItem {
                HistoryDetailView(history: item, analysisType: analysisType)
            }
        }
    }
    
    private func loadHistory() async {
        await MainActor.run {
            isLoading = true
            loadError = nil
        }
        
        do {
            let history = try await networkService.getAnalysisHistory(
                recordingId: recordingId,
                analysisType: analysisType
            )
            
            await MainActor.run {
                self.historyItems = history.sorted { $0.version > $1.version }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - History Item Card
struct HistoryItemCard: View {
    let item: AnalysisHistory
    let analysisType: AnalysisType
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            AnimatedCardView(
                title: "版本 \(item.version)",
                icon: item.isCurrent ? "star.fill" : "clock",
                gradient: item.isCurrent ? 
                    (analysisType == .transcription ? AppTheme.Gradients.primary : AppTheme.Gradients.success) :
                    [AppTheme.Colors.cardHighlight.opacity(0.3), AppTheme.Colors.cardHighlight],
                delay: 0.0
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    // 狀態和提供者
                    HStack {
                        StatusBadge(status: item.status.rawValue, color: item.status.color)
                        
                        Spacer()
                        
                        ProviderBadge(provider: item.provider)
                        
                        if item.isCurrent {
                            CurrentBadge()
                        }
                    }
                    
                    // 詳細資訊
                    HStack(spacing: 20) {
                        InfoItem(
                            icon: "calendar",
                            text: item.formattedCreatedAt
                        )
                        
                        if let score = item.confidenceScore {
                            InfoItem(
                                icon: "percent",
                                text: String(format: "%.1f%%", score * 100)
                            )
                        }
                        
                        if let time = item.processingTime {
                            InfoItem(
                                icon: "timer",
                                text: String(format: "%.1fs", time)
                            )
                        }
                    }
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    // 內容預覽
                    if !item.content.isEmpty && item.status == .completed {
                        Text(item.content)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(3)
                            .padding(.top, 4)
                    }
                    
                    // 錯誤訊息
                    if let error = item.errorMessage, item.status == .failed {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.error)
                            
                            Text(error)
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.error)
                                .lineLimit(2)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - History Detail View
struct HistoryDetailView: View {
    let history: AnalysisHistory
    let analysisType: AnalysisType
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 基本資訊卡片
                    AnimatedCardView(
                        title: "版本資訊",
                        icon: "info.circle.fill",
                        gradient: analysisType == .transcription ? AppTheme.Gradients.primary : AppTheme.Gradients.success,
                        delay: 0.1
                    ) {
                        VStack(spacing: 16) {
                            DetailRow(label: "版本號", value: String(history.version))
                            DetailRow(label: "狀態", value: history.status.displayName)
                            DetailRow(label: "提供者", value: history.provider.capitalized)
                            DetailRow(label: "語言", value: history.language.uppercased())
                            DetailRow(label: "建立時間", value: history.formattedCreatedAt)
                            
                            if let score = history.confidenceScore {
                                DetailRow(label: "信心度", value: String(format: "%.1f%%", score * 100))
                            }
                            
                            if let time = history.processingTime {
                                DetailRow(label: "處理時間", value: String(format: "%.2f 秒", time))
                            }
                            
                            if history.isCurrent {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(AppTheme.Colors.warning)
                                    Text("當前使用版本")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppTheme.Colors.warning)
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                    
                    // 內容卡片
                    if !history.content.isEmpty && history.status == .completed {
                        AnimatedCardView(
                            title: analysisType.displayName + "內容",
                            icon: analysisType == .transcription ? "text.alignleft" : "list.bullet.clipboard",
                            gradient: analysisType == .transcription ? AppTheme.Gradients.primary : AppTheme.Gradients.success,
                            delay: 0.2
                        ) {
                            ContentDisplayView(
                                content: history.content,
                                type: analysisType == .transcription ? .transcription : .summary
                            )
                        }
                    }
                    
                    // 錯誤資訊卡片
                    if let error = history.errorMessage, history.status == .failed {
                        AnimatedCardView(
                            title: "錯誤資訊",
                            icon: "exclamationmark.triangle.fill",
                            gradient: [AppTheme.Colors.error, AppTheme.Colors.error.opacity(0.8)],
                            delay: 0.3
                        ) {
                            Text(error)
                                .font(.body)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("版本 \(history.version) 詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct StatusBadge: View {
    let status: String
    let color: Color
    
    var body: some View {
        Text(statusDisplay)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(AppTheme.CornerRadius.small)
    }
    
    private var statusDisplay: String {
        switch status.uppercased() {
        case "COMPLETED": return "已完成"
        case "PROCESSING": return "處理中"
        case "FAILED": return "失敗"
        default: return status
        }
    }
}

struct ProviderBadge: View {
    let provider: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: providerIcon)
                .font(.caption)
            Text(provider.capitalized)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.Colors.info.opacity(0.2))
        .foregroundColor(AppTheme.Colors.info)
        .cornerRadius(AppTheme.CornerRadius.small)
    }
    
    private var providerIcon: String {
        switch provider.lowercased() {
        case "openai": return "brain"
        case "deepgram": return "waveform"
        case "gemini": return "sparkle"
        case "whisper": return "mic.circle"
        default: return "server.rack"
        }
    }
}

struct CurrentBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption)
            Text("當前")
                .font(.caption)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.Colors.warning.opacity(0.2))
        .foregroundColor(AppTheme.Colors.warning)
        .cornerRadius(AppTheme.CornerRadius.small)
    }
}

struct InfoItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
    }
}

// MARK: - Preview
#Preview {
    AnalysisHistoryView(
        recordingId: UUID().uuidString,
        analysisType: .transcription
    )
}