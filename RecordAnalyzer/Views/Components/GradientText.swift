import SwiftUI

// MARK: - 簡約漸變文字
struct GradientText: View {
    let text: String
    let gradient: [Color]
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    
    init(
        text: String,
        gradient: [Color] = AppTheme.Gradients.primary,
        fontSize: CGFloat = AppTheme.FontSize.body,
        fontWeight: Font.Weight = .regular
    ) {
        self.text = text
        self.gradient = gradient
        self.fontSize = fontSize
        self.fontWeight = fontWeight
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(colors: gradient),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

// MARK: - 動態文字效果
struct AnimatedText: View {
    let text: String
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let color: Color
    
    @State private var animationAmount = 0.0
    
    init(
        text: String,
        fontSize: CGFloat = AppTheme.FontSize.body,
        fontWeight: Font.Weight = .regular,
        color: Color = AppTheme.Colors.textPrimary
    ) {
        self.text = text
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.color = color
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundColor(color)
            .scaleEffect(1 + animationAmount * 0.05)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 2)
                        .repeatForever(autoreverses: true)
                ) {
                    animationAmount = 1
                }
            }
    }
}

// MARK: - 打字機效果文字
struct TypewriterText: View {
    let text: String
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let color: Color
    let typingSpeed: Double
    
    @State private var displayedText = ""
    @State private var currentIndex = 0
    
    init(
        text: String,
        fontSize: CGFloat = AppTheme.FontSize.body,
        fontWeight: Font.Weight = .regular,
        color: Color = AppTheme.Colors.textPrimary,
        typingSpeed: Double = 0.05
    ) {
        self.text = text
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.color = color
        self.typingSpeed = typingSpeed
    }
    
    var body: some View {
        Text(displayedText)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundColor(color)
            .onAppear {
                typeText()
            }
    }
    
    private func typeText() {
        Task { @MainActor in
            for i in 0..<text.count {
                let index = text.index(text.startIndex, offsetBy: i)
                displayedText.append(text[index])
                currentIndex = i + 1
                try? await Task.sleep(nanoseconds: UInt64(typingSpeed * 1_000_000_000))
            }
        }
    }
}

// MARK: - 預覽
struct GradientText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            // 漸變文字
            GradientText(
                text: "漸變文字效果",
                gradient: AppTheme.Gradients.primary,
                fontSize: AppTheme.FontSize.title2,
                fontWeight: .bold
            )
            
            // 動態文字
            AnimatedText(
                text: "動態呼吸效果",
                fontSize: AppTheme.FontSize.title3,
                fontWeight: .medium,
                color: AppTheme.Colors.secondary
            )
            
            // 打字機效果
            TypewriterText(
                text: "打字機效果文字展示",
                fontSize: AppTheme.FontSize.body,
                typingSpeed: 0.1
            )
        }
        .padding()
        .background(AppTheme.Colors.background)
    }
}