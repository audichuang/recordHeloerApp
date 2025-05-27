import Foundation
import ObjectiveC

// MARK: - API Response Models
struct APIResponse<T: Codable>: Codable {
    let data: T?
    let message: String?
    let statusCode: Int?
}

struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case user
    }
}

struct RegisterRequest: Codable {
    let username: String
    let email: String
    let password: String
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

// MARK: - Network Service
@MainActor
class NetworkService: ObservableObject {
    static let shared = NetworkService()
    
    #if DEBUG
    // 開發環境使用 Tailscale 網絡的主機名
    private let baseURL = "http://audimacbookpro:9527/api"
    #else
    // 生產環境應該使用實際的服務器地址
    private let baseURL = "https://api.recordhelper.com/api"
    #endif
    
    private let session = URLSession.shared
    
    @Published var isConnected = false
    
    private init() {
        Task {
            await checkConnection()
        }
    }
    
    // MARK: - Token Management
    private func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: "auth_token")
    }
    
    private func saveAuthToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "auth_token")
    }
    
    private func clearAuthToken() {
        UserDefaults.standard.removeObject(forKey: "auth_token")
    }
    
    // MARK: - Request Building
    private func buildRequest(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        requiresAuth: Bool = false
    ) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth, let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    // MARK: - Generic API Call
    private func performRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        requiresAuth: Bool = false,
        responseType: T.Type
    ) async throws -> T {
        guard let request = buildRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            requiresAuth: requiresAuth
        ) else {
            throw NetworkError.invalidURL
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            print("API Response [\(endpoint)]: \(httpResponse.statusCode)")
            
            // 調試: 打印接收到的 JSON 數據
            if let jsonString = String(data: data, encoding: .utf8) {
                print("收到的 JSON 數據: \(jsonString)")
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    print("JSON 解碼錯誤: \(error)")
                    throw NetworkError.decodingError
                }
            case 401:
                clearAuthToken()
                throw NetworkError.unauthorized
            case 400...499:
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    throw NetworkError.apiError(errorResponse.message ?? "客戶端錯誤")
                }
                throw NetworkError.clientError(httpResponse.statusCode)
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknownError
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Connection Check
    func checkConnection() async {
        do {
            let _: SystemStatusResponse = try await performRequest(
                endpoint: "/system/status",
                responseType: SystemStatusResponse.self
            )
            isConnected = true
        } catch {
            isConnected = false
            print("後端連線失敗: \(error)")
        }
    }
    
    // MARK: - Authentication APIs
    func register(username: String, email: String, password: String) async throws -> User {
        let request = RegisterRequest(username: username, email: email, password: password)
        let requestData = try JSONEncoder().encode(request)
        
        let response: LoginResponse = try await performRequest(
            endpoint: "/auth/register",
            method: .POST,
            body: requestData,
            responseType: LoginResponse.self
        )
        
        // 保存訪問令牌和刷新令牌
        saveAuthToken(response.accessToken)
        UserDefaults.standard.set(response.refreshToken, forKey: "refresh_token")
        
        // 記錄成功註冊
        print("註冊成功: 用戶名 = \(response.user.username)")
        
        return response.user
    }
    
    func login(email: String, password: String) async throws -> User {
        let request = LoginRequest(email: email, password: password)
        let requestData = try JSONEncoder().encode(request)
        
        let response: LoginResponse = try await performRequest(
            endpoint: "/auth/login",
            method: .POST,
            body: requestData,
            responseType: LoginResponse.self
        )
        
        // 保存訪問令牌和刷新令牌
        saveAuthToken(response.accessToken)
        UserDefaults.standard.set(response.refreshToken, forKey: "refresh_token")
        
        // 記錄成功登入
        print("登入成功: 用戶名 = \(response.user.username)")
        
        return response.user
    }
    
    func logout() async throws {
        let _: EmptyResponse = try await performRequest(
            endpoint: "/auth/logout",
            method: .POST,
            requiresAuth: true,
            responseType: EmptyResponse.self
        )
        
        clearAuthToken()
    }
    
    func getCurrentUser() async throws -> User {
        return try await performRequest(
            endpoint: "/auth/me",
            requiresAuth: true,
            responseType: User.self
        )
    }
    
    // MARK: - Recordings APIs
    func getRecordings() async throws -> [Recording] {
        let response: RecordingsResponse = try await performRequest(
            endpoint: "/recordings",
            requiresAuth: true,
            responseType: RecordingsResponse.self
        )
        return response.recordings
    }
    
    func uploadRecording(fileURL: URL, title: String, onProgress: @escaping (Double) -> Void) async throws -> Recording {
        // 1. 檢查文件是否存在
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("⚠️ 錯誤: 錄音文件不存在: \(fileURL.path)")
            throw NetworkError.apiError("錄音文件不存在")
        }
        
        // 2. 檢查文件大小
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let fileSize = attributes?[.size] as? NSNumber,
              fileSize.intValue > 0 && fileSize.intValue < 100 * 1024 * 1024 else { // 100MB限制
            print("⚠️ 錯誤: 文件大小無效或超過100MB限制")
            throw NetworkError.apiError("文件大小無效或超過100MB限制")
        }
        
        // 3. 建立請求
        guard let uploadURL = URL(string: "\(baseURL)/recordings/upload") else {
            print("⚠️ 錯誤: 無效的URL")
            throw NetworkError.invalidURL
        }
        
        print("📤 開始上傳音頻文件: \(fileURL.lastPathComponent), 大小: \(fileSize.intValue / 1024 / 1024)MB")
        print("📥 上傳至端點: \(uploadURL.absoluteString)")
        
        // 使用正確的方式處理 multipart/form-data
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔑 使用授權令牌: Bearer \(String(token.prefix(10)))...")
        } else {
            print("⚠️ 警告: 未提供授權令牌")
        }
        
        // 測試資源本地化
        let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
        if !didStartAccessing {
            print("⚠️ 無法訪問安全資源: \(fileURL)")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // 首先，創建臨時文件以存儲 multipart 數據
            let tempFileURL: URL
            do {
                tempFileURL = try FileManager.default.url(
                    for: .itemReplacementDirectory,
                    in: .userDomainMask,
                    appropriateFor: fileURL,
                    create: true
                ).appendingPathComponent("upload-\(UUID().uuidString)")
            } catch {
                print("⚠️ 無法創建臨時文件: \(error)")
                continuation.resume(throwing: NetworkError.networkError("無法創建臨時文件: \(error.localizedDescription)"))
                return
            }
            
            do {
                // 寫入標題部分
                guard let outputStream = OutputStream(url: tempFileURL, append: false) else {
                    throw NetworkError.networkError("無法創建輸出流")
                }
                
                outputStream.open()
                
                // 標題部分
                let titlePrefix = "--\(boundary)\r\nContent-Disposition: form-data; name=\"title\"\r\n\r\n"
                let titleSuffix = "\r\n"
                
                print("✍️ 寫入標題: \"\(title)\"")
                
                writeToStream(outputStream, data: titlePrefix.data(using: .utf8)!)
                writeToStream(outputStream, data: title.data(using: .utf8)!)
                writeToStream(outputStream, data: titleSuffix.data(using: .utf8)!)
                
                // 文件部分
                let filePrefix = "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\nContent-Type: \(mimeTypeForFileExtension(fileURL.pathExtension))\r\n\r\n"
                let fileSuffix = "\r\n"
                
                print("📋 添加文件頭部: \(fileURL.lastPathComponent), MIME類型: \(mimeTypeForFileExtension(fileURL.pathExtension))")
                
                writeToStream(outputStream, data: filePrefix.data(using: .utf8)!)
                
                // 分塊讀取文件，避免內存問題
                if let inputStream = InputStream(url: fileURL) {
                    inputStream.open()
                    
                    let bufferSize = 1024 * 1024 // 1MB 緩衝區
                    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                    defer { buffer.deallocate() }
                    
                    var totalBytesRead = 0
                    
                    while inputStream.hasBytesAvailable {
                        let bytesRead = inputStream.read(buffer, maxLength: bufferSize)
                        if bytesRead > 0 {
                            let bufferPointer = UnsafeBufferPointer(start: buffer, count: bytesRead)
                            let chunkData = Data(bufferPointer)
                            writeToStream(outputStream, data: chunkData)
                            
                            totalBytesRead += bytesRead
                            print("📊 已讀取: \(totalBytesRead / 1024)KB / \(fileSize.intValue / 1024)KB")
                        } else if bytesRead < 0 {
                            throw NetworkError.networkError("讀取文件錯誤")
                        } else {
                            break
                        }
                    }
                    
                    print("✅ 文件讀取完成: \(totalBytesRead) bytes")
                    inputStream.close()
                } else {
                    print("⚠️ 無法打開文件輸入流: \(fileURL.path)")
                }
                
                writeToStream(outputStream, data: fileSuffix.data(using: .utf8)!)
                
                // 結尾分隔符
                let endBoundary = "--\(boundary)--\r\n"
                writeToStream(outputStream, data: endBoundary.data(using: .utf8)!)
                
                outputStream.close()
                
                print("📤 開始發送請求...")
                
                // 現在使用文件形式上傳
                let task = session.uploadTask(with: request, fromFile: tempFileURL) { data, response, error in
                    // 釋放安全訪問
                    if didStartAccessing {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                    
                    // 無論結果如何，都刪除臨時文件
                    try? FileManager.default.removeItem(at: tempFileURL)
                    
                    if let error = error {
                        print("❌ 上傳錯誤: \(error.localizedDescription)")
                        continuation.resume(throwing: NetworkError.networkError(error.localizedDescription))
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        print("❌ 無效的回應")
                        continuation.resume(throwing: NetworkError.invalidResponse)
                        return
                    }
                    
                    print("📡 收到HTTP狀態碼: \(httpResponse.statusCode)")
                    
                    guard let data = data else {
                        print("❌ 沒有回應數據")
                        continuation.resume(throwing: NetworkError.invalidResponse)
                        return
                    }
                    
                    // 調試: 打印接收到的 JSON 數據
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📥 上傳回應 JSON: \(jsonString)")
                    }
                    
                    do {
                        switch httpResponse.statusCode {
                        case 200...299:
                            // 嘗試解碼為 UploadResponse
                            if let uploadResponse = try? JSONDecoder().decode(UploadResponse.self, from: data) {
                                print("✅ 上傳成功: \(uploadResponse.message), ID: \(uploadResponse.recording_id)")
                                
                                // 創建一個臨時的 Recording 對象
                                let tempRecording = Recording(
                                    id: UUID(uuidString: uploadResponse.recording_id) ?? UUID(),
                                    title: title,
                                    fileName: fileURL.lastPathComponent,
                                    duration: 0, // 暫時不知道確切時長
                                    createdAt: Date(),
                                    transcription: "處理中...",
                                    summary: "處理中...",
                                    fileURL: fileURL
                                )
                                continuation.resume(returning: tempRecording)
                            } else {
                                // 如果無法解析為 UploadResponse，也可能直接返回 Recording
                                let decoder = JSONDecoder()
                                let recording = try decoder.decode(Recording.self, from: data)
                                continuation.resume(returning: recording)
                            }
                        case 401:
                            print("🔒 未授權(401): 令牌可能無效")
                            DispatchQueue.main.async {
                                self.clearAuthToken()
                            }
                            continuation.resume(throwing: NetworkError.unauthorized)
                        case 422:
                            // 特別處理不可處理內容錯誤
                            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                                print("⚠️ 上傳格式錯誤(422): \(errorResponse.message ?? "未知錯誤")")
                                continuation.resume(throwing: NetworkError.apiError(errorResponse.message ?? "上傳文件格式錯誤"))
                            } else {
                                print("⚠️ 上傳格式錯誤(422): 文件格式或內容不符合要求")
                                continuation.resume(throwing: NetworkError.apiError("文件格式或內容不符合要求"))
                            }
                        default:
                            print("❌ 伺服器錯誤(\(httpResponse.statusCode))")
                            continuation.resume(throwing: NetworkError.serverError(httpResponse.statusCode))
                        }
                    } catch {
                        print("❌ JSON解碼錯誤: \(error)")
                        continuation.resume(throwing: NetworkError.decodingError)
                    }
                }
                
                // 添加進度監控
                let uploadProgressObserver = task.progress.observe(\.fractionCompleted) { progress, _ in
                    DispatchQueue.main.async {
                        print("📊 上傳進度: \(Int(progress.fractionCompleted * 100))%")
                        onProgress(progress.fractionCompleted)
                    }
                }
                
                // 保存觀察者以避免提前釋放
                objc_setAssociatedObject(task, UnsafeRawPointer(bitPattern: 1)!, uploadProgressObserver, .OBJC_ASSOCIATION_RETAIN)
                
                task.resume()
                print("🚀 上傳請求已開始執行")
                
            } catch {
                print("❌ 準備上傳時出錯: \(error)")
                try? FileManager.default.removeItem(at: tempFileURL)
                continuation.resume(throwing: error)
            }
        }
    }
    
    // 寫入數據到輸出流
    private func writeToStream(_ outputStream: OutputStream, data: Data) {
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Void in
            if let baseAddress = buffer.baseAddress {
                let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)
                outputStream.write(pointer, maxLength: data.count)
            }
        }
    }
    
    func deleteRecording(id: UUID) async throws {
        let _: EmptyResponse = try await performRequest(
            endpoint: "/recordings/\(id.uuidString)",
            method: .DELETE,
            requiresAuth: true,
            responseType: EmptyResponse.self
        )
    }
    
    // MARK: - Helper Methods
    // 根據檔案擴展名獲取MIME類型
    private func mimeTypeForFileExtension(_ fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "m4a":
            return "audio/m4a"
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "aac":
            return "audio/aac"
        case "flac":
            return "audio/flac"
        case "mp4":
            return "audio/mp4"
        case "ogg":
            return "audio/ogg"
        default:
            return "audio/octet-stream"  // 通用音頻類型
        }
    }
}

// MARK: - Supporting Types
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case clientError(Int)
    case serverError(Int)
    case networkError(String)
    case decodingError
    case apiError(String)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無效的URL"
        case .invalidResponse:
            return "無效的回應"
        case .unauthorized:
            return "未授權，請重新登入"
        case .clientError(let code):
            return "客戶端錯誤 (\(code))"
        case .serverError(let code):
            return "伺服器錯誤 (\(code))"
        case .networkError(let message):
            return "網路錯誤: \(message)"
        case .decodingError:
            return "數據解析錯誤"
        case .apiError(let message):
            return message
        case .unknownError:
            return "未知錯誤"
        }
    }
}

// MARK: - Response Models
struct EmptyResponse: Codable {}

struct APIErrorResponse: Codable {
    let message: String?
    let statusCode: Int?
    
    enum CodingKeys: String, CodingKey {
        case message
        case statusCode = "status_code"
    }
}

struct SystemStatusResponse: Codable {
    let status: String
    let version: String
}

struct RecordingsResponse: Codable {
    let recordings: [Recording]
}

// 添加上傳響應模型
struct UploadResponse: Codable {
    let message: String
    let recording_id: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case message
        case recording_id
        case status
    }
} 