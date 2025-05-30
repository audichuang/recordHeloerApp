import SwiftUI
import AVFoundation

struct RecordingDetailView: View {
    let recording: Recording
    @State private var selectedTab = 0
    @State private var showingShareSheet = false
    @State private var detailRecording: Recording
    @State private var isLoadingDetail = false
    @State private var loadError: String?
    @State private var isRegeneratingTranscription = false
    @State private var isRegeneratingSummary = false
    @State private var showingHistory = false
    @State private var historyType: AnalysisType = .transcription
    @State private var historySheetData: HistorySheetData?
    @State private var regenerateError: String?
    @State private var showRegenerateAlert = false
    @State private var showRegenerateSuccess = false
    @State private var regenerateSuccessMessage = ""
    @State private var showSRTView = true
    @State private var parsedSRTSegments: [SRTSegment] = []
    @StateObject private var audioPlayer = AudioPlayerManager()
    @State private var isInitialized = false
    @EnvironmentObject var recordingManager: RecordingManager
    
    private let networkService = NetworkService.shared
    
    // 懸浮播放器顯示條件
    private var shouldShowFloatingPlayer: Bool {
        // 只要有SRT片段就顯示
        !parsedSRTSegments.isEmpty
    }
    
    init(recording: Recording) {
        self.recording = recording
        self._detailRecording = State(initialValue: recording)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            mainContent
                .background(AppTheme.Colors.background)
                .padding(.bottom, shouldShowFloatingPlayer ? 56 : 0) // 調整底部空間以配合新的播放器高度
            
            // 簡化的懸浮播放器
            if shouldShowFloatingPlayer {
                SimplFloatingPlayer(
                    audioPlayer: audioPlayer,
                    recordingTitle: detailRecording.title,
                    segments: parsedSRTSegments,
                    onSegmentTap: { segment in
                        audioPlayer.seekToSegment(segment)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: shouldShowFloatingPlayer)
            }
        }
        .navigationTitle(detailRecording.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                shareButton
            }
        }
        .onAppear(perform: handleOnAppear)
        .onDisappear(perform: handleOnDisappear)
        .onChange(of: recordingManager.recordings) { oldRecordings, newRecordings in
            handleRecordingsChange(oldRecordings: oldRecordings, newRecordings: newRecordings)
        }
        .refreshable {
            await loadRecordingDetail()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AnalysisVersionChanged"))) { notification in
            handleVersionChanged(notification: notification)
        }
        .sheet(item: $historySheetData) { data in
            AnalysisHistoryView(recordingId: data.recordingId, analysisType: data.analysisType)
                .onAppear {
                    print("📋 AnalysisHistoryView 顯示 - analysisType: \(data.analysisType.rawValue)")
                }
        }
        .alert("重新生成失敗", isPresented: $showRegenerateAlert) {
                Button("確定", role: .cancel) {}
            } message: {
                if let error = regenerateError {
                    Text(error)
                }
            }
            .alert("處理狀態", isPresented: $showRegenerateSuccess) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(regenerateSuccessMessage)
            }
    }
    
    private var mainContent: some View {
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
    }
    
    private func parseSRTContent() {
        guard let srtContent = detailRecording.srtContent, !srtContent.isEmpty else { 
            print("⚠️ 沒有 SRT 內容可解析")
            return 
        }
        
        // 記憶體優化：在背景執行解析，限制片段數量
        Task.detached(priority: .userInitiated) {
            let segments = await Self.parseSRTSegments(from: srtContent)
            
            await MainActor.run {
                // 如果片段過多，只取前500個避免卡頓
                if segments.count > 500 {
                    self.parsedSRTSegments = Array(segments.prefix(500))
                    print("⚠️ SRT 片段過多(\(segments.count))，只顯示前500個以確保性能")
                } else {
                    self.parsedSRTSegments = segments
                }
                print("📝 解析 SRT 完成，顯示 \(self.parsedSRTSegments.count) 個片段")
                
                // 不再自動切換到 SRT 視圖，讓用戶手動選擇
                // if !self.parsedSRTSegments.isEmpty && self.detailRecording.hasTimestamps {
                //     self.showSRTView = true
                // }
            }
        }
    }
    
    // 靜態方法，記憶體效率更高
    private static func parseSRTSegments(from srtContent: String) async -> [SRTSegment] {
        var segments: [SRTSegment] = []
        segments.reserveCapacity(500) // 預分配容量，提升性能
        
        let lines = srtContent.components(separatedBy: .newlines)
        var i = 0
        var segmentId = 1
        
        while i < lines.count {
            // Skip empty lines
            let trimmedLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty {
                i += 1
                continue
            }
            
            // Parse segment number (optional, we'll use our own ID)
            if let _ = Int(trimmedLine) {
                i += 1
            }
            
            // Parse time range
            if i < lines.count && lines[i].contains("-->") {
                let times = lines[i].components(separatedBy: "-->")
                if times.count == 2 {
                    let startTime = Self.parseSRTTime(times[0].trimmingCharacters(in: .whitespaces))
                    let endTime = Self.parseSRTTime(times[1].trimmingCharacters(in: .whitespaces))
                    i += 1
                    
                    // Parse text lines (優化字符串處理)
                    var textParts: [String] = []
                    while i < lines.count && !lines[i].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        textParts.append(lines[i])
                        i += 1
                    }
                    
                    let text = textParts.joined(separator: " ")
                    if !text.isEmpty {
                        segments.append(SRTSegment(
                            id: segmentId,
                            startTime: startTime,
                            endTime: endTime,
                            text: text,
                            speaker: nil
                        ))
                        segmentId += 1
                    }
                }
            }
            i += 1
        }
        
        return segments
    }
    
    private static func parseSRTTime(_ timeString: String) -> Double {
        let parts = timeString.replacingOccurrences(of: ",", with: ".").components(separatedBy: ":")
        guard parts.count >= 3 else { return 0 }
        
        let hours = Double(parts[0]) ?? 0
        let minutes = Double(parts[1]) ?? 0
        let seconds = Double(parts[2]) ?? 0
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    private func handleOnAppear() {
        // 只在第一次 onAppear 時執行初始化
        guard !isInitialized else { return }
        isInitialized = true
        
        // 暫停自動刷新以避免數據更新造成視圖跳出
        recordingManager.stopMonitoringForProcessing()
        
        // 解析 SRT 內容
        if detailRecording.srtContent != nil {
            parseSRTContent()
        }
        
        // 載入音頻（如果有 SRT）
        if detailRecording.hasTimestamps {
            Task {
                print("🎵 開始載入音頻 (handleOnAppear)")
                await loadAudioForPlayback()
            }
        }
        
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
    
    private func handleOnDisappear() {
        // 恢復自動刷新
        recordingManager.startMonitoringForProcessing()
        // 清理音頻播放器資源
        audioPlayer.cleanup()
    }
    
    private func handleRecordingsChange(oldRecordings: [Recording], newRecordings: [Recording]) {
        // 只在狀態變化時同步，避免覆蓋詳細內容
        if let updatedRecording = newRecordings.first(where: { $0.id == detailRecording.id }) {
            // 檢查是否有實質性變化
            let oldRecording = oldRecordings.first(where: { $0.id == detailRecording.id })
            
            // 只在狀態或內容有變化時更新，使用 withAnimation 控制
            if oldRecording?.status != updatedRecording.status ||
               (oldRecording?.transcription?.isEmpty ?? true) != (updatedRecording.transcription?.isEmpty ?? true) ||
               (oldRecording?.summary?.isEmpty ?? true) != (updatedRecording.summary?.isEmpty ?? true) {
                print("📱 檢測到錄音內容變化，同步更新")
                // 使用 .none 動畫避免視圖跳動
                withAnimation(.none) {
                    syncWithRecordingManager()
                }
                
                // 如果狀態變為已完成且沒有完整內容，重新載入詳情
                if updatedRecording.status == "completed" && checkIfNeedsDetailLoading() {
                    print("📱 錄音處理完成，載入完整內容")
                    Task {
                        await loadRecordingDetailInBackground()
                    }
                }
            }
        }
    }
    
    /// 與 RecordingManager 中的數據同步
    private func syncWithRecordingManager() {
        // 只在初始化時同步一次，避免後續更新導致視圖跳動
        if detailRecording.transcription == nil && detailRecording.summary == nil {
            if let updatedRecording = recordingManager.recordings.first(where: { $0.id == detailRecording.id }) {
                let oldStatus = detailRecording.status
                
                // 避免不必要的更新
                guard updatedRecording != detailRecording else { return }
                
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
    }
    
    /// 處理版本切換通知
    private func handleVersionChanged(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let recordingId = userInfo["recordingId"] as? String,
              recordingId == detailRecording.id.uuidString else {
            return
        }
        
        // 版本已切換，重新載入錄音詳情
        Task {
            await loadRecordingDetail()
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
                
                // 不更新 RecordingManager，避免觸發視圖跳動
                // self.updateRecordingInManager(fullRecording)
                
                // 重新解析 SRT
                self.parseSRTContent()
                
                // 載入音頻（如果有 SRT 且尚未載入）
                if fullRecording.hasTimestamps {
                    if self.audioPlayer.duration == 0 {
                        Task {
                            print("🎵 開始載入音頻 (loadRecordingDetail)")
                            await self.loadAudioForPlayback()
                        }
                    }
                }
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
                
                // 不更新 RecordingManager，避免觸發視圖跳動
                // self.updateRecordingInManager(fullRecording)
                
                print("📱 背景載入完成，內容已更新")
                print("📝 逐字稿內容: \(fullRecording.transcription?.prefix(100) ?? "nil")")
                print("📝 摘要內容: \(fullRecording.summary?.prefix(100) ?? "nil")")
                print("📝 SRT 內容: \(fullRecording.srtContent?.prefix(100) ?? "nil")")
                print("📝 有時間戳: \(fullRecording.hasTimestamps)")
                
                // 重新解析 SRT
                self.parseSRTContent()
                
                // 載入音頻（如果有 SRT 且尚未載入）
                if fullRecording.hasTimestamps {
                    if self.audioPlayer.duration == 0 {
                        Task {
                            print("🎵 開始載入音頻 (loadRecordingDetailInBackground)")
                            await self.loadAudioForPlayback()
                        }
                    }
                }
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
        // 移除直接更新 recordingManager，避免觸發 onChange 導致視圖跳動
        // 只在真正需要時才更新（例如狀態變化）
        if let index = recordingManager.recordings.firstIndex(where: { $0.id == updatedRecording.id }) {
            let existingRecording = recordingManager.recordings[index]
            // 只在狀態有實質變化時才更新
            if existingRecording.status != updatedRecording.status {
                recordingManager.recordings[index] = updatedRecording
            }
        }
    }
    
    /// 載入音頻用於播放
    private func loadAudioForPlayback() async {
        do {
            // 下載音頻數據
            let audioData = try await networkService.downloadRecording(id: detailRecording.id.uuidString)
            
            // 使用音頻播放器載入
            await audioPlayer.loadAudioFromData(audioData)
            
            print("🎵 音頻載入完成，時長: \(audioPlayer.duration)")
        } catch {
            print("❌ 載入音頻失敗: \(error)")
            await MainActor.run {
                self.loadError = "無法載入音頻: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Regeneration Methods
    private func regenerateTranscription() async {
        await MainActor.run {
            isRegeneratingTranscription = true
            regenerateError = nil
        }
        
        do {
            let response = try await networkService.regenerateTranscription(recordingId: detailRecording.id.uuidString)
            print("🔄 開始重新生成逐字稿: \(response.message)")
            
            // 顯示處理中的提示
            await MainActor.run {
                regenerateSuccessMessage = "逐字稿重新生成中，請稍候..."
                showRegenerateSuccess = true
            }
            
            // 開始輪詢狀態
            let success = await pollForCompletion(isTranscription: true)
            
            if success {
                await MainActor.run {
                    regenerateSuccessMessage = "✅ 逐字稿重新生成完成！"
                    showRegenerateSuccess = true
                }
            }
            
        } catch {
            await MainActor.run {
                regenerateError = error.localizedDescription
                showRegenerateAlert = true
                isRegeneratingTranscription = false
            }
        }
    }
    
    private func regenerateSummary() async {
        await MainActor.run {
            isRegeneratingSummary = true
            regenerateError = nil
        }
        
        do {
            let response = try await networkService.regenerateSummary(recordingId: detailRecording.id.uuidString)
            print("🔄 開始重新生成摘要: \(response.message)")
            
            // 顯示處理中的提示
            await MainActor.run {
                regenerateSuccessMessage = "摘要重新生成中，請稍候..."
                showRegenerateSuccess = true
            }
            
            // 開始輪詢狀態
            let success = await pollForCompletion(isTranscription: false)
            
            if success {
                await MainActor.run {
                    regenerateSuccessMessage = "✅ 摘要重新生成完成！"
                    showRegenerateSuccess = true
                }
            }
            
        } catch {
            await MainActor.run {
                regenerateError = error.localizedDescription
                showRegenerateAlert = true
                isRegeneratingSummary = false
            }
        }
    }
    
    private func pollForCompletion(isTranscription: Bool) async -> Bool {
        var attempts = 0
        let maxAttempts = 60 // 最多等待3分鐘
        let delay: UInt64 = 3_000_000_000 // 3秒
        var success = false
        
        while attempts < maxAttempts {
            do {
                try await Task.sleep(nanoseconds: delay)
                
                // 重新載入錄音詳情
                let updatedRecording = try await networkService.getRecordingDetail(id: detailRecording.id.uuidString)
                
                await MainActor.run {
                    self.detailRecording = updatedRecording
                    self.updateRecordingInManager(updatedRecording)
                    
                    // 每10秒更新一次進度提示
                    if attempts % 3 == 0 {
                        let seconds = (attempts + 1) * 3
                        let processType = isTranscription ? "逐字稿" : "摘要"
                        self.regenerateSuccessMessage = "\(processType)處理中... 已等待 \(seconds) 秒"
                        self.showRegenerateSuccess = true
                    }
                    
                    // 檢查處理狀態
                    if updatedRecording.status == "completed" {
                        self.isRegeneratingTranscription = false
                        self.isRegeneratingSummary = false
                        print("✅ 重新生成完成")
                        success = true
                    }
                }
                
                // 如果處理完成，跳出循環
                if updatedRecording.status == "completed" {
                    break
                }
                
                attempts += 1
                
            } catch {
                print("❌ 輪詢失敗: \(error.localizedDescription)")
                await MainActor.run {
                    self.regenerateError = "獲取狀態失敗: \(error.localizedDescription)"
                    self.showRegenerateAlert = true
                    self.isRegeneratingTranscription = false
                    self.isRegeneratingSummary = false
                }
                break
            }
        }
        
        // 超時處理
        if attempts >= maxAttempts {
            await MainActor.run {
                self.regenerateError = "處理超時，請稍後重試"
                self.showRegenerateAlert = true
                self.isRegeneratingTranscription = false
                self.isRegeneratingSummary = false
            }
        }
        
        return success
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
                // 操作按鈕組
                HStack(spacing: 12) {
                    // 重新生成按鈕
                    RegenerateButton(
                        title: "重新生成",
                        isLoading: isRegeneratingTranscription,
                        gradient: AppTheme.Gradients.primary
                    ) {
                        Task {
                            await regenerateTranscription()
                        }
                    }
                    .disabled(isRegeneratingTranscription || detailRecording.status != "completed")
                    
                    // 歷史記錄按鈕
                    Button(action: {
                        print("🔘 點擊逐字稿歷史記錄按鈕")
                        historySheetData = HistorySheetData(
                            recordingId: detailRecording.id.uuidString,
                            analysisType: .transcription
                        )
                    }) {
                        Label("歷史記錄", systemImage: "clock.arrow.circlepath")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.Colors.primary)
                    
                    
                    Spacer()
                }
                
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
                        let _ = print("🎯 顯示逐字稿，長度: \(transcription.count)")
                        let _ = print("📱 showSRTView: \(showSRTView), SRT片段數: \(parsedSRTSegments.count)")
                        let _ = print("🎵 音頻時長: \(audioPlayer.duration), 是否正在播放: \(audioPlayer.isPlaying)")
                        let _ = print("🎮 懸浮播放器應顯示: \(shouldShowFloatingPlayer)")
                        
                        if !parsedSRTSegments.isEmpty {
                            // 顯示 SRT 字幕視圖（性能優化版）
                            // 使用優化的 SRT 視圖，防止卡頓
                            SRTTranscriptView(
                                segments: parsedSRTSegments,
                                audioPlayer: audioPlayer,
                                onSegmentTap: { segment in
                                    audioPlayer.seekToSegment(segment)
                                }
                            )
                        } else {
                            ContentDisplayView(content: transcription, type: .transcription)
                        }
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
                    // 操作按鈕組
                    HStack(spacing: 12) {
                        // 重新生成按鈕
                        RegenerateButton(
                            title: "重新生成",
                            isLoading: isRegeneratingSummary,
                            gradient: AppTheme.Gradients.success
                        ) {
                            Task {
                                await regenerateSummary()
                            }
                        }
                        .disabled(isRegeneratingSummary || detailRecording.status != "completed")
                        
                        // 歷史記錄按鈕
                        Button(action: {
                            print("🔘 點擊摘要歷史記錄按鈕")
                            historySheetData = HistorySheetData(
                                recordingId: detailRecording.id.uuidString,
                                analysisType: .summary
                            )
                        }) {
                            Label("歷史記錄", systemImage: "clock.arrow.circlepath")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.Colors.success)
                        
                        Spacer()
                    }
                    
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
    
    // MARK: - Audio Player Card (Optimized)
    private var audioPlayerCard: some View {
        AnimatedCardView(
            title: "音頻播放器",
            icon: "play.circle.fill",
            gradient: AppTheme.Gradients.info,
            delay: 0.5
        ) {
            VStack(spacing: 16) {
                // 調試信息
                if audioPlayer.duration <= 0 {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(AppTheme.Colors.warning)
                        Text("時長: \(audioPlayer.duration)s, 載入中: \(audioPlayer.isLoading)")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                // 簡化的播放控制
                HStack(spacing: 20) {
                    // 播放/暫停按鈕
                    Button(action: {
                        audioPlayer.togglePlayPause()
                    }) {
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            )
                    }
                    .disabled(audioPlayer.isLoading || audioPlayer.duration <= 0)
                    
                    // 時間和進度
                    VStack(alignment: .leading, spacing: 6) {
                        // 時間顯示
                        HStack {
                            Text(audioPlayer.formattedCurrentTime)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Spacer()
                            
                            Text(audioPlayer.formattedDuration)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        // 簡化的進度條
                        if audioPlayer.duration > 0 {
                            ProgressView(value: audioPlayer.progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.Colors.primary))
                                .frame(height: 6)
                        } else {
                            Rectangle()
                                .fill(AppTheme.Colors.cardHighlight)
                                .frame(height: 6)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }
                
                // 狀態信息
                if audioPlayer.isLoading {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                            .scaleEffect(0.7)
                        Text("載入音頻中...")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                } else if let error = audioPlayer.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppTheme.Colors.error)
                            .font(.caption)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.error)
                    }
                } else if audioPlayer.duration <= 0 {
                    Text("無法獲取音頻時長")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.warning)
                }
            }
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
                    .animation(isAnimating ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isAnimating)
                
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
        .onDisappear {
            isAnimating = false
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

/// 高性能分段文本視圖，使用虛擬化技術減少記憶體使用
struct OptimizedTextView: View {
    let content: String
    @State private var chunks: [TextChunk] = []
    @State private var visibleChunks: Set<Int> = []
    @State private var isInitialized = false
    
    private let chunkSize = 1000 // 每個區塊的字元數
    private let visibleBuffer = 3 // 可見區域前後緩衝的區塊數
    
    struct TextChunk: Identifiable {
        let id: Int
        let text: String
        let startIndex: String.Index
        let endIndex: String.Index
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if isInitialized {
                        ForEach(chunks) { chunk in
                            ChunkView(
                                chunk: chunk,
                                isVisible: visibleChunks.contains(chunk.id),
                                onAppear: { markChunkVisible(chunk.id) },
                                onDisappear: { markChunkInvisible(chunk.id) }
                            )
                        }
                    } else {
                        SkeletonTextView()
                    }
                }
                .padding()
            }
        }
        .task {
            await initializeChunks()
        }
    }
    
    private func initializeChunks() async {
        guard !content.isEmpty else { return }
        
        await MainActor.run {
            var tempChunks: [TextChunk] = []
            var currentIndex = content.startIndex
            var chunkId = 0
            
            while currentIndex < content.endIndex {
                let remainingDistance = content.distance(from: currentIndex, to: content.endIndex)
                let chunkDistance = min(chunkSize, remainingDistance)
                let endIndex = content.index(currentIndex, offsetBy: chunkDistance)
                
                let chunkText = String(content[currentIndex..<endIndex])
                tempChunks.append(TextChunk(
                    id: chunkId,
                    text: chunkText,
                    startIndex: currentIndex,
                    endIndex: endIndex
                ))
                
                currentIndex = endIndex
                chunkId += 1
            }
            
            chunks = tempChunks
            // 初始化時顯示前幾個區塊
            for i in 0..<min(5, chunks.count) {
                visibleChunks.insert(i)
            }
            isInitialized = true
            
            print("📊 文本分塊完成: \(chunks.count) 個區塊，每塊約 \(chunkSize) 字元")
        }
    }
    
    private func markChunkVisible(_ id: Int) {
        visibleChunks.insert(id)
        
        // 預加載前後的區塊
        for offset in 1...visibleBuffer {
            if id - offset >= 0 {
                visibleChunks.insert(id - offset)
            }
            if id + offset < chunks.count {
                visibleChunks.insert(id + offset)
            }
        }
    }
    
    private func markChunkInvisible(_ id: Int) {
        // 延遲移除，避免滾動時頻繁載入/卸載
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // 檢查是否真的不在可見範圍內
            let visibleRange = (id - visibleBuffer)...(id + visibleBuffer)
            let shouldRemove = !visibleChunks.contains { visibleRange.contains($0) }
            
            if shouldRemove {
                visibleChunks.remove(id)
            }
        }
    }
}

// 單個文本區塊視圖
struct ChunkView: View {
    let chunk: OptimizedTextView.TextChunk
    let isVisible: Bool
    let onAppear: () -> Void
    let onDisappear: () -> Void
    
    var body: some View {
        Group {
            if isVisible {
                Text(chunk.text)
                    .font(.body)
                    .lineSpacing(6)
                    .textSelection(.enabled)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(chunk.id)
            } else {
                // 佔位符，保持滾動位置
                Color.clear
                    .frame(height: estimatedHeight)
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear { onAppear() }
        .onDisappear { onDisappear() }
    }
    
    private var estimatedHeight: CGFloat {
        // 估算文本高度（基於平均行高和字元數）
        let averageCharsPerLine: CGFloat = 40
        let lineHeight: CGFloat = 24
        let estimatedLines = CGFloat(chunk.text.count) / averageCharsPerLine
        return estimatedLines * lineHeight
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

// MARK: - Lightweight SRT View (Ultra Performance)
struct SRTTranscriptView: View {
    let segments: [SRTSegment]
    @ObservedObject var audioPlayer: AudioPlayerManager
    let onSegmentTap: (SRTSegment) -> Void
    
    @State private var displaySegments: [SRTSegment] = []
    @State private var currentPage = 0
    @State private var hasMorePages = true
    @State private var currentSegmentId: Int?
    @State private var isLoading = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    private let pageSize = 30  // 每頁顯示30個片段
    
    var body: some View {
        VStack(spacing: 0) {
            // 優雅的頂部控制欄
            HStack(spacing: 16) {
                // 播放狀態指示
                HStack(spacing: 10) {
                    // 動態播放指示器
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: audioPlayer.isPlaying ? "waveform.circle.fill" : "play.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.primary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(audioPlayer.isPlaying ? "正在播放" : "已暫停")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if let currentSegment = getCurrentSegment() {
                            Text(currentSegment.formattedStartTime)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                // 快速跳轉按鈕
                if let currentSegment = getCurrentSegment() {
                    Button(action: {
                        if let proxy = scrollProxy {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(currentSegment.id, anchor: .center)
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                            Text("跳至目前")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.primary.opacity(0.1))
                        )
                        .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        AppTheme.Colors.card,
                        AppTheme.Colors.background.opacity(0.95)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            Divider()
                .background(AppTheme.Colors.divider.opacity(0.5))
            
            // 美化的字幕列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        ForEach(displaySegments, id: \.id) { segment in
                            Group {
                                EnhancedSRTRow(
                                    segment: segment,
                                    isActive: isSegmentActive(segment),
                                    audioPlayer: audioPlayer,
                                    onTap: {
                                        hapticFeedback.impactOccurred()
                                        onSegmentTap(segment)
                                    }
                                )
                                .id(segment.id)
                                .onAppear {
                                    // 當顯示到倒數第5個項目時，自動載入下一頁
                                    if segment.id == displaySegments.dropLast(4).last?.id {
                                        autoLoadNextPage()
                                    }
                                }
                                
                                // 分隔線
                                if segment.id != displaySegments.last?.id {
                                    Rectangle()
                                        .fill(AppTheme.Colors.divider.opacity(0.2))
                                        .frame(height: 0.5)
                                        .padding(.leading, 76)
                                }
                            }
                        }
                        
                        // 載入指示器
                        if hasMorePages {
                            VStack(spacing: 12) {
                                if isLoading {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                                        Text("載入更多字幕...")
                                            .font(.system(size: 13))
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    }
                                } else {
                                    Text("還有 \(segments.count - displaySegments.count) 條字幕")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .onAppear {
                                autoLoadNextPage()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollDismissesKeyboard(.immediately)
                .background(AppTheme.Colors.background)
                .onAppear {
                    scrollProxy = proxy
                }
            }
        }
        .background(AppTheme.Colors.background)
        .onAppear {
            initializeView()
            hapticFeedback.prepare()
        }
        .onChange(of: audioPlayer.currentTime) { _, newTime in
            updateCurrentSegment(at: newTime)
        }
    }
    
    private func initializeView() {
        let initialSegments = Array(segments.prefix(pageSize))
        displaySegments = initialSegments
        currentPage = 0
        hasMorePages = segments.count > pageSize
        print("📱 SRT視圖初始化: 顯示 \(initialSegments.count)/\(segments.count) 個片段")
    }
    
    private func loadNextPage() {
        let startIndex = (currentPage + 1) * pageSize
        let endIndex = min(startIndex + pageSize, segments.count)
        
        guard startIndex < segments.count else {
            hasMorePages = false
            return
        }
        
        let nextBatch = Array(segments[startIndex..<endIndex])
        displaySegments.append(contentsOf: nextBatch)
        currentPage += 1
        hasMorePages = endIndex < segments.count
        
        print("📱 載入下一頁: 第\(currentPage)頁，新增 \(nextBatch.count) 個片段")
    }
    
    private func autoLoadNextPage() {
        // 防止重複載入
        guard hasMorePages && !isLoading else { return }
        
        isLoading = true
        
        // 添加短暫延遲，模擬載入效果並防止過於頻繁的載入
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.loadNextPage()
            self.isLoading = false
        }
    }
    
    private func getCurrentSegment() -> SRTSegment? {
        return segments.first { segment in
            audioPlayer.currentTime >= segment.startTime && audioPlayer.currentTime < segment.endTime
        }
    }
    
    private func isSegmentActive(_ segment: SRTSegment) -> Bool {
        audioPlayer.currentTime >= segment.startTime && audioPlayer.currentTime < segment.endTime
    }
    
    private func updateCurrentSegment(at time: TimeInterval) {
        if let currentSegment = getCurrentSegment() {
            if currentSegment.id != currentSegmentId {
                currentSegmentId = currentSegment.id
                
                // 確保當前片段在顯示列表中
                if !displaySegments.contains(where: { $0.id == currentSegment.id }) {
                    // 找到片段位置並載入到該頁
                    if let index = segments.firstIndex(where: { $0.id == currentSegment.id }) {
                        let targetPage = index / pageSize
                        loadToPage(targetPage)
                    }
                }
                
                // 自動滾動到當前播放的字幕（如果正在播放）
                // 使用延遲以避免頻繁滾動
                if audioPlayer.isPlaying {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            scrollToSegment(currentSegment)
                        }
                    }
                }
            }
        }
    }
    
    private func scrollToSegment(_ segment: SRTSegment) {
        scrollProxy?.scrollTo(segment.id, anchor: .center)
    }
    
    private func loadToPage(_ targetPage: Int) {
        let startIndex = 0
        let endIndex = min((targetPage + 1) * pageSize, segments.count)
        
        guard endIndex > displaySegments.count else { return }
        
        displaySegments = Array(segments[startIndex..<endIndex])
        currentPage = targetPage
        hasMorePages = endIndex < segments.count
    }
}

// MARK: - Enhanced SRT Row (Beautiful Design)
struct EnhancedSRTRow: View {
    let segment: SRTSegment
    let isActive: Bool
    @ObservedObject var audioPlayer: AudioPlayerManager
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            isPressed = true
            onTap()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }) {
            HStack(alignment: .center, spacing: 0) {
                // 左側時間戳 - 簡化版
                VStack(alignment: .trailing, spacing: 4) {
                    Text(segment.formattedStartTime)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(isActive ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    
                    if isActive {
                        // 簡化的進度指示
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(width: 60)
                .padding(.vertical, 16)
                .padding(.leading, 8)
                
                // 內容區域 - 簡化版
                VStack(alignment: .leading, spacing: 4) {
                    // 字幕文字
                    Text(segment.text)
                        .font(.system(size: isActive ? 16 : 15))
                        .fontWeight(isActive ? .medium : .regular)
                        .foregroundColor(isActive ? AppTheme.Colors.textPrimary : AppTheme.Colors.textPrimary.opacity(0.85))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    
                    // 簡化的狀態顯示
                    if isActive {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.Colors.primary)
                            
                            Text("正在播放")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 右側播放控制 - 簡化版
                if isActive {
                    Button(action: {
                        audioPlayer.togglePlayPause()
                    }) {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(
                // 簡化的背景
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(isActive ? AppTheme.Colors.primary : Color.clear)
                        .frame(width: 3)
                    
                    Rectangle()
                        .fill(isActive ? AppTheme.Colors.primary.opacity(0.05) : (isPressed ? AppTheme.Colors.primary.opacity(0.02) : Color.clear))
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func calculateSegmentProgress() -> CGFloat {
        guard isActive else { return 0 }
        let segmentDuration = segment.endTime - segment.startTime
        let elapsed = audioPlayer.currentTime - segment.startTime
        return max(0, min(1, elapsed / segmentDuration))
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let secs = Int(seconds)
        return String(format: "%d.%d秒", secs, Int((seconds - Double(secs)) * 10))
    }
}

// MARK: - Simple Floating Player (Ultra Minimal with Frosted Glass)
struct SimplFloatingPlayer: View {
    @ObservedObject var audioPlayer: AudioPlayerManager
    let recordingTitle: String
    let segments: [SRTSegment]
    let onSegmentTap: (SRTSegment) -> Void
    
    @State private var isExpanded = false
    @State private var pulsatingAnimation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 優雅的進度條
            if audioPlayer.duration > 0 && !audioPlayer.isLoading {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景軌道
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 3)
                        
                        // 進度條
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        AppTheme.Colors.primary,
                                        AppTheme.Colors.primary.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * audioPlayer.progress, height: 3)
                            .animation(.linear(duration: 0.1), value: audioPlayer.progress)
                            .shadow(color: AppTheme.Colors.primary.opacity(0.5), radius: 2, x: 0, y: 0)
                    }
                }
                .frame(height: 3)
            }
            
            ZStack {
                // 美化的毛玻璃背景
                VisualEffectBlur(blurStyle: .systemChromeMaterial)
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.05),
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                HStack(spacing: 14) {
                    // 播放控制區（美化版）
                    if audioPlayer.isLoading {
                        // 載入動畫
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.Colors.primary.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                                    .scaleEffect(0.7)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("載入音頻中")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Text("請稍候...")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                    } else {
                        // 美化的播放按鈕
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                audioPlayer.togglePlayPause()
                            }
                        }) {
                            ZStack {
                                // 外圈動態效果
                                if audioPlayer.isPlaying {
                                    Circle()
                                        .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 2)
                                        .frame(width: 44, height: 44)
                                        .scaleEffect(pulsatingAnimation ? 1.1 : 1.0)
                                        .opacity(pulsatingAnimation ? 0 : 1)
                                        .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: pulsatingAnimation)
                                }
                                
                                // 主按鈕
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                AppTheme.Colors.primary.opacity(0.9),
                                                AppTheme.Colors.primary
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                    .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                                
                                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .offset(x: audioPlayer.isPlaying ? 0 : 1) // 播放按鈕稍微偏右
                            }
                        }
                        .disabled(audioPlayer.duration <= 0)
                        .scaleEffect(audioPlayer.isPlaying ? 1.0 : 0.95)
                        .onAppear {
                            pulsatingAnimation = true
                        }
                    }
                    
                    // 內容區域（美化版）
                    VStack(alignment: .leading, spacing: 3) {
                        // 當前播放內容
                        HStack(spacing: 6) {
                            if audioPlayer.isPlaying {
                                Image(systemName: "waveform")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.Colors.primary)
                                    // 僅在 iOS 17+ 使用 symbolEffect
                                    .overlay(
                                        Image(systemName: "waveform")
                                            .font(.system(size: 10))
                                            .foregroundColor(AppTheme.Colors.primary.opacity(0.5))
                                            .scaleEffect(x: 1.0, y: pulsatingAnimation ? 1.2 : 0.8)
                                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsatingAnimation)
                                    )
                            }
                            
                            if let currentSegment = getCurrentSegment() {
                                Text(currentSegment.text)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            } else {
                                Text(recordingTitle)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary.opacity(0.85))
                                    .lineLimit(1)
                            }
                        }
                        
                        // 時間信息（美化版）
                        if audioPlayer.duration > 0 && !audioPlayer.isLoading {
                            HStack(spacing: 4) {
                                Text(audioPlayer.formattedCurrentTime)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(AppTheme.Colors.primary)
                                
                                Text("/")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                                
                                Text(audioPlayer.formattedDuration)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 控制按鈕組（美化版）
                    if !audioPlayer.isLoading {
                        HStack(spacing: 12) {
                            // 後退按鈕
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    audioPlayer.seek(to: max(0, audioPlayer.currentTime - 15))
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: "gobackward.15")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                }
                            }
                            .disabled(audioPlayer.duration <= 0)
                            
                            // 前進按鈕
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    audioPlayer.seek(to: min(audioPlayer.duration, audioPlayer.currentTime + 15))
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: "goforward.15")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                }
                            }
                            .disabled(audioPlayer.duration <= 0)
                        }
                        .padding(.trailing, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 0))
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: -4)
            .shadow(color: AppTheme.Colors.primary.opacity(0.08), radius: 20, x: 0, y: -8)
        }
    }
    
    private func getCurrentSegment() -> SRTSegment? {
        return segments.first { segment in
            audioPlayer.currentTime >= segment.startTime && audioPlayer.currentTime < segment.endTime
        }
    }
}

// MARK: - Visual Effect Blur Helper
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

// MARK: - History Sheet Data
struct HistorySheetData: Identifiable {
    let id = UUID()
    let recordingId: String
    let analysisType: AnalysisType
}


