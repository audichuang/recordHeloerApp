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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // 歡迎區域
                    welcomeSection
                    
                    // 上傳區域
                    uploadSection
                    
                    // 上傳進度
                    if recordingManager.isUploading {
                        uploadProgressSection
                    }
                    
                    // 錯誤信息
                    if let error = recordingManager.errorMessage {
                        errorBanner(message: error)
                    }
                    
                    // 最近的錄音
                    recentRecordingsSection
                }
                .padding()
            }
            .navigationTitle("錄音分析助手")
            .refreshable {
                await recordingManager.loadRecordings()
            }
            .onAppear {
                // 確保每次視圖出現時都從後端加載最新的錄音數據
                Task {
                    await recordingManager.loadRecordings()
                }
            }
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
    }
    
    private var welcomeSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("歡迎回來！")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let user = authManager.currentUser {
                        Text("\(user.username)")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }
            
            Text("將您的錄音轉換為準確的文字記錄和智能摘要")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(15)
    }
    
    private var uploadSection: some View {
        VStack(spacing: 16) {
            Text("上傳新錄音")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Button(action: {
                    showingFilePicker = true
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        Text("選擇錄音檔案")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("支援 MP3, M4A, WAV 等格式")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [10]))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // 分割線
                HStack {
                    VStack { Divider() }
                    Text("或")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    VStack { Divider() }
                }
                .padding(.horizontal)
                
                // 從其他APP導入提示
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("從其他APP分享")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            
                            Text("在語音備忘錄或其他錄音APP中點擊分享，選擇「錄音分析助手」")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(15)
    }
    
    private var uploadProgressSection: some View {
        VStack(spacing: 12) {
            Text("正在處理錄音...")
                .font(.headline)
            
            ProgressView(value: recordingManager.uploadProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(1.2)
            
            Text("\(Int(recordingManager.uploadProgress * 100))% 完成")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(15)
    }
    
    private func errorBanner(message: String) -> some View {
        VStack(spacing: 12) {
            Text("錯誤信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(15)
    }
    
    private var recentRecordingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("最近的錄音")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink("查看全部") {
                    HistoryView()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if recordingManager.recordings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("尚無錄音記錄")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("上傳您的第一個錄音文件開始使用")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(recordingManager.recordings.prefix(3))) { recording in
                        NavigationLink(destination: RecordingDetailView(recording: recording)) {
                            RecordingRowView(recording: recording)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthenticationManager())
        .environmentObject(RecordingManager())
} 