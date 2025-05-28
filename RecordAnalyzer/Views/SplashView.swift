import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color("AppBackground")
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // App Icon
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Text("錄音分析助手")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color("TextPrimary"))
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .padding(.top, 20)
                
                Text("正在驗證登入狀態...")
                    .font(.subheadline)
                    .foregroundColor(Color("TextSecondary"))
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}