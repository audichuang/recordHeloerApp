import SwiftUI

struct GradientButton: View {
    var title: String
    var icon: String? = nil
    var action: () -> Void
    var gradient: [Color] = AppTheme.Gradients.primary
    var foregroundColor: Color = .white
    var isDisabled: Bool = false
    var fullWidth: Bool = true
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            if !isDisabled {
                withAnimation(AppTheme.Animation.standard) {
                    isPressed = true
                }
                
                // 添加觸覺反饋
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                // 稍微延遲執行動作，以便用戶看到按下效果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    action()
                    
                    withAnimation(AppTheme.Animation.standard) {
                        isPressed = false
                    }
                }
            }
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .symbolEffect(.bounce, options: .speed(1.2), value: isHovered)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                ZStack {
                    if isDisabled {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                            .fill(Color.gray.opacity(0.2))
                    } else {
                        // 發光效果層
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                            .fill(gradient[0])
                            .blur(radius: isHovered ? 15 : 0)
                            .opacity(isHovered ? 0.7 : 0)
                            .scaleEffect(isHovered ? 1.05 : 1)
                            
                        // 按鈕背景層
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: gradient),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                    .blendMode(.overlay)
                            )
                            .shadow(
                                color: gradient[0].opacity(0.5),
                                radius: isPressed ? 2 : (isHovered ? 10 : 6),
                                x: 0,
                                y: isPressed ? 1 : (isHovered ? 6 : 3)
                            )
                    }
                }
            )
            .foregroundColor(isDisabled ? .gray : foregroundColor)
            .scaleEffect(isPressed ? 0.96 : (isHovered ? 1.03 : 1))
            .onHover { hovering in
                withAnimation(AppTheme.Animation.standard) {
                    isHovered = hovering
                }
            }
        }
        .disabled(isDisabled)
    }
}

struct GradientButtonStyle: ButtonStyle {
    var gradient: [Color] = AppTheme.Gradients.primary
    var foregroundColor: Color = .white
    var isDisabled: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    if isDisabled {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                            .fill(Color.gray.opacity(0.2))
                    } else {
                        // 發光效果層
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                            .fill(gradient[0])
                            .blur(radius: configuration.isPressed ? 0 : 10)
                            .opacity(configuration.isPressed ? 0 : 0.5)
                            .scaleEffect(configuration.isPressed ? 1 : 1.05)
                            
                        // 按鈕背景層
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: gradient),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                    .blendMode(.overlay)
                            )
                            .shadow(
                                color: gradient[0].opacity(0.5),
                                radius: configuration.isPressed ? 2 : 8,
                                x: 0,
                                y: configuration.isPressed ? 1 : 4
                            )
                    }
                }
            )
            .foregroundColor(isDisabled ? .gray : foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

#Preview {
    VStack(spacing: 20) {
        GradientButton(
            title: "開始上傳",
            icon: "arrow.up.circle.fill",
            action: {}
        )
        
        GradientButton(
            title: "處理錄音",
            action: {},
            gradient: AppTheme.Gradients.success
        )
        
        GradientButton(
            title: "刪除錄音",
            action: {},
            gradient: AppTheme.Gradients.error
        )
        
        GradientButton(
            title: "已停用按鈕",
            action: {},
            isDisabled: true
        )
        
        Button("標準按鈕") {}
            .buttonStyle(
                GradientButtonStyle(
                    gradient: AppTheme.Gradients.warning
                )
            )
    }
    .padding()
    .background(AppTheme.Colors.background)
} 