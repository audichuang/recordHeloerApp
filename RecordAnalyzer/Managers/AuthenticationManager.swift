import Foundation
import SwiftUI

// Swift 6.0 升級：使用 @MainActor 確保UI更新安全
@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isCheckingAuth = true  // 新增：檢查認證狀態中
    
    private let networkService = NetworkService.shared
    
    // Swift 6.0 升級：使用 actor 來處理數據存儲
    private let dataStore = AuthDataStore()
    
    init() {
        // 監聽未授權訪問通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnauthorizedAccess),
            name: .unauthorizedAccess,
            object: nil
        )
    }
    
    @objc private func handleUnauthorizedAccess() {
        print("🔒 收到未授權訪問通知，執行登出")
        Task { @MainActor in
            currentUser = nil
            isAuthenticated = false
            await dataStore.clearUser()
        }
    }
    
    func register(username: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 調用真實API
            let user = try await networkService.register(
                username: username,
                email: email,
                password: password
            )
            
            self.currentUser = user
            self.isAuthenticated = true
            self.isLoading = false
            
            // 保存認證狀態
            await dataStore.saveUser(user)
        } catch {
            self.errorMessage = "註冊失敗：\(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 調用真實API
            let user = try await networkService.login(email: email, password: password)
            
            self.currentUser = user
            self.isAuthenticated = true
            self.isLoading = false
            
            // 保存認證狀態
            await dataStore.saveUser(user)
        } catch {
            self.errorMessage = "登入失敗：\(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    func logout() {
        Task {
            do {
                // 調用真實API登出
                try await networkService.logout()
            } catch {
                print("登出API調用失敗: \(error)")
                // 即使API失敗，也要清除本地狀態
            }
            
            currentUser = nil
            isAuthenticated = false
            await dataStore.clearUser()
        }
    }
    
    // 新增：檢查令牌有效性
    func verifyAuthenticationStatus() async {
        isCheckingAuth = true
        
        // 先檢查是否有保存的令牌
        if let token = UserDefaults.standard.string(forKey: "auth_token") {
            print("發現保存的令牌，嘗試驗證...")
            
            do {
                let currentUser = try await networkService.getCurrentUser()
                self.currentUser = currentUser
                self.isAuthenticated = true
                print("令牌有效，已自動登入用戶: \(currentUser.username)")
                
                // 更新本地保存的用戶信息
                await dataStore.saveUser(currentUser)
            } catch {
                print("令牌驗證失敗: \(error)")
                // Token無效，清除本地狀態
                await dataStore.clearUser()
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
        
        isCheckingAuth = false
    }
    
    private func checkSavedAuthState() async {
        print("檢查保存的認證狀態")
        
        // 先檢查是否有直接保存的令牌
        if let token = UserDefaults.standard.string(forKey: "auth_token") {
            print("發現保存的令牌，嘗試驗證...")
            
            do {
                let currentUser = try await networkService.getCurrentUser()
                self.currentUser = currentUser
                self.isAuthenticated = true
                print("令牌有效，已自動登入用戶: \(currentUser.username)")
                
                // 更新本地保存的用戶信息
                await dataStore.saveUser(currentUser)
            } catch {
                print("令牌驗證失敗: \(error)")
                // 檢查是否有保存的用戶數據
                if let user = await dataStore.loadUser() {
                    print("找到保存的用戶數據，嘗試使用其中的令牌...")
                    // 不需要進一步操作，因為 NetworkService 會自動從保存的用戶數據中嘗試獲取令牌
                } else {
                    print("沒有發現保存的用戶數據，清除登入狀態")
                    // Token無效，清除本地狀態
                    await dataStore.clearUser()
                    UserDefaults.standard.removeObject(forKey: "auth_token")
                    UserDefaults.standard.removeObject(forKey: "refresh_token")
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
            }
        } else if let user = await dataStore.loadUser() {
            print("發現保存的用戶數據，嘗試驗證...")
            
            // 檢查保存的用戶數據是否包含令牌
            if let userData = UserDefaults.standard.data(forKey: "savedUser"),
               let savedUser = try? JSONDecoder().decode(User.self, from: userData),
               savedUser.accessToken != nil {
                
                print("用戶數據包含令牌，嘗試驗證...")
                
                do {
                    let currentUser = try await networkService.getCurrentUser()
                    self.currentUser = currentUser
                    self.isAuthenticated = true
                    print("令牌有效，已自動登入用戶: \(currentUser.username)")
                    
                    // 更新本地保存的用戶信息
                    await dataStore.saveUser(currentUser)
                } catch {
                    print("令牌驗證失敗: \(error)")
                    // Token無效，清除本地狀態
                    await dataStore.clearUser()
                    UserDefaults.standard.removeObject(forKey: "auth_token")
                    UserDefaults.standard.removeObject(forKey: "refresh_token")
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
            } else {
                print("保存的用戶數據不包含有效令牌，清除登入狀態")
                await dataStore.clearUser()
                self.currentUser = nil
                self.isAuthenticated = false
            }
        } else {
            print("沒有發現保存的認證狀態")
        }
    }
}

// Swift 6.0 新功能：使用 actor 確保數據安全
actor AuthDataStore {
    private let userKey = "savedUser"
    
    func saveUser(_ user: User) {
        // 確保保存的用戶數據包含令牌資訊
        var userToSave = user
        
        // 如果用戶對象沒有令牌但 UserDefaults 中有令牌，將令牌添加到用戶對象
        if userToSave.accessToken == nil,
           let accessToken = UserDefaults.standard.string(forKey: "auth_token") {
            userToSave.accessToken = accessToken
        }
        
        if userToSave.refreshToken == nil,
           let refreshToken = UserDefaults.standard.string(forKey: "refresh_token") {
            userToSave.refreshToken = refreshToken
        }
        
        if let userData = try? JSONEncoder().encode(userToSave) {
            UserDefaults.standard.set(userData, forKey: userKey)
            UserDefaults.standard.synchronize()
            print("📝 AuthDataStore: 保存用戶數據成功")
        } else {
            print("⚠️ AuthDataStore: 無法編碼用戶數據")
        }
    }
    
    func loadUser() -> User? {
        guard let userData = UserDefaults.standard.data(forKey: userKey) else {
            print("⚠️ AuthDataStore: 未找到保存的用戶數據")
            return nil
        }
        
        do {
            let user = try JSONDecoder().decode(User.self, from: userData)
            print("📝 AuthDataStore: 加載用戶數據成功: \(user.username)")
            return user
        } catch {
            print("⚠️ AuthDataStore: 解碼用戶數據失敗: \(error)")
            return nil
        }
    }
    
    func clearUser() {
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "refresh_token")
        UserDefaults.standard.synchronize()
        print("🗑️ AuthDataStore: 清除用戶數據")
    }
}

// User 模型定義
struct User: Codable, Identifiable, Equatable {
    let id: String
    let username: String
    let email: String
    let isActive: Bool
    let profileData: [String: String]
    let createdAt: String
    let updatedAt: String
    
    // 添加令牌儲存
    var accessToken: String?
    var refreshToken: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case isActive = "is_active"
        case profileData = "profile_data"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
    
    // 添加用於驗證令牌是否存在的輔助方法
    func hasValidToken() -> Bool {
        return accessToken != nil
    }
    
    // 添加用於創建帶有令牌的新用戶實例的方法
    func withTokens(access: String?, refresh: String?) -> User {
        var newUser = self
        newUser.accessToken = access
        newUser.refreshToken = refresh
        return newUser
    }
} 