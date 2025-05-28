import SwiftUI
import Combine

// MARK: - 定義 Field 枚舉在外面，供所有視圖使用
enum RegisterField: Hashable {
    case username, email, password, confirmPassword
}

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
    @State private var keyboardHeight: CGFloat = 0
    @State private var activeField: RegisterField? = nil
    
    // 使用 @FocusState 來更好地管理焦點
    @FocusState private var focusedField: RegisterField?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景層 - 確保能接收點擊事件
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }
                
                // 實際背景
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                // 動態背景圖案
                RegisterBackgroundDecoration()
                
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 25) {
                            // 標題和圖標 - 鍵盤出現時縮小間距
                            RegisterHeader(animateCards: animateCards)
                                .padding(.vertical, keyboardHeight > 0 ? 10 : 20)
                            
                            // 註冊表單卡片
                            RegisterFormCard(
                                username: $username,
                                email: $email,
                                password: $password,
                                confirmPassword: $confirmPassword,
                                showPassword: $showPassword,
                                showConfirmPassword: $showConfirmPassword,
                                focusedField: $focusedField
                            )
                            .padding(.horizontal)
                            
                            // 安全提示卡片 - 鍵盤出現時隱藏
                            if keyboardHeight == 0 {
                                SecurityTipsCard()
                                    .padding(.horizontal)
                                    .transition(.opacity.combined(with: .scale))
                            }
                            
                            // 確保輸入框不會被鍵盤遮擋的間距
                            Spacer(minLength: keyboardHeight > 0 ? 250 : 80)
                        }
                        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 20 : 50)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1), value: keyboardHeight)
                    .animation(.easeInOut(duration: 0.2), value: animateCards)
                    
                    // 監聽焦點變化 - 優化響應速度和動畫
                    .onChange(of: focusedField) { newValue in
                        activeField = newValue
                        
                        // 添加輕微的觸覺反饋
                        if newValue != nil {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        
                        // 只在確認密碼獲得焦點時進行輕微調整
                        if newValue == .confirmPassword && keyboardHeight > 0 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                    scrollProxy.scrollTo("buttons", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
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
        // 監聽鍵盤顯示 - 加入防護措施
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let newHeight = keyboardFrame.height
            
            // 避免重複設置相同高度
            if abs(newHeight - keyboardHeight) > 1 {
                keyboardHeight = newHeight
            }
        }
        // 監聽鍵盤隱藏
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
            activeField = nil
            focusedField = nil
        }
    }
    
    private func dismissKeyboard() {
        // 添加輕微觸覺反饋
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // 清除焦點狀態
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            activeField = nil
            focusedField = nil
        }
        
        // 收起鍵盤
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - 子視圖

struct RegisterBackgroundDecoration: View {
    var body: some View {
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
    }
}

struct RegisterHeader: View {
    var animateCards: Bool
    
    var body: some View {
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
    }
}

struct RegisterFormCard: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    @Binding var username: String
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var showPassword: Bool
    @Binding var showConfirmPassword: Bool
    @FocusState.Binding var focusedField: RegisterField?
    
    var body: some View {
        AnimatedCardView(
            title: "帳戶資訊",
            icon: "person.badge.plus",
            gradient: AppTheme.Gradients.secondary,
            delay: 0.2
        ) {
            VStack(spacing: 20) {
                // 用戶名稱輸入
                UsernameInputField(
                    username: $username,
                    focusedField: $focusedField
                )
                .id(RegisterField.username)
                
                // 電子郵件輸入
                RegisterEmailField(
                    email: $email,
                    focusedField: $focusedField
                )
                .id(RegisterField.email)
                
                // 密碼輸入
                RegisterPasswordField(
                    password: $password,
                    showPassword: $showPassword,
                    focusedField: $focusedField
                )
                .id(RegisterField.password)
                
                // 確認密碼輸入
                ConfirmPasswordField(
                    confirmPassword: $confirmPassword,
                    showConfirmPassword: $showConfirmPassword,
                    focusedField: $focusedField
                )
                .id(RegisterField.confirmPassword)
                
                // 密碼不一致提示
                if password != confirmPassword && !confirmPassword.isEmpty {
                    PasswordMismatchWarning()
                        .transition(.asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        ).animation(.spring(response: 0.4, dampingFraction: 0.8)))
                }
                
                // 錯誤訊息
                if let errorMessage = authManager.errorMessage {
                    RegisterErrorMessage(message: errorMessage)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // 註冊和取消按鈕
                RegisterButtonsRow(
                    username: username,
                    email: email,
                    password: password,
                    confirmPassword: confirmPassword
                )
                .id("buttons")
            }
        }
    }
}

struct UsernameInputField: View {
    @Binding var username: String
    @FocusState.Binding var focusedField: RegisterField?
    
    var body: some View {
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
                    .submitLabel(.next)
                    .focused($focusedField, equals: .username)
                    .onSubmit {
                        focusedField = .email
                    }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(AppTheme.Colors.cardHighlight)
                    .stroke(
                        focusedField == .username ? AppTheme.Colors.secondary : Color.clear,
                        lineWidth: focusedField == .username ? 2 : 0
                    )
                    .scaleEffect(focusedField == .username ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: focusedField == .username)
            )
            .onTapGesture {
                focusedField = .username
            }
            
