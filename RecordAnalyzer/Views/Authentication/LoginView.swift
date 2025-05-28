import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegister = false
    @State private var animateCards = false
    @State private var showPassword = false
    
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
                        .padding(.top, 70)
                        
                        ShimmeringText(
                            text: "錄音分析助手",
                            fontSize: 30,
                            fontWeight: .bold,
                            baseColor: AppTheme.Colors.textPrimary
                        )
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
                    AnimatedCardView(
                        title: "帳戶登入",
                        icon: "person.fill",
                        gradient: AppTheme.Gradients.primary,
                        delay: 0.2
                    ) {
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
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                        .fill(AppTheme.Colors.cardHighlight)
                                )
                            }
                            
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
                                    } else {
                                        SecureField("請輸入密碼", text: $password)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .textContentType(.password)
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
                            }
                            
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
                                    Task {
                                        await authManager.login(email: email, password: password)
                                    }
                                },
                                gradient: AppTheme.Gradients.primary,
                                isDisabled: authManager.isLoading || email.isEmpty || password.isEmpty
                            )
                            .padding(.top, 10)
                            
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
                    .padding(.horizontal)
                    
                    Spacer(minLength: 80)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(AppTheme.Animation.standard.delay(0.1)) {
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
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
} 