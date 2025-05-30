import SwiftUI

/// 全局設計系統 - 簡約現代風格
struct AppTheme {
    /// 主題顏色 - 更簡約的配色方案
    struct Colors {
        // 主要顏色 - 優雅的靛藍色系
        static let primary = Color(hex: "4F46E5")      // 主色調
        static let primaryDark = Color(hex: "4338CA")  // 深色變體
        static let primaryLight = Color(hex: "6366F1") // 淺色變體
        
        // 次要顏色 - 柔和的紫色系
        static let secondary = Color(hex: "7C3AED")
        static let secondaryDark = Color(hex: "6D28D9")
        static let secondaryLight = Color(hex: "8B5CF6")
        
        // 點綴色 - 清新的青色
        static let accent = Color(hex: "06B6D4")
        
        // 狀態顏色 - 更柔和的狀態色
        static let success = Color(hex: "22C55E")
        static let successLight = Color(hex: "86EFAC")
        static let warning = Color(hex: "F97316")
        static let warningLight = Color(hex: "FDBA74")
        static let error = Color(hex: "EF4444")
        static let errorLight = Color(hex: "FCA5A5")
        static let info = Color(hex: "3B82F6")
        static let infoLight = Color(hex: "93BBFC")
        
        // 背景顏色 - 簡潔的層次
        static let background = Color("AppBackground")
        static let surface = Color("CardBackground")
        static let surfaceLight = Color.white.opacity(0.05)
        
        // 卡片顏色 - 向後兼容
        static let card = Color("CardBackground")
        static let cardHighlight = Color("CardHighlight")
        
        // 文字顏色 - 優化對比度
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary").opacity(0.7)
        static let textTertiary = Color("TextTertiary").opacity(0.5)
        
        // 邊框與分隔線 - 更細膩
        static let border = Color.gray.opacity(0.1)
        static let divider = Color.gray.opacity(0.08)
    }
    
    /// 簡約漸變色組合
    struct Gradients {
        // 微妙的漸變效果
        static let primary = [Colors.primary, Colors.primary.opacity(0.8)]
        static let secondary = [Colors.secondary, Colors.secondary.opacity(0.8)]
        static let accent = [Colors.accent, Colors.accent.opacity(0.8)]
        
        // 狀態漸變 - 更柔和
        static let success = [Colors.success, Colors.success.opacity(0.8)]
        static let warning = [Colors.warning, Colors.warning.opacity(0.8)]
        static let error = [Colors.error, Colors.error.opacity(0.8)]
        static let info = [Colors.info, Colors.info.opacity(0.8)]
        
        // 背景漸變 - 極其微妙
        static let backgroundSubtle = [
            Color.white.opacity(0.02),
            Color.white.opacity(0.01)
        ]
    }
    
    /// 陰影設定 - 更柔和的陰影系統
    struct Shadows {
        static let subtle = Shadow(
            color: .black.opacity(0.03),
            radius: 8,
            x: 0,
            y: 2
        )
        
        static let soft = Shadow(
            color: .black.opacity(0.05),
            radius: 16,
            x: 0,
            y: 4
        )
        
        static let medium = Shadow(
            color: .black.opacity(0.08),
            radius: 24,
            x: 0,
            y: 8
        )
        
        static let glow = Shadow(
            color: Colors.primary.opacity(0.2),
            radius: 32,
            x: 0,
            y: 0
        )
        
        struct Shadow {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
    }
    
    /// 圓角設定 - 統一的現代圓角
    struct CornerRadius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xl: CGFloat = 28
        static let full: CGFloat = 999
    }
    
    /// 間距設定 - 簡化的間距系統
    struct Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
    
    /// 動畫設定 - 流暢的動畫
    struct Animation {
        static let smooth = SwiftUI.Animation.spring(
            response: 0.4,
            dampingFraction: 0.85,
            blendDuration: 0
        )
        
        static let quick = SwiftUI.Animation.spring(
            response: 0.3,
            dampingFraction: 0.82,
            blendDuration: 0
        )
        
        static let bouncy = SwiftUI.Animation.spring(
            response: 0.5,
            dampingFraction: 0.68,
            blendDuration: 0
        )
        
        static let subtle = SwiftUI.Animation.easeInOut(duration: 0.35)
    }
    
    /// 字體大小 - 清晰的層級
    struct FontSize {
        static let caption: CGFloat = 12
        static let body: CGFloat = 16
        static let title3: CGFloat = 20
        static let title2: CGFloat = 24
        static let title1: CGFloat = 32
        static let largeTitle: CGFloat = 40
    }
}

// MARK: - View Extensions
extension View {
    /// 極簡陰影效果
    func subtleShadow() -> some View {
        self.shadow(
            color: AppTheme.Shadows.subtle.color,
            radius: AppTheme.Shadows.subtle.radius,
            x: AppTheme.Shadows.subtle.x,
            y: AppTheme.Shadows.subtle.y
        )
    }
    
    /// 柔和陰影效果
    func softShadow() -> some View {
        self.shadow(
            color: AppTheme.Shadows.soft.color,
            radius: AppTheme.Shadows.soft.radius,
            x: AppTheme.Shadows.soft.x,
            y: AppTheme.Shadows.soft.y
        )
    }
    
    /// 中等陰影效果
    func mediumShadow() -> some View {
        self.shadow(
            color: AppTheme.Shadows.medium.color,
            radius: AppTheme.Shadows.medium.radius,
            x: AppTheme.Shadows.medium.x,
            y: AppTheme.Shadows.medium.y
        )
    }
    
    /// 發光效果
    func glowEffect() -> some View {
        self.shadow(
            color: AppTheme.Shadows.glow.color,
            radius: AppTheme.Shadows.glow.radius,
            x: AppTheme.Shadows.glow.x,
            y: AppTheme.Shadows.glow.y
        )
    }
    
    /// 現代卡片樣式
    func modernCard(
        padding: CGFloat = AppTheme.Spacing.l,
        cornerRadius: CGFloat = AppTheme.CornerRadius.large
    ) -> some View {
        self
            .padding(padding)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )
            .softShadow()
    }
    
    /// 簡約按鈕樣式
    func minimalButton(
        foregroundColor: Color = AppTheme.Colors.primary,
        backgroundColor: Color = AppTheme.Colors.primary.opacity(0.1)
    ) -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.l)
            .padding(.vertical, AppTheme.Spacing.m)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }
    
    /// 主要按鈕樣式
    func primaryButton() -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, AppTheme.Spacing.m)
            .foregroundColor(.white)
            .background(AppTheme.Colors.primary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            .softShadow()
    }
    
    /// 微妙的背景漸變
    func subtleGradientBackground() -> some View {
        self.background(
            LinearGradient(
                gradient: Gradient(colors: AppTheme.Gradients.backgroundSubtle),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    /// 性能優化：減少重繪
    func optimizedRendering() -> some View {
        self
            .drawingGroup()
            .compositingGroup()
    }
}

// MARK: - 性能優化修飾符
struct LazyLoadModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .task {
                // 延遲載入重內容
            }
    }
}

extension View {
    func lazyLoad() -> some View {
        modifier(LazyLoadModifier())
    }
}