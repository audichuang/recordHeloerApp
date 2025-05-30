import Foundation
import SwiftUI
import AVFoundation

// Swift 6.0 升級：使用 @MainActor 確保UI更新安全
@MainActor
class RecordingManager: ObservableObject {
    @Published var recordings: [Recording] = []
    @Published var recordingSummaries: [RecordingSummary] = []
    @Published var isLoading = false
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading = false
    @Published var error: String?
    
    private let networkService = NetworkService.shared
    
    // Swift 6.0 升級：使用 actor 來處理數據存儲
    private let dataStore = RecordingDataStore()
    
    // 通知相關
    private var notificationObserver: NSObjectProtocol?
    
    // 設定通知觀察者
    func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("RecordingProcessingCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let recordingId = notification.userInfo?["recordingId"] as? String,
                  let status = notification.userInfo?["status"] as? String else {
                return
            }
            
            Task { @MainActor in
                await self?.updateRecordingStatus(recordingId: recordingId, status: status)
            }
        }
    }
    
    init() {
        recordings = []
        recordingSummaries = []
        setupNotificationObserver()
        Task {
            // 初始化時加載最近的錄音摘要
            await loadRecentRecordingSummaries(limit: 10)
        }
    }
    
    deinit {
        // 通知觀察者會在 ARC 清理時自動移除
    }
    
    /// 更新錄音狀態（由推送通知觸發）
    func updateRecordingStatus(recordingId: String, status: String) async {
        guard let uuid = UUID(uuidString: recordingId) else { 
            print("❌ 無效的錄音 ID: \(recordingId)")
            return 
        }
        
        print("📱 更新錄音狀態: ID=\(recordingId), 新狀態=\(status)")
        
        // 更新本地列表中的狀態
        if let index = recordings.firstIndex(where: { $0.id == uuid }) {
            // 創建新的錄音對象以確保觸發 SwiftUI 更新
            var updatedRecording = recordings[index]
            updatedRecording.status = status
            recordings[index] = updatedRecording
            print("✅ 已更新 recordings 列表中的狀態")
            
            // 根據不同狀態更新其他屬性
            switch status.lowercased() {
            case "transcribed":
                // 逐字稿完成，重新加載以獲取逐字稿內容
                do {
                    let detailedRecording = try await networkService.getRecording(id: uuid)
                    recordings[index] = detailedRecording
                    print("✅ 已加載逐字稿內容")
                    // 確保通知 UI 更新
                    await MainActor.run {
                        self.objectWillChange.send()
                    }
                } catch {
                    print("❌ 無法加載錄音詳情: \(error)")
                }
                
            case "completed":
                // 全部完成，重新加載詳細信息
                do {
                    let detailedRecording = try await networkService.getRecording(id: uuid)
                    recordings[index] = detailedRecording
                    print("✅ 已加載完整錄音詳情")
                    // 確保通知 UI 更新
                    await MainActor.run {
                        self.objectWillChange.send()
                    }
                } catch {
                    print("❌ 無法加載錄音詳情: \(error)")
                }
                
            default:
                // 其他狀態也發送更新通知
                await MainActor.run {
                    self.objectWillChange.send()
                }
                break
            }
        } else {
            print("⚠️ 在 recordings 列表中找不到錄音 ID: \(recordingId)")
        }
        
        // 也更新摘要列表
        if let index = recordingSummaries.firstIndex(where: { $0.id == uuid }) {
            var summary = recordingSummaries[index]
            summary.status = status
            
            // 根據狀態更新標誌
            switch status.lowercased() {
            case "transcribed":
                summary.hasTranscript = true
                summary.hasSummary = false
            case "completed":
                summary.hasTranscript = true
                summary.hasSummary = true
            default:
                break
            }
            
            recordingSummaries[index] = summary
            print("✅ 已更新 recordingSummaries 列表中的狀態")
        } else {
            print("⚠️ 在 recordingSummaries 列表中找不到錄音 ID: \(recordingId)")
        }
        
        // 通知 UI 更新
        objectWillChange.send()
    }
    
    
    
    func uploadRecording(fileURL: URL, title: String, promptTemplateId: Int? = nil) async -> Recording? {
        isUploading = true
        uploadProgress = 0.0
        error = nil
        
        // 如果是從 iCloud 或外部存儲獲取的文件，可能需要先下載
        let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
        if !didStartAccessing {
            print("⚠️ 警告：無法訪問安全資源，可能影響上傳")
        }
        
        defer {
            if didStartAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            // 檢查文件大小
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                  let fileSize = attributes[.size] as? NSNumber,
                  fileSize.intValue > 0 else {
                error = "無法獲取文件大小或文件為空"
                isUploading = false
                return nil
            }
            
            // 檢查文件格式
            let validExtensions = ["mp3", "wav", "m4a", "aac", "flac", "mp4", "ogg"]
            guard validExtensions.contains(fileURL.pathExtension.lowercased()) else {
                error = "不支援的音頻格式: \(fileURL.pathExtension)"
                isUploading = false
                return nil
            }
            
            print("📤 準備上傳文件: \(fileURL.lastPathComponent), 大小: \(fileSize.intValue / 1024 / 1024)MB")
            
            // 調用真實API上傳
            let uploadedRecording = try await networkService.uploadRecording(
                fileURL: fileURL,
                title: title,
                promptTemplateId: promptTemplateId,
                onProgress: { progress in
                    // 在主線程更新進度
                    DispatchQueue.main.async {
                        self.uploadProgress = progress
                    }
                }
            )
            
            // 使用後端返回的狀態
            var newRecording = uploadedRecording
            // 後端返回 processing，我們可以將其視為 transcribing 的開始
            if newRecording.status == "processing" {
                newRecording.status = "transcribing"
            } else if newRecording.status == nil {
                newRecording.status = "uploading"
            }
            
            print("✅ 上傳成功，錄音狀態: \(newRecording.status ?? "unknown")")
            
            // 立即添加到列表
            recordings.insert(newRecording, at: 0)
            
            print("✅ 已添加到本地列表")
            
            await dataStore.saveRecording(newRecording)
            
            // 不再需要輪詢，等待推送通知
            
            isUploading = false
            uploadProgress = 0.0
            
            return newRecording
        
        } catch let error as NetworkError {
            switch error {
            case .unauthorized:
                self.error = "驗證失敗，請重新登入"
            case .apiError(let message):
                self.error = "上傳失敗：\(message)"
            case .networkError(let message):
                self.error = "網絡錯誤：\(message)"
            case .serverError(let code):
                self.error = "伺服器錯誤 (\(code))"
            default:
                self.error = "上傳失敗：\(error.localizedDescription)"
            }
            isUploading = false
            uploadProgress = 0.0
            return nil
        } catch {
            self.error = "上傳失敗：\(error.localizedDescription)"
            isUploading = false
            uploadProgress = 0.0
            return nil
        }
    }
    
    /// 載入最近的錄音摘要（專為HomeView設計）
    func loadRecentRecordingSummaries(limit: Int = 5) async {
        print("🏠 開始加載最近 \(limit) 個錄音摘要...")
        
        do {
            let summaries = try await networkService.getRecentRecordings(limit: limit)
            print("✅ 成功加載了 \(summaries.count) 個最近錄音摘要")
            
            recordingSummaries = summaries
            
            // 如果recordings數組為空或者較少，也生成對應的Recording對象
            if recordings.isEmpty || recordings.count <= limit {
                recordings = summaries.map { $0.toRecording() }
                    .sorted { $0.createdAt > $1.createdAt }
            }
            
        } catch {
            print("❌ 載入最近錄音摘要失敗: \(error)")
            self.error = "載入錄音列表失敗: \(error.localizedDescription)"
        }
    }
    
    /// 載入最近的錄音（專為HomeView設計，向後兼容）
    func loadRecentRecordings(limit: Int = 5) async {
        await loadRecentRecordingSummaries(limit: limit)
    }
    
    /// 載入錄音摘要列表（輕量級）
    func loadRecordingsSummary() async {
        print("📚 開始加載錄音摘要列表...")
        isLoading = true
        error = nil
        
        do {
            let summaries = try await networkService.getRecordingsSummary()
            print("✅ 成功加載了 \(summaries.count) 個錄音摘要")
            
            recordingSummaries = summaries
            
            // 同時更新recordings數組以保持兼容性
            recordings = summaries.map { $0.toRecording() }
            
            // 確保排序（最新的在前）
            recordingSummaries.sort { $0.createdAt > $1.createdAt }
            recordings.sort { $0.createdAt > $1.createdAt }
            
            print("📊 錄音列表已排序，最新錄音: \(recordings.first?.title ?? "無"), 創建時間: \(recordings.first?.createdAt ?? Date())")
            
        } catch {
            print("❌ 載入錄音摘要列表失敗: \(error)")
            self.error = "載入錄音列表失敗: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func loadRecordings() async {
        print("🔄 開始加載錄音列表...")
        isLoading = true
        error = nil
        
        do {
            // 載入完整的錄音列表（包含逐字稿和摘要）
            print("📡 嘗試從網路加載完整錄音列表...")
            let networkRecordings = try await networkService.getRecordings()
            print("✅ 從網路成功加載了 \(networkRecordings.count) 個錄音記錄（含完整內容）")
            
            // 更新UI
            self.recordings = networkRecordings
            
            // 更新本地存儲
            await dataStore.clearAllRecordings()
            for recording in networkRecordings {
                await dataStore.saveRecording(recording)
            }
            print("💾 已將網路數據保存到本地存儲")
            
            isLoading = false
        } catch let error as NetworkError {
            print("❌ 網路加載失敗: \(error.localizedDescription)")
            
            // 如果網路失敗，嘗試從本地存儲載入
            print("📂 嘗試從本地存儲加載錄音...")
            let savedRecordings = await dataStore.loadRecordings()
            
            if !savedRecordings.isEmpty {
                print("📋 從本地存儲加載了 \(savedRecordings.count) 個錄音")
                recordings = savedRecordings
                self.error = "無法連接伺服器，顯示本地快取資料。"
            } else {
                print("⚠️ 本地存儲中沒有錄音數據")
                self.error = "載入錄音失敗：\(error.localizedDescription)"
            }
            
            isLoading = false
        } catch {
            print("❌ 未知錯誤: \(error.localizedDescription)")
            self.error = "載入錄音失敗：\(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func deleteRecording(_ recording: Recording) async {
        do {
            // 從伺服器刪除
            try await networkService.deleteRecording(id: recording.id)
            
            // 從本地列表和存儲中刪除
            recordings.removeAll { $0.id == recording.id }
            await dataStore.deleteRecording(recording.id)
        } catch {
            self.error = "刪除失敗：\(error.localizedDescription)"
        }
    }
    
    func updateRecordingTitle(recordingId: UUID, newTitle: String) async -> Bool {
        // TODO: 實現伺服器端的更新標題 API
        // try await networkService.updateRecordingTitle(id: recordingId, title: newTitle)
        
        // 暫時只更新本地數據
        if let index = recordings.firstIndex(where: { $0.id == recordingId }) {
            recordings[index].title = newTitle
            await dataStore.saveRecording(recordings[index])
            return true
        }
        return false
    }
}

// Swift 6.0 新功能：使用 actor 確保數據安全
actor RecordingDataStore {
    private let recordingsKey = "savedRecordings"
    
    func saveRecording(_ recording: Recording) {
        var recordings = loadRecordings()
        
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
        } else {
            recordings.append(recording)
        }
        
        if let data = try? JSONEncoder().encode(recordings.sorted { $0.createdAt > $1.createdAt }) {
            UserDefaults.standard.set(data, forKey: recordingsKey)
        }
    }
    
    func loadRecordings() -> [Recording] {
        guard let data = UserDefaults.standard.data(forKey: recordingsKey),
              let recordings = try? JSONDecoder().decode([Recording].self, from: data) else {
            return []
        }
        return recordings.sorted { $0.createdAt > $1.createdAt }
    }
    
    func deleteRecording(_ recordingId: UUID) {
        var recordings = loadRecordings()
        recordings.removeAll { $0.id == recordingId }
        
        if let data = try? JSONEncoder().encode(recordings) {
            UserDefaults.standard.set(data, forKey: recordingsKey)
        }
    }
    
    func clearAllRecordings() {
        UserDefaults.standard.removeObject(forKey: recordingsKey)
    }
} 