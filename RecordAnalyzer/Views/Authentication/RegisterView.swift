import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                // 標題
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("建立新帳戶")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("請填寫以下資訊來註冊")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 30)
                
                // 註冊表單
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("用戶名稱")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("請輸入用戶名稱", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                    }
                    
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
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("確認密碼")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        SecureField("請再次輸入密碼", text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    if password != confirmPassword && !confirmPassword.isEmpty {
                        Text("密碼不一致")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    if let errorMessage = authManager.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: {
                        Task {
                            await authManager.register(
                                username: username,
                                email: email,
                                password: password
                            )
                            if authManager.isAuthenticated {
                                dismiss()
                            }
                        }
                    }) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("註冊")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!isFormValid || authManager.isLoading)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .navigationTitle("註冊")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !username.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 6
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthenticationManager())
} 