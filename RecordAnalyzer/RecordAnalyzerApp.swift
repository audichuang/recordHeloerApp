import SwiftUI
import Foundation
import UserNotifications
import Combine

// MARK: - 通知服務 - 負責管理本地通知和應用狀態更新
@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    // 通知中心
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // 通知狀態
    @Published var isAuthorized = false
    
    // 通知類型
    enum NotificationType: String {
        case recordingCompleted = "recording_completed"
        case transcriptionReady = "transcription_ready"
        case summaryReady = "summary_ready"
        case processingFailed = "processing_failed"
        
        var title: String {
            switch self {
            case .recordingCompleted: return "錄音處理完成"
            case .transcriptionReady: return "逐字稿準備就緒"
            case .summaryReady: return "摘要準備就緒"
            case .processingFailed: return "處理失敗"
            }
        }
    }
    
    // 更新訊息廣播
    @Published var latestUpdateMessage: String?
    @Published var shouldRefreshData = false
    
    private init() {
        Task {
            await requestAuthorization()
        }
    }
    
    /// 請求通知權限
    func requestAuthorization() async {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let center = UNUserNotificationCenter.current() // 使用本地變數
            isAuthorized = try await center.requestAuthorization(options: options)
            print("📱 通知授權狀態: \(isAuthorized ? "已授權" : "未授權")")
        } catch {
            print("❌ 請求通知授權失敗: \(error.localizedDescription)")
            isAuthorized = false
        }
    }
    
    /// 發送本地通知
    func sendNotification(
        type: NotificationType,
        title: String? = nil,
        body: String,
        recordingId: String,
        delay: TimeInterval = 0
    ) {
        guard isAuthorized else {
            print("⚠️ 未獲得通知授權，無法發送通知")
            return
        }
        
        // 創建通知內容
        let content = UNMutableNotificationContent()
        content.title = title ?? type.title
        content.body = body
        content.sound = .default
        
        // 添加自定義數據
        content.userInfo = [
            "type": type.rawValue,
            "recordingId": recordingId
        ]
        
        // 創建觸發器（延遲發送）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        
        // 創建通知請求
        let request = UNNotificationRequest(
            identifier: "\(type.rawValue)_\(recordingId)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        // 添加通知請求
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ 發送通知失敗: \(error.localizedDescription)")
            } else {
                print("✅ 已排程通知: \(content.title)")
            }
        }
        
        // 同時更新最新消息並觸發刷新
        DispatchQueue.main.async {
            self.latestUpdateMessage = body
            self.shouldRefreshData = true
        }
    }
    
    /// 取消所有通知
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    /// 取消特定錄音的通知
    func cancelNotifications(for recordingId: String) {
        notificationCenter.getPendingNotificationRequests { requests in
            let identifiersToRemove = requests
                .filter { $0.content.userInfo["recordingId"] as? String == recordingId }
                .map { $0.identifier }
            
            if !identifiersToRemove.isEmpty {
                self.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
                print("🗑️ 已取消 \(identifiersToRemove.count) 個與錄音 \(recordingId) 相關的通知")
            }
        }
    }
    
    /// 觸發資料刷新
    func triggerDataRefresh() {
        shouldRefreshData = true
        
        // 1秒後自動重置狀態
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.shouldRefreshData = false
        }
    }
    
    /// 處理通知點擊事件
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        
        if let typeString = userInfo["type"] as? String,
           let recordingId = userInfo["recordingId"] as? String,
           let type = NotificationType(rawValue: typeString) {
            
            print("👆 用戶點擊了通知: \(type.title), 錄音ID: \(recordingId)")
            
            // 這裡可以處理通知點擊後的導航或顯示相關資訊
            // 例如：導航到特定錄音的詳情頁面
            
            // 觸發數據刷新
            triggerDataRefresh()
        }
    }
}

@main
struct RecordAnalyzerApp: App {
    // 創建環境對象
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var recordingManager = RecordingManager()
    @StateObject private var notificationService = NotificationService.shared
    @State private var incomingFileURL: URL?
    @State private var showingFileImport = false
    @State private var showingSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showingSplash || authManager.isCheckingAuth {
                    SplashView()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .environmentObject(authManager)
                        .environmentObject(recordingManager)
                        .environmentObject(notificationService)
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
                }
            }
            .onAppear {
                setupFileImportHandling()
                setupNotifications()
                checkAuthenticationStatus()
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
    
    private func setupNotifications() {
        print("🔔 設置通知處理...")
        
        // 請求通知授權
        Task {
            await notificationService.requestAuthorization()
        }
        
        // 設置通知代理，處理通知點擊事件
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    private func checkAuthenticationStatus() {
        print("🔐 檢查認證狀態...")
        
        Task {
            // 執行認證檢查
            await authManager.verifyAuthenticationStatus()
            
            // 延遲一點讓動畫更流暢
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            
            // 隱藏啟動畫面
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    showingSplash = false
                }
            }
        }
    }
}

