import SwiftUI

// MARK: - 現代極簡卡片組件
struct ModernCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = AppTheme.Spacing.l
    var cornerRadius: CGFloat = AppTheme.CornerRadius.large
    var showBorder: Bool = false
    
    init(
        padding: CGFloat = AppTheme.Spacing.l,
        cornerRadius: CGFloat = AppTheme.CornerRadius.large,
        showBorder: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.showBorder = showBorder
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        showBorder ?
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                        : nil
                    )
            )
            .subtleShadow()
    }
}

// MARK: - 互動式卡片
struct InteractiveCard<Content: View>: View {
    let content: Content
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    init(
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        ModernCard {
            content
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .opacity(isPressed ? 0.9 : 1.0)
        .animation(AppTheme.Animation.quick, value: isPressed)
        .onTapGesture {
            withAnimation(AppTheme.Animation.quick) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(AppTheme.Animation.quick) {
                    isPressed = false
                }
                action()
            }
        }
    }
}

// MARK: - 狀態卡片（簡化版）
struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            // 圖標
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
            
            // 內容
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text(value)
                    .font(.system(size: AppTheme.FontSize.title3, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            Spacer()
        }
        .padding(AppTheme.Spacing.m)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - 漸層卡片（極簡版）
struct GradientCard<Content: View>: View {
    let gradient: [Color]
    let content: Content
    
    init(
        gradient: [Color] = AppTheme.Gradients.primary,
        @ViewBuilder content: () -> Content
    ) {
        self.gradient = gradient
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(AppTheme.Spacing.l)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: gradient),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.9)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
            .softShadow()
    }
}

// MARK: - 骨架屏卡片
struct SkeletonCard: View {
    @State private var shimmer = false
    
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                // 標題骨架
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .fill(AppTheme.Colors.border)
                    .frame(height: 20)
                    .frame(maxWidth: 200)
                
                // 內容骨架
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                        .fill(AppTheme.Colors.border)
                        .frame(height: 16)
                }
            }
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: shimmer ? 300 : -300)
                .animation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                    value: shimmer
                )
            )
            .clipped()
        }
        .onAppear {
            shimmer = true
        }
    }
}

// MARK: - 預覽
struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.l) {
                // 基本卡片
                ModernCard {
                    Text("基本卡片內容")
                        .font(.body)
                }
                
                // 互動式卡片
                InteractiveCard(action: {}) {
                    HStack {
                        Text("可點擊卡片")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                // 狀態卡片
                StatusCard(
                    title: "總錄音",
                    value: "42",
                    icon: "waveform.circle.fill",
                    color: AppTheme.Colors.primary
                )
                
                // 漸層卡片
                GradientCard {
                    VStack(spacing: AppTheme.Spacing.s) {
                        Image(systemName: "sparkles")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                        Text("漸層卡片")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                
                // 骨架屏
                SkeletonCard()
            }
            .padding()
        }
        .background(AppTheme.Colors.background)
    }
}