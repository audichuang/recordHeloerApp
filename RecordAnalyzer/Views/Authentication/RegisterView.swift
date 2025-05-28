import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var animateCards = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    
    var body: some View {
        ZStack {
            // 背景層
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            // 動態背景圖案
            VStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: AppTheme.Gradients.secondary),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 50)
                    .offset(x: -120, y: -50)
                    .opacity(0.3)
                
                Spacer()
            }
            
            ScrollView {
                VStack(spacing: 25) {
                    // 標題和圖標
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: AppTheme.Gradients.secondary),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(
                                    color: AppTheme.Colors.secondary.opacity(0.5),
                                    radius: 15,
                                    x: 0,
                                    y: 5
                                )
                                .offset(y: animateCards ? 0 : 20)
                                .opacity(animateCards ? 1 : 0)
                            
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .symbolEffect(.pulse, options: .repeating, value: animateCards)
                                .offset(y: animateCards ? 0 : 20)
                                .opacity(animateCards ? 1 : 0)
                        }
                        .padding(.top, 30)
                        
                        Text("建立新帳戶")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .offset(y: animateCards ? 0 : 15)
                            .opacity(animateCards ? 1 : 0)
                        
                        Text("請填寫以下資訊來註冊")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .offset(y: animateCards ? 0 : 15)
                            .opacity(animateCards ? 1 : 0)
                    }
                    .padding(.vertical, 20)
                    
                    // 註冊表單卡片
                    AnimatedCardView(
                        title: "帳戶資訊",
                        icon: "person.badge.plus",
                        gradient: AppTheme.Gradients.secondary,
                        delay: 0.2
                    ) {
                        VStack(spacing: 20) {
                            // 用戶名稱輸入
                            VStack(alignment: .leading, spacing: 8) {
                                Text("用戶名稱")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(AppTheme.Colors.secondary)
                                        .font(.system(size: 16))
                                    
                                    TextField("請輸入用戶名稱", text: $username)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                        .fill(AppTheme.Colors.cardHighlight)
                                )
                                
                                if !username.isEmpty && username.count < 3 {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(AppTheme.Colors.warning)
                                            .font(.system(size: 12))
                                        
                                        Text("用戶名稱至少需要3個字符")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.Colors.warning)
                                    }
                                }
                            }
                            
                            // 電子郵件輸入
                            VStack(alignment: .leading, spacing: 8) {
                                Text("電子郵件")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(AppTheme.Colors.secondary)
                                        .font(.system(size: 16))
                                    
                                    TextField("請輸入電子郵件", text: $email)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                        .fill(AppTheme.Colors.cardHighlight)
                                )
                                
                                if !email.isEmpty && !isValidEmail(email) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(AppTheme.Colors.warning)
                                            .font(.system(size: 12))
                                        
                                        Text("請輸入有效的電子郵件地址")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.Colors.warning)
                                    }
                                }
                            }
                            
                            // 密碼輸入
                            VStack(alignment: .leading, spacing: 8) {
                                Text("密碼")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(AppTheme.Colors.secondary)
                                        .font(.system(size: 16))
                                    
                                    if showPassword {
                                        TextField("請輸入密碼", text: $password)
                                            .textFieldStyle(PlainTextFieldStyle())
                                    } else {
                                        SecureField("請輸入密碼", text: $password)
                                            .textFieldStyle(PlainTextFieldStyle())
                                    }
                                    
                                    Button(action: {
                                        showPassword.toggle()
                                    }) {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                            .font(.system(size: 16))
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                        .fill(AppTheme.Colors.cardHighlight)
                                )
                                
                                if !password.isEmpty && password.count < 6 {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(AppTheme.Colors.warning)
                                            .font(.system(size: 12))
                                        
                                        Text("密碼至少需要6個字符")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.Colors.warning)
                                    }
                                }
                            }
                            
                            // 確認密碼輸入
                            VStack(alignment: .leading, spacing: 8) {
                                Text("確認密碼")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                HStack {
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundColor(AppTheme.Colors.secondary)
                                        .font(.system(size: 16))
                                    
                                    if showConfirmPassword {
                                        TextField("請再次輸入密碼", text: $confirmPassword)
                                            .textFieldStyle(PlainTextFieldStyle())
                                    } else {
                                        SecureField("請再次輸入密碼", text: $confirmPassword)
                                            .textFieldStyle(PlainTextFieldStyle())
                                    }
                                    
                                    Button(action: {
                                        showConfirmPassword.toggle()
                                    }) {
                                        Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                            .font(.system(size: 16))
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                        .fill(AppTheme.Colors.cardHighlight)
                                )
                            }
                            
                            if password != confirmPassword && !confirmPassword.isEmpty {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AppTheme.Colors.error)
                                        .font(.system(size: 12))
                                    
                                    Text("密碼不一致")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.Colors.error)
                                }
                            }
                            
                            if let errorMessage = authManager.errorMessage {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AppTheme.Colors.error)
                                        .font(.system(size: 12))
                                    
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundColor(AppTheme.Colors.error)
                                }
                            }
                            
                            // 添加間距確保按鈕不會被鍵盤遮擋
                            Spacer()
                                .frame(height: 20)
                            
                            // 註冊和取消按鈕
                            HStack(spacing: 15) {
                                Button(action: {
                                    dismiss()
                                }) {
                                    Text("取消")
                                        .fontWeight(.medium)
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 20)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                                .stroke(AppTheme.Colors.divider, lineWidth: 1)
                                                .background(AppTheme.Colors.card)
                                        )
                                }
                                
                                GradientButton(
                                    title: "註冊",
                                    icon: authManager.isLoading ? nil : "checkmark",
                                    action: {
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
                                    },
                                    gradient: AppTheme.Gradients.secondary,
                                    isDisabled: !isFormValid || authManager.isLoading
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 安全提示卡片
                    AnimatedCardView(
                        title: "安全提示",
                        icon: "shield.fill",
                        gradient: AppTheme.Gradients.info,
                        delay: 0.3
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.Colors.success)
                                    .font(.system(size: 14))
                                
                                Text("密碼至少6個字符")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.Colors.success)
                                    .font(.system(size: 14))
                                
                                Text("建議包含大小寫字母、數字和特殊符號")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.Colors.success)
                                    .font(.system(size: 14))
                                
                                Text("使用有效的電子郵件地址以便接收通知")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 80)
                }
                .padding(.bottom, 50)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(AppTheme.Animation.standard.delay(0.1)) {
                animateCards = true
            }
        }
        .onDisappear {
            animateCards = false
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