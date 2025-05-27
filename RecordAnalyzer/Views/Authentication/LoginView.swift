import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegister = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Logo 區域
                VStack(spacing: 16) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .symbolEffect(.bounce, value: authManager.isLoading)
                    
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
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .textContentType(.emailAddress)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("密碼")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        SecureField("請輸入密碼", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                    }
                    
                    if let errorMessage = authManager.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .transition(.scale.combined(with: .opacity))
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
                                    .tint(.white)
                            }
                            Text("登入")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                    .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                    .animation(.easeInOut(duration: 0.2), value: authManager.isLoading)
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
                    .buttonStyle(.borderless)
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
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingRegister) {
            RegisterView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
} 