import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @State private var searchText = ""
    @State private var sortOption: SortOption = .dateDescending
    
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
                
                // 錄音列表
                recordingsList
            }
            .navigationTitle("歷史紀錄")
            .refreshable {
                await recordingManager.loadRecordings()
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
                
                Text("\(filteredAndSortedRecordings.count) 個錄音")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white)
    }
    
    private var recordingsList: some View {
        Group {
            if recordingManager.isLoading {
                ProgressView("載入中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredAndSortedRecordings.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredAndSortedRecordings) { recording in
                            NavigationLink(destination: RecordingDetailView(recording: recording)) {
                                RecordingRowView(recording: recording)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "music.note.list" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(searchText.isEmpty ? "尚無錄音記錄" : "找不到相關錄音")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(searchText.isEmpty ? 
                 "上傳您的第一個錄音文件開始使用" : 
                 "請嘗試其他搜尋關鍵字")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if searchText.isEmpty {
                NavigationLink("開始上傳") {
                    HomeView()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var filteredAndSortedRecordings: [Recording] {
        let filtered = searchText.isEmpty ? 
            recordingManager.recordings : 
            recordingManager.recordings.filter { recording in
                recording.title.localizedCaseInsensitiveContains(searchText) ||
                recording.fileName.localizedCaseInsensitiveContains(searchText) ||
                recording.transcription.localizedCaseInsensitiveContains(searchText)
            }
        
        return filtered.sorted { first, second in
            switch sortOption {
            case .dateDescending:
                return first.createdAt > second.createdAt
            case .dateAscending:
                return first.createdAt < second.createdAt
            case .titleAscending:
                return first.title < second.title
            case .durationDescending:
                return first.duration > second.duration
            }
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(RecordingManager())
} 