            if !username.isEmpty && username.count < 3 {
                ValidationMessage(
                    icon: "exclamationmark.triangle.fill",
                    text: "用戶名稱至少需要3個字符",
                    color: AppTheme.Colors.warning
                )
            }
        }
    }
}

struct RegisterEmailField: View {
    @Binding var email: String
    @FocusState.Binding var focusedField: RegisterField?
    
    var body: some View {
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
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .onSubmit {
                        focusedField = .password
                    }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(AppTheme.Colors.cardHighlight)
                    .stroke(
                        focusedField == .email ? AppTheme.Colors.secondary : Color.clear,
                        lineWidth: focusedField == .email ? 2 : 0
                    )
                    .scaleEffect(focusedField == .email ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: focusedField == .email)
            )
            .onTapGesture {
                focusedField = .email
            }
            
            if !email.isEmpty && !isValidEmail(email) {
                ValidationMessage(
                    icon: "exclamationmark.triangle.fill",
                    text: "請輸入有效的電子郵件地址",
                    color: AppTheme.Colors.warning
                )
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

struct RegisterPasswordField: View {
    @Binding var password: String
    @Binding var showPassword: Bool
    @FocusState.Binding var focusedField: RegisterField?
    
    var body: some View {
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
                        .submitLabel(.next)
                        .focused($focusedField, equals: .password)
                        .onSubmit {
                            focusedField = .confirmPassword
                        }
                } else {
                    SecureField("請輸入密碼", text: $password)
                        .textFieldStyle(PlainTextFieldStyle())
                        .submitLabel(.next)
                        .focused($focusedField, equals: .password)
                        .onSubmit {
                            focusedField = .confirmPassword
                        }
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
                    .stroke(
                        focusedField == .password ? AppTheme.Colors.secondary : Color.clear,
                        lineWidth: focusedField == .password ? 2 : 0
                    )
                    .scaleEffect(focusedField == .password ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: focusedField == .password)
            )
            .onTapGesture {
                focusedField = .password
            }
            
            if !password.isEmpty && password.count < 6 {
                ValidationMessage(
                    icon: "exclamationmark.triangle.fill",
                    text: "密碼至少需要6個字符",
                    color: AppTheme.Colors.warning
                )
            }
        }
    }
}

struct ConfirmPasswordField: View {
    @Binding var confirmPassword: String
    @Binding var showConfirmPassword: Bool
    @FocusState.Binding var focusedField: RegisterField?
    
    var body: some View {
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
                        .submitLabel(.done)
                        .focused($focusedField, equals: .confirmPassword)
                        .onSubmit {
                            focusedField = nil
                        }
                } else {
                    SecureField("請再次輸入密碼", text: $confirmPassword)
                        .textFieldStyle(PlainTextFieldStyle())
                        .submitLabel(.done)
                        .focused($focusedField, equals: .confirmPassword)
                        .onSubmit {
                            focusedField = nil
                        }
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
                    .stroke(
                        focusedField == .confirmPassword ? AppTheme.Colors.secondary : Color.clear,
                        lineWidth: focusedField == .confirmPassword ? 2 : 0
                    )
                    .scaleEffect(focusedField == .confirmPassword ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: focusedField == .confirmPassword)
            )
            .onTapGesture {
                focusedField = .confirmPassword
            }
        }
    }
}

// MARK: - 輔助組件

struct ValidationMessage: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 12))
            
            Text(text)
                .font(.caption)
                .foregroundColor(color)
        }
        .transition(.scale.combined(with: .opacity))
    }
}

struct PasswordMismatchWarning: View {
    var body: some View {
        ValidationMessage(
            icon: "exclamationmark.triangle.fill",
            text: "密碼不一致",
            color: AppTheme.Colors.error
        )
    }
}

struct RegisterErrorMessage: View {
    var message: String
    
    var body: some View {
        ValidationMessage(
            icon: "exclamationmark.triangle.fill",
            text: message,
            color: AppTheme.Colors.error
        )
    }
}

struct RegisterButtonsRow: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    var username: String
    var email: String
    var password: String
    var confirmPassword: String
    
    var body: some View {
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
                    // 添加觸覺反饋
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    // 先關閉鍵盤
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    
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
                isDisabled: !isFormValid
            )
            .scaleEffect(authManager.isLoading ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: authManager.isLoading)
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 10)
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

struct SecurityTipsCard: View {
    var body: some View {
        AnimatedCardView(
            title: "安全提示",
            icon: "shield.fill",
            gradient: AppTheme.Gradients.info,
            delay: 0.3
        ) {
            VStack(alignment: .leading, spacing: 10) {
                SecurityTipRow(text: "密碼至少6個字符")
                SecurityTipRow(text: "建議包含大小寫字母、數字和特殊符號")
                SecurityTipRow(text: "使用有效的電子郵件地址以便接收通知")
            }
            .padding(.vertical, 5)
        }
    }
}

struct SecurityTipRow: View {
    var text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppTheme.Colors.success)
                .font(.system(size: 14))
            
            Text(text)
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthenticationManager())
}