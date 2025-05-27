import Foundation
import SwiftUI
import AVFoundation

// Swift 6.0 升級：使用 @MainActor 確保UI更新安全
@MainActor
class RecordingManager: ObservableObject {
    @Published var recordings: [Recording] = []
    @Published var isLoading = false
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading = false
    @Published var errorMessage: String?
    
    private let networkService = NetworkService.shared
    
    // Swift 6.0 升級：使用 actor 來處理數據存儲
    private let dataStore = RecordingDataStore()
    
    // 定時刷新
    private var refreshTimer: Timer?
    private var shouldAutoRefresh = false
    
    init() {
        Task {
            await loadRecordings()
        }
        startAutoRefresh()
    }
    
    deinit {
        // Swift 6.0: 在 deinit 中不能直接訪問非 Sendable 屬性
        // 改為依賴 ARC 自動清理
    }
    
    /// 開始自動刷新 - 當有錄音正在處理時
    private func startAutoRefresh() {
        // 每30秒檢查一次是否有處理中的錄音
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndRefreshIfNeeded()
            }
        }
    }
    
    /// 停止自動刷新
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        shouldAutoRefresh = false
    }
    
    /// 檢查是否需要刷新（有處理中的錄音時）
    private func checkAndRefreshIfNeeded() async {
        print("🔍 檢查是否需要自動刷新...")
        print("📋 當前錄音數量: \(recordings.count)")
        
        // 檢查是否有處理中的錄音
        let processingRecordings = recordings.filter { recording in
            if let status = recording.status {
                let isProcessing = ["uploading", "processing"].contains(status.lowercased())
                if isProcessing {
                    print("📊 發現處理中的錄音: \(recording.title) - 狀態: \(status)")
                }
                return isProcessing
            }
            return false
        }
        
        print("⚙️ 處理中的錄音數量: \(processingRecordings.count)")
        
        if !processingRecordings.isEmpty {
            print("🔄 檢測到 \(processingRecordings.count) 個處理中的錄音，開始自動刷新...")
            await loadRecordingsSummary()
        } else {
            print("✅ 沒有處理中的錄音，跳過自動刷新")
        }
    }
    
    /// 上傳錄音後開始監控
    func startMonitoringForProcessing() {
        shouldAutoRefresh = true
    }
    
    /// 停止監控
    func stopMonitoringForProcessing() {
        shouldAutoRefresh = false
    }
    
    func uploadRecording(fileURL: URL, title: String) async -> Recording? {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
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
                errorMessage = "無法獲取文件大小或文件為空"
                isUploading = false
                return nil
            }
            
            // 檢查文件格式
            let validExtensions = ["mp3", "wav", "m4a", "aac", "flac", "mp4", "ogg"]
            guard validExtensions.contains(fileURL.pathExtension.lowercased()) else {
                errorMessage = "不支援的音頻格式: \(fileURL.pathExtension)"
                isUploading = false
                return nil
            }
            
            print("📤 準備上傳文件: \(fileURL.lastPathComponent), 大小: \(fileSize.intValue / 1024 / 1024)MB")
            
            // 調用真實API上傳
            let uploadedRecording = try await networkService.uploadRecording(
                fileURL: fileURL,
                title: title,
                onProgress: { progress in
                    // 在主線程更新進度
                    DispatchQueue.main.async {
                        self.uploadProgress = progress
                    }
                }
            )
            
            // 確保錄音狀態為處理中
            var newRecording = uploadedRecording
            if newRecording.status == nil || !["processing", "uploading"].contains(newRecording.status!.lowercased()) {
                newRecording.status = "processing"
            }
            
            print("✅ 上傳成功，錄音狀態: \(newRecording.status ?? "unknown")")
            
            recordings.insert(newRecording, at: 0)
            await dataStore.saveRecording(newRecording)
            
            // 開始監控處理狀態
            startMonitoringForProcessing()
            
            // 立即觸發一次狀態檢查
            Task {
                await self.checkAndRefreshIfNeeded()
            }
            
            isUploading = false
            uploadProgress = 0.0
            
            return newRecording
        
        } catch let error as NetworkError {
            switch error {
            case .unauthorized:
                errorMessage = "驗證失敗，請重新登入"
            case .apiError(let message):
                errorMessage = "上傳失敗：\(message)"
            case .networkError(let message):
                errorMessage = "網絡錯誤：\(message)"
            case .serverError(let code):
                errorMessage = "伺服器錯誤 (\(code))"
            default:
                errorMessage = "上傳失敗：\(error.localizedDescription)"
            }
            isUploading = false
            uploadProgress = 0.0
            return nil
        } catch {
            errorMessage = "上傳失敗：\(error.localizedDescription)"
            isUploading = false
            uploadProgress = 0.0
            return nil
        }
    }
    
    /// 載入錄音摘要列表（輕量級，用於定期刷新）
    func loadRecordingsSummary() async {
        print("🔄 開始加載錄音摘要列表...")
        // 不顯示載入狀態，避免頻繁的UI閃爍
        
        do {
            print("📡 嘗試從網路加載錄音摘要列表...")
            let summaryRecordings = try await networkService.getRecordingsSummary()
            print("✅ 從網路成功加載了 \(summaryRecordings.count) 個錄音摘要")
            
            // 更新現有錄音的狀態信息
            var updatedRecordings = recordings
            
            for summaryRecording in summaryRecordings {
                if let index = updatedRecordings.firstIndex(where: { $0.id == summaryRecording.id }) {
                    // 更新現有錄音的狀態信息
                    let existingRecording = updatedRecordings[index]
                    updatedRecordings[index] = Recording(
                        id: existingRecording.id,
                        title: summaryRecording.title,
                        fileName: existingRecording.fileName.isEmpty ? summaryRecording.fileName : existingRecording.fileName,
                        duration: summaryRecording.duration,
                        createdAt: existingRecording.createdAt,
                        transcription: existingRecording.transcription,
                        summary: existingRecording.summary,
                        fileURL: existingRecording.fileURL,
                        fileSize: summaryRecording.fileSize,
                        status: summaryRecording.status
                    )
                } else {
                    // 新錄音，添加到列表
                    updatedRecordings.insert(summaryRecording, at: 0)
                }
            }
            
            // 按創建時間排序
            updatedRecordings.sort { $0.createdAt > $1.createdAt }
            
            // 更新UI
            recordings = updatedRecordings
            
            // 檢查是否還有處理中的錄音
            let stillProcessing = recordings.contains { recording in
                if let status = recording.status {
                    return ["uploading", "processing"].contains(status.lowercased())
                }
                return false
            }
            
            if !stillProcessing {
                // 如果沒有處理中的錄音，停止監控並載入完整資料
                stopMonitoringForProcessing()
                print("📋 所有錄音處理完成，載入完整資料...")
                await loadRecordings()
            }
            
        } catch let error as NetworkError {
            print("❌ 網路加載摘要失敗: \(error.localizedDescription)")
        } catch {
            print("❌ 未知錯誤: \(error.localizedDescription)")
        }
    }
    
    func loadRecordings() async {
        print("🔄 開始加載錄音列表...")
        isLoading = true
        errorMessage = nil
        
        do {
            // 先嘗試從網路載入
            print("📡 嘗試從網路加載錄音列表...")
            let networkRecordings = try await networkService.getRecordings()
            print("✅ 從網路成功加載了 \(networkRecordings.count) 個錄音")
            
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
                errorMessage = "無法連接伺服器，顯示本地快取資料。"
            } else {
                print("⚠️ 本地存儲中沒有錄音數據")
                errorMessage = "載入錄音失敗：\(error.localizedDescription)"
            }
            
            isLoading = false
        } catch {
            print("❌ 未知錯誤: \(error.localizedDescription)")
            errorMessage = "載入錄音失敗：\(error.localizedDescription)"
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
            errorMessage = "刪除失敗：\(error.localizedDescription)"
        }
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