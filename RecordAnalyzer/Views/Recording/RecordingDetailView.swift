import SwiftUI

struct RecordingDetailView: View {
    let recording: Recording
    @State private var selectedTab = 0
    @State private var showingShareSheet = false
    @State private var detailRecording: Recording
    @State private var isLoadingDetail = false
    @State private var loadError: String?
    @EnvironmentObject var recordingManager: RecordingManager
    
    private let networkService = NetworkService.shared
    
    init(recording: Recording) {
        self.recording = recording
        self._detailRecording = State(initialValue: recording)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // 錄音資訊卡片
                AnimatedCardView(
                    title: "錄音資訊",
                    icon: "waveform.circle.fill",
                    gradient: AppTheme.Gradients.primary,
                    delay: 0.1
                ) {
                    recordingInfoContent
                }
                
                // 標籤切換卡片
                AnimatedCardView(
                    title: "內容選擇",
                    icon: "square.grid.2x2",
                    gradient: AppTheme.Gradients.info,
                    delay: 0.2
                ) {
                    tabSelectorContent
                }
                
                // 內容區域
                if selectedTab == 0 {
                    transcriptionCard
                } else {
                    summaryCard
                }
            }
            .padding()
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(detailRecording.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                shareButton
            }
        }
        .onAppear {
            // 立即顯示現有內容，不阻塞UI
            syncWithRecordingManager()
            
            // 檢查是否需要載入完整詳細內容
            let needsDetailLoading = checkIfNeedsDetailLoading()
            
            if needsDetailLoading {
                print("📱 DetailView首次載入，在背景中獲取完整內容")
                // 不設置 isLoadingDetail = true，避免阻塞UI
                Task {
                    await loadRecordingDetailInBackground()
                }
            } else {
                print("📱 DetailView已有完整內容，無需重新載入")
            }
        }
        .onChange(of: recordingManager.recordings) { _, newRecordings in
            // 只在狀態變化時同步，避免覆蓋詳細內容
            if let updatedRecording = newRecordings.first(where: { $0.id == detailRecording.id }),
               updatedRecording.status != detailRecording.status {
                print("📱 檢測到錄音狀態變化，同步更新")
                syncWithRecordingManager()
                
                // 如果狀態變為已完成且沒有完整內容，重新載入詳情
                if updatedRecording.status == "completed" && checkIfNeedsDetailLoading() {
                    print("📱 錄音處理完成，載入完整內容")
                    isLoadingDetail = true
                    Task {
                        await loadRecordingDetail()
                    }
                }
            }
        }
        .refreshable {
            await loadRecordingDetail()
        }
    }
    
    /// 與 RecordingManager 中的數據同步
    private func syncWithRecordingManager() {
        if let updatedRecording = recordingManager.recordings.first(where: { $0.id == detailRecording.id }) {
            let oldStatus = detailRecording.status
            
            // 直接使用 RecordingManager 中的最新數據
            detailRecording = updatedRecording
            
            // 如果狀態從處理中變為已完成，且內容為空，則立即顯示載入狀態並重新載入
            if oldStatus != "completed" && updatedRecording.status == "completed" {
                let hasTranscription = !(updatedRecording.transcription?.isEmpty ?? true) && updatedRecording.transcription != "可用"
                let hasSummary = !(updatedRecording.summary?.isEmpty ?? true) && updatedRecording.summary != "可用"
                
                if !hasTranscription || !hasSummary {
                    isLoadingDetail = true
                    Task {
                        await loadRecordingDetail()
                    }
                }
            }
        }
    }
    
    /// 載入完整錄音詳情
    private func loadRecordingDetail() async {
        await MainActor.run {
            isLoadingDetail = true
            loadError = nil
        }
        
        do {
            let fullRecording = try await networkService.getRecordingDetail(id: detailRecording.id.uuidString)
            
            await MainActor.run {
                self.detailRecording = fullRecording
                self.isLoadingDetail = false
                
                // 同步更新的詳細資料到 RecordingManager
                self.updateRecordingInManager(fullRecording)
            }
        } catch {
            await MainActor.run {
                self.loadError = error.localizedDescription
                self.isLoadingDetail = false
            }
        }
    }
    
    /// 在背景載入完整錄音詳情（不阻塞UI）
    private func loadRecordingDetailInBackground() async {
        await MainActor.run {
            loadError = nil
        }
        
        do {
            let fullRecording = try await networkService.getRecordingDetail(id: detailRecording.id.uuidString)
            
            await MainActor.run {
                // 平滑更新內容，不顯示載入狀態
                self.detailRecording = fullRecording
                
                // 同步更新的詳細資料到 RecordingManager
                self.updateRecordingInManager(fullRecording)
                
                print("📱 背景載入完成，內容已更新")
            }
        } catch {
            await MainActor.run {
                self.loadError = error.localizedDescription
                print("❌ 背景載入失敗: \(error.localizedDescription)")
            }
        }
    }
    
    /// 將更新的錄音詳情同步到 RecordingManager
    private func updateRecordingInManager(_ updatedRecording: Recording) {
        if let index = recordingManager.recordings.firstIndex(where: { $0.id == updatedRecording.id }) {
            recordingManager.recordings[index] = updatedRecording
        }
    }
    
    private var recordingInfoContent: some View {
        VStack(spacing: 20) {
            // 檔案基本資訊
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(detailRecording.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(2)
                        
                        Text(detailRecording.fileName)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    // 狀態指示器
                    StatusIndicator(
                        status: detailRecording.status ?? "unknown",
                        isLoading: isLoadingDetail
                    )
                }
            }
            
            // 詳細資訊格子
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ModernInfoCard(icon: "clock", title: "時長", value: detailRecording.formattedDuration, color: AppTheme.Colors.info)
                ModernInfoCard(icon: "calendar", title: "日期", value: detailRecording.formattedDate, color: AppTheme.Colors.secondary)
                ModernInfoCard(icon: "doc", title: "大小", value: detailRecording.formattedFileSize, color: AppTheme.Colors.success)
            }
        }
    }
    
    private var tabSelectorContent: some View {
        HStack(spacing: 12) {
            TabButton(
                title: "逐字稿",
                icon: "text.alignleft",
                isSelected: selectedTab == 0,
                gradient: AppTheme.Gradients.primary
            ) {
                withAnimation(AppTheme.Animation.standard) {
                    selectedTab = 0
                }
            }
            
            TabButton(
                title: "摘要",
                icon: "list.bullet.clipboard",
                isSelected: selectedTab == 1,
                gradient: AppTheme.Gradients.success
            ) {
                withAnimation(AppTheme.Animation.standard) {
                    selectedTab = 1
                }
            }
        }
    }
    
    private var transcriptionCard: some View {
        AnimatedCardView(
            title: "完整逐字稿",
            icon: "text.alignleft",
            gradient: AppTheme.Gradients.primary,
            delay: 0.3
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if let transcription = detailRecording.transcription, !transcription.isEmpty {
                    if transcription == "可用" {
                        // 顯示背景載入狀態
                        ModernLoadingView(
                            title: "正在載入逐字稿",
                            message: "正在從伺服器獲取完整的逐字稿內容",
                            icon: "text.alignleft",
                            gradient: AppTheme.Gradients.primary
                        )
                    } else {
                        // 優化的文本顯示
                        ContentDisplayView(content: transcription, type: .transcription)
                    }
                } else if isLoadingDetail {
                    ModernLoadingView(
                        title: "正在載入",
                        message: "請稍候，正在獲取內容",
                        icon: "text.alignleft",
                        gradient: AppTheme.Gradients.primary
                    )
                } else if let error = loadError {
                    ModernErrorView(error: error) {
                        Task {
                            await loadRecordingDetail()
                        }
                    }
                } else {
                    ModernEmptyStateView(
                        title: "逐字稿尚未生成",
                        message: "該錄音的逐字稿尚未生成或處理中",
                        icon: "doc.text.magnifyingglass",
                        gradient: AppTheme.Gradients.primary
                    )
                }
            }
        }
    }
    
    private var summaryCard: some View {
        VStack(spacing: 20) {
            AnimatedCardView(
                title: "智能摘要",
                icon: "list.bullet.clipboard",
                gradient: AppTheme.Gradients.success,
                delay: 0.3
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    if let summary = detailRecording.summary, !summary.isEmpty {
                        if summary == "可用" {
                            ModernLoadingView(
                                title: "正在載入摘要",
                                message: "正在從伺服器獲取智能摘要內容",
                                icon: "list.bullet.clipboard",
                                gradient: AppTheme.Gradients.success
                            )
                        } else {
                            ContentDisplayView(content: summary, type: .summary)
                        }
                    } else if isLoadingDetail {
                        ModernLoadingView(
                            title: "正在載入",
                            message: "請稍候，正在獲取內容",
                            icon: "list.bullet.clipboard",
                            gradient: AppTheme.Gradients.success
                        )
                    } else if let error = loadError {
                        ModernErrorView(error: error) {
                            Task {
                                await loadRecordingDetail()
                            }
                        }
                    } else {
                        ModernEmptyStateView(
                            title: "摘要尚未生成",
                            message: "該錄音的智能摘要尚未生成或處理中",
                            icon: "doc.text.viewfinder",
                            gradient: AppTheme.Gradients.success
                        )
                    }
                }
            }
            
            // 統計資訊卡片
            if let summary = detailRecording.summary,
               let transcription = detailRecording.transcription,
               !summary.isEmpty, !transcription.isEmpty,
               summary != "可用", transcription != "可用",
               summary.count > 0 && transcription.count > 0 {
                
                AnimatedCardView(
                    title: "分析統計",
                    icon: "chart.bar.fill",
                    gradient: AppTheme.Gradients.warning,
                    delay: 0.4
                ) {
                    statisticsContent(transcription: transcription, summary: summary)
                }
            }
        }
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
                "標題: \(detailRecording.title)",
                "逐字稿: \(detailRecording.transcription ?? "尚未生成")",
                "摘要: \(detailRecording.summary ?? "尚未生成")"
            ])
        }
    }
    
    private func checkIfNeedsDetailLoading() -> Bool {
        let needsTranscription = detailRecording.transcription?.isEmpty ?? true || detailRecording.transcription == "可用"
        let needsSummary = detailRecording.summary?.isEmpty ?? true || detailRecording.summary == "可用"
        return needsTranscription || needsSummary
    }
    
    private func statisticsContent(transcription: String, summary: String) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ModernStatCard(
                title: "原文字數",
                value: "\(transcription.count)",
                icon: "textformat.123",
                gradient: AppTheme.Gradients.primary
            )
            
            ModernStatCard(
                title: "摘要字數",
                value: "\(summary.count)",
                icon: "doc.text",
                gradient: AppTheme.Gradients.success
            )
            
            ModernStatCard(
                title: "壓縮比",
                value: String(format: "%.1f%%", Double(summary.count) / Double(transcription.count) * 100),
                icon: "arrow.down.circle",
                gradient: AppTheme.Gradients.warning
            )
        }
    }
}

