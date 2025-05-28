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
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        // 確保重定向時保留原始請求的所有標頭（包括授權標頭）
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpShouldUsePipelining = true
        // 重要：這將確保授權標頭在重定向時被保留
        config.httpMaximumConnectionsPerHost = 10
        
        return URLSession(configuration: config)
    }()
    
    @Published var isConnected = false
    
    private init() {
        Task {
            await checkConnection()
        }
    }
    
    // MARK: - Token Management
    private func getAuthToken() -> String? {
        // 先嘗試從 keychain 或 UserDefaults 獲取令牌
        if let token = UserDefaults.standard.string(forKey: "auth_token") {
            return token
        }
        
        // 如果未找到，嘗試從保存的用戶對象中獲取
        if let userData = UserDefaults.standard.data(forKey: "savedUser") {
            do {
                let user = try JSONDecoder().decode(User.self, from: userData)
                if let token = user.accessToken {
                    // 找到令牌後，更新到標準位置
                    UserDefaults.standard.set(token, forKey: "auth_token")
                    return token
                }
            } catch {
                print("⚠️ 無法解析保存的用戶數據: \(error.localizedDescription)")
            }
        }
        
        print("⚠️ 無法獲取授權令牌")
        return nil
    }
    
    private func saveAuthToken(_ token: String) {
        print("💾 保存授權令牌: Bearer \(String(token.prefix(10)))...")
        UserDefaults.standard.set(token, forKey: "auth_token")
        UserDefaults.standard.synchronize()
    }
    
    private func clearAuthToken() {
        print("🗑️ 清除授權令牌")
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "refresh_token")
        UserDefaults.standard.synchronize()
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
        
        // 添加授權標頭
        if requiresAuth {
            if let token = getAuthToken() {
                let authHeader = "Bearer \(token)"
                request.setValue(authHeader, forHTTPHeaderField: "Authorization")
                print("🔑 添加授權標頭: Bearer \(String(token.prefix(10)))...")
            } else {
                print("⚠️ 警告: 需要授權但找不到有效的令牌")
            }
        }
        
        // 設置URLRequest以跟隨重定向並保留授權標頭
        request.httpShouldHandleCookies = true
        
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
            print("⚠️ 無效的URL: \(baseURL)\(endpoint)")
            throw NetworkError.invalidURL
        }
        
        print("📡 發送請求: \(method.rawValue) \(request.url?.absoluteString ?? "unknown")")
        if requiresAuth {
            print("🔐 請求包含授權標頭: \(request.value(forHTTPHeaderField: "Authorization") != nil ? "是" : "否")")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 無效的HTTP回應")
                throw NetworkError.invalidResponse
            }
            
            print("📊 API回應 [\(endpoint)]: \(httpResponse.statusCode)")
            
            // 如果是重定向，顯示重定向信息
            if (300...399).contains(httpResponse.statusCode) {
                if let location = httpResponse.value(forHTTPHeaderField: "Location") {
                    print("⚠️ 被重定向到: \(location)")
                }
            }
            
            // 調試: 打印接收到的 JSON 數據
            if let jsonString = String(data: data, encoding: .utf8) {
                let trimmedJSON = jsonString.count > 500 ? "\(jsonString.prefix(500))..." : jsonString
                print("📄 收到的JSON數據: \(trimmedJSON)")
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let decoder = JSONDecoder()
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    decoder.dateDecodingStrategy = .formatted(dateFormatter)
                    
                    return try decoder.decode(T.self, from: data)
                } catch {
                    print("❌ JSON解碼錯誤: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("🔍 嘗試解碼: \(jsonString)")
                    }
                    throw NetworkError.decodingError
                }
            case 401:
                print("🔒 未授權(401): 清除授權令牌")
                clearAuthToken()
                throw NetworkError.unauthorized
            case 403:
                print("🚫 拒絕訪問(403): 請確認用戶權限")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 錯誤詳情: \(jsonString)")
                }
                throw NetworkError.apiError("拒絕訪問，請確認您的帳號權限")
            case 400...499:
                do {
                    let errorResponse = try JSONDecoder().decode(APIErrorResponse.self, from: data)
                    print("⚠️ API錯誤: \(errorResponse.message ?? "未知錯誤")")
                    throw NetworkError.apiError(errorResponse.message ?? "客戶端錯誤")
                } catch {
                    print("⚠️ 客戶端錯誤(\(httpResponse.statusCode))")
                    throw NetworkError.clientError(httpResponse.statusCode)
                }
            case 500...599:
                print("⚠️ 伺服器錯誤(\(httpResponse.statusCode))")
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                print("⚠️ 未知錯誤狀態碼: \(httpResponse.statusCode)")
                throw NetworkError.unknownError
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            print("❌ 網路錯誤: \(error.localizedDescription)")
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
        
        // 修改用戶實例，添加令牌
        var mutableUser = response.user
        mutableUser.accessToken = response.accessToken
        mutableUser.refreshToken = response.refreshToken
        
        // 將完整用戶對象（包含令牌）保存到 UserDefaults
        if let userData = try? JSONEncoder().encode(mutableUser) {
            UserDefaults.standard.set(userData, forKey: "savedUser")
            UserDefaults.standard.synchronize()
            print("📝 保存用戶數據（包含令牌）到 UserDefaults")
        }
        
        return mutableUser
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
    /// 獲取錄音列表（完整信息，包含轉錄和摘要）
    func getRecordings() async throws -> [Recording] {
        print("🔍 開始從API獲取錄音列表...")
        // 確保端點包含尾部斜線，避免重定向
        print("🔗 API端點: \(baseURL)/recordings/")
        
        if let token = getAuthToken() {
            print("🔑 使用授權令牌: Bearer \(String(token.prefix(10)))...")
        } else {
            print("⚠️ 警告: 沒有授權令牌，API請求可能失敗")
        }
        
        let response: RecordingListResponse = try await performRequest(
            endpoint: "/recordings/", // 修正：添加尾部斜線
            requiresAuth: true,
            responseType: RecordingListResponse.self
        )
        
        print("📊 成功獲取 \(response.recordings.count) 個錄音記錄")
        
        // 轉換為前端 Recording 格式
        let recordings = response.recordings.map { recordingResponse in
            Recording(
                id: UUID(uuidString: recordingResponse.id) ?? UUID(),
                title: recordingResponse.title,
                originalFilename: recordingResponse.original_filename,
                format: recordingResponse.format,
                mimeType: recordingResponse.mime_type,
                duration: recordingResponse.duration,
                createdAt: ISO8601DateFormatter().date(from: recordingResponse.created_at) ?? Date(),
                transcription: recordingResponse.transcript,
                summary: recordingResponse.summary,
                fileURL: nil,
                fileSize: recordingResponse.file_size,
                status: recordingResponse.status
            )
        }
        
        return recordings
    }
    
    /// 獲取錄音摘要列表（輕量級，僅基本信息）
    func getRecordingsSummary() async throws -> [Recording] {
        guard let token = getAuthToken() else {
            throw NetworkError.unauthorized
        }
        
        guard let url = URL(string: "\(baseURL)/recordings/summary") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("📡 發送請求到: \(url)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            print("📡 響應狀態碼: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200...299:
                // 解析響應
                let jsonString = String(data: data, encoding: .utf8) ?? "無法解析響應數據"
                print("📡 響應數據: \(jsonString.prefix(500))...")
                
                let decoder = JSONDecoder()
                
                do {
                    // 解析為 RecordingSummaryList
                    let response = try decoder.decode(RecordingSummaryList.self, from: data)
                    print("✅ 成功解析錄音摘要列表: \(response.recordings.count) 個錄音")
                    
                    // 轉換為 Recording 對象（只包含基本信息）
                    let recordings = response.recordings.map { summary in
                        Recording(
                            id: UUID(uuidString: summary.id) ?? UUID(),
                            title: summary.title,
                            originalFilename: "", // 摘要API不包含文件詳情
                            format: "",
                            mimeType: "",
                            duration: summary.duration,
                            createdAt: ISO8601DateFormatter().date(from: summary.created_at) ?? Date(),
                            transcription: summary.has_transcript ? "可用" : nil,
                            summary: summary.has_summary ? "可用" : nil,
                            fileURL: nil,
                            fileSize: summary.file_size,
                            status: summary.status
                        )
                    }
                    
                    return recordings
                } catch {
                    print("❌ 解析錄音摘要列表失敗: \(error.localizedDescription)")
                    throw NetworkError.decodingError
                }
                
            case 401:
                throw NetworkError.unauthorized
            case 400...499:
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
    
    func uploadRecording(fileURL: URL, title: String, onProgress: @escaping @Sendable (Double) -> Void) async throws -> Recording {
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
        
        // 3. 建立請求 - 直接使用正確的最終URL，避免重定向
        // 根據後端日誌，最終URL不包含尾部斜線
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
        
        // 關鍵設置：禁止自動處理重定向
        request.httpShouldHandleCookies = true
        
        // 自定義標頭以增強調試能力
        request.setValue("iOS-App/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        
        // 明確告訴服務器保持連接開啟
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
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
                
                // 直接使用委託模式避免在task初始化前使用
                let delegate = UploadDelegate(authToken: getAuthToken())
                
                // 創建自定義配置，禁用重定向
                let sessionConfig = URLSessionConfiguration.default
                sessionConfig.httpShouldUsePipelining = true
                sessionConfig.httpMaximumConnectionsPerHost = 10
                sessionConfig.timeoutIntervalForRequest = 180.0 // 增加超時
                sessionConfig.httpShouldSetCookies = true
                sessionConfig.httpCookieAcceptPolicy = .always
                sessionConfig.waitsForConnectivity = true // 增加連接穩定性
                
                // 添加授權標頭
                if let token = getAuthToken() {
                    var headers = sessionConfig.httpAdditionalHeaders ?? [:]
                    headers["Authorization"] = "Bearer \(token)"
                    sessionConfig.httpAdditionalHeaders = headers
                }
                
                let uploadSession = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)
                
                // 使用委託創建上傳任務，委託將處理請求的回調
                let task = uploadSession.uploadTask(with: request, fromFile: tempFileURL)
                
                // 設置完成處理程序
                delegate.completionHandler = { (data: Data?, response: URLResponse?, error: Error?) in
                    // 釋放安全訪問
                    if didStartAccessing {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                    
                    // 無論結果如何，都刪除臨時文件
                    try? FileManager.default.removeItem(at: tempFileURL)
                    
                    if let error = error {
                        print("❌ 上傳錯誤: \(error.localizedDescription)")
                        
                        // 添加更詳細的錯誤信息
                        if let nsError = error as NSError? {
                            print("🔍 錯誤代碼: \(nsError.code), 域: \(nsError.domain)")
                            if let failingURL = nsError.userInfo[NSURLErrorFailingURLStringErrorKey] as? String {
                                print("🔗 失敗URL: \(failingURL)")
                            }
                        }
                        
                        continuation.resume(throwing: NetworkError.networkError(error.localizedDescription))
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        print("❌ 無效的回應")
                        continuation.resume(throwing: NetworkError.invalidResponse)
                        return
                    }
                    
                    print("📡 收到HTTP狀態碼: \(httpResponse.statusCode)")
                    
                    // 輸出所有響應頭
                    print("📝 響應頭:")
                    for (key, value) in httpResponse.allHeaderFields {
                        print("   \(key): \(value)")
                    }
                    
                    // 判斷如果是403錯誤
                    if httpResponse.statusCode == 403 {
                        print("🔒 收到403 Forbidden響應")
                        
                        // 檢查原始請求和當前請求的授權標頭
                        print("🔍 403錯誤詳細診斷:")
                        print("   原始請求URL: \(task.originalRequest?.url?.absoluteString ?? "未知")")
                        print("   當前請求URL: \(task.currentRequest?.url?.absoluteString ?? "未知")")
                        
                        // 檢查授權標頭
                        if let originalAuth = task.originalRequest?.value(forHTTPHeaderField: "Authorization") {
                            print("   原始請求授權標頭: \(originalAuth.prefix(15))...")
                        } else {
                            print("   ⚠️ 原始請求沒有授權標頭!")
                        }
                        
                        if let currentAuth = task.currentRequest?.value(forHTTPHeaderField: "Authorization") {
                            print("   當前請求授權標頭: \(currentAuth.prefix(15))...")
                        } else {
                            print("   ⚠️ 當前請求沒有授權標頭!")
                        }
                    }
                    
                    guard let data = data else {
                        print("❌ 沒有回應數據")
                        continuation.resume(throwing: NetworkError.invalidResponse)
                        return
                    }
                    
                    // 調試: 打印接收到的 JSON 數據
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📥 上傳回應 JSON: \(jsonString)")
                    }
                    
                    switch httpResponse.statusCode {
                        case 200...299:
                            // 嘗試解碼為 UploadResponse
                            do {
                                let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
                                print("✅ 上傳成功: \(uploadResponse.message), ID: \(uploadResponse.recording_id)")
                                
                                // 創建一個臨時的 Recording 對象
                                let tempRecording = Recording(
                                    id: UUID(uuidString: uploadResponse.recording_id) ?? UUID(),
                                    title: title,
                                    originalFilename: fileURL.lastPathComponent,
                                    format: fileURL.pathExtension.lowercased(),
                                    mimeType: self.mimeTypeForFileExtension(fileURL.pathExtension),
                                    duration: 0, // 暫時不知道確切時長
                                    createdAt: Date(),
                                    transcription: "處理中...",
                                    summary: "處理中...",
                                    fileURL: fileURL
                                )
                                continuation.resume(returning: tempRecording)
                            } catch {
                                // 如果無法解析為 UploadResponse，嘗試直接返回 Recording
                                print("❌ 無法解析為 UploadResponse: \(error.localizedDescription)")
                                do {
                                    let decoder = JSONDecoder()
                                    let recording = try decoder.decode(Recording.self, from: data)
                                    continuation.resume(returning: recording)
                                } catch {
                                    print("❌ 無法解析為 Recording: \(error.localizedDescription)")
                                    continuation.resume(throwing: NetworkError.decodingError)
                                }
                            }
                        case 401:
                            print("🔒 未授權(401): 令牌可能無效")
                            DispatchQueue.main.async {
                                self.clearAuthToken()
                            }
                            continuation.resume(throwing: NetworkError.unauthorized)
                        case 422:
                            // 特別處理不可處理內容錯誤
                            do {
                                let errorResponse = try JSONDecoder().decode(APIErrorResponse.self, from: data)
                                print("⚠️ 上傳格式錯誤(422): \(errorResponse.message ?? "未知錯誤")")
                                continuation.resume(throwing: NetworkError.apiError(errorResponse.message ?? "上傳文件格式錯誤"))
                            } catch {
                                print("⚠️ 上傳格式錯誤(422): 文件格式或內容不符合要求")
                                continuation.resume(throwing: NetworkError.apiError("文件格式或內容不符合要求"))
                            }
                        default:
                            print("❌ 伺服器錯誤(\(httpResponse.statusCode))")
                            continuation.resume(throwing: NetworkError.serverError(httpResponse.statusCode))
                        }
                }
                
                // 添加進度監控，直接使用 onProgress 而不是 ProgressHandlerRef
                // 使用弱引用避免循環引用
                let uploadProgressObserver = task.progress.observe(\.fractionCompleted) { progress, _ in
                    let progressValue = progress.fractionCompleted
                    
                    DispatchQueue.main.async {
                        print("📊 上傳進度: \(Int(progressValue * 100))%")
                        onProgress(progressValue)
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
        print("🗑️ 嘗試刪除錄音: \(id.uuidString)")
        let _: EmptyResponse = try await performRequest(
            endpoint: "/recordings/\(id.uuidString)/", // 添加尾部斜線
            method: .DELETE,
            requiresAuth: true,
            responseType: EmptyResponse.self
        )
        print("✅ 成功刪除錄音: \(id.uuidString)")
    }
    
    /// 獲取特定錄音的詳細信息（包含完整轉錄和摘要）
    func getRecordingDetail(id: String) async throws -> Recording {
        guard let token = getAuthToken() else {
            throw NetworkError.unauthorized
        }
        
        guard let url = URL(string: "\(baseURL)/recordings/\(id)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("📡 發送請求到: \(url)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            print("📡 響應狀態碼: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200...299:
                let jsonString = String(data: data, encoding: .utf8) ?? "無法解析響應數據"
                print("📡 響應數據: \(jsonString.prefix(500))...")
                
                let decoder = JSONDecoder()
                
                do {
                    // 解析為 RecordingResponse（後端格式）
                    let response = try decoder.decode(RecordingResponse.self, from: data)
                    print("✅ 成功解析錄音詳情: \(response.title)")
                    
                    // 轉換為前端的 Recording 格式
                    let recording = Recording(
                        id: UUID(uuidString: response.id) ?? UUID(),
                        title: response.title,
                        originalFilename: response.original_filename,
                        format: response.format,
                        mimeType: response.mime_type,
                        duration: response.duration,
                        createdAt: ISO8601DateFormatter().date(from: response.created_at) ?? Date(),
                        transcription: response.transcript,
                        summary: response.summary,
                        fileURL: nil,
                        fileSize: response.file_size,
                        status: response.status
                    )
                    
                    return recording
                } catch {
                    print("❌ 解析錄音詳情失敗: \(error.localizedDescription)")
                    throw NetworkError.decodingError
                }
                
            case 401:
                throw NetworkError.unauthorized
            case 404:
                throw NetworkError.apiError("錄音不存在")
            case 400...499:
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

struct RecordingListResponse: Codable {
    let recordings: [RecordingResponse]
    let total: Int
    let page: Int
    let per_page: Int
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

// 添加錄音摘要響應模型
struct RecordingSummary: Codable {
    let id: String
    let title: String
    let duration: TimeInterval?
    let file_size: Int
    let status: String
    let created_at: String
    let has_transcript: Bool
    let has_summary: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case duration
        case file_size
        case status
        case created_at
        case has_transcript
        case has_summary
    }
}

struct RecordingSummaryList: Codable {
    let recordings: [RecordingSummary]
    let total: Int
    let page: Int
    let per_page: Int
}

// 添加後端錄音詳情響應模型
struct RecordingResponse: Codable {
    let id: String
    let title: String
    let original_filename: String
    let format: String
    let mime_type: String
    let duration: TimeInterval?
    let file_size: Int
    let status: String
    let created_at: String
    let transcript: String?
    let summary: String?
}

// MARK: - Upload Delegate
class UploadDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate, @unchecked Sendable {
    let authToken: String?
    
    init(authToken: String?) {
        self.authToken = authToken
        super.init()
    }
    
    var completionHandler: ((Data?, URLResponse?, Error?) -> Void)?
    private var receivedData: Data?
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        print("🔄 正在處理重定向: \(response.statusCode) -> \(request.url?.absoluteString ?? "unknown")")
        
        // 創建新請求，複製原始請求的所有標頭
        var newReq = request
        
        // 複製原始請求的標頭
        if let originalRequest = task.originalRequest {
            for (headerField, headerValue) in originalRequest.allHTTPHeaderFields ?? [:] {
                newReq.setValue(headerValue, forHTTPHeaderField: headerField)
            }
        }
        
        // 確保授權標頭存在
        if let token = self.authToken, newReq.value(forHTTPHeaderField: "Authorization") == nil {
            newReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔑 重定向後重新添加授權標頭")
        }
        
        print("📋 重定向後的請求標頭:")
        for (key, value) in newReq.allHTTPHeaderFields ?? [:] {
            print("   \(key): \(String(value.prefix(key == "Authorization" ? 15 : 30)))...")
        }
        
        completionHandler(newReq)
    }
    
    // 處理數據任務收到響應
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        print("📥 收到響應: \(response)")
        receivedData = Data()
        completionHandler(.allow)
    }
    
    // 處理接收到的數據
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData?.append(data)
    }
    
    // 處理任務完成
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("🏁 任務完成")
        completionHandler?(receivedData, task.response, error)
    }
} 