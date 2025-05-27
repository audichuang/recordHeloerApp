import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                NavigationStack {
                    TabView(selection: $selectedTab) {
                        HomeView()
                            .tabItem {
                                Label("首頁", systemImage: "house.fill")
                            }
                            .tag(0)
                        
                        HistoryView()
                            .tabItem {
                                Label("歷史紀錄", systemImage: "clock.fill")
                            }
                            .tag(1)
                        
                        ProfileView()
                            .tabItem {
                                Label("個人資料", systemImage: "person.fill")
                            }
                            .tag(2)
                    }
                    .tint(.blue)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Menu {
                                Button("設定", systemImage: "gear") {
                                    // 設定動作
                                }
                                Button("說明", systemImage: "questionmark.circle") {
                                    // 說明動作
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
                .animation(.smooth(duration: 0.3), value: selectedTab)
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

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
        .environmentObject(RecordingManager())
} 