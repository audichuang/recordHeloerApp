import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @State private var searchText = ""
    @State private var sortOption: SortOption = .dateDescending
    @State private var showingLoadingAnimation = true
    
    enum SortOption: String, CaseIterable {
        case dateDescending = "最新優先"
        case dateAscending = "最舊優先"
        case titleAscending = "標題 A-Z"
        case durationDescending = "時長最長"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜尋和排序區域
                searchAndSortSection
                    .opacity(recordingManager.isLoading ? 0.6 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: recordingManager.isLoading)
                
                // 錄音列表
                recordingsList
            }
            .navigationTitle("歷史紀錄")
            .refreshable {
                await refreshData()
            }
            .onAppear {
                loadDataIfNeeded()
            }
        }
    }
    
    private var searchAndSortSection: some View {
        VStack(spacing: 12) {
            // 搜尋框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("搜尋錄音...", text: $searchText)
                
                if !searchText.isEmpty {
                    Button("清除") {
                        searchText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // 排序選項
            HStack {
                Text("排序方式:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("排序", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Spacer()
                
                HStack(spacing: 4) {
                    if recordingManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    
                    Text("\(filteredAndSortedRecordings.count) 個錄音")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
    
    private var recordingsList: some View {
        Group {
            if recordingManager.isLoading && recordingManager.recordings.isEmpty {
                // 骨架屏載入動畫
                loadingSkeletonView
            } else if filteredAndSortedRecordings.isEmpty {
                emptyStateView
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredAndSortedRecordings) { recording in
                            NavigationLink(destination: RecordingDetailView(recording: recording)) {
                                RecordingRowView(recording: recording)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: filteredAndSortedRecordings.count)
                }
                .refreshable {
                    await refreshData()
                }
            }
        }
    }
    
    private var loadingSkeletonView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonRowView()
                }
            }
            .padding()
        }
        .disabled(true)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // 動畫圖標
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: searchText.isEmpty ? "music.note.list" : "magnifyingglass")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.blue)
                    .scaleEffect(showingLoadingAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: showingLoadingAnimation)
            }
            
            VStack(spacing: 12) {
                Text(searchText.isEmpty ? "尚無錄音記錄" : "找不到相關錄音")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(searchText.isEmpty ? 
                     "上傳您的第一個錄音文件開始使用智能分析功能" : 
                     "請嘗試其他搜尋關鍵字或調整篩選條件")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if searchText.isEmpty {
                NavigationLink("立即上傳錄音") {
                    HomeView()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .scaleEffect(showingLoadingAnimation ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: showingLoadingAnimation)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .onAppear {
            showingLoadingAnimation = true
        }
    }
    
    private var filteredAndSortedRecordings: [Recording] {
        let filtered = searchText.isEmpty ? 
            recordingManager.recordings : 
            recordingManager.recordings.filter { recording in
                recording.title.localizedCaseInsensitiveContains(searchText) ||
                recording.originalFilename.localizedCaseInsensitiveContains(searchText) ||
                (recording.transcription?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        
        return filtered.sorted { first, second in
            switch sortOption {
            case .dateDescending:
                return first.createdAt > second.createdAt
            case .dateAscending:
                return first.createdAt < second.createdAt
            case .titleAscending:
                return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
            case .durationDescending:
                // 處理時長排序 - 有時長的項目優先，然後按時長降序排列
                let firstDuration = first.duration ?? 0
                let secondDuration = second.duration ?? 0
                
                if firstDuration == 0 && secondDuration == 0 {
                    // 如果都沒有時長，按創建時間降序
                    return first.createdAt > second.createdAt
                } else if firstDuration == 0 {
                    // 第一個沒有時長，排在後面
                    return false
                } else if secondDuration == 0 {
                    // 第二個沒有時長，排在後面
                    return true
                } else {
                    // 都有時長，按時長降序
                    return firstDuration > secondDuration
                }
            }
        }
    }
    
    /// 刷新數據
    private func refreshData() async {
        // 使用輕量級的摘要API進行刷新
        await recordingManager.loadRecordingsSummary()
    }
    
    /// 首次載入或需要時載入數據
    private func loadDataIfNeeded() {
        guard !recordingManager.isLoading && recordingManager.recordings.isEmpty else {
            return
        }
        
        Task {
            // 使用輕量級的摘要API進行初始載入
            await recordingManager.loadRecordingsSummary()
        }
    }
}

struct SkeletonRowView: View {
    @State private var isShimmering = false
    
    var body: some View {
        HStack(spacing: 16) {
            // 錄音圖標骨架
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .shimmer(isShimmering)
            
            VStack(alignment: .leading, spacing: 8) {
                // 標題骨架
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)
                    .shimmer(isShimmering)
                
                // 詳細信息骨架
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 12)
                        .shimmer(isShimmering)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 12)
                        .shimmer(isShimmering)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onAppear {
            isShimmering = true
        }
    }
}

extension View {
    func shimmer(_ isShimmering: Bool) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.6), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .scaleEffect(x: isShimmering ? 3 : 0, anchor: .leading)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isShimmering)
        )
        .clipped()
    }
}

#Preview {
    HistoryView()
        .environmentObject(RecordingManager())
} 