// MARK: - iOS 18 優化版 Markdown 摘要顯示組件

@available(iOS 18.0, *)
struct EnhancedMarkdownSummaryView: View {
    let content: String
    @State private var processedSections: [MarkdownSection] = []
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(Array(processedSections.enumerated()), id: \.offset) { index, section in
                MarkdownSectionView(section: section, index: index)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            AppTheme.Colors.success.opacity(0.06),
                            AppTheme.Colors.success.opacity(0.12)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.success.opacity(0.15), lineWidth: 1)
                )
        )
        .task {
            await processMarkdownContent()
        }
    }
    
    @MainActor
    private func processMarkdownContent() async {
        // 快速處理 Markdown 解析
        let sections = await Task.detached(priority: .userInitiated) {
            MarkdownProcessor.processSummaryContent(content)
        }.value
        
        processedSections = sections
    }
}

// MARK: - Markdown 處理器

struct MarkdownProcessor {
    static func processSummaryContent(_ content: String) -> [MarkdownSection] {
        var sections: [MarkdownSection] = []
        
        // 按行分割內容
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        for line in lines {
            let section = parseMarkdownLine(line)
            sections.append(section)
        }
        
        return sections
    }
    
    private static func parseMarkdownLine(_ line: String) -> MarkdownSection {
        // 標題檢測 (# ## ###)
        if line.hasPrefix("# ") {
            return MarkdownSection(
                type: .heading1,
                content: String(line.dropFirst(2).trimmingCharacters(in: .whitespaces)),
                rawContent: line
            )
        } else if line.hasPrefix("## ") {
            return MarkdownSection(
                type: .heading2,
                content: String(line.dropFirst(3).trimmingCharacters(in: .whitespaces)),
                rawContent: line
            )
        } else if line.hasPrefix("### ") {
            return MarkdownSection(
                type: .heading3,
                content: String(line.dropFirst(4).trimmingCharacters(in: .whitespaces)),
                rawContent: line
            )
        }
        // 項目符號檢測 (- * +)
        else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return MarkdownSection(
                type: .bulletPoint,
                content: String(line.dropFirst(2).trimmingCharacters(in: .whitespaces)),
                rawContent: line
            )
        }
        // 數字列表檢測 (1. 2. 3.)
        else if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            return MarkdownSection(
                type: .numberedList,
                content: String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces),
                rawContent: line
            )
        }
        // 一般段落
        else {
            return MarkdownSection(
                type: .paragraph,
                content: line,
                rawContent: line
            )
        }
    }
}

