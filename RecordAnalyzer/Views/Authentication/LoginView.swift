import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var appleAuthManager = AppleAuthenticationManager()
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegister = false
    @State private var animateCards = false
    @State private var showPassword = false
    
    // 鍵盤處理相關狀態
    @State private var keyboardHeight: CGFloat = 0
    @State private var activeField: LoginField? = nil
    @FocusState private var isEmailFocused: Bool
    @FocusState private var isPasswordFocused: Bool
    
    private enum LoginField: Hashable {
        case email, password
    }
    
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
                VStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: AppTheme.Gradients.primary),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 220, height: 220)
                        .blur(radius: 60)
                        .offset(y: -180)
                        .opacity(0.4)
                    
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
                        .offset(x: 120, y: 0)
                        .opacity(0.3)
                    
                    Spacer()
                }
                
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 30) {
                            // 應用標誌和標題
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: AppTheme.Gradients.primary),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 100, height: 100)
                                        .shadow(
                                            color: AppTheme.Colors.primary.opacity(0.5),
                                            radius: 15,
                                            x: 0,
                                            y: 5
                                        )
                                        .offset(y: animateCards ? 0 : 20)
                                        .opacity(animateCards ? 1 : 0)
                                    
                                    Image(systemName: "waveform")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                        .symbolEffect(.variableColor, options: .repeating, value: animateCards)
                                        .offset(y: animateCards ? 0 : 20)
                                        .opacity(animateCards ? 1 : 0)
                                }
                                .padding(.top, keyboardHeight > 0 ? 30 : 70)
                                
                                GradientText(
                                    text: "錄音分析助手",
                                    gradient: AppTheme.Gradients.primary
                                )
                                .font(.system(size: 30, weight: .bold))
                                .offset(y: animateCards ? 0 : 15)
                                .opacity(animateCards ? 1 : 0)
                                
                                Text("將您的錄音轉換為文字和智能摘要")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .offset(y: animateCards ? 0 : 15)
                                    .opacity(animateCards ? 1 : 0)
                            }
                            .padding(.bottom, 20)
                            
                            // 登入卡片
                            ModernCard {
                                VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                                    HStack {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(AppTheme.Colors.primary)
                                        Text("帳戶登入")
                                            .font(.system(size: 18, weight: .semibold))
                                        Spacer()
                                    }
                                    
                                    VStack(spacing: 20) {
                                    // 電子郵件輸入
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("電子郵件")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                        
                                        HStack {
                                            Image(systemName: "envelope.fill")
                                                .foregroundColor(AppTheme.Colors.primary)
                                                .font(.system(size: 16))
                                            
                                            TextField("請輸入電子郵件", text: $email)
                                                .textFieldStyle(PlainTextFieldStyle())
                                                .keyboardType(.emailAddress)
                                                .textInputAutocapitalization(.never)
                                                .textContentType(.emailAddress)
                                                .focused($isEmailFocused)
                                                .submitLabel(.next)
                                                .onSubmit {
                                                    activeField = .password
                                                    isPasswordFocused = true
                                                }
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                                .fill(AppTheme.Colors.cardHighlight)
                                                .stroke(
                                                    isEmailFocused ? AppTheme.Colors.primary : Color.clear,
                                                    lineWidth: isEmailFocused ? 2 : 0
                                                )
                                                .scaleEffect(isEmailFocused ? 1.02 : 1.0)
                                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEmailFocused)
                                        )
                                        .onTapGesture {
                                            activeField = .email
                                            isEmailFocused = true
                                        }
                                    }
                                    .id("emailField")
                                    
                                    // 密碼輸入
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("密碼")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                        
                                        HStack {
                                            Image(systemName: "lock.fill")
                                                .foregroundColor(AppTheme.Colors.primary)
                                                .font(.system(size: 16))
                                            
                                            if showPassword {
                                                TextField("請輸入密碼", text: $password)
                                                    .textFieldStyle(PlainTextFieldStyle())
                                                    .textContentType(.password)
                                                    .focused($isPasswordFocused)
                                                    .submitLabel(.done)
                                                    .onSubmit {
                                                        dismissKeyboard()
                                                        if !email.isEmpty && !password.isEmpty {
                                                            Task {
                                                                await authManager.login(email: email, password: password)
                                                            }
                                                        }
                                                    }
                                            } else {
                                                SecureField("請輸入密碼", text: $password)
                                                    .textFieldStyle(PlainTextFieldStyle())
                                                    .textContentType(.password)
                                                    .focused($isPasswordFocused)
                                                    .submitLabel(.done)
                                                    .onSubmit {
                                                        dismissKeyboard()
                                                        if !email.isEmpty && !password.isEmpty {
                                                            Task {
                                                                await authManager.login(email: email, password: password)
                                                            }
                                                        }
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
                                                    isPasswordFocused ? AppTheme.Colors.primary : Color.clear,
                                                    lineWidth: isPasswordFocused ? 2 : 0
                                                )
                                                .scaleEffect(isPasswordFocused ? 1.02 : 1.0)
                                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPasswordFocused)
                                        )
                                        .onTapGesture {
                                            activeField = .password
                                            isPasswordFocused = true
                                        }
                                    }
                                    .id("passwordField")
                                    
                                    // 錯誤訊息
                                    if let errorMessage = authManager.errorMessage {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(AppTheme.Colors.error)
                                            
                                            Text(errorMessage)
                                                .foregroundColor(AppTheme.Colors.error)
                                                .font(.caption)
                                        }
                                        .padding(.vertical, 4)
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                    
                                    // 登入按鈕
                                    GradientButton(
                                        title: "登入",
                                        icon: authManager.isLoading ? nil : "arrow.right",
                                        action: {
                                            // 添加觸覺反饋
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                            impactFeedback.impactOccurred()
                                            
                                            dismissKeyboard()
                                            Task {
                                                await authManager.login(email: email, password: password)
                                            }
                                        },
                                        gradient: AppTheme.Gradients.primary,
                                        isDisabled: authManager.isLoading || email.isEmpty || password.isEmpty
                                    )
                                    .scaleEffect(authManager.isLoading ? 0.98 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: authManager.isLoading)
                                    .padding(.top, 10)
                                    .id("loginButton")
                                    
                                    // 分隔線與或字
                                    HStack {
                                        Rectangle()
                                            .fill(AppTheme.Colors.divider)
                                            .frame(height: 1)
                                        
                                        Text("或")
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                            .font(.subheadline)
                                            .padding(.horizontal, 10)
                                        
                                        Rectangle()
                                            .fill(AppTheme.Colors.divider)
                                            .frame(height: 1)
                                    }
                                    .padding(.vertical, 10)
                                    
                                    // Sign in with Apple 按鈕
                                    Group {
                                        #if targetEnvironment(simulator)
                                        // 模擬器測試按鈕
                                        Button(action: {
                                            Task {
                                                // 使用測試數據模擬 Apple 登入
                                                await authManager.loginWithApple(
                                                    userID: "simulator.test.user.001",
                                                    email: "apple.test@example.com",
                                                    fullName: PersonNameComponents(
                                                        givenName: "測試",
                                                        familyName: "用戶"
                                                    ),
                                                    identityToken: "simulator.test.token",
                                                    authorizationCode: "simulator.test.code"
                                                )
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: "applelogo")
                                                    .font(.system(size: 20))
                                                Text("Sign in with Apple (模擬器測試)")
                                                    .font(.system(size: 19, weight: .medium))
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 50)
                                            .background(Color.black)
                                            .cornerRadius(AppTheme.CornerRadius.medium)
                                        }
                                        .disabled(authManager.isLoading)
                                        .opacity(authManager.isLoading ? 0.6 : 1.0)
                                        #else
                                        // 真實設備使用真正的 Sign in with Apple
                                        SignInWithAppleButton(.signIn) { request in
                                            // 配置請求
                                        } onCompletion: { result in
                                            switch result {
                                            case .success(let authorization):
                                                handleAppleSignInSuccess(authorization)
                                            case .failure(let error):
                                                authManager.errorMessage = "Apple 登入失敗: \(error.localizedDescription)"
                                            }
                                        }
                                        .signInWithAppleButtonStyle(.black)
                                        .frame(height: 50)
                                        .cornerRadius(AppTheme.CornerRadius.medium)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                                .stroke(AppTheme.Colors.divider, lineWidth: 1)
                                        )
                                        .disabled(appleAuthManager.isSigningIn || authManager.isLoading)
                                        .opacity((appleAuthManager.isSigningIn || authManager.isLoading) ? 0.6 : 1.0)
                                        #endif
                                    }
                                    
                                    // 註冊連結
                                    Button(action: {
                                        showingRegister = true
                                    }) {
                                        HStack {
                                            Text("還沒有帳戶？")
                                                .foregroundColor(AppTheme.Colors.textSecondary)
                                            
                                            Text("註冊新帳戶")
                                                .foregroundColor(AppTheme.Colors.primary)
                                                .fontWeight(.medium)
                                        }
                                        .font(.subheadline)
                                        .padding(.top, 10)
                                    }
                                }
                                }
                            }
                            .padding(.horizontal)
                            
                            // 確保有足夠空間避免鍵盤遮擋
                            Spacer(minLength: keyboardHeight > 0 ? 200 : 80)
                        }
                        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 20 : 50)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1), value: keyboardHeight)
                    .animation(.easeInOut(duration: 0.2), value: animateCards)
                    
                    // 監聽焦點變化 - 優化響應速度和動畫
                    .onChange(of: activeField) { newValue in
                        // 添加輕微的觸覺反饋
                        if newValue != nil {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        
                        // 只在密碼欄位獲得焦點且鍵盤已出現時進行輕微調整
                        if newValue == .password && keyboardHeight > 0 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                    scrollProxy.scrollTo("loginButton", anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // 監聽 Email 焦點狀態
                    .onChange(of: isEmailFocused) { isFocused in
                        if isFocused {
                            activeField = .email
                        } else if activeField == .email {
                            activeField = nil
                        }
                    }
                    
                    // 監聽密碼焦點狀態
                    .onChange(of: isPasswordFocused) { isFocused in
                        if isFocused {
                            activeField = .password
                        } else if activeField == .password {
                            activeField = nil
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(AppTheme.Animation.smooth.delay(0.1)) {
                animateCards = true
            }
        }
        .onDisappear {
            animateCards = false
        }
        .sheet(isPresented: $showingRegister) {
            RegisterView()
                .environmentObject(authManager)
        }
        // 簡化鍵盤監聽 - 主要用於狀態管理和 UI 調整
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
            activeField = nil
        }
    }
    
    private func dismissKeyboard() {
        // 添加輕微觸覺反饋
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // 清除焦點狀態
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            activeField = nil
            isEmailFocused = false
            isPasswordFocused = false
        }
        
        // 收起鍵盤
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func handleAppleSignInSuccess(_ authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authCodeData = appleIDCredential.authorizationCode,
              let authCode = String(data: authCodeData, encoding: .utf8) else {
            authManager.errorMessage = "無法取得 Apple ID 憑證"
            return
        }
        
        Task {
            await authManager.loginWithApple(
                userID: appleIDCredential.user,
                email: appleIDCredential.email,
                fullName: appleIDCredential.fullName,
                identityToken: identityToken,
                authorizationCode: authCode
            )
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
}