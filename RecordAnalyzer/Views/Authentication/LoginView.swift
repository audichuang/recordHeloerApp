import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegister = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Logo 區域
                VStack(spacing: 16) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("錄音分析助手")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("將您的錄音轉換為文字和摘要")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 50)
                
                // 登入表單
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("電子郵件")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("請輸入電子郵件", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("密碼")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        SecureField("請輸入密碼", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    if let errorMessage = authManager.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: {
                        Task {
                            await authManager.login(email: email, password: password)
                        }
                    }) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("登入")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                }
                .padding(.horizontal, 40)
                
                // 註冊連結
                VStack(spacing: 16) {
                    Text("還沒有帳戶？")
                        .foregroundColor(.secondary)
                    
                    Button("註冊新帳戶") {
                        showingRegister = true
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                }
                
                Spacer()
                
                // 測試帳戶提示
                VStack(spacing: 8) {
                    Text("測試帳戶")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Email: test@example.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Password: password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 30)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingRegister) {
            RegisterView()
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
} 