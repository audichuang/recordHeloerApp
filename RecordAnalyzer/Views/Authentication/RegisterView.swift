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
            ScrollView {
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
                                .disableAutocorrection(true)
                            
                            if !username.isEmpty && username.count < 3 {
                                Text("用戶名稱至少需要3個字符")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("電子郵件")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("請輸入電子郵件", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            if !email.isEmpty && !isValidEmail(email) {
                                Text("請輸入有效的電子郵件地址")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("密碼")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            SecureField("請輸入密碼", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            if !password.isEmpty && password.count < 6 {
                                Text("密碼至少需要6個字符")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
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
                        
                        // 添加間距確保按鈕不會被鍵盤遮擋
                        Spacer()
                            .frame(height: 20)
                        
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
                    
                    // 底部間距，確保內容不會被切斷
                    Spacer()
                        .frame(height: 100)
                }
            }
            .scrollDismissesKeyboard(.interactively)
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
        username.count >= 3 &&
        !email.isEmpty &&
        isValidEmail(email) &&
        !password.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthenticationManager())
} 