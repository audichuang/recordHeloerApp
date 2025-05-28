import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @State private var searchText = ""
    @State private var sortOption: SortOption = .dateDescending
    @State private var showingLoadingAnimation = true
    @State private var cachedFilteredRecordings: [Recording] = []
    @State private var lastSearchText = ""
    @State private var lastSortOption: SortOption = .dateDescending
    
    enum SortOption: String, CaseIterable {
        case dateDescending = "最新優先"
        case dateAscending = "最舊優先"
        case titleAscending = "標題 A-Z"
        case durationDescending = "時長最長"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // 搜尋和排序卡片
                AnimatedCardView(
                    title: "搜尋與篩選",
                    icon: "magnifyingglass",
                    gradient: AppTheme.Gradients.info,
                    delay: 0.1
                ) {
                    searchAndSortContent
                }
                
                // 統計卡片
                AnimatedCardView(
                    title: "統計資訊",
                    icon: "chart.bar.fill",
                    gradient: AppTheme.Gradients.secondary,
                    delay: 0.2
                ) {
                    statisticsContent
                }
                
                // 錄音列表卡片
                AnimatedCardView(
                    title: "錄音列表 (\(filteredAndSortedRecordings.count))",
                    icon: "list.bullet",
                    gradient: AppTheme.Gradients.primary,
                    delay: 0.3
                ) {
                    recordingsListContent
                }
            }
            .padding()
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("歷史紀錄")
        .refreshable {
            await refreshData()
        }
        .onAppear {
            loadDataIfNeeded()
        }
    }
    
    private var searchAndSortContent: some View {
        VStack(spacing: 16) {
            // 搜尋框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.Colors.primary)
                    .font(.system(size: 16))
                
                TextField("搜尋錄音...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(AppTheme.Colors.cardHighlight)
            )
            
            // 排序選項
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("排序方式")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Picker("排序", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .accentColor(AppTheme.Colors.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if recordingManager.isLoading {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("載入中...")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    } else {
                        Text("\(filteredAndSortedRecordings.count) 個錄音")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
        }
    }
    
    private var recordingsListContent: some View {
        Group {
            if recordingManager.isLoading && recordingManager.recordings.isEmpty {
                loadingSkeletonContent
            } else if filteredAndSortedRecordings.isEmpty {
                emptyStateContent
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredAndSortedRecordings) { recording in
                        NavigationLink(destination: RecordingDetailView(recording: recording)
                            .id(recording.id)) {
                            RecordingRowView(recording: recording)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .id(recording.id) // 加入ID以提升導航性能
                    }
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: filteredAndSortedRecordings.count)
            }
        }
    }
    
    private var loadingSkeletonContent: some View {
        LazyVStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonRowView()
            }
        }
        .disabled(true)
    }
    
    private var emptyStateContent: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: searchText.isEmpty ? "music.note.list" : "magnifyingglass")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(AppTheme.Colors.primary)
                    .scaleEffect(showingLoadingAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: showingLoadingAnimation)
            }
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "尚無錄音記錄" : "找不到相關錄音")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(searchText.isEmpty ? 
                     "上傳您的第一個錄音文件開始使用" : 
                     "請嘗試其他搜尋關鍵字")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if searchText.isEmpty {
                NavigationLink("立即上傳錄音") {
                    HomeView()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .scaleEffect(showingLoadingAnimation ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: showingLoadingAnimation)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .onAppear {
            showingLoadingAnimation = true
        }
    }
    
    private var statisticsContent: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("\(recordingManager.recordings.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("總錄音數")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(AppTheme.Colors.primary.opacity(0.1))
            )
            
            VStack(spacing: 8) {
                Text(totalDurationText)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.success)
                
                Text("總時長")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(AppTheme.Colors.success.opacity(0.1))
            )
            
            VStack(spacing: 8) {
                Text("\(filteredAndSortedRecordings.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.secondary)
                
                Text("篩選結果")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(AppTheme.Colors.secondary.opacity(0.1))
            )
        }
    }
    
    private var totalDurationText: String {
        let total = recordingManager.recordings.reduce(0.0) { $0 + ($1.duration ?? 0.0) }
        let hours = Int(total) / 3600
        let minutes = Int(total) % 3600 / 60
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var filteredAndSortedRecordings: [Recording] {
        // 如果數據沒有變化，返回緩存結果
        if searchText == lastSearchText && 
           sortOption == lastSortOption && 
           !cachedFilteredRecordings.isEmpty &&
           cachedFilteredRecordings.count <= recordingManager.recordings.count {
            return cachedFilteredRecordings
        }
        
        // 更新緩存標記
        DispatchQueue.main.async {
            self.lastSearchText = searchText
            self.lastSortOption = sortOption
        }
        
        let filtered = searchText.isEmpty ? 
            recordingManager.recordings : 
            recordingManager.recordings.filter { recording in
                recording.title.localizedCaseInsensitiveContains(searchText) ||
                recording.originalFilename.localizedCaseInsensitiveContains(searchText) ||
                (recording.transcription?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        
        let sorted = filtered.sorted { first, second in
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
        
        // 更新緩存
        DispatchQueue.main.async {
            self.cachedFilteredRecordings = sorted
        }
        
        return sorted
    }
    
    /// 刷新數據
    private func refreshData() async {
        // 清除緩存
        cachedFilteredRecordings = []
        
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