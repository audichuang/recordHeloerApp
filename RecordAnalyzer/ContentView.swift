import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedTab = 0
    @State private var animateBackground = false
    @State private var animateBubbles = false
    
    // 漸變背景色彩
    let gradient1 = [Color(hex: "6366F1"), Color(hex: "8B5CF6")]
    let gradient2 = [Color(hex: "3B82F6"), Color(hex: "2DD4BF")]
    
    var body: some View {
        ZStack {
            // 適應性背景
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            // 只在淺色模式顯示裝飾性漸變
            if UITraitCollection.current.userInterfaceStyle == .light {
                // 動態背景漸變
                RadialGradient(
                    gradient: Gradient(colors: animateBackground ? gradient1 : gradient2),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: UIScreen.main.bounds.width * 1.3
                )
                .opacity(0.08)
                .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: animateBackground)
                .ignoresSafeArea()
                .onAppear { animateBackground.toggle() }
                
                // 背景裝飾氣泡
                GeometryReader { geo in
                    ZStack {
                        // 大氣泡
                        Circle()
                            .fill(Color(hex: "6366F1").opacity(0.05))
                            .frame(width: 200, height: 200)
                            .offset(x: animateBubbles ? geo.size.width * 0.3 : -30, y: animateBubbles ? geo.size.height * 0.1 : 100)
                        
                        // 中氣泡
                        Circle()
                            .fill(Color(hex: "8B5CF6").opacity(0.04))
                            .frame(width: 140, height: 140)
                            .offset(x: animateBubbles ? geo.size.width * 0.7 : geo.size.width * 0.8, 
                                    y: animateBubbles ? geo.size.height * 0.5 : geo.size.height * 0.6)
                        
                        // 小氣泡
                        Circle()
                            .fill(Color(hex: "3B82F6").opacity(0.03))
                            .frame(width: 80, height: 80)
                            .offset(x: animateBubbles ? geo.size.width * 0.2 : geo.size.width * 0.1, 
                                    y: animateBubbles ? geo.size.height * 0.7 : geo.size.height * 0.8)
                    }
                    .animation(.easeInOut(duration: 15).repeatForever(autoreverses: true), value: animateBubbles)
                    .onAppear {
                        animateBubbles.toggle()
                    }
                }
            }
            
            Group {
                if authManager.isAuthenticated {
                    NavigationView {
                        TabView(selection: $selectedTab) {
                            HomeView(selectedTab: $selectedTab)
                                .tabItem {
                                    Label("首頁", systemImage: "house.fill")
                                }
                                .tag(0)
                            
                            HistoryView()
                                .tabItem {
                                    Label("歷史", systemImage: "clock.fill")
                                }
                                .tag(1)
                            
                            ProfileView()
                                .tabItem {
                                    Label("個人", systemImage: "person.fill")
                                }
                                .tag(2)
                        }
                        .tint(Color(hex: "6366F1"))
                        .background(Color.clear)
                        .onAppear {
                            // 設置TabBar的外觀
                            let appearance = UITabBarAppearance()
                            appearance.configureWithOpaqueBackground()
                            appearance.backgroundColor = UIColor.systemBackground
                            appearance.shadowColor = UIColor.separator.withAlphaComponent(0.3)
                            
                            // 設置選中和未選中的顏色
                            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppTheme.Colors.primary)
                            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.Colors.primary)]
                            appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
                            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray]
                            
                            // 內聯布局設定
                            appearance.inlineLayoutAppearance.selected.iconColor = UIColor(AppTheme.Colors.primary)
                            appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.Colors.primary)]
                            appearance.inlineLayoutAppearance.normal.iconColor = UIColor.systemGray
                            appearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray]
                            
                            // 緊凑布局設定
                            appearance.compactInlineLayoutAppearance.selected.iconColor = UIColor(AppTheme.Colors.primary)
                            appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.Colors.primary)]
                            appearance.compactInlineLayoutAppearance.normal.iconColor = UIColor.systemGray
                            appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray]
                            
                            // 使用自定義外觀
                            UITabBar.appearance().standardAppearance = appearance
                            if #available(iOS 15.0, *) {
                                UITabBar.appearance().scrollEdgeAppearance = appearance
                            }
                        }
                    }
                    .background(Color.clear)
                    .onAppear {
                        // 設置NavigationBar的外觀
                        let appearance = UINavigationBarAppearance()
                        appearance.configureWithOpaqueBackground()
                        appearance.backgroundColor = UIColor.systemBackground
                        appearance.shadowColor = UIColor.separator.withAlphaComponent(0.3)
                        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
                        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
                        
                        // 使用自定義外觀
                        UINavigationBar.appearance().standardAppearance = appearance
                        UINavigationBar.appearance().scrollEdgeAppearance = appearance
                        UINavigationBar.appearance().compactAppearance = appearance
                        if #available(iOS 15.0, *) {
                            UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                } else {
                    LoginView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.smooth(duration: 0.4), value: authManager.isAuthenticated)
        }
    }
}

// 擴展Color以支持十六進制值
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
        .environmentObject(RecordingManager())
} 