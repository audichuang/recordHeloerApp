import SwiftUI

struct CardView<Content: View>: View {
    var title: String? = nil
    var icon: String? = nil
    var iconGradient: [Color] = AppTheme.Gradients.primary
    var gradientBorder: Bool = false
    var borderGradient: [Color] = [AppTheme.Colors.primary.opacity(0.3), AppTheme.Colors.secondary.opacity(0.1)]
    var showShadow: Bool = true
    var showHoverEffect: Bool = true
    var cornerRadius: CGFloat = AppTheme.CornerRadius.large
    @ViewBuilder let content: Content
    
    @State private var animateHover = false
    @State private var animateGlow = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
            if let title = title {
                HStack {
                    if let icon = icon {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: iconGradient),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                                .shadow(color: iconGradient[0].opacity(0.5), radius: 5, x: 0, y: 2)
                            
                            Image(systemName: icon)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .symbolEffect(.pulse, options: .repeating, value: animateGlow)
                        }
                    }
                    
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.Colors.textPrimary, AppTheme.Colors.textPrimary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Spacer()
                }
            }
            
            content
        }
        .padding(AppTheme.Spacing.l)
        .background(
            ZStack {
                // 基礎層
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppTheme.Colors.card)
                
                // 漸變邊框
                if gradientBorder {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: borderGradient),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .opacity(animateHover ? 1 : 0.7)
                }
                
                // 懸停時的高光效果
                if showHoverEffect && animateHover {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white.opacity(0.1), Color.clear]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.overlay)
                }
            }
        )
        .shadow(
            color: showShadow ? Color.black.opacity(animateHover ? 0.1 : 0.05) : .clear,
            radius: animateHover ? 15 : 8,
            x: 0,
            y: animateHover ? 8 : 4
        )
        .scaleEffect(showHoverEffect && animateHover ? 1.02 : 1.0)
        .onHover { hovering in
            if showHoverEffect {
                withAnimation(AppTheme.Animation.standard) {
                    animateHover = hovering
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                animateGlow = true
            }
        }
    }
}

struct ActionCardView: View {
    var title: String
    var description: String
    var icon: String
    var iconGradient: [Color] = AppTheme.Gradients.primary
    var actionTitle: String = "執行"
    var action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        CardView(gradientBorder: true) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                HStack(spacing: AppTheme.Spacing.m) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: iconGradient),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: iconGradient[0].opacity(0.5), radius: 5, x: 0, y: 2)
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .symbolEffect(.bounce, options: .speed(1.2), value: isHovered)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }
                
                Button(action: action) {
                    HStack {
                        Text(actionTitle)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .opacity(isHovered ? 1 : 0.6)
                            .offset(x: isHovered ? 3 : 0)
                            .animation(.spring(response: 0.3), value: isHovered)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                            .fill(isHovered ? 
                                  AppTheme.Colors.cardHighlight.opacity(0.8) : 
                                  AppTheme.Colors.cardHighlight)
                    )
                    .onHover { hovering in
                        isHovered = hovering
                    }
                }
                .foregroundColor(isHovered ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct AnimatedCardView<Content: View>: View {
    var title: String? = nil
    var icon: String? = nil
    var gradient: [Color] = AppTheme.Gradients.primary
    var delay: Double = 0
    @ViewBuilder let content: Content
    
    @State private var isShowing = false
    
    var body: some View {
        CardView(title: title, icon: icon, iconGradient: gradient, gradientBorder: true) {
            content
        }
        .offset(y: isShowing ? 0 : 30)
        .opacity(isShowing ? 1 : 0)
        .onAppear {
            withAnimation(AppTheme.Animation.standard.delay(delay)) {
                isShowing = true
            }
        }
        .onDisappear {
            isShowing = false
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            CardView(title: "基本卡片", icon: "star.fill") {
                Text("這是一個基本卡片視圖")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            CardView(gradientBorder: true) {
                Text("這是一個帶有漸變邊框的卡片")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            AnimatedCardView(title: "動畫卡片", icon: "sparkles", gradient: AppTheme.Gradients.info) {
                Text("這是一個帶有入場動畫的卡片")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            ActionCardView(
                title: "上傳錄音",
                description: "選擇一個音頻文件上傳並進行分析",
                icon: "arrow.up.circle.fill",
                actionTitle: "選擇文件",
                action: {}
            )
        }
        .padding()
        .background(AppTheme.Colors.background)
    }
} 