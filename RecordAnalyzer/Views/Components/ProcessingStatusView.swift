import SwiftUI

struct ProcessingStatusView: View {
    let status: String
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            // 動畫圖示
            ZStack {
                // 背景圓圈
                Circle()
                    .fill(statusBackgroundColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                // 主圖示
                Image(systemName: statusIcon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(statusColor)
                    .scaleEffect(isAnimating && isProcessing ? 1.1 : 1.0)
                    .animation(
                        isProcessing ? Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default,
                        value: isAnimating
                    )
                
                // 處理中的旋轉動畫
                if isProcessing {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [statusColor, statusColor.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                        .animation(
                            Animation.linear(duration: 2.0).repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
            }
            
            // 狀態文字
            VStack(spacing: 4) {
                Text(statusTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(statusDescription)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // 進度指示器（如果正在處理中）
            if isProcessing {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(statusColor)
                    .scaleEffect(x: 1, y: 0.8)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: statusColor.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            withAnimation {
                isAnimating = true
            }
        }
    }
    
    // 計算屬性
    private var isProcessing: Bool {
        ["uploading", "transcribing", "summarizing"].contains(status.lowercased())
    }
    
    private var statusIcon: String {
        switch status.lowercased() {
        case "uploading":
            return "icloud.and.arrow.up"
        case "transcribing":
            return "waveform.and.mic"
        case "transcribed":
            return "text.quote"
        case "summarizing":
            return "doc.text.magnifyingglass"
        case "completed":
            return "checkmark.circle.fill"
        case "failed":
            return "exclamationmark.triangle.fill"
        default:
            return "questionmark.circle"
        }
    }
    
    private var statusTitle: String {
        switch status.lowercased() {
        case "uploading":
            return "上傳中"
        case "transcribing":
            return "語音轉文字中"
        case "transcribed":
            return "逐字稿已完成"
        case "summarizing":
            return "生成摘要中"
        case "completed":
            return "處理完成"
        case "failed":
            return "處理失敗"
        default:
            return "處理中"
        }
    }
    
    private var statusDescription: String {
        switch status.lowercased() {
        case "uploading":
            return "正在將您的錄音檔案上傳到雲端..."
        case "transcribing":
            return "AI 正在將語音內容轉換為文字..."
        case "transcribed":
            return "逐字稿已準備就緒，開始分析內容..."
        case "summarizing":
            return "AI 正在智能分析並生成摘要..."
        case "completed":
            return "所有處理已完成，可以查看完整內容"
        case "failed":
            return "處理過程中發生錯誤，請稍後重試"
        default:
            return "正在處理您的錄音..."
        }
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "uploading":
            return .blue
        case "transcribing":
            return .purple
        case "transcribed":
            return .indigo
        case "summarizing":
            return .orange
        case "completed":
            return .green
        case "failed":
            return .red
        default:
            return .gray
        }
    }
    
    private var statusBackgroundColor: Color {
        statusColor
    }
}

// 簡化版狀態標籤（用於列表顯示）
struct ProcessingStatusBadge: View {
    let status: String
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            // 動畫圓點
            if isProcessing {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            } else {
                Image(systemName: miniIcon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(statusColor)
            }
            
            Text(statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            isAnimating = true
        }
    }
    
    private var isProcessing: Bool {
        ["uploading", "transcribing", "summarizing"].contains(status.lowercased())
    }
    
    private var miniIcon: String {
        switch status.lowercased() {
        case "completed":
            return "checkmark"
        case "failed":
            return "xmark"
        case "transcribed":
            return "doc.text"
        default:
            return "ellipsis"
        }
    }
    
    private var statusText: String {
        switch status.lowercased() {
        case "uploading":
            return "上傳中"
        case "transcribing":
            return "轉錄中"
        case "transcribed":
            return "逐字稿完成"
        case "summarizing":
            return "生成摘要中"
        case "completed":
            return "已完成"
        case "failed":
            return "失敗"
        default:
            return "處理中"
        }
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "uploading":
            return .blue
        case "transcribing":
            return .purple
        case "transcribed":
            return .indigo
        case "summarizing":
            return .orange
        case "completed":
            return .green
        case "failed":
            return .red
        default:
            return .gray
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        ProcessingStatusView(status: "uploading")
        ProcessingStatusView(status: "transcribing")
        ProcessingStatusView(status: "summarizing")
        ProcessingStatusView(status: "completed")
        
        HStack(spacing: 20) {
            ProcessingStatusBadge(status: "uploading")
            ProcessingStatusBadge(status: "transcribing")
            ProcessingStatusBadge(status: "completed")
        }
    }
    .padding()
}