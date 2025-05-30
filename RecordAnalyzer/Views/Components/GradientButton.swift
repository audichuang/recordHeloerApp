import SwiftUI

// MARK: - 現代極簡按鈕
struct ModernButton: View {
    enum ButtonStyle {
        case primary
        case secondary
        case minimal
        case ghost
    }
    
    let title: String
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            // 觸覺反饋
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            action()
        }) {
            HStack(spacing: AppTheme.Spacing.s) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, AppTheme.Spacing.l)
            .padding(.vertical, AppTheme.Spacing.m)
            .foregroundColor(foregroundColor)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            .overlay(overlayBorder)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(AppTheme.Animation.quick, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(AppTheme.Animation.quick) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
    
    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            AppTheme.Colors.primary
                .softShadow()
        case .secondary:
            AppTheme.Colors.secondary.opacity(0.15)
        case .minimal:
            AppTheme.Colors.primary.opacity(0.08)
        case .ghost:
            Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary, .minimal:
            return AppTheme.Colors.primary
        case .ghost:
            return AppTheme.Colors.textSecondary
        }
    }
    
    @ViewBuilder
    private var overlayBorder: some View {
        switch style {
        case .ghost:
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        default:
            EmptyView()
        }
    }
}

// MARK: - 浮動操作按鈕
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .softShadow()
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(AppTheme.Animation.bouncy) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - 圖標按鈕
struct IconButton: View {
    let icon: String
    let size: CGFloat
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        icon: String,
        size: CGFloat = 24,
        color: Color = AppTheme.Colors.primary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(color)
                .frame(width: size + 20, height: size + 20)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                        .scaleEffect(isPressed ? 1.2 : 1.0)
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(AppTheme.Animation.quick) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - 載入按鈕
struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if !isLoading {
                action()
            }
        }) {
            HStack(spacing: AppTheme.Spacing.s) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(isLoading ? "處理中..." : title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, AppTheme.Spacing.l)
            .padding(.vertical, AppTheme.Spacing.m)
            .foregroundColor(.white)
            .background(AppTheme.Colors.primary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            .softShadow()
            .opacity(isLoading ? 0.8 : 1.0)
        }
        .disabled(isLoading)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 分段控制器（簡約版）
struct ModernSegmentedControl: View {
    let options: [String]
    @Binding var selectedIndex: Int
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            ForEach(0..<options.count, id: \.self) { index in
                Button(action: {
                    withAnimation(AppTheme.Animation.smooth) {
                        selectedIndex = index
                    }
                }) {
                    Text(options[index])
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(
                            selectedIndex == index
                            ? .white
                            : AppTheme.Colors.textSecondary
                        )
                        .padding(.horizontal, AppTheme.Spacing.m)
                        .padding(.vertical, AppTheme.Spacing.s)
                        .background(
                            selectedIndex == index
                            ? AppTheme.Colors.primary
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(AppTheme.Spacing.xs)
        .background(AppTheme.Colors.surfaceLight)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }
}

// MARK: - GradientButton (向後兼容)
struct GradientButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let gradient: [Color]
    let isDisabled: Bool
    
    init(
        title: String,
        icon: String? = nil,
        action: @escaping () -> Void,
        gradient: [Color] = AppTheme.Gradients.primary,
        isDisabled: Bool = false
    ) {
        self.title = title
        self.icon = icon
        self.action = action
        self.gradient = gradient
        self.isDisabled = isDisabled
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.s) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, AppTheme.Spacing.l)
            .padding(.vertical, AppTheme.Spacing.m)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: gradient),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(isDisabled ? 0.6 : 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            .softShadow()
        }
        .disabled(isDisabled)
    }
}

// MARK: - 預覽
struct GradientButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppTheme.Spacing.l) {
            // 主要按鈕
            ModernButton("開始錄音", icon: "mic.fill", style: .primary) {}
            
            // 次要按鈕
            ModernButton("檢視歷史", icon: "clock", style: .secondary) {}
            
            // 極簡按鈕
            ModernButton("更多選項", style: .minimal) {}
            
            // 幽靈按鈕
            ModernButton("取消", style: .ghost) {}
            
            // 浮動按鈕
            FloatingActionButton(icon: "plus") {}
            
            // 圖標按鈕
            HStack(spacing: AppTheme.Spacing.m) {
                IconButton(icon: "heart", color: AppTheme.Colors.error) {}
                IconButton(icon: "bookmark", color: AppTheme.Colors.warning) {}
                IconButton(icon: "share", color: AppTheme.Colors.info) {}
            }
            
            // 載入按鈕
            LoadingButton(title: "上傳", isLoading: true) {}
            
            // 分段控制器
            ModernSegmentedControl(
                options: ["全部", "處理中", "已完成"],
                selectedIndex: .constant(0)
            )
        }
        .padding()
        .background(AppTheme.Colors.background)
    }
}