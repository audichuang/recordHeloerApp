import SwiftUI

/// 全局設計系統
struct AppTheme {
    /// 主題顏色
    struct Colors {
        // 主要顏色
        static let primary = Color(hex: "6366F1")
        static let primaryDark = Color(hex: "4F46E5")
        static let primaryLight = Color(hex: "818CF8")
        
        // 次要顏色
        static let secondary = Color(hex: "8B5CF6")
        static let secondaryDark = Color(hex: "7C3AED")
        static let secondaryLight = Color(hex: "A78BFA")
        
        // 狀態顏色
        static let success = Color(hex: "10B981")
        static let successDark = Color(hex: "059669")
        static let warning = Color(hex: "F59E0B")
        static let warningDark = Color(hex: "D97706")
        static let error = Color(hex: "EF4444")
        static let errorDark = Color(hex: "DC2626")
        static let info = Color(hex: "3B82F6")
        static let infoDark = Color(hex: "2563EB")
        
        // 背景顏色
        static let background = Color("AppBackground")
        static let card = Color("CardBackground")
        static let cardHighlight = Color("CardHighlight")
        
        // 文字顏色
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let textTertiary = Color("TextTertiary")
        
        // 輔助顏色
        static let divider = Color("Divider")
        
        // 動態色彩適配
        static let adaptiveBackground = Color("AdaptiveBackground")
        static let adaptiveCard = Color("AdaptiveCard")
        static let adaptiveText = Color("AdaptiveText")
    }
    
    /// 漸變顏色組合
    struct Gradients {
        static let primary = [Colors.primary, Colors.secondary]
        static let secondary = [Color(hex: "3B82F6"), Color(hex: "2DD4BF")]
        static let success = [Colors.success, Colors.successDark]
        static let warning = [Colors.warning, Colors.warningDark]
        static let error = [Colors.error, Colors.errorDark]
        static let info = [Colors.info, Colors.infoDark]
    }
    
    /// 陰影設定
    struct Shadows {
        static let small = Shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        static let medium = Shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        static let large = Shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
        
        struct Shadow {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
    }
    
    /// 圓角設定
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
    }
    
    /// 間距設定
    struct Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }
    
    /// 動畫設定
    struct Animation {
        static let standard = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let slow = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.7)
        static let fast = SwiftUI.Animation.spring(response: 0.2, dampingFraction: 0.7)
    }
}

/// 添加自定義修飾符
extension View {
    /// 套用小陰影
    func smallShadow() -> some View {
        self.shadow(
            color: AppTheme.Shadows.small.color,
            radius: AppTheme.Shadows.small.radius,
            x: AppTheme.Shadows.small.x,
            y: AppTheme.Shadows.small.y
        )
    }
    
    /// 套用中等陰影
    func mediumShadow() -> some View {
        self.shadow(
            color: AppTheme.Shadows.medium.color,
            radius: AppTheme.Shadows.medium.radius,
            x: AppTheme.Shadows.medium.x,
            y: AppTheme.Shadows.medium.y
        )
    }
    
    /// 套用大陰影
    func largeShadow() -> some View {
        self.shadow(
            color: AppTheme.Shadows.large.color,
            radius: AppTheme.Shadows.large.radius,
            x: AppTheme.Shadows.large.x,
            y: AppTheme.Shadows.large.y
        )
    }
    
    /// 添加卡片樣式
    func cardStyle(cornerRadius: CGFloat = AppTheme.CornerRadius.large) -> some View {
        self
            .padding(AppTheme.Spacing.l)
            .background(AppTheme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .smallShadow()
    }
    
    /// 添加主題漸變背景
    func gradientBackground(
        colors: [Color] = AppTheme.Gradients.primary,
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> some View {
        self.background(
            LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: startPoint,
                endPoint: endPoint
            )
        )
    }
} 