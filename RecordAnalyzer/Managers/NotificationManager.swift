import Foundation
@preconcurrency import UserNotifications
import UIKit

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var deviceToken: String?
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() async {
        do {
            print("🔔 請求通知權限...")
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            self.isAuthorized = granted
            
            print("🔔 通知權限結果: \(granted)")
            
            if granted {
                print("🔔 註冊遠端通知...")
                await UIApplication.shared.registerForRemoteNotifications()
            } else {
                print("❌ 通知權限被拒絕，無法接收推送通知")
            }
        } catch {
            print("❌ 通知權限請求失敗: \(error)")
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.isAuthorized = settings.authorizationStatus == .authorized
        
        print("🔔 通知權限狀態檢查:")
        print("  - 授權狀態: \(settings.authorizationStatus.rawValue)")
        print("  - 是否授權: \(self.isAuthorized)")
        print("  - 警告設定: \(settings.alertSetting.rawValue)")
        print("  - 聲音設定: \(settings.soundSetting.rawValue)")
        print("  - 角標設定: \(settings.badgeSetting.rawValue)")
        
        if settings.authorizationStatus == .authorized {
            print("✅ 通知權限已授權，檢查設備 token 註冊...")
            // 如果已授權但沒有設備 token，重新註冊
            if deviceToken == nil {
                print("🔔 重新註冊遠端通知...")
                await UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    func registerDeviceToken(_ deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        self.deviceToken = token
        print("📱 獲得裝置 Token: \(token)")
        print("📱 Token 長度: \(token.count) 字符")
        
        // 延遲發送，等待用戶認證完成
        Task {
            await sendTokenToBackendWithRetry(token)
        }
    }
    
    private func sendTokenToBackendWithRetry(_ token: String, maxRetries: Int = 5) async {
        for attempt in 1...maxRetries {
            print("🔄 嘗試發送設備 Token (第 \(attempt) 次)...")
            
            // 檢查用戶認證狀態 - 使用正確的鍵
            guard let userData = UserDefaults.standard.data(forKey: "savedUser"),
                  let user = try? JSONDecoder().decode(User.self, from: userData),
                  user.accessToken != nil else {
                print("⏳ 用戶認證尚未完成，等待 3 秒後重試...")
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 等待 3 秒
                continue
            }
            
            // 用戶已認證，發送 Token
            await sendTokenToBackend(token)
            return
        }
        
        print("❌ 超過最大重試次數，設備 Token 發送失敗")
    }
    
    /// 手動發送設備 Token（在用戶登入成功後調用）
    func sendDeviceTokenIfAvailable() {
        guard let token = deviceToken else {
            print("📱 沒有可用的設備 Token")
            return
        }
        
        print("📱 手動發送已保存的設備 Token: \(token)")
        Task {
            await sendTokenToBackend(token)
        }
    }
    
    private func sendTokenToBackend(_ token: String) async {
        print("🚀 開始發送設備 Token 到後端...")
        
        guard let userData = UserDefaults.standard.data(forKey: "savedUser"),
              let user = try? JSONDecoder().decode(User.self, from: userData) else {
            print("❌ 無法取得用戶認證資料，設備 Token 發送失敗")
            return
        }
        
        print("✅ 用戶認證資料存在，用戶: \(user.username)")
        
        do {
            var request = URLRequest(url: URL(string: "http://audimacbookpro:9527/api/users/device-token")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // 使用 User 的 accessToken 屬性
            if let accessToken = user.accessToken {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                print("✅ 認證 Token 已設定")
            } else {
                print("❌ 用戶沒有有效的認證 Token")
                return
            }
            
            let body = ["device_token": token, "platform": "ios"]
            request.httpBody = try JSONEncoder().encode(body)
            
            print("🌐 發送 API 請求到: http://audimacbookpro:9527/api/users/device-token")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 API 回應狀態碼: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    print("✅ 設備 Token 註冊成功！")
                } else {
                    let responseString = String(data: data, encoding: .utf8) ?? "無回應內容"
                    print("❌ 設備 Token 註冊失敗: \(responseString)")
                }
            }
        } catch {
            print("❌ 發送設備 Token 失敗: \(error)")
        }
    }
    
    func showLocalNotification(title: String, body: String, identifier: String? = nil) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("本地通知發送失敗: \(error)")
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // 當 App 在前景時也顯示通知
        return [.banner, .sound, .badge]
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // 處理通知點擊事件
        let userInfo = response.notification.request.content.userInfo
        
        if let recordingId = userInfo["recordingId"] as? String {
            // 導航到特定錄音詳情頁
            await MainActor.run {
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToRecording"),
                    object: nil,
                    userInfo: ["recordingId": recordingId]
                )
            }
        }
    }
    
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) async {
        // 處理遠端推送通知
        guard let type = userInfo["type"] as? String else { return }
        
        switch type {
        case "recording_completed":
            if let recordingId = userInfo["recordingId"] as? String,
               let status = userInfo["status"] as? String {
                // 發送通知給 RecordingManager 更新狀態
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: Notification.Name("RecordingProcessingCompleted"),
                        object: nil,
                        userInfo: [
                            "recordingId": recordingId,
                            "status": status
                        ]
                    )
                }
            }
        default:
            break
        }
    }
}