// 通知代理類 - 處理通知響應
@MainActor
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationDelegate()
    
    // 在前台顯示通知
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 即使應用在前台，仍然顯示通知
        completionHandler([.banner, .badge, .sound])
    }
    
    // 處理通知點擊事件
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 複製通知數據，避免數據競爭
        let userInfoCopy = response.notification.request.content.userInfo
        let typeString = userInfoCopy["type"] as? String
        let recordingId = userInfoCopy["recordingId"] as? String
        
        Task { @MainActor in
            // 使用主線程安全地處理通知響應
            if let typeString = typeString,
               let recordingId = recordingId,
               let type = NotificationService.NotificationType(rawValue: typeString) {
                
                print("👆 用戶點擊了通知: \(type.title), 錄音ID: \(recordingId)")
                NotificationService.shared.triggerDataRefresh()
            }
        }
        
        completionHandler()
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
    @State private var animateCard = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景漸變
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "F9FAFB"), Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 文件信息展示
                        CardView(title: "來自其他APP的音頻文件", icon: "doc.circle.fill") {
                            VStack(spacing: 16) {
                                // 文件圖標
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "6366F1").opacity(0.1))
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: "waveform.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(Color(hex: "6366F1"))
                                }
                                .scaleEffect(animateCard ? 1.0 : 0.8)
                                .opacity(animateCard ? 1.0 : 0)
                                
                                VStack(spacing: 8) {
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
                            .padding(.vertical, 8)
                        }
                        .offset(y: animateCard ? 0 : 30)
                        .opacity(animateCard ? 1 : 0)
                        
                        // 輸入區域
                        CardView(title: "錄音標題", icon: "text.cursor") {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("請輸入錄音標題...", text: $fileName)
                                    .padding()
                                    .background(Color(hex: "F3F4F6"))
                                    .cornerRadius(10)
                                    .submitLabel(.done)
                                
                                Text("為這個錄音文件起一個便於識別的名稱")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .offset(y: animateCard ? 0 : 30)
                        .opacity(animateCard ? 1 : 0)
                        
                        // 消息顯示
                        if let errorMessage = errorMessage {
                            CardView(icon: "exclamationmark.triangle.fill", iconGradient: [Color(hex: "EF4444"), Color(hex: "DC2626")]) {
                                Text(errorMessage)
                                    .foregroundColor(Color(hex: "EF4444"))
                                    .font(.subheadline)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        
                        if let successMessage = successMessage {
                            CardView(icon: "checkmark.circle.fill", iconGradient: [Color(hex: "10B981"), Color(hex: "059669")]) {
                                Text(successMessage)
                                    .foregroundColor(Color(hex: "10B981"))
                                    .font(.subheadline)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        
                        // 操作按鈕
                        VStack(spacing: 16) {
                            if isProcessing {
                                HStack {
                                    Spacer()
                                    
                                    ProgressView()
                                        .scaleEffect(1.2)
                                        .padding(.trailing, 10)
                                    
                                    Text("正在上傳...")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(Color(hex: "F3F4F6"))
                                .cornerRadius(12)
                            } else {
                                GradientButton(
                                    title: "開始分析",
                                    icon: "arrow.up.circle.fill",
                                    action: uploadFile,
                                    isDisabled: fileName.isEmpty || !authManager.isAuthenticated
                                )
                                .padding(.horizontal, 8)
                                
                                Button("取消") {
                                    withAnimation {
                                        onComplete()
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(Color(hex: "6B7280"))
                            }
                            
                            if !authManager.isAuthenticated {
                                VStack(spacing: 8) {
                                    Text("請先登入以使用錄音分析功能")
                                        .font(.caption)
                                        .foregroundColor(Color(hex: "F59E0B"))
                                    
                                    Button("前往登入") {
                                        // 這裡可以觸發登入流程
                                        onComplete()
                                    }
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "6366F1"))
                                }
                            }
                        }
                        .offset(y: animateCard ? 0 : 30)
                        .opacity(animateCard ? 1 : 0)
                    }
                    .padding()
                }
            }
            .navigationTitle("導入錄音文件")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onComplete()
                    }
                }
            }
            .onAppear {
                setupInitialData()
                
                // 執行動畫
                withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                    animateCard = true
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
        
        withAnimation {
            isProcessing = true
            errorMessage = nil
            successMessage = nil
        }
        
        Task {
            let result = await recordingManager.uploadRecording(fileURL: fileURL, title: fileName)
            
            await MainActor.run {
                withAnimation(.spring()) {
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
} 