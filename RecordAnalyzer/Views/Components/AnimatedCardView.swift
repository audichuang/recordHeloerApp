import SwiftUI

// MARK: - 動畫卡片視圖
struct AnimatedCardView<Content: View>: View {
    let title: String
    let icon: String
    let gradient: [Color]
    let delay: Double
    let content: Content
    
    @State private var appeared = false
    
    init(
        title: String,
        icon: String,
        gradient: [Color] = AppTheme.Gradients.primary,
        delay: Double = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.gradient = gradient
        self.delay = delay
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
            // 標題行
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: gradient),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            // 內容
            content
        }
        .padding(AppTheme.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: gradient.map { $0.opacity(0.3) }),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .softShadow()
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(AppTheme.Animation.smooth.delay(delay)) {
                appeared = true
            }
        }
    }
}

// MARK: - 簡單動畫卡片
struct SimpleAnimatedCard<Content: View>: View {
    let content: Content
    let delay: Double
    
    @State private var appeared = false
    
    init(
        delay: Double = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.delay = delay
        self.content = content()
    }
    
    var body: some View {
        content
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(AppTheme.Animation.smooth.delay(delay)) {
                    appeared = true
                }
            }
    }
}

// MARK: - 預覽
struct AnimatedCardView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.l) {
                AnimatedCardView(
                    title: "個人資訊",
                    icon: "person.fill",
                    gradient: AppTheme.Gradients.primary,
                    delay: 0.1
                ) {
                    VStack(spacing: AppTheme.Spacing.m) {
                        HStack {
                            Text("用戶名稱")
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            Spacer()
                            Text("測試用戶")
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        
                        HStack {
                            Text("電子郵件")
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            Spacer()
                            Text("test@example.com")
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                    }
                }
                
                AnimatedCardView(
                    title: "統計資訊",
                    icon: "chart.bar.fill",
                    gradient: AppTheme.Gradients.secondary,
                    delay: 0.2
                ) {
                    HStack(spacing: AppTheme.Spacing.xl) {
                        VStack {
                            Text("42")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("錄音數量")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        VStack {
                            Text("3.5")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("小時")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.Colors.background)
    }
}