// MARK: - Markdown 資料模型

struct MarkdownSection: Equatable {
    let type: MarkdownType
    let content: String
    let rawContent: String
    
    static func == (lhs: MarkdownSection, rhs: MarkdownSection) -> Bool {
        return lhs.type == rhs.type && 
               lhs.content == rhs.content && 
               lhs.rawContent == rhs.rawContent
    }
}

enum MarkdownType: Equatable {
    case heading1
    case heading2
    case heading3
    case bulletPoint
    case numberedList
    case paragraph
}

// MARK: - Markdown 組件視圖

@available(iOS 18.0, *)
struct MarkdownSectionView: View {
    let section: MarkdownSection
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左側指示器
            leftIndicator
            
            // 主要內容
            VStack(alignment: .leading, spacing: 4) {
                contentView
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var leftIndicator: some View {
        switch section.type {
        case .heading1, .heading2, .heading3:
            RoundedRectangle(cornerRadius: 2)
                .fill(AppTheme.Colors.success.opacity(0.8))
                .frame(width: 4, height: 20)
                .padding(.top, 2)
            
        case .bulletPoint:
            Circle()
                .fill(AppTheme.Colors.success.opacity(0.7))
                .frame(width: 6, height: 6)
                .padding(.top, 8)
            
        case .numberedList:
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.Colors.success.opacity(0.2))
                .frame(width: 16, height: 16)
                .overlay(
                    Text("\(index + 1)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.success)
                )
                .padding(.top, 4)
            
        case .paragraph:
            Rectangle()
                .fill(AppTheme.Colors.success.opacity(0.3))
                .frame(width: 2, height: 12)
                .padding(.top, 6)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch section.type {
        case .heading1:
            Text(try! AttributedString(markdown: section.content))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
        case .heading2:
            Text(try! AttributedString(markdown: section.content))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
        case .heading3:
            Text(try! AttributedString(markdown: section.content))
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
        case .bulletPoint, .numberedList, .paragraph:
            Text(try! AttributedString(markdown: section.content))
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Markdown 骨架屏

@available(iOS 18.0, *)
struct MarkdownSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<6, id: \.self) { index in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(AppTheme.Colors.cardHighlight)
                        .frame(width: 6, height: 6)
                        .padding(.top, 8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Colors.cardHighlight)
                            .frame(height: 16)
                            .frame(maxWidth: CGFloat.random(in: 200...350))
                        
                        if index % 3 == 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppTheme.Colors.cardHighlight)
                                .frame(height: 16)
                                .frame(maxWidth: CGFloat.random(in: 150...250))
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - 相容性包裝器

struct UniversalSummaryView: View {
    let content: String
    
    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                EnhancedMarkdownSummaryView(content: content)
            } else {
                LegacySummaryView(content: content)
            }
        }
    }
}

// MARK: - iOS 18 以下的備用組件

struct LegacySummaryView: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(processContent().enumerated()), id: \.offset) { index, item in
                SummaryLineView(text: item, index: index)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            AppTheme.Colors.success.opacity(0.06),
                            AppTheme.Colors.success.opacity(0.12)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.success.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    private func processContent() -> [String] {
        return content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct SummaryLineView: View {
    let text: String
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 簡單的項目指示器
            Circle()
                .fill(AppTheme.Colors.success.opacity(0.7))
                .frame(width: 6, height: 6)
                .padding(.top, 8)
            
            // 內容文字
            Text(cleanText(text))
                .font(.body)
                .lineSpacing(5)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
    
    private func cleanText(_ text: String) -> String {
        // 移除常見的項目符號
        return text.replacingOccurrences(of: "^[•\\-\\*]\\s*", with: "", options: .regularExpression)
    }
}

// MARK: - 現代化組件

struct StatusIndicator: View {
    let status: String
    let isLoading: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(statusColor)
                } else {
                    Image(systemName: statusIcon)
                        .font(.system(size: 14))
                        .foregroundColor(statusColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("狀態")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text(statusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
            }
        }
    }
    
    private var statusIcon: String {
        switch status.lowercased() {
        case "completed": return "checkmark.circle.fill"
        case "processing": return "gear"
        case "failed": return "exclamationmark.triangle.fill"
        case "pending": return "clock.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "completed": return AppTheme.Colors.success
        case "processing": return AppTheme.Colors.warning
        case "failed": return AppTheme.Colors.error
        case "pending": return AppTheme.Colors.info
        default: return AppTheme.Colors.textSecondary
        }
    }
    
    private var statusText: String {
        switch status.lowercased() {
        case "completed": return "已完成"
        case "processing": return "處理中"
        case "failed": return "失敗"
        case "pending": return "等待中"
        default: return "未知"
        }
    }
}

struct ModernInfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .fill(color.opacity(0.05))
        )
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(isSelected ? 
                          LinearGradient(gradient: Gradient(colors: gradient), startPoint: .topLeading, endPoint: .bottomTrailing) :
                          LinearGradient(gradient: Gradient(colors: [AppTheme.Colors.cardHighlight]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: isSelected ? gradient[0].opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
            )
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModernLoadingView: View {
    let title: String
    let message: String
    let icon: String
    let gradient: [Color]
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(gradient[0].opacity(0.2), lineWidth: 3)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(gradient: Gradient(colors: gradient), startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(gradient[0])
            }
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(gradient[0])
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .onAppear {
            isAnimating = true
        }
    }
}

struct ModernEmptyStateView: View {
    let title: String
    let message: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(gradient[0].opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(gradient[0])
            }
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

struct ModernErrorView: View {
    let error: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.Colors.error)
            
            VStack(spacing: 8) {
                Text("載入失敗")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("重試") {
                retry()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.error)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

enum ContentType {
    case transcription
    case summary
}

struct ContentDisplayView: View {
    let content: String
    let type: ContentType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if type == .summary {
                // 使用新的優化摘要組件
                UniversalSummaryView(content: content)
            } else {
                // 轉錄文字保持原樣
                LazyVStack(alignment: .leading, spacing: 8) {
                    OptimizedTextView(content: content)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                        .fill(backgroundColorForType)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                .stroke(borderColorForType, lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var backgroundColorForType: Color {
        switch type {
        case .transcription:
            return AppTheme.Colors.primary.opacity(0.05)
        case .summary:
            return AppTheme.Colors.success.opacity(0.05)
        }
    }
    
    private var borderColorForType: Color {
        switch type {
        case .transcription:
            return AppTheme.Colors.primary.opacity(0.2)
        case .summary:
            return AppTheme.Colors.success.opacity(0.2)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 高性能文本視圖，支持大量文本的漸進加載
struct OptimizedTextView: View {
    let content: String
    @State private var visibleRange: Range<String.Index>?
    @State private var isInitialized = false
    
    private let initialChunkSize = 3000
    private let chunkSize = 2000
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let range = visibleRange {
                        Text(String(content[range]))
                            .font(.body)
                            .lineSpacing(6)
                            .textSelection(.enabled)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .id("content")
                    } else if !isInitialized {
                        // 骨架屏
                        SkeletonTextView()
                    }
                    
                    if shouldShowLoadMore {
                        Button("載入更多內容") {
                            loadMoreContent()
                        }
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(.top, 16)
                    }
                }
                .padding()
            }
        }
        .task {
            await initializeContent()
        }
    }
    
    private var shouldShowLoadMore: Bool {
        guard let range = visibleRange else { return false }
        return range.upperBound < content.endIndex
    }
    
    private func initializeContent() async {
        guard !content.isEmpty else { return }
        
        let endIndex = content.index(content.startIndex, offsetBy: min(initialChunkSize, content.count))
        
        await MainActor.run {
            visibleRange = content.startIndex..<endIndex
            isInitialized = true
        }
    }
    
    private func loadMoreContent() {
        guard let currentRange = visibleRange else { return }
        
        let currentEnd = currentRange.upperBound
        let newEndOffset = min(content.distance(from: content.startIndex, to: currentEnd) + chunkSize, content.count)
        let newEndIndex = content.index(content.startIndex, offsetBy: newEndOffset)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            visibleRange = content.startIndex..<newEndIndex
        }
    }
}

struct SkeletonTextView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<8, id: \.self) { _ in
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.Colors.cardHighlight)
                        .frame(height: 16)
                        .frame(maxWidth: .infinity)
                        .opacity(isAnimating ? 0.3 : 0.6)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    NavigationView {
        RecordingDetailView(recording: Recording(
            title: "會議記錄 - 項目進度討論",
            originalFilename: "meeting_20241201.m4a",
            format: "m4a",
            mimeType: "audio/m4a",
            duration: 1245.0,
            createdAt: Date(),
            transcription: "今天的會議主要討論了項目的進度情況。我們已經完成了第一階段的開發工作，目前正在進行測試階段。預計下週可以完成所有測試工作，然後進入第二階段的開發。在討論過程中，我們也識別了一些潛在的風險和挑戰，需要在接下來的工作中特別注意。團隊成員都表示對目前的進度感到滿意，並且對後續的工作安排有清晰的了解。",
            summary: """
            # 會議摘要
            ## 主要討論點
            - 項目進度：第一階段開發完成
            - 測試階段：正在進行中
            - 時程規劃：下週完成測試
            
            ## 風險識別
            1. 潛在技術挑戰
            2. 資源分配問題
            3. 時程壓力
            
            ### 團隊反饋
            團隊成員對**目前的進度**感到滿意，並且對後續的工作安排有`清晰的了解`。
            """,
            fileURL: nil,
            fileSize: 2048000,
            status: "completed"
        ))
    }
}