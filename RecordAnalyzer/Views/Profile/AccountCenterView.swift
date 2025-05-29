import SwiftUI
import AuthenticationServices

struct AccountCenterView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var appleAuthManager = AppleAuthenticationManager()
    @State private var showingBindApple = false
    @State private var showingUnbindConfirmation = false
    @State private var isProcessing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    accountInfoCard
                    bindingSection
                    explanationSection
                }
                .padding()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("會員中心")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingBindApple) {
            AppleBindingView(isPresented: $showingBindApple) { success in
                if success {
                    Task {
                        await authManager.refreshUserInfo()
                    }
                }
            }
            .environmentObject(authManager)
        }
        .alert("解除綁定", isPresented: $showingUnbindConfirmation) {
            Button("取消", role: .cancel) { }
            Button("確定解除", role: .destructive) {
                Task {
                    await unbindAppleID()
                }
            }
        } message: {
            Text("確定要解除 Apple ID 綁定嗎？解除後您仍可使用電子郵件登入。")
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("確定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - View Components
    
    private var accountInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            userInfoHeader
            Divider()
            registrationTypeRow
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(AppTheme.Colors.card)
                .shadow(
                    color: AppTheme.Colors.primary.opacity(0.1),
                    radius: 10,
                    x: 0,
                    y: 5
                )
        )
    }
    
    private var userInfoHeader: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(authManager.currentUser?.username ?? "使用者")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(authManager.currentUser?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
    
    private var registrationTypeRow: some View {
        HStack {
            Text("註冊方式")
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Spacer()
            
            if authManager.currentUser?.registrationType == "apple" {
                Label("Apple ID", systemImage: "applelogo")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            } else {
                Label("電子郵件", systemImage: "envelope.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
        }
    }
    
    private var bindingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("帳號綁定")
                .font(.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            appleBindingRow
            googleBindingRow
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(AppTheme.Colors.card)
                .shadow(
                    color: AppTheme.Colors.primary.opacity(0.1),
                    radius: 10,
                    x: 0,
                    y: 5
                )
        )
    }
    
    private var appleBindingRow: some View {
        HStack {
            Image(systemName: "applelogo")
                .font(.title2)
                .foregroundColor(.black)
                .frame(width: 40, height: 40)
                .background(Color.white)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple ID")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(appleBindingStatusText)
                    .font(.caption)
                    .foregroundColor(appleBindingStatusColor)
            }
            
            Spacer()
            
            appleBindingButton
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .fill(AppTheme.Colors.cardHighlight)
        )
    }
    
    private var appleBindingStatusText: String {
        authManager.currentUser?.appleId != nil ? "已綁定" : "未綁定"
    }
    
    private var appleBindingStatusColor: Color {
        authManager.currentUser?.appleId != nil ? .green : AppTheme.Colors.textSecondary
    }
    
    @ViewBuilder
    private var appleBindingButton: some View {
        if authManager.currentUser?.registrationType == "apple" {
            // 通過 Apple ID 註冊的用戶不能解綁
            Text("主要登入")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(AppTheme.Colors.primary.opacity(0.1))
                )
                .foregroundColor(AppTheme.Colors.primary)
        } else if authManager.currentUser?.appleId != nil {
            // 已綁定，可以解綁
            Button(action: {
                showingUnbindConfirmation = true
            }) {
                Text("解除綁定")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .stroke(AppTheme.Colors.error, lineWidth: 1)
                    )
                    .foregroundColor(AppTheme.Colors.error)
            }
            .disabled(isProcessing)
        } else {
            // 未綁定，可以綁定
            Button(action: {
                showingBindApple = true
            }) {
                Text("綁定")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.primary)
                    )
                    .foregroundColor(.white)
            }
            .disabled(isProcessing)
        }
    }
    
    private var googleBindingRow: some View {
        HStack {
            Image(systemName: "g.circle.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color(red: 0.24, green: 0.52, blue: 0.94))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Google")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("即將推出")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Text("敬請期待")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(AppTheme.Colors.divider)
                )
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .fill(AppTheme.Colors.cardHighlight.opacity(0.5))
        )
    }
    
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("綁定說明", systemImage: "info.circle.fill")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.primary)
            
            Group {
                Text("• 綁定第三方帳號後，您可以使用多種方式登入")
                Text("• 如果您是透過第三方帳號註冊，則無法解除該帳號的綁定")
                Text("• 請確保至少保留一種登入方式")
            }
            .font(.caption)
            .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func unbindAppleID() async {
        isProcessing = true
        
        let success = await NetworkService.shared.unbindAppleID()
        if success {
            await authManager.refreshUserInfo()
            alertMessage = "已成功解除 Apple ID 綁定"
            showingAlert = true
        } else {
            alertMessage = "解除綁定失敗，請稍後再試"
            showingAlert = true
        }
        
        isProcessing = false
    }
}

