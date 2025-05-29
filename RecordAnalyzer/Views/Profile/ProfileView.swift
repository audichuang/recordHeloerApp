import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var recordingManager: RecordingManager
    @State private var showingLogoutAlert = false
    @State private var showingAccountCenter = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // 用戶資訊卡片
                AnimatedCardView(
                    title: "個人資訊",
                    icon: "person.fill",
                    gradient: AppTheme.Gradients.primary,
                    delay: 0.1
                ) {
                    userInfoContent
                }
                
                // 統計資訊
                AnimatedCardView(
                    title: "使用統計",
                    icon: "chart.bar.fill",
                    gradient: AppTheme.Gradients.secondary,
                    delay: 0.2
                ) {
                    statisticsContent
                }
                
                // 設定選項
                AnimatedCardView(
                    title: "設定",
                    icon: "gear",
                    gradient: AppTheme.Gradients.info,
                    delay: 0.3
                ) {
                    settingsContent
                }
                
                // 登出按鈕
                AnimatedCardView(
                    title: "帳戶操作",
                    icon: "power",
                    gradient: AppTheme.Gradients.error,
                    delay: 0.4
                ) {
                    logoutContent
                }
            }
            .padding()
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("個人資料")
        .alert("確認登出", isPresented: $showingLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("登出", role: .destructive) {
                authManager.logout()
            }
        } message: {
            Text("您確定要登出嗎？")
        }
        .sheet(isPresented: $showingAccountCenter) {
            AccountCenterView()
                .environmentObject(authManager)
        }
    }
    
    private var userInfoContent: some View {
        VStack(spacing: 20) {
            // 用戶頭像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: AppTheme.Gradients.primary),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: AppTheme.Colors.primary.opacity(0.5), radius: 8, x: 0, y: 4)
                
                Text(userInitials)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // 用戶資訊
            VStack(spacing: 8) {
                if let user = authManager.currentUser {
                    GradientText(
                        text: user.username,
                        gradient: AppTheme.Gradients.primary,
                        fontSize: 24,
                        fontWeight: .bold
                    )
                    
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text("會員自 \(formattedJoinDate)")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var statisticsContent: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ModernStatCard(
                    title: "總錄音數",
                    value: "\(recordingManager.recordings.count)",
                    icon: "waveform",
                    gradient: AppTheme.Gradients.primary
                )
                
                ModernStatCard(
                    title: "總時長",
                    value: totalDuration,
                    icon: "clock",
                    gradient: AppTheme.Gradients.success
                )
            }
            
            HStack(spacing: 12) {
                ModernStatCard(
                    title: "本月新增",
                    value: "\(currentMonthRecordings)",
                    icon: "calendar",
                    gradient: AppTheme.Gradients.warning
                )
                
                ModernStatCard(
                    title: "平均時長",
                    value: averageDuration,
                    icon: "chart.line.uptrend.xyaxis",
                    gradient: AppTheme.Gradients.secondary
                )
            }
        }
    }
    
    private var settingsContent: some View {
        VStack(spacing: 12) {
            ModernSettingRow(
                icon: "person.crop.circle.badge.checkmark",
                title: "會員中心",
                subtitle: "管理帳號綁定與登入方式",
                iconColor: AppTheme.Colors.primary,
                action: { 
                    showingAccountCenter = true
                }
            )
            
            ModernSettingRow(
                icon: "bell",
                title: "通知設定",
                subtitle: "管理推送通知",
                iconColor: AppTheme.Colors.warning,
                action: { }
            )
            
            ModernSettingRow(
                icon: "icloud",
                title: "雲端同步",
                subtitle: "自動備份錄音到雲端",
                iconColor: AppTheme.Colors.info,
                action: { }
            )
            
            ModernSettingRow(
                icon: "gear",
                title: "音質設定",
                subtitle: "調整錄音和上傳品質",
                iconColor: AppTheme.Colors.primary,
                action: { }
            )
            
            ModernSettingRow(
                icon: "questionmark.circle",
                title: "幫助與支援",
                subtitle: "常見問題和客服聯繫",
                iconColor: AppTheme.Colors.success,
                action: { }
            )
            
            ModernSettingRow(
                icon: "doc.text",
                title: "隱私政策",
                subtitle: "查看隱私政策和使用條款",
                iconColor: AppTheme.Colors.textSecondary,
                action: { }
            )
        }
    }
    
    private var logoutContent: some View {
        VStack(spacing: 16) {
            Button(action: {
                showingLogoutAlert = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "power")
                        .font(.system(size: 16))
                    Text("登出")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                        .fill(AppTheme.Colors.error.opacity(0.1))
                )
                .foregroundColor(AppTheme.Colors.error)
            }
            
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
                
                Text("版本 1.0.0")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
                
                Spacer()
            }
        }
    }
    
    // 計算屬性
    private var userInitials: String {
        guard let user = authManager.currentUser else { return "U" }
        let names = user.username.components(separatedBy: " ")
        if names.count > 1 {
            return String(names[0].prefix(1)) + String(names[1].prefix(1))
        } else {
            return String(user.username.prefix(2))
        }
    }
    
    private var formattedJoinDate: String {
        guard let user = authManager.currentUser else { return "" }
        
        // createdAt 是 String 類型，不需要 Optional 解包
        let dateString = user.createdAt
        
        // 嘗試將 ISO 8601 格式的字符串轉換為日期
        if let isoDate = ISO8601DateFormatter().date(from: dateString) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.locale = Locale(identifier: "zh_TW")
            return formatter.string(from: isoDate)
        } else {
            // 如果無法解析日期格式，直接返回原始字符串
            return dateString
        }
    }
    
    private var totalDuration: String {
        let total = recordingManager.recordings.reduce(0.0) { $0 + ($1.duration ?? 0.0) }
        let hours = Int(total) / 3600
        let minutes = Int(total) % 3600 / 60
        if hours > 0 {
            return String(format: "%d小時%d分", hours, minutes)
        } else {
            return String(format: "%d分鐘", minutes)
        }
    }
    
    private var averageDuration: String {
        guard !recordingManager.recordings.isEmpty else { return "0分" }
        let average = recordingManager.recordings.reduce(0.0) { $0 + ($1.duration ?? 0.0) } / Double(recordingManager.recordings.count)
        let minutes = Int(average) / 60
        return String(format: "%d分", minutes)
    }
    
    private var currentMonthRecordings: Int {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        return recordingManager.recordings.filter { recording in
            let month = calendar.component(.month, from: recording.createdAt)
            let year = calendar.component(.year, from: recording.createdAt)
            return month == currentMonth && year == currentYear
        }.count
    }
}

struct ModernStatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: gradient),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: gradient[0].opacity(0.5), radius: 4, x: 0, y: 2)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .fill(gradient[0].opacity(0.1))
        )
    }
}

struct ModernSettingRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(AppTheme.Colors.cardHighlight)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationManager())
        .environmentObject(RecordingManager())
} 