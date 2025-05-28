import SwiftUI

struct GradientText: View {
    var text: String
    var gradient: [Color]
    var fontSize: CGFloat = 24
    var fontWeight: Font.Weight = .bold
    var animate: Bool = false
    
    @State private var animateGradient = false
    
    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundStyle(
                LinearGradient(
                    colors: gradient,
                    startPoint: animate ? (animateGradient ? .topLeading : .bottomTrailing) : .topLeading,
                    endPoint: animate ? (animateGradient ? .bottomTrailing : .topLeading) : .bottomTrailing
                )
            )
            .onAppear {
                if animate {
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
                        animateGradient.toggle()
                    }
                }
            }
    }
}

struct AnimatedGradientText: View {
    var text: String
    var gradient: [Color] = AppTheme.Gradients.primary
    var fontSize: CGFloat = 24
    var fontWeight: Font.Weight = .bold
    var animationDuration: Double = 3
    
    @State private var startPoint: UnitPoint = .topLeading
    @State private var endPoint: UnitPoint = .bottomTrailing
    
    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundStyle(
                LinearGradient(
                    colors: gradient,
                    startPoint: startPoint,
                    endPoint: endPoint
                )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: animationDuration).repeatForever(autoreverses: true)) {
                    startPoint = .bottomTrailing
                    endPoint = .topLeading
                }
            }
    }
}

struct ShimmeringText: View {
    var text: String
    var fontSize: CGFloat = 24
    var fontWeight: Font.Weight = .bold
    var baseColor: Color = AppTheme.Colors.primary
    var highlightColor: Color = .white
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Text(text)
                .font(.system(size: fontSize, weight: fontWeight))
                .foregroundColor(baseColor)
            
            Text(text)
                .font(.system(size: fontSize, weight: fontWeight))
                .foregroundColor(highlightColor)
                .mask(
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.8), location: 0.45),
                                    .init(color: .white, location: 0.5),
                                    .init(color: .white.opacity(0.8), location: 0.55),
                                    .init(color: .clear, location: 1)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .rotationEffect(.degrees(70))
                        .offset(x: isAnimating ? 200 : -200)
                )
                .blendMode(.overlay)
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        GradientText(
            text: "基本漸變文字",
            gradient: AppTheme.Gradients.primary
        )
        
        GradientText(
            text: "動畫漸變文字",
            gradient: AppTheme.Gradients.info,
            animate: true
        )
        
        AnimatedGradientText(
            text: "平滑動畫漸變文字",
            gradient: AppTheme.Gradients.secondary
        )
        
        ShimmeringText(
            text: "閃耀文字效果",
            fontSize: 28,
            baseColor: AppTheme.Colors.success
        )
    }
    .padding()
    .background(AppTheme.Colors.background)
} 