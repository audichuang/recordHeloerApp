import SwiftUI
import Foundation
import UserNotifications
import Combine
import UIKit

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            NotificationManager.shared.registerDeviceToken(deviceToken)
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ 註冊遠端通知失敗: \(error)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // 處理背景推送通知
        Task {
            await NotificationManager.shared.handleRemoteNotification(userInfo: userInfo)
            completionHandler(.newData)
        }
    }
}

@main
struct RecordAnalyzerApp: App {
    // 創建環境對象
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var recordingManager = RecordingManager()
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var promptTemplateManager = PromptTemplateManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
                        .environmentObject(notificationManager)
                        .environmentObject(promptTemplateManager)
                        .sheet(isPresented: $showingFileImport) {
                            if let fileURL = incomingFileURL {
                                FileImportView(fileURL: fileURL) {
                                    // 文件處理完成後清理
                                    incomingFileURL = nil
                                    showingFileImport = false
                                }
                                .environmentObject(recordingManager)
                                .environmentObject(authManager)
                                .environmentObject(promptTemplateManager)
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
                
                // 設定通知觀察者
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("NavigateToRecording"),
                    object: nil,
                    queue: .main
                ) { notification in
                    if let recordingId = notification.userInfo?["recordingId"] as? String {
                        // TODO: 導航到特定錄音
                        print("🔔 收到通知點擊，錄音ID: \(recordingId)")
                    }
                }
            }
        }
    }
    
    // MARK: - 初始化方法
    
    private func setupNotifications() {
        Task {
            print("🔔 設置通知權限...")
            
            // 檢查現有權限狀態
            await notificationManager.checkAuthorizationStatus()
            
            // 如果沒有權限，請求權限
            if !notificationManager.isAuthorized {
                await notificationService.requestAuthorization()
                await notificationManager.requestAuthorization()
                
                // 再次檢查權限狀態
                await notificationManager.checkAuthorizationStatus()
            }
        }
    }
    
    private func checkAuthenticationStatus() {
        Task {
            await authManager.verifyAuthenticationStatus()
            
            // 如果用戶已登入，載入模板
            if authManager.isAuthenticated {
                await promptTemplateManager.loadTemplates()
            }
            
            // 檢查完成後，延遲一下再隱藏啟動畫面
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            withAnimation(.easeOut(duration: 0.3)) {
                showingSplash = false
            }
        }
    }
    
    // MARK: - 文件處理
    
    private func setupFileImportHandling() {
        // 設置文件處理
        print("🔧 設置文件導入處理")
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("📁 收到 URL: \(url)")
        
        // 處理不同的 URL scheme
        if url.scheme == "recordanalyzer" {
            // 處理自定義 URL scheme
            handleCustomScheme(url)
        } else if url.scheme == "file" || url.scheme == "recordanalyzer-files" {
            // 處理文件導入
            handleFileImport(url)
        }
    }
    
    private func handleCustomScheme(_ url: URL) {
        // 處理自定義 URL scheme 的邏輯
        // 例如：recordanalyzer://action?parameter=value
        print("🔗 處理自定義 URL scheme: \(url)")
    }
    
    private func handleFileImport(_ url: URL) {
        print("📥 處理文件導入: \(url.lastPathComponent)")
        
        // 確保文件是音頻文件
        let supportedExtensions = ["mp3", "wav", "m4a", "aac", "flac", "ogg"]
        let fileExtension = url.pathExtension.lowercased()
        
        guard supportedExtensions.contains(fileExtension) else {
            print("❌ 不支援的文件格式: \(fileExtension)")
            return
        }
        
        // 設置文件 URL 並顯示導入視圖
        incomingFileURL = url
        showingFileImport = true
    }
}

// MARK: - 文件導入視圖
struct FileImportView: View {
    let fileURL: URL
    let onComplete: () -> Void
    
    @EnvironmentObject var recordingManager: RecordingManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isProcessing {
                    ProgressView("正在處理文件...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text("準備導入音頻文件")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(fileURL.lastPathComponent)
                        .font(.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(AppTheme.Colors.error)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    HStack(spacing: 20) {
                        Button("取消") {
                            onComplete()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("導入") {
                            Task {
                                await processFile()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .navigationTitle("導入文件")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func processFile() async {
        isProcessing = true
        errorMessage = nil
        
        do {
            // 確保用戶已登入
            guard authManager.isAuthenticated else {
                errorMessage = "請先登入後再導入文件"
                isProcessing = false
                return
            }
            
            // 開始訪問安全範圍的 URL
            guard fileURL.startAccessingSecurityScopedResource() else {
                errorMessage = "無法訪問文件"
                isProcessing = false
                return
            }
            
            defer {
                fileURL.stopAccessingSecurityScopedResource()
            }
            
            // 複製文件到應用的臨時目錄
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileURL = tempDir.appendingPathComponent(fileURL.lastPathComponent)
            
            // 如果臨時文件已存在，先刪除
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                try FileManager.default.removeItem(at: tempFileURL)
            }
            
            try FileManager.default.copyItem(at: fileURL, to: tempFileURL)
            
            // 上傳文件
            _ = try await recordingManager.uploadRecording(
                fileURL: tempFileURL,
                title: fileURL.deletingPathExtension().lastPathComponent
            )
            
            // 清理臨時文件
            try? FileManager.default.removeItem(at: tempFileURL)
            
            // 完成
            onComplete()
            
        } catch {
            errorMessage = "導入失敗: \(error.localizedDescription)"
            isProcessing = false
        }
    }
}