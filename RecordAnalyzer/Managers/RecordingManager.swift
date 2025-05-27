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
    
    init() {
        Task {
            await loadRecordings()
        }
    }
    
    func uploadRecording(fileURL: URL, title: String) async -> Recording? {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        do {
            // 調用真實API上傳
            let newRecording = try await networkService.uploadRecording(
                fileURL: fileURL,
                title: title,
                onProgress: { progress in
                    // 在主線程更新進度
                    DispatchQueue.main.async {
                        self.uploadProgress = progress
                    }
                }
            )
            
            recordings.insert(newRecording, at: 0)
            await dataStore.saveRecording(newRecording)
            
            isUploading = false
            uploadProgress = 0.0
            
            return newRecording
        } catch {
            errorMessage = "上傳失敗：\(error.localizedDescription)"
            isUploading = false
            uploadProgress = 0.0
            return nil
        }
    }
    
    func loadRecordings() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 先嘗試從網路載入
            let networkRecordings = try await networkService.getRecordings()
            self.recordings = networkRecordings
            
            // 更新本地存儲
            await dataStore.clearAllRecordings()
            for recording in networkRecordings {
                await dataStore.saveRecording(recording)
            }
            
            isLoading = false
        } catch {
            // 如果網路失敗，嘗試從本地存儲載入
            print("從網路載入錄音失敗: \(error.localizedDescription)。嘗試從本地載入...")
            let savedRecordings = await dataStore.loadRecordings()
            if !savedRecordings.isEmpty {
                recordings = savedRecordings
                errorMessage = "無法連接伺服器，顯示本地快取資料。"
            } else {
                errorMessage = "載入錄音失敗：\(error.localizedDescription)"
            }
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