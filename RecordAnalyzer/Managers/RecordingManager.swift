import Foundation
import SwiftUI
import AVFoundation

class RecordingManager: ObservableObject {
    @Published var recordings: [Recording] = []
    @Published var isLoading = false
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading = false
    
    private let baseURL = "http://localhost:5000/api"
    
    init() {
        loadSampleData()
    }
    
    func uploadRecording(fileURL: URL, title: String) async -> Recording? {
        await MainActor.run {
            isUploading = true
            uploadProgress = 0.0
        }
        
        // 模擬上傳進度
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await MainActor.run {
                uploadProgress = Double(i) / 10.0
            }
        }
        
        // 模擬分析結果
        let mockTranscription = """
        這是一段測試錄音的逐字稿。在這段錄音中，用戶談論了今天的會議內容，包括項目進度的討論，下一階段的計劃安排，以及團隊成員的工作分配。整個會議持續了大約30分鐘，涵蓋了多個重要議題。
        """
        
        let mockSummary = """
        會議摘要：
        1. 項目進度順利，預計下週完成第一階段
        2. 下一階段計劃已確定，將於下月開始
        3. 團隊成員工作分配已明確
        4. 需要額外資源支持的部分已識別
        """
        
        let newRecording = Recording(
            title: title,
            fileName: fileURL.lastPathComponent,
            duration: 185.0, // 模擬3分5秒
            createdAt: Date(),
            transcription: mockTranscription,
            summary: mockSummary,
            fileURL: fileURL
        )
        
        await MainActor.run {
            self.recordings.insert(newRecording, at: 0)
            self.isUploading = false
            self.uploadProgress = 0.0
        }
        
        return newRecording
    }
    
    func loadRecordings() async {
        await MainActor.run {
            isLoading = true
        }
        
        // 模擬API調用
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            // 這裡會從伺服器載入真實數據
            self.isLoading = false
        }
    }
    
    func deleteRecording(_ recording: Recording) {
        recordings.removeAll { $0.id == recording.id }
    }
    
    private func loadSampleData() {
        let sampleRecordings = [
            Recording(
                title: "會議記錄 - 項目進度討論",
                fileName: "meeting_20241201.m4a",
                duration: 1245.0,
                createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                transcription: "今天的會議主要討論了項目的進度情況。我們已經完成了第一階段的開發工作，目前正在進行測試階段。預計下週可以完成所有測試工作，然後進入第二階段的開發。在討論過程中，我們也識別了一些潛在的風險和挑戰，需要在接下來的工作中特別注意。團隊成員都表示對目前的進度感到滿意，並且對後續的工作安排有清晰的了解。",
                summary: "會議摘要：討論項目進度，第一階段開發完成，正在測試中，預計下週完成測試並進入第二階段。識別了風險和挑戰，團隊對進度滿意。",
                fileURL: nil
            ),
            Recording(
                title: "客戶訪談記錄",
                fileName: "interview_20241130.m4a",
                duration: 2100.0,
                createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                transcription: "這次客戶訪談非常有收穫。客戶對我們的產品表示了極大的興趣，特別是對新功能的設計理念很認同。他們提出了一些建設性的建議，包括用戶界面的優化、功能流程的簡化等。客戶也分享了他們目前使用的解決方案的痛點，這為我們的產品改進提供了寶貴的參考。整體來說，這次訪談為我們後續的產品開發指明了方向。",
                summary: "客戶訪談摘要：客戶對產品興趣濃厚，認同設計理念，提出界面優化和流程簡化建議，分享了現有解決方案痛點，為產品開發提供方向。",
                fileURL: nil
            ),
            Recording(
                title: "學習筆記 - Swift 開發心得",
                fileName: "study_notes_20241129.m4a",
                duration: 890.0,
                createdAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                transcription: "今天學習了 SwiftUI 的一些高級用法，包括狀態管理、數據綁定和自定義視圖組件。特別是 @StateObject 和 @ObservedObject 的區別，以及何時使用 @EnvironmentObject。這些概念對於構建複雜的應用程序非常重要。我也實踐了一些動畫效果，發現 SwiftUI 的動畫系統非常強大且易於使用。明天計劃繼續學習網絡請求和數據持久化的相關內容。",
                summary: "學習筆記摘要：學習 SwiftUI 高級用法，包括狀態管理、數據綁定、自定義組件，理解了各種屬性包裝器的區別，實踐了動畫效果，計劃學習網絡和數據持久化。",
                fileURL: nil
            )
        ]
        
        recordings = sampleRecordings
    }
} 