// MARK: - Apple Binding View

struct AppleBindingView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var appleAuthManager = AppleAuthenticationManager()
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    let onComplete: (Bool) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                appleIconSection
                titleSection
                descriptionSection
                Spacer()
                errorSection
                signInButton
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                        onComplete(false)
                    }
                }
            }
        }
    }
    
    private var appleIconSection: some View {
        Image(systemName: "applelogo")
            .font(.system(size: 80))
            .foregroundColor(.black)
            .padding(.top, 40)
    }
    
    private var titleSection: some View {
        Text("綁定 Apple ID")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(AppTheme.Colors.textPrimary)
    }
    
    private var descriptionSection: some View {
        Text("綁定 Apple ID 後，您可以使用 Apple 登入快速訪問您的帳號")
            .font(.body)
            .foregroundColor(AppTheme.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
    }
    
    @ViewBuilder
    private var errorSection: some View {
        if let error = errorMessage {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppTheme.Colors.error)
                
                Text(error)
                    .foregroundColor(AppTheme.Colors.error)
                    .font(.caption)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .fill(AppTheme.Colors.error.opacity(0.1))
            )
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var signInButton: some View {
        Group {
            #if targetEnvironment(simulator)
            // 模擬器測試按鈕
            Button(action: {
                Task {
                    await bindWithTestData()
                }
            }) {
                HStack {
                    Image(systemName: "applelogo")
                        .font(.system(size: 20))
                    Text("綁定 Apple ID (模擬器測試)")
                        .font(.system(size: 19, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.black)
                .cornerRadius(AppTheme.CornerRadius.medium)
            }
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.6 : 1.0)
            .padding(.horizontal)
            #else
            // 真實設備使用真正的 Sign in with Apple
            SignInWithAppleButton(.signIn) { request in
                // 配置請求
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    handleAppleSignInSuccess(authorization)
                case .failure(let error):
                    errorMessage = "Apple 登入失敗: \(error.localizedDescription)"
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .padding(.horizontal)
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.6 : 1.0)
            #endif
        }
    }
    
    // MARK: - Actions
    
    private func bindWithTestData() async {
        isProcessing = true
        errorMessage = nil
        
        // 模擬器測試數據
        let success = await NetworkService.shared.bindAppleID(
            userID: "simulator.test.bind.001",
            identityToken: "simulator.test.token",
            authorizationCode: "simulator.test.code",
            email: nil,
            fullName: nil
        )
        
        if success {
            isPresented = false
            onComplete(true)
        } else {
            errorMessage = "綁定失敗，請稍後再試"
        }
        
        isProcessing = false
    }
    
    private func handleAppleSignInSuccess(_ authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authCodeData = appleIDCredential.authorizationCode,
              let authCode = String(data: authCodeData, encoding: .utf8) else {
            errorMessage = "無法取得 Apple ID 憑證"
            return
        }
        
        Task {
            isProcessing = true
            errorMessage = nil
            
            let success = await NetworkService.shared.bindAppleID(
                userID: appleIDCredential.user,
                identityToken: identityToken,
                authorizationCode: authCode,
                email: appleIDCredential.email,
                fullName: appleIDCredential.fullName
            )
            
            if success {
                isPresented = false
                onComplete(true)
            } else {
                errorMessage = "綁定失敗，請稍後再試"
            }
            
            isProcessing = false
        }
    }
}

#Preview {
    AccountCenterView()
        .environmentObject(AuthenticationManager())
}