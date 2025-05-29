import Foundation
import AVFoundation
import Combine

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentSegmentId: Int?
    
    private var audioPlayer: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var isCleanedUp = false
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // 手動清理方法，應在視圖消失時調用
    func cleanup() {
        guard !isCleanedUp else { return }
        isCleanedUp = true
        
        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        audioPlayer = nil
        cancellables.removeAll()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func loadAudio(from url: URL) async {
        isLoading = true
        error = nil
        
        // 創建 AVPlayerItem
        let playerItem = AVPlayerItem(url: url)
        
        // 創建播放器
        audioPlayer = AVPlayer(playerItem: playerItem)
        
        // 觀察播放狀態
        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                Task { @MainActor in
                    if status == .readyToPlay {
                        self?.duration = playerItem.duration.seconds
                        self?.isLoading = false
                    } else if status == .failed {
                        self?.error = playerItem.error?.localizedDescription ?? "載入失敗"
                        self?.isLoading = false
                    }
                }
            }
            .store(in: &cancellables)
        
        // 添加時間觀察器
        addTimeObserver()
        
        // 觀察播放結束
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handlePlaybackEnded()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadAudioFromData(_ data: Data) async {
        isLoading = true
        error = nil
        
        do {
            // 創建臨時文件
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
            try data.write(to: tempURL)
            
            print("🎵 創建臨時音頻文件: \(tempURL.lastPathComponent), 大小: \(data.count) bytes")
            
            // 創建 AVPlayerItem
            let playerItem = AVPlayerItem(url: tempURL)
            
            // 創建播放器
            audioPlayer = AVPlayer(playerItem: playerItem)
            
            // 等待播放器準備就緒
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                var observer: NSKeyValueObservation?
                observer = playerItem.observe(\.status, options: [.new]) { [weak self] item, change in
                    Task { @MainActor in
                        switch item.status {
                        case .readyToPlay:
                            let durationSeconds = item.duration.seconds
                            if durationSeconds.isFinite && durationSeconds > 0 {
                                self?.duration = durationSeconds
                                print("🎵 音頻載入成功，時長: \(durationSeconds) 秒")
                            } else {
                                print("⚠️ 音頻時長無效: \(durationSeconds)")
                                self?.error = "音頻文件可能已損壞"
                            }
                            self?.isLoading = false
                            observer?.invalidate()
                            continuation.resume()
                            
                        case .failed:
                            let errorMsg = item.error?.localizedDescription ?? "載入失敗"
                            print("❌ 音頻載入失敗: \(errorMsg)")
                            self?.error = errorMsg
                            self?.isLoading = false
                            observer?.invalidate()
                            continuation.resume()
                            
                        default:
                            break
                        }
                    }
                }
            }
            
            // 添加時間觀察器
            addTimeObserver()
            
            // 觀察播放結束
            NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
                .sink { [weak self] _ in
                    Task { @MainActor in
                        self?.handlePlaybackEnded()
                    }
                }
                .store(in: &cancellables)
            
            // 延遲清理臨時文件（給播放器更多時間載入）
            DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
                try? FileManager.default.removeItem(at: tempURL)
                print("🧹 清理臨時音頻文件: \(tempURL.lastPathComponent)")
            }
            
        } catch {
            print("❌ 載入音頻數據失敗: \(error)")
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
                self?.updateCurrentSegment()
            }
        }
    }
    
    private func updateCurrentSegment() {
        // 這個方法會在 RecordingDetailView 中被覆寫
    }
    
    func play() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        audioPlayer?.seek(to: cmTime) { [weak self] completed in
            if completed {
                Task { @MainActor in
                    self?.currentTime = time
                }
            }
        }
    }
    
    func seekToSegment(_ segment: SRTSegment) {
        // 精確定位到段落開始時間
        let targetTime = segment.startTime + 0.1 // 稍微往後一點以確保在段落內
        seek(to: targetTime)
        
        // 如果未播放，自動開始播放
        if !isPlaying {
            play()
        }
    }
    
    private func handlePlaybackEnded() {
        isPlaying = false
        currentTime = 0
        audioPlayer?.seek(to: .zero)
    }
    
    func stop() {
        audioPlayer?.pause()
        audioPlayer?.seek(to: .zero)
        isPlaying = false
        currentTime = 0
    }
    
    // 格式化時間顯示
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedCurrentTime: String {
        formatTime(currentTime)
    }
    
    var formattedDuration: String {
        formatTime(duration)
    }
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
}