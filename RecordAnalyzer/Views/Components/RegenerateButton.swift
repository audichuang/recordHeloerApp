import SwiftUI

struct RegenerateButton: View {
    let title: String
    let icon: String = "arrow.clockwise"
    let isLoading: Bool
    let gradient: [Color]
    let action: () async -> Void
    
    var body: some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                
                Text(isLoading ? "處理中..." : title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: gradient),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(isLoading ? 0.7 : 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(
                color: gradient.first?.opacity(0.3) ?? .clear,
                radius: isLoading ? 2 : 4,
                x: 0,
                y: isLoading ? 1 : 2
            )
            .scaleEffect(isLoading ? 0.95 : 1.0)
        }
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

#Preview {
    VStack(spacing: 20) {
        RegenerateButton(
            title: "重新生成",
            isLoading: false,
            gradient: AppTheme.Gradients.primary
        ) {
            // Preview action
        }
        
        RegenerateButton(
            title: "重新生成",
            isLoading: true,
            gradient: AppTheme.Gradients.success
        ) {
            // Preview action
        }
    }
    .padding()
    .background(AppTheme.Colors.background)
}