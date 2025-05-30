import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var recordingManager: RecordingManager
    @EnvironmentObject var templateManager: PromptTemplateManager
    @State private var showingFilePicker = false
    @State private var showingUploadDialog = false
    @State private var uploadTitle = ""
    @State private var selectedFileURL: URL?
    @State private var selectedTemplate: PromptTemplate?
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var animateCards = false
    @State private var selectedRecording: Recording?
    @State private var showingEditDialog = false
    @State private var showingDeleteAlert = false
    @State private var editingTitle = ""
    @State private var isSaving = false
    @Binding var selectedTab: Int
    
    init(selectedTab: Binding<Int> = .constant(0)) {
        self._selectedTab = selectedTab
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppTheme.Spacing.xl) {
                // 簡約歡迎區塊
                welcomeHeader
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 20)
                    .animation(AppTheme.Animation.smooth.delay(0.1), value: animateCards)
                
                // 主要操作區
                uploadSection
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 20)
                    .animation(AppTheme.Animation.smooth.delay(0.2), value: animateCards)
                
                // 錯誤提示（如果有）
                if let error = recordingManager.error {
                    errorNotification(message: error)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
                
                // 最近錄音列表
                recentSection
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 20)
                    .animation(AppTheme.Animation.smooth.delay(0.3), value: animateCards)
            }
            .padding(.horizontal)
            .padding(.vertical, AppTheme.Spacing.m)
        }
        .background(AppTheme.Colors.background)
        .navigationBarTitleDisplayMode(.large)
        .navigationTitle("錄音助手")
        .refreshable {
            await recordingManager.loadRecentRecordings(limit: 5)
        }
        .onAppear {
            animateCards = true
            if recordingManager.recordings.isEmpty {
                Task {
                    await recordingManager.loadRecentRecordings(limit: 5)
                }
            }
        }
        .onDisappear {
            animateCards = false
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: audioContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $showingUploadDialog) {
            UploadDialogView(
                fileURL: $selectedFileURL,
                uploadTitle: $uploadTitle,
                selectedTemplate: $selectedTemplate,
                templateManager: templateManager,
                onUpload: {
                    Task {
                        if let url = selectedFileURL {
                            _ = await recordingManager.uploadRecording(
                                fileURL: url,
                                title: uploadTitle.isEmpty ? "未命名錄音" : uploadTitle,
                                promptTemplateId: selectedTemplate?.id
                            )
                            uploadTitle = ""
                            selectedFileURL = nil
                            selectedTemplate = nil
                            showingUploadDialog = false
                        }
                    }
                },
                onCancel: {
                    uploadTitle = ""
                    selectedFileURL = nil
                    selectedTemplate = nil
                    showingUploadDialog = false
                }
            )
        }
        .alert("上傳錯誤", isPresented: $showingErrorAlert) {
            Button("確定", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "未知錯誤")
        }
        .alert("編輯標題", isPresented: $showingEditDialog, actions: editDialogActions, message: editDialogMessage)
        .alert("刪除錄音", isPresented: $showingDeleteAlert, actions: deleteDialogActions, message: deleteDialogMessage)
    }
    
    // MARK: - 簡約歡迎頭部
    private var welcomeHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(getGreeting())
                    .font(.system(size: AppTheme.FontSize.title1, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                if let user = authManager.currentUser {
                    Text(user.username)
                        .font(.system(size: AppTheme.FontSize.title3))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            // 簡約統計資訊
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(recordingManager.recordings.count)")
                    .font(.system(size: AppTheme.FontSize.title2, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                Text("錄音檔案")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xs)
    }
    
    // MARK: - 上傳區塊
    private var uploadSection: some View {
        ModernCard(showBorder: true) {
            VStack(spacing: AppTheme.Spacing.m) {
                // 圖標和標題
                HStack {
                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 28))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("上傳新錄音")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text("支援 MP3、WAV、M4A 等格式")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    
                    Spacer()
                }
                
                // 上傳進度或按鈕
                if recordingManager.isUploading {
                    uploadProgressView
                } else {
                    ModernButton("選擇檔案", icon: "doc.badge.plus", style: .primary) {
                        showingFilePicker = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - 上傳進度視圖
    private var uploadProgressView: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            // 進度條
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                        .fill(AppTheme.Colors.border)
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                        .fill(AppTheme.Colors.primary)
                        .frame(width: geometry.size.width * recordingManager.uploadProgress, height: 6)
                        .animation(AppTheme.Animation.smooth, value: recordingManager.uploadProgress)
                }
            }
            .frame(height: 6)
            
            HStack {
                Text("上傳中...")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                Text("\(Int(recordingManager.uploadProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
    }
    
    // MARK: - 最近錄音區塊
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
            // 標題行
            HStack {
                Text("最近錄音")
                    .font(.system(size: AppTheme.FontSize.title3, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                if !recordingManager.recordings.isEmpty {
                    ModernButton("查看全部", style: .minimal) {
                        selectedTab = 1
                    }
                }
            }
            
            if recordingManager.isLoading && recordingManager.recordings.isEmpty {
                // 載入骨架屏
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCard()
                }
            } else if recordingManager.recordings.isEmpty {
                // 空狀態
                emptyStateView
            } else {
                // 錄音列表
                LazyVStack(spacing: AppTheme.Spacing.m) {
                    ForEach(recordingManager.recordings.prefix(5)) { recording in
                        NavigationLink(destination: RecordingDetailView(recording: recording)) {
                            RecordingCard(recording: recording) {
                                // NavigationLink 會自動處理導航
                            }
                        }
                        .buttonStyle(PlainButtonStyle()) // 移除默認的按鈕樣式
                        .contextMenu {
                            recordingContextMenu(for: recording)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 錄音卡片（簡約版）
    private struct RecordingCard: View {
        let recording: Recording
        let action: () -> Void
        
        var body: some View {
            ModernCard(showBorder: true) {
                HStack(spacing: AppTheme.Spacing.m) {
                    // 狀態圖標
                    statusIcon
                    
                    // 內容
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text(recording.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: AppTheme.Spacing.s) {
                            Label(formatDuration(recording.duration ?? 0), systemImage: "clock")
                            Text("•")
                            Text(formatDate(recording.createdAt))
                        }
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    
                    Spacer()
                    
                    // 狀態標籤
                    if let status = recording.status {
                        ProcessingStatusBadge(status: status)
                    }
                }
            }
        }
        
        private var statusIcon: some View {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: statusIconName)
                    .font(.system(size: 20))
                    .foregroundColor(statusColor)
            }
        }
        
        private var statusIconName: String {
            switch recording.status?.lowercased() {
            case "processing":
                return "arrow.triangle.2.circlepath"
            case "uploading":
                return "arrow.up.circle"
            case "transcribing":
                return "waveform.circle"
            case "transcribed":
                return "text.alignleft"
            case "summarizing":
                return "text.badge.checkmark"
            case "completed":
                return "checkmark.circle.fill"
            case "failed":
                return "exclamationmark.circle.fill"
            default:
                return "circle.dashed"
            }
        }
        
        private var statusColor: Color {
            switch recording.status?.lowercased() {
            case "processing", "uploading", "transcribing", "summarizing":
                return AppTheme.Colors.warning
            case "transcribed":
                return AppTheme.Colors.info
            case "completed":
                return AppTheme.Colors.success
            case "failed":
                return AppTheme.Colors.error
            default:
                return AppTheme.Colors.textTertiary
            }
        }
        
        private func formatDuration(_ seconds: Double?) -> String {
            // 檢查 duration 是否為 nil 或無效值
            guard let seconds = seconds, seconds > 0, seconds.isFinite else { 
                return "--:--" 
            }
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
    
    // MARK: - 空狀態視圖
    private var emptyStateView: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Text("還沒有錄音")
                .font(.headline)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text("點擊上方按鈕上傳您的第一個錄音檔案")
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xxl)
    }
    
    // MARK: - 錯誤通知
    private func errorNotification(message: String) -> some View {
        HStack(spacing: AppTheme.Spacing.m) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(AppTheme.Colors.error)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
            
            IconButton(icon: "xmark", size: 16, color: AppTheme.Colors.textSecondary) {
                recordingManager.error = nil
            }
        }
        .padding(AppTheme.Spacing.m)
        .background(AppTheme.Colors.errorLight.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(AppTheme.Colors.error.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }
    
    // MARK: - 輔助方法
    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12:
            return "早安"
        case 12..<18:
            return "午安"
        case 18..<22:
            return "晚安"
        default:
            return "夜深了"
        }
    }
    
    private var audioContentTypes: [UTType] {
        [
            .audio,
            .mp3,
            .wav,
            UTType(filenameExtension: "m4a") ?? .audio,
            UTType(filenameExtension: "aac") ?? .audio,
            UTType(filenameExtension: "flac") ?? .audio
        ]
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                let validExtensions = ["mp3", "wav", "m4a", "aac", "flac", "mp4", "ogg"]
                if validExtensions.contains(url.pathExtension.lowercased()) {
                    selectedFileURL = url
                    uploadTitle = url.deletingPathExtension().lastPathComponent
                    showingUploadDialog = true
                } else {
                    errorMessage = "不支援的音頻格式"
                    showingErrorAlert = true
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
    
    // MARK: - Context Menu
    @ViewBuilder
    private func recordingContextMenu(for recording: Recording) -> some View {
        Button {
            selectedRecording = recording
            editingTitle = recording.title
            showingEditDialog = true
        } label: {
            Label("編輯標題", systemImage: "pencil")
        }
        
        Button(role: .destructive) {
            selectedRecording = recording
            showingDeleteAlert = true
        } label: {
            Label("刪除", systemImage: "trash")
        }
    }
    
    // MARK: - Dialog Actions
    
    private func editDialogActions() -> some View {
        Group {
            TextField("錄音標題", text: $editingTitle)
            Button("取消", role: .cancel) { }
            Button("儲存") {
                Task {
                    await updateRecordingTitle()
                }
            }
        }
    }
    
    private func editDialogMessage() -> some View {
        Text("請輸入新的錄音標題")
    }
    
    private func deleteDialogActions() -> some View {
        Group {
            Button("取消", role: .cancel) { }
            Button("刪除", role: .destructive) {
                Task {
                    await deleteRecording()
                }
            }
        }
    }
    
    private func deleteDialogMessage() -> some View {
        Text("確定要刪除「\(selectedRecording?.title ?? "")」嗎？")
    }
    
    // MARK: - Actions
    private func updateRecordingTitle() async {
        guard let recording = selectedRecording, !editingTitle.isEmpty else { return }
        
        isSaving = true
        
        // 更新錄音標題的功能暫時不可用
        // TODO: 實現 updateRecordingTitle 方法
        
        isSaving = false
        selectedRecording = nil
        editingTitle = ""
    }
    
    private func deleteRecording() async {
        guard let recording = selectedRecording else { return }
        
        await recordingManager.deleteRecording(recording)
        await recordingManager.loadRecentRecordings(limit: 5)
        
        selectedRecording = nil
    }
}

// MARK: - Preview
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HomeView()
                .environmentObject(AuthenticationManager())
                .environmentObject(RecordingManager())
        }
    }
}