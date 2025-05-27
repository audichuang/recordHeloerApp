import Foundation
import SwiftUI

// Swift 6.0 升級：使用 @MainActor 確保UI更新安全
@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkService = NetworkService.shared
    
    // Swift 6.0 升級：使用 actor 來處理數據存儲
    private let dataStore = AuthDataStore()
    
    init() {
        Task {
            await checkSavedAuthState()
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
    
    private func checkSavedAuthState() async {
        if let user = await dataStore.loadUser() {
            // 檢查token是否仍然有效
            do {
                let currentUser = try await networkService.getCurrentUser()
                self.currentUser = currentUser
                self.isAuthenticated = true
                
                // 更新本地保存的用戶信息
                await dataStore.saveUser(currentUser)
            } catch {
                // Token無效，清除本地狀態
                await dataStore.clearUser()
                self.currentUser = nil
                self.isAuthenticated = false
                print("Token無效，已清除登入狀態: \(error)")
            }
        }
    }
}

// Swift 6.0 新功能：使用 actor 確保數據安全
actor AuthDataStore {
    private let userKey = "savedUser"
    
    func saveUser(_ user: User) {
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
    }
    
    func loadUser() -> User? {
        guard let userData = UserDefaults.standard.data(forKey: userKey),
              let user = try? JSONDecoder().decode(User.self, from: userData) else {
            return nil
        }
        return user
    }
    
    func clearUser() {
        UserDefaults.standard.removeObject(forKey: userKey)
    }
} 