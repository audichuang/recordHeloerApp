import SwiftUI
import Foundation

@main
struct RecordAnalyzerApp: App {
    // 創建環境對象
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var recordingManager = RecordingManager()
    @State private var incomingFileURL: URL?
    @State private var showingFileImport = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(recordingManager)
                .sheet(isPresented: $showingFileImport) {
                    if let fileURL = incomingFileURL {
                        FileImportView(fileURL: fileURL) {
                            // 文件處理完成後清理
                            incomingFileURL = nil
                            showingFileImport = false
                        }
                        .environmentObject(recordingManager)
                        .environmentObject(authManager)
                    }
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onAppear {
                    setupFileImportHandling()
                }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("📲 收到分享文件: \(url)")
        
        // 檢查是否為音頻文件
        let validExtensions = ["mp3", "wav", "m4a", "aac", "flac", "mp4", "ogg"]
        let fileExtension = url.pathExtension.lowercased()
        
        if validExtensions.contains(fileExtension) {
            incomingFileURL = url
            showingFileImport = true
        } else {
            print("❌ 不支援的文件格式: \(fileExtension)")
        }
    }
    
    private func setupFileImportHandling() {
        // 可以在這裡做一些初始設置
        print("🚀 錄音分析APP已啟動，支援文件分享導入")
    }
}

// 文件導入處理視圖
struct FileImportView: View {
    let fileURL: URL
    let onComplete: () -> Void
    
    @EnvironmentObject var recordingManager: RecordingManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var fileName: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 文件信息展示
                fileInfoSection
                
                // 輸入區域
                titleInputSection
                
                // 操作按鈕
                actionButtonsSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("導入錄音文件")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onComplete()
                    }
                }
            }
        }
        .onAppear {
            setupInitialData()
        }
    }
    
    private var fileInfoSection: some View {
        VStack(spacing: 16) {
            // 文件圖標
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Text("來自其他APP的音頻文件")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(fileURL.lastPathComponent)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                // 文件大小信息
                if let fileSize = getFileSize() {
                    Text("文件大小: \(formatFileSize(fileSize))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var titleInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("錄音標題")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextField("請輸入錄音標題...", text: $fileName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.done)
            
            Text("為這個錄音文件起一個便於識別的名稱")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if let successMessage = successMessage {
                Text(successMessage)
                    .foregroundColor(.green)
                    .font(.caption)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Button(action: uploadFile) {
                if isProcessing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("正在上傳...")
                    }
                } else {
                    Text("開始分析")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(fileName.isEmpty || isProcessing || !authManager.isAuthenticated)
            
            if !authManager.isAuthenticated {
                VStack(spacing: 8) {
                    Text("請先登入以使用錄音分析功能")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Button("前往登入") {
                        // 這裡可以觸發登入流程
                        onComplete()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func setupInitialData() {
        // 使用文件名作為預設標題（去掉副檔名）
        let nameWithoutExtension = fileURL.deletingPathExtension().lastPathComponent
        fileName = nameWithoutExtension
    }
    
    private func getFileSize() -> Int? {
        do {
            let resources = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            return resources.fileSize
        } catch {
            return nil
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func uploadFile() {
        guard !fileName.isEmpty else { return }
        
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            let result = await recordingManager.uploadRecording(fileURL: fileURL, title: fileName)
            
            await MainActor.run {
                if result != nil {
                    successMessage = "文件上傳成功！正在進行語音分析..."
                    
                    // 延遲一秒後關閉視圖
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        onComplete()
                    }
                } else {
                    errorMessage = recordingManager.error ?? "上傳失敗"
                }
                
                isProcessing = false
            }
        }
    }
} 