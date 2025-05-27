import Foundation
import SwiftUI

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = "http://localhost:5000/api"
    
    init() {
        // 檢查是否有保存的登入狀態
        checkSavedAuthState()
    }
    
    func register(username: String, email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // 模擬API調用
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            // 假資料註冊成功
            let newUser = User(username: username, email: email, createdAt: Date())
            self.currentUser = newUser
            self.isAuthenticated = true
            self.isLoading = false
            
            // 保存認證狀態
            saveAuthState()
        }
    }
    
    func login(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // 模擬API調用
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            // 假資料登入成功
            if email == "test@example.com" && password == "password" {
                let user = User(username: "測試用戶", email: email, createdAt: Date())
                self.currentUser = user
                self.isAuthenticated = true
                
                // 保存認證狀態
                saveAuthState()
            } else {
                self.errorMessage = "電子郵件或密碼錯誤"
            }
            
            self.isLoading = false
        }
    }
    
    func logout() {
        currentUser = nil
        isAuthenticated = false
        clearAuthState()
    }
    
    private func checkSavedAuthState() {
        if let userData = UserDefaults.standard.data(forKey: "savedUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
            isAuthenticated = true
        }
    }
    
    private func saveAuthState() {
        if let user = currentUser,
           let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "savedUser")
        }
    }
    
    private func clearAuthState() {
        UserDefaults.standard.removeObject(forKey: "savedUser")
    }
} 