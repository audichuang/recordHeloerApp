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
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 自定義導航欄
                HStack {
                    Button("關閉") {
                        dismiss()
                    }
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.primary)
                    
                    Spacer()
                    
                    Text("\(analysisType.displayName)歷史記錄")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // 佔位符，保持標題居中
                    Button("關閉") {
                        dismiss()
                    }
                    .font(.body)
                    .opacity(0)
                    .disabled(true)
                }
                .padding()
                .background(AppTheme.Colors.card)
                
                Divider()
                    .background(AppTheme.Colors.divider)
                
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
                                    analysisType: analysisType,
                                    onTap: {
                                        selectedItem = item
                                        showDetailSheet = true
                                    },
                                    onSetCurrent: {
                                        Task {
                                            await setAsCurrentVersion(item)
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
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
    
    // MARK: - Methods
    private func setAsCurrentVersion(_ item: AnalysisHistory) async {
        print("🔄 開始設置版本 \(item.version) 為當前版本")
        
        await MainActor.run {
            isLoading = true
            loadError = nil
        }
        
        do {
            print("📡 調用 API 設置當前版本: \(item.id.uuidString)")
            try await networkService.setCurrentAnalysisVersion(historyId: item.id.uuidString)
            
            print("✅ API 調用成功，重新加載歷史記錄")
            // 重新加載歷史記錄
            await loadHistory()
            
            // 發送通知，讓 RecordingDetailView 重新加載數據
            await MainActor.run {
                print("📢 發送版本變更通知")
                NotificationCenter.default.post(
                    name: NSNotification.Name("AnalysisVersionChanged"),
                    object: nil,
                    userInfo: [
                        "recordingId": item.recordingId.uuidString,
                        "analysisType": analysisType.rawValue
                    ]
                )
            }
        } catch {
            print("❌ 設置當前版本失敗: \(error.localizedDescription)")
            await MainActor.run {
                loadError = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func loadHistory() async {
        print("🔍 loadHistory 開始 - analysisType: \(analysisType.rawValue)")
        
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
                
                // 調試：打印每個項目的詳細信息
                for item in self.historyItems {
                    print("📋 歷史項目 - 版本: \(item.version), 狀態: \(item.status.rawValue), 當前: \(item.isCurrent)")
                }
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
    let onSetCurrent: () -> Void
    
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                HStack {
                    Image(systemName: item.isCurrent ? "star.fill" : "clock")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(item.isCurrent ? 
                            (analysisType == .transcription ? AppTheme.Colors.primary : AppTheme.Colors.success) :
                            AppTheme.Colors.textSecondary)
                    Text("版本 \(item.version)")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 12) {
                // 狀態和提供者
                HStack {
                    StatusBadge(status: item.status.rawValue, color: item.status.color)
                    
                    Spacer()
                    
                    ProviderBadge(provider: item.provider)
                    
                    if item.isCurrent {
                        CurrentBadge()
                    } else if item.status == .completed {
                        // 只有已完成且不是當前版本的才顯示切換按鈕
                        Button(action: {
                            print("🔄 點擊設為當前按鈕 - 版本 \(item.version)")
                            onSetCurrent()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                                Text("設為當前")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.Colors.primary.opacity(0.2))
                            .foregroundColor(AppTheme.Colors.primary)
                            .cornerRadius(AppTheme.CornerRadius.small)
                        }
                        .buttonStyle(BorderlessButtonStyle()) // 使用 BorderlessButtonStyle 避免按鈕事件被父視圖攔截
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
        .onTapGesture {
            // 只有在點擊卡片的非按鈕區域時才觸發
            onTap()
        }
    }
}

// MARK: - History Detail View
struct HistoryDetailView: View {
    let history: AnalysisHistory
    let analysisType: AnalysisType
    
    @Environment(\.dismiss) private var dismiss
    @State private var showSwitchVersionAlert = false
    @State private var isSwitchingVersion = false
    @State private var switchError: String?
    private let networkService = NetworkService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 基本資訊卡片
                    ModernCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(analysisType == .transcription ? AppTheme.Colors.primary : AppTheme.Colors.success)
                                Text("版本資訊")
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                            }
                            
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
                    }
                    
                    // 內容卡片
                    if !history.content.isEmpty && history.status == .completed {
                        ModernCard {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                                HStack {
                                    Image(systemName: analysisType == .transcription ? "text.alignleft" : "list.bullet.clipboard")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(analysisType == .transcription ? AppTheme.Colors.primary : AppTheme.Colors.success)
                                    Text(analysisType.displayName + "內容")
                                        .font(.system(size: 18, weight: .semibold))
                                    Spacer()
                                }
                                ContentDisplayView(
                                    content: history.content,
                                    type: analysisType == .transcription ? .transcription : .summary
                                )
                            }
                        }
                    }
                    
                    // 錯誤資訊卡片
                    if let error = history.errorMessage, history.status == .failed {
                        ModernCard {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.error)
                                    Text("錯誤資訊")
                                        .font(.system(size: 18, weight: .semibold))
                                    Spacer()
                                }
                                Text(error)
                                    .font(.body)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .multilineTextAlignment(.leading)
                            }
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
                
                // 只有當不是當前版本且狀態為已完成時，才顯示切換版本按鈕
                if !history.isCurrent && history.status == .completed {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showSwitchVersionAlert = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("使用此版本")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                        }
                        .disabled(isSwitchingVersion)
                    }
                }
            }
            .alert("切換版本", isPresented: $showSwitchVersionAlert) {
                Button("取消", role: .cancel) { }
                Button("確定", role: .destructive) {
                    Task {
                        await switchToThisVersion()
                    }
                }
            } message: {
                Text("確定要將此版本設為當前使用的\(analysisType.displayName)嗎？")
            }
            .overlay {
                if isSwitchingVersion {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    ModernLoadingView(
                        title: "切換中",
                        message: "正在切換版本...",
                        icon: "arrow.triangle.2.circlepath",
                        gradient: analysisType == .transcription ? AppTheme.Gradients.primary : AppTheme.Gradients.success
                    )
                }
            }
        }
    }
    
    // MARK: - Methods
    private func switchToThisVersion() async {
        await MainActor.run {
            isSwitchingVersion = true
            switchError = nil
        }
        
        do {
            try await networkService.setCurrentAnalysisVersion(historyId: history.id.uuidString)
            
            await MainActor.run {
                isSwitchingVersion = false
                // 發送通知，讓 RecordingDetailView 重新加載數據
                NotificationCenter.default.post(
                    name: NSNotification.Name("AnalysisVersionChanged"),
                    object: nil,
                    userInfo: [
                        "recordingId": history.recordingId.uuidString,
                        "analysisType": analysisType.rawValue
                    ]
                )
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSwitchingVersion = false
                switchError = error.localizedDescription
                // 顯示錯誤提示
                showSwitchVersionAlert = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showSwitchVersionAlert = true
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
        switch status.lowercased() {
        case "completed": return "已完成"
        case "processing": return "處理中"
        case "failed": return "失敗"
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