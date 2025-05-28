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
        .navigationTitle(detailRecording.title)
        .navigationBarTitleDisplayMode(.large)
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
    
    private var recordingInfoCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(detailRecording.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    
                    Text(detailRecording.fileName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                InfoItem(icon: "clock", title: "時長", value: detailRecording.formattedDuration)
                InfoItem(icon: "calendar", title: "日期", value: detailRecording.formattedDate)
                InfoItem(icon: "doc", title: "大小", value: detailRecording.formattedFileSize)
                if let status = detailRecording.status {
                    InfoItem(icon: statusIcon, title: "狀態", value: detailRecording.statusText)
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
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(.blue)
                    Text("完整逐字稿")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    
                    // 當內容是"可用"時，顯示載入指示器
                    if detailRecording.transcription == "可用" || isLoadingDetail {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                if let transcription = detailRecording.transcription, !transcription.isEmpty {
                    if transcription == "可用" {
                        // 顯示背景載入狀態
                        backgroundLoadingView(
                            title: "正在載入逐字稿",
                            message: "正在從伺服器獲取完整的逐字稿內容，請稍候...",
                            icon: "text.alignleft",
                            color: .blue
                        )
                    } else {
                        // 使用優化的文本顯示
                        OptimizedTextView(content: transcription)
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                    }
                } else if isLoadingDetail {
                    loadingPlaceholder
                } else if let error = loadError {
                    errorMessage(error)
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
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "list.bullet.clipboard")
                        .foregroundColor(.green)
                    Text("智能摘要")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    
                    // 當內容是"可用"時，顯示載入指示器
                    if detailRecording.summary == "可用" || isLoadingDetail {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                if let summary = detailRecording.summary, !summary.isEmpty {
                    if summary == "可用" {
                        // 顯示背景載入狀態
                        backgroundLoadingView(
                            title: "正在載入摘要",
                            message: "正在從伺服器獲取完整的智能摘要內容，請稍候...",
                            icon: "list.bullet.clipboard",
                            color: .green
                        )
                    } else {
                        // 使用MarkdownText組件來渲染Markdown格式的摘要
                        MarkdownText(content: summary)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        
                        // 統計資訊 - 只在有數據時顯示
                        if let transcription = detailRecording.transcription, 
                           !transcription.isEmpty, 
                           transcription != "可用",
                           transcription.count > 0 && summary.count > 0 {
                            
                            LazyVStack(spacing: 12) {
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
                    }
                } else if isLoadingDetail {
                    loadingPlaceholder
                } else if let error = loadError {
                    errorMessage(error)
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
    
    /// 背景載入狀態視圖
    private func backgroundLoadingView(title: String, message: String, icon: String, color: Color) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 3)
                    .frame(width: 60, height: 60)
                
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(color)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .offset(y: -5)
            }
            
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
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
    
    private var statusIcon: String {
        guard let status = detailRecording.status else { return "questionmark.circle" }
        
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
        guard let status = detailRecording.status else { return .gray }
        
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
    
    private var loadingPlaceholder: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.blue)
            
            Text("正在載入內容...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("請稍候，我們正在獲取完整的轉錄和摘要內容")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func errorMessage(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("載入失敗")
                .font(.headline)
                .fontWeight(.bold)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重試") {
                Task {
                    await loadRecordingDetail()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func checkIfNeedsDetailLoading() -> Bool {
        let needsTranscription = detailRecording.transcription?.isEmpty ?? true || detailRecording.transcription == "可用"
        let needsSummary = detailRecording.summary?.isEmpty ?? true || detailRecording.summary == "可用"
        return needsTranscription || needsSummary
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

/// 優化的文本視圖，用於顯示大量文本而不阻塞UI
struct OptimizedTextView: View {
    let content: String
    @State private var displayedChunks: [String] = []
    @State private var isLoadingInitialChunk: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var allContentLoaded: Bool = false

    private let chunkSize = 2000

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if isLoadingInitialChunk && displayedChunks.isEmpty {
                    ProgressView("正在載入內容...")
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                ForEach(displayedChunks.indices, id: \.self) { index in
                    Text(displayedChunks[index])
                        .font(.body)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .onAppear {
                            if index == displayedChunks.count - 1 && !allContentLoaded && !isLoadingMore && !isLoadingInitialChunk {
                                loadMoreContent()
                            }
                        }
                }

                if !displayedChunks.isEmpty && isLoadingMore {
                    ProgressView()
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal)
        }
        .task {
            if displayedChunks.isEmpty && !content.isEmpty {
                await loadInitialChunk()
            }
        }
    }

    private func loadInitialChunk() async {
        guard !content.isEmpty else { return }
        
        await MainActor.run {
            isLoadingInitialChunk = true
        }

        let firstChunk = await Task.detached(priority: .userInitiated) { () -> String in
            let end = min(chunkSize, content.count)
            let endIndex = content.index(content.startIndex, offsetBy: end)
            return String(content[content.startIndex..<endIndex])
        }.value

        await MainActor.run {
            if !firstChunk.isEmpty {
                displayedChunks.append(firstChunk)
            }
            allContentLoaded = displayedChunks.reduce(0, { $0 + $1.count }) >= content.count
            isLoadingInitialChunk = false
        }
    }

    private func loadMoreContent() {
        guard !isLoadingInitialChunk && !isLoadingMore && !allContentLoaded else { return }
        
        Task {
            await MainActor.run { isLoadingMore = true }

            let currentLength = displayedChunks.reduce(0) { $0 + $1.count }
            
            let nextChunk = await Task.detached(priority: .userInitiated) { () -> String? in
                guard currentLength < content.count else { return nil }
                
                let start = currentLength
                let end = min(start + chunkSize, content.count)
                
                let startIndex = content.index(content.startIndex, offsetBy: start)
                let endIndex = content.index(content.startIndex, offsetBy: end)
                return String(content[startIndex..<endIndex])
            }.value

            await MainActor.run {
                if let chunk = nextChunk, !chunk.isEmpty {
                    displayedChunks.append(chunk)
                }
                allContentLoaded = displayedChunks.reduce(0, { $0 + $1.count }) >= content.count
                isLoadingMore = false
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
            summary: "會議摘要：討論項目進度，第一階段開發完成，正在測試中，預計下週完成測試並進入第二階段。識別了風險和挑戰，團隊對進度滿意。",
            fileURL: nil,
            fileSize: 2048000,
            status: "completed"
        ))
    }
} 