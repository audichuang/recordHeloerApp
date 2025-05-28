import Foundation
import UserNotifications

/// 通知服務 - 負責管理本地通知和應用狀態更新
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
            isAuthorized = try await notificationCenter.requestAuthorization(options: options)
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