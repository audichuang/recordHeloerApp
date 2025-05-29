import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var recordingManager: RecordingManager
    @State private var showingFilePicker = false
    @State private var showingUploadDialog = false
    @State private var uploadTitle = ""
    @State private var selectedFileURL: URL?
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var animateCards = false
    @State private var selectedRecording: Recording?
    @State private var showingEditDialog = false
    @State private var showingDeleteAlert = false
    @State private var editingTitle = ""
    @State private var isSaving = false
    @Binding var selectedTab: Int
    
    // 為預覽提供預設初始化器
    init(selectedTab: Binding<Int> = .constant(0)) {
        self._selectedTab = selectedTab
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // 歡迎區域
                welcomeSection
                    .smallShadow()
                    .offset(y: animateCards ? 0 : -30)
                    .opacity(animateCards ? 1 : 0)
                
                // 上傳區域
                AnimatedCardView(
                    title: "上傳新錄音",
                    icon: "square.and.arrow.up.fill",
                    gradient: AppTheme.Gradients.info,
                    delay: 0.2
                ) {
                    uploadContent
                }
                
                // 錯誤信息
                if let error = recordingManager.error {
                    errorBanner(message: error)
                        .smallShadow()
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                }
                
                // 最近的錄音
                AnimatedCardView(
                    title: "最近的錄音",
                    icon: "clock.fill",
                    gradient: AppTheme.Gradients.secondary,
                    delay: 0.4
                ) {
                    recentRecordingsContent
                }
            }
            .padding()
        }
        .background(Color.clear)
        .navigationTitle("錄音分析助手")
        .refreshable {
            // 使用專門為HomeView設計的最近錄音API
            await recordingManager.loadRecentRecordings(limit: 5)
        }
        .onAppear {
            withAnimation(AppTheme.Animation.standard) {
                animateCards = true
            }
            
            if recordingManager.recordings.isEmpty {
                Task {
                    // 使用專門為HomeView設計的最近錄音API
                    await recordingManager.loadRecentRecordings(limit: 5)
                }
            }
        }
        .onDisappear {
            animateCards = false
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [
                .audio, 
                .mp3,
                .wav,
                UTType(filenameExtension: "m4a") ?? .audio,
                UTType(filenameExtension: "aac") ?? .audio,
                UTType(filenameExtension: "flac") ?? .audio
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // 檢查文件擴展名
                    let validExtensions = ["mp3", "wav", "m4a", "aac", "flac", "mp4", "ogg"]
                    if validExtensions.contains(url.pathExtension.lowercased()) {
                        // 嘗試從文件名推斷標題
                        let suggestedTitle = url.deletingPathExtension().lastPathComponent
                        
                        selectedFileURL = url
                        uploadTitle = suggestedTitle
                        showingUploadDialog = true
                    } else {
                        errorMessage = "不支援的音頻格式: \(url.pathExtension). 請上傳 MP3, WAV, M4A, AAC 或 FLAC 格式文件。"
                        showingErrorAlert = true
                    }
                }
            case .failure(let error):
                print("檔案選擇錯誤: \(error)")
                errorMessage = "檔案選擇失敗: \(error.localizedDescription)"
                showingErrorAlert = true
            }
        }
        .alert("上傳錄音", isPresented: $showingUploadDialog) {
            TextField("請輸入錄音標題", text: $uploadTitle)
            Button("上傳") {
                if let url = selectedFileURL {
                    Task {
                        print("開始上傳文件: \(url.lastPathComponent)")
                        _ = await recordingManager.uploadRecording(
                            fileURL: url,
                            title: uploadTitle.isEmpty ? "未命名錄音" : uploadTitle
                        )
                        uploadTitle = ""
                        selectedFileURL = nil
                    }
                }
            }
            Button("取消", role: .cancel) {
                uploadTitle = ""
                selectedFileURL = nil
            }
        } message: {
            if let url = selectedFileURL {
                Text("將上傳: \(url.lastPathComponent)\n請為您的錄音檔案輸入一個標題")
            } else {
                Text("請為您的錄音檔案輸入一個標題")
            }
        }
        .alert("上傳錯誤", isPresented: $showingErrorAlert) {
            Button("確定", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "未知錯誤")
        }
        .alert("編輯標題", isPresented: $showingEditDialog) {
            TextField("錄音標題", text: $editingTitle)
            Button("取消", role: .cancel) { }
            Button("儲存") {
                Task {
                    await self.updateRecordingTitle()
                }
            }
        } message: {
            Text("請輸入新的錄音標題")
        }
        .alert("刪除錄音", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("刪除", role: .destructive) {
                Task {
                    await self.deleteRecording()
                }
            }
        } message: {
            Text("確定要刪除「\(selectedRecording?.title ?? "")」嗎？此操作無法復原。")
        }
    }
    
    private var welcomeSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    ShimmeringText(
                        text: "歡迎回來！",
                        fontSize: 24,
                        fontWeight: .bold,
                        baseColor: AppTheme.Colors.textPrimary
                    )
                    
                    if let user = authManager.currentUser {
                        GradientText(
                            text: "\(user.username)",
                            gradient: AppTheme.Gradients.primary,
                            fontSize: 20,
                            fontWeight: .semibold
                        )
                    }
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: AppTheme.Gradients.primary),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: AppTheme.Colors.primary.opacity(0.5), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "waveform")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .symbolEffect(.variableColor, options: .speed(0.5), value: animateCards)
                }
            }
            
            Text("將您的錄音轉換為準確的文字記錄和智能摘要")
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.leading)
                .padding(.top, 4)
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .fill(AppTheme.Colors.card)
                
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [AppTheme.Colors.primary.opacity(0.5), AppTheme.Colors.secondary.opacity(0.3)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .opacity(0.5)
            }
        )
    }
    
    private var uploadContent: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingFilePicker = true
            }) {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        if recordingManager.isUploading {
                            // 顯示圓形進度指示器
                            ZStack {
                                // 背景圓圈 - 使用更深的顏色
                                Circle()
                                    .stroke(lineWidth: 10)
                                    .foregroundColor(Color.gray.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                // 進度圓圈 - 使用更鮮豔的顏色
                                Circle()
                                    .trim(from: 0.0, to: recordingManager.uploadProgress)
                                    .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(Angle(degrees: -90))
                                    .animation(.easeInOut(duration: 0.3), value: recordingManager.uploadProgress)
                                    .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 4, x: 0, y: 0)
                                
                                // 百分比文字 - 使用白色確保清晰可見
                                Text("\(Int(recordingManager.uploadProgress * 100))%")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            }
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 34))
                                .foregroundColor(AppTheme.Colors.primary)
                                .symbolEffect(.bounce, options: .speed(0.5), value: animateCards)
                        }
                    }
                    
                    Text(recordingManager.isUploading ? "正在處理錄音..." : "選擇錄音檔案")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(recordingManager.isUploading ? AppTheme.Colors.textPrimary : AppTheme.Colors.primary)
                    
                    Text(recordingManager.isUploading ? "請稍候，正在分析您的錄音" : "支援 MP3, M4A, WAV 等格式")
                        .font(.caption)
                        .foregroundColor(recordingManager.isUploading ? AppTheme.Colors.textPrimary.opacity(0.8) : AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [AppTheme.Colors.primary.opacity(0.5), AppTheme.Colors.secondary.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 2, dash: [10])
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(recordingManager.isUploading)
            
            // 分割線
            HStack {
                VStack { Divider() }
                Text("或")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                VStack { Divider() }
            }
            .padding(.horizontal)
            
            // 從其他APP導入提示
            VStack(spacing: 8) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.success.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.success)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("從其他APP分享")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.Colors.success)
                        
                        Text("在語音備忘錄或其他錄音APP中點擊分享，選擇「錄音分析助手」")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                        .fill(AppTheme.Colors.success.opacity(0.1))
                )
            }
        }
    }
    
    
    private func errorBanner(message: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppTheme.Colors.error)
                
                Text("錯誤信息")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.error)
                
                Spacer()
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(AppTheme.Colors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                        .stroke(AppTheme.Colors.error.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var recentRecordingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer()
                
                Button(action: {
                    // 直接切換到歷史標籤頁
                    selectedTab = 1
                }) {
                    HStack(spacing: 4) {
                        Text("查看全部")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
            
            if recordingManager.recordings.isEmpty {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "music.note.list")
                            .font(.system(size: 34))
                            .foregroundColor(.gray)
                    }
                    
                    VStack(spacing: 8) {
                        Text("尚無錄音記錄")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text("上傳您的第一個錄音文件開始使用")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(recordingManager.recordings.prefix(5)), id: \.id) { recording in
                        NavigationLink(destination: RecordingDetailView(recording: recording)) {
                            RecordingRowView(recording: recording)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button(action: {
                                selectedRecording = recording
                                editingTitle = recording.title
                                showingEditDialog = true
                            }) {
                                Label("編輯標題", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive, action: {
                                selectedRecording = recording
                                showingDeleteAlert = true
                            }) {
                                Label("刪除錄音", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}

// 自定義漸變進度條樣式
struct GradientProgressStyle: ProgressViewStyle {
    var height: Double = 8
    var gradient: Gradient
    
    func makeBody(configuration: Configuration) -> some View {
        let fractionCompleted = configuration.fractionCompleted ?? 0
        
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: height / 2)
                .frame(height: height)
                .foregroundColor(Color.gray.opacity(0.2))
            
            RoundedRectangle(cornerRadius: height / 2)
                .frame(width: max(CGFloat(fractionCompleted) * UIScreen.main.bounds.width - 80, 0), height: height)
                .foregroundStyle(
                    LinearGradient(
                        gradient: gradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}

extension HomeView {
    /// 更新錄音標題
    private func updateRecordingTitle() async {
        guard let recording = self.selectedRecording,
              !self.editingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        self.isSaving = true
        
        do {
            try await NetworkService.shared.updateRecordingTitle(
                recordingId: recording.id.uuidString,
                newTitle: self.editingTitle
            )
            
            // 更新本地數據
            await MainActor.run {
                if let index = self.recordingManager.recordings.firstIndex(where: { $0.id == recording.id }) {
                    self.recordingManager.recordings[index].title = self.editingTitle
                }
                
                self.selectedRecording = nil
                self.isSaving = false
            }
        } catch {
            await MainActor.run {
                // 顯示錯誤（可以添加錯誤提示）
                print("更新標題失敗: \(error.localizedDescription)")
                self.isSaving = false
            }
        }
    }
    
    /// 刪除錄音
    private func deleteRecording() async {
        guard let recording = self.selectedRecording else { return }
        
        await self.recordingManager.deleteRecording(recording)
        self.selectedRecording = nil
    }
}

#Preview {
    HomeView(selectedTab: .constant(0))
        .environmentObject(AuthenticationManager())
        .environmentObject(RecordingManager())
} 