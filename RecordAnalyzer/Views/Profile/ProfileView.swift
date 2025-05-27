import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var recordingManager: RecordingManager
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // 用戶資訊卡片
                    userInfoCard
                    
                    // 統計資訊
                    statisticsSection
                    
                    // 設定選項
                    settingsSection
                    
                    // 登出按鈕
                    logoutSection
                }
                .padding()
            }
            .navigationTitle("個人資料")
        }
        .alert("確認登出", isPresented: $showingLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("登出", role: .destructive) {
                authManager.logout()
            }
        } message: {
            Text("您確定要登出嗎？")
        }
    }
    
    private var userInfoCard: some View {
        VStack(spacing: 16) {
            // 用戶頭像
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 80, height: 80)
                .overlay(
                    Text(userInitials)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // 用戶資訊
            VStack(spacing: 8) {
                if let user = authManager.currentUser {
                    Text(user.username)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("會員自 \(formattedJoinDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(15)
    }
    
    private var statisticsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("使用統計")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            HStack(spacing: 16) {
                StatisticCard(
                    title: "總錄音數",
                    value: "\(recordingManager.recordings.count)",
                    icon: "waveform",
                    color: .blue
                )
                
                StatisticCard(
                    title: "總時長",
                    value: totalDuration,
                    icon: "clock",
                    color: .green
                )
            }
            
            HStack(spacing: 16) {
                StatisticCard(
                    title: "本月新增",
                    value: "\(currentMonthRecordings)",
                    icon: "calendar",
                    color: .orange
                )
                
                StatisticCard(
                    title: "平均時長",
                    value: averageDuration,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                )
            }
        }
    }
    
    private var settingsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("設定")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                SettingRow(
                    icon: "bell",
                    title: "通知設定",
                    subtitle: "管理推送通知",
                    action: { }
                )
                
                SettingRow(
                    icon: "icloud",
                    title: "雲端同步",
                    subtitle: "自動備份錄音到雲端",
                    action: { }
                )
                
                SettingRow(
                    icon: "gear",
                    title: "音質設定",
                    subtitle: "調整錄音和上傳品質",
                    action: { }
                )
                
                SettingRow(
                    icon: "questionmark.circle",
                    title: "幫助與支援",
                    subtitle: "常見問題和客服聯繫",
                    action: { }
                )
                
                SettingRow(
                    icon: "doc.text",
                    title: "隱私政策",
                    subtitle: "查看隱私政策和使用條款",
                    action: { }
                )
            }
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private var logoutSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                showingLogoutAlert = true
            }) {
                HStack {
                    Image(systemName: "power")
                    Text("登出")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(12)
            }
            
            Text("版本 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
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