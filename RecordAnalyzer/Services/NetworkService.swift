import Foundation
import ObjectiveC
import SwiftUI

// MARK: - Notification Names
extension Notification.Name {
    static let unauthorizedAccess = Notification.Name("unauthorizedAccess")
}

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
        config.httpMaximumConnectionsPerHost = 10
        config.waitsForConnectivity = true
        
        // 創建自定義委託來處理重定向
        let delegate = NetworkServiceDelegate()
        
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
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
    private func performRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        requiresAuth: Bool = false,
        responseType: T.Type
    ) async throws -> T {
        // 特殊處理：prompt-templates 端點需要尾部斜線
        let cleanEndpoint: String
        if endpoint.contains("prompt-templates") && !endpoint.hasSuffix("/") && !endpoint.contains("default") && !endpoint.contains("set-default") {
            cleanEndpoint = endpoint + "/"
        } else {
            // 其他端點：確保沒有尾部斜線（除非是根路徑）
            cleanEndpoint = endpoint.hasSuffix("/") && endpoint != "/" ? String(endpoint.dropLast()) : endpoint
        }
        
        guard let request = buildRequest(
            endpoint: cleanEndpoint,
            method: method,
            body: body,
            requiresAuth: requiresAuth
        ) else {
            print("⚠️ 無效的URL: \(baseURL)\(cleanEndpoint)")
            throw NetworkError.invalidURL
        }
        
        print("📡 發送請求: \(method.rawValue) \(request.url?.absoluteString ?? "unknown")")
        if requiresAuth {
            print("🔐 請求包含授權標頭: \(request.value(forHTTPHeaderField: "Authorization") != nil ? "是" : "否")")
            if let authHeader = request.value(forHTTPHeaderField: "Authorization") {
                print("🔑 授權標頭內容: \(String(authHeader.prefix(20)))...")
            }
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
                print("🔒 未授權(401): 清除授權令牌並通知登出")
                clearAuthToken()
                // 發送通知讓 AuthenticationManager 處理登出
                await MainActor.run {
                    NotificationCenter.default.post(name: .unauthorizedAccess, object: nil)
                }
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
    
    // Apple ID 登入
    func loginWithApple(
        userID: String,
        email: String?,
        fullName: String,
        identityToken: String,
        authorizationCode: String
    ) async throws -> User {
        struct AppleLoginRequest: Codable {
            let userID: String
            let email: String?
            let fullName: String
            let identityToken: String
            let authorizationCode: String
            
            enum CodingKeys: String, CodingKey {
                case userID = "user_id"
                case email
                case fullName = "full_name"
                case identityToken = "identity_token"
                case authorizationCode = "authorization_code"
            }
        }
        
        let request = AppleLoginRequest(
            userID: userID,
            email: email,
            fullName: fullName,
            identityToken: identityToken,
            authorizationCode: authorizationCode
        )
        
        let requestData = try JSONEncoder().encode(request)
        
        let response: LoginResponse = try await performRequest(
            endpoint: "/auth/apple",
            method: .POST,
            body: requestData,
            responseType: LoginResponse.self
        )
        
        // 保存訪問令牌和刷新令牌
        saveAuthToken(response.accessToken)
        UserDefaults.standard.set(response.refreshToken, forKey: "refresh_token")
        
        // 記錄成功登入
        print("Apple 登入成功: 用戶名 = \(response.user.username)")
        
        // 修改用戶實例，添加令牌
        var mutableUser = response.user
        mutableUser.accessToken = response.accessToken
        mutableUser.refreshToken = response.refreshToken
        
        // 將完整用戶對象（包含令牌）保存到 UserDefaults
        if let userData = try? JSONEncoder().encode(mutableUser) {
            UserDefaults.standard.set(userData, forKey: "savedUser")
            UserDefaults.standard.synchronize()
            print("📝 保存 Apple 登入用戶數據（包含令牌）到 UserDefaults")
        }
        
        return mutableUser
    }
    
    // 綁定 Apple ID
    func bindAppleID(
        userID: String,
        identityToken: String,
        authorizationCode: String,
        email: String?,
        fullName: PersonNameComponents?
    ) async -> Bool {
        struct AppleBindingRequest: Codable {
            let userID: String
            let identityToken: String
            let authorizationCode: String
            let email: String?
            let fullName: String?
            
            enum CodingKeys: String, CodingKey {
                case userID = "user_id"
                case identityToken = "identity_token"
                case authorizationCode = "authorization_code"
                case email
                case fullName = "full_name"
            }
        }
        
        let fullNameString = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .isEmpty ? nil : [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        
        let request = AppleBindingRequest(
            userID: userID,
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            email: email,
            fullName: fullNameString
        )
        
        do {
            let requestData = try JSONEncoder().encode(request)
            
            let _: EmptyResponse = try await performRequest(
                endpoint: "/users/bind-apple",
                method: .POST,
                body: requestData,
                requiresAuth: true,
                responseType: EmptyResponse.self
            )
            
            return true
        } catch {
            print("❌ 綁定 Apple ID 失敗: \(error)")
            return false
        }
    }
    
    // 解除綁定 Apple ID
    func unbindAppleID() async -> Bool {
        do {
            let _: EmptyResponse = try await performRequest(
                endpoint: "/users/unbind-apple",
                method: .DELETE,
                requiresAuth: true,
                responseType: EmptyResponse.self
            )
            
            return true
        } catch {
            print("❌ 解除綁定 Apple ID 失敗: \(error)")
            return false
        }
    }
    
    func getCurrentUser() async throws -> User {
        print("📡 正在獲取當前用戶信息...")
        let user = try await performRequest(
            endpoint: "/auth/me",
            requiresAuth: true,
            responseType: User.self
        )
        print("✅ 獲取用戶信息成功:")
        print("   - ID: \(user.id)")
        print("   - Username: \(user.username)")
        print("   - Email: \(user.email)")
        print("   - Apple ID: \(user.appleId ?? "nil")")
        print("   - Registration Type: \(user.registrationType ?? "nil")")
        return user
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
    
    /// 錄音摘要列表響應結構
    struct RecordingSummaryListResponse: Codable {
        let recordings: [RecordingSummary]
        let total: Int
        let page: Int
        let perPage: Int
        
        enum CodingKeys: String, CodingKey {
            case recordings, total, page
            case perPage = "per_page"
        }
    }
    
    /// 獲取錄音摘要列表（輕量級，僅基本信息）
    func getRecordingsSummary(page: Int = 1, perPage: Int = 20) async throws -> [RecordingSummary] {
        guard let token = getAuthToken() else {
            throw NetworkError.unauthorized
        }
        
        // 構建帶分頁參數的URL
        guard var urlComponents = URLComponents(string: "\(baseURL)/recordings/summary") else {
            throw NetworkError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw NetworkError.unauthorized
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        do {
            let recordingListResponse = try JSONDecoder().decode(RecordingSummaryListResponse.self, from: data)
            return recordingListResponse.recordings
        } catch {
            print("❌ 解析錄音摘要列表失敗: \(error)")
            throw NetworkError.decodingError
        }
    }
    
    /// 獲取最近的錄音摘要（專為HomeView設計）
    func getRecentRecordings(limit: Int = 5) async throws -> [RecordingSummary] {
        return try await getRecordingsSummary(page: 1, perPage: limit)
    }
    
    func uploadRecording(fileURL: URL, title: String, promptTemplateId: Int? = nil, onProgress: @escaping @Sendable (Double) -> Void) async throws -> Recording {
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
                
                // Prompt Template ID 部分（如果提供）
                if let templateId = promptTemplateId {
                    let templatePrefix = "--\(boundary)\r\nContent-Disposition: form-data; name=\"prompt_template_id\"\r\n\r\n"
                    let templateSuffix = "\r\n"
                    
                    print("📝 寫入模板ID: \(templateId)")
                    
                    writeToStream(outputStream, data: templatePrefix.data(using: .utf8)!)
                    writeToStream(outputStream, data: "\(templateId)".data(using: .utf8)!)
                    writeToStream(outputStream, data: templateSuffix.data(using: .utf8)!)
                }
                
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
            endpoint: "/recordings/\(id.uuidString)", // 移除尾部斜線
            method: .DELETE,
            requiresAuth: true,
            responseType: EmptyResponse.self
        )
        print("✅ 成功刪除錄音: \(id.uuidString)")
    }
    
    /// 獲取特定錄音（UUID版本）
    func getRecording(id: UUID) async throws -> Recording {
        return try await getRecordingDetail(id: id.uuidString)
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
                    
                    // 處理 timestamps_data
                    var timestampsData: TimestampsData? = nil
                    if let hasTimestamps = response.has_timestamps, hasTimestamps {
                        // 如果有時間戳，創建空的 TimestampsData
                        // 實際的時間戳資料會在前端解析 SRT 內容時產生
                        timestampsData = TimestampsData(words: nil, sentenceSegments: nil)
                    }
                    
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
                        status: response.status,
                        timelineTranscript: nil,
                        hasTimeline: false,
                        analysisMetadata: nil,
                        srtContent: response.srt_content,
                        hasTimestamps: response.has_timestamps ?? false,
                        timestampsData: timestampsData
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
    
    // MARK: - Analysis Regeneration APIs
    /// 重新生成逐字稿
    func regenerateTranscription(recordingId: String, provider: String? = nil) async throws -> RegenerateResponse {
        var requestBody: [String: Any] = [:]
        if let provider = provider {
            requestBody["provider"] = provider
        }
        
        let requestData = try JSONSerialization.data(withJSONObject: requestBody)
        
        return try await performRequest(
            endpoint: "/analysis/\(recordingId)/regenerate-transcription",
            method: .POST,
            body: requestData,
            requiresAuth: true,
            responseType: RegenerateResponse.self
        )
    }
    
    /// 重新生成摘要
    func regenerateSummary(recordingId: String, provider: String? = nil, promptTemplateId: Int? = nil) async throws -> RegenerateResponse {
        var requestBody: [String: Any] = [:]
        if let provider = provider {
            requestBody["provider"] = provider
        }
        if let templateId = promptTemplateId {
            requestBody["prompt_template_id"] = templateId
        }
        
        let requestData = try JSONSerialization.data(withJSONObject: requestBody)
        
        return try await performRequest(
            endpoint: "/analysis/\(recordingId)/regenerate-summary",
            method: .POST,
            body: requestData,
            requiresAuth: true,
            responseType: RegenerateResponse.self
        )
    }
    
    /// 獲取分析歷史記錄
    func getAnalysisHistory(recordingId: String, analysisType: AnalysisType? = nil) async throws -> [AnalysisHistory] {
        var endpoint = "/analysis/\(recordingId)/history"
        
        if let type = analysisType {
            // 轉換為後端 API 期望的小寫格式
            let typeValue = type == .transcription ? "transcription" : "summary"
            endpoint += "?analysis_type=\(typeValue)"
            print("📋 獲取歷史記錄 - 類型: \(typeValue), 端點: \(endpoint)")
        } else {
            print("📋 獲取所有歷史記錄（未指定類型）")
        }
        
        let histories: [AnalysisHistory] = try await performRequest(
            endpoint: endpoint,
            requiresAuth: true,
            responseType: [AnalysisHistory].self
        )
        
        print("📋 獲取到 \(histories.count) 個歷史記錄")
        for history in histories {
            print("   - 版本 \(history.version): \(history.analysisType.rawValue), 當前: \(history.isCurrent)")
        }
        
        return histories
    }
    
    /// 下載錄音音頻數據
    func downloadRecording(id: String) async throws -> Data {
        guard let token = getAuthToken() else {
            throw NetworkError.unauthorized
        }
        
        guard let url = URL(string: "\(baseURL)/recordings/\(id)/download") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("📡 開始下載錄音: \(id)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            print("📡 下載響應狀態碼: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200...299:
                print("✅ 成功下載錄音，大小: \(data.count / 1024)KB")
                return data
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
    
    /// 更新錄音標題
    func updateRecordingTitle(recordingId: String, newTitle: String) async throws {
        struct UpdateTitleRequest: Codable {
            let title: String
        }
        
        struct UpdateTitleResponse: Codable {
            let message: String
            let title: String
        }
        
        let requestBody = UpdateTitleRequest(title: newTitle)
        let requestData = try JSONEncoder().encode(requestBody)
        
        let _: UpdateTitleResponse = try await performRequest(
            endpoint: "/recordings/\(recordingId)/title",
            method: .PUT,
            body: requestData,
            requiresAuth: true,
            responseType: UpdateTitleResponse.self
        )
        
        print("✅ 成功更新錄音標題: \(recordingId) -> \(newTitle)")
    }
    
    /// 切換分析版本為當前版本
    func setCurrentAnalysisVersion(historyId: String) async throws {
        struct SetCurrentVersionResponse: Codable {
            let message: String
            let historyId: String
            let recordingId: String
            let analysisType: String
            let version: Int
            
            enum CodingKeys: String, CodingKey {
                case message
                case historyId = "history_id"
                case recordingId = "recording_id"
                case analysisType = "analysis_type"
                case version
            }
        }
        
        print("🔄 正在切換分析版本: \(historyId)")
        
        let _: SetCurrentVersionResponse = try await performRequest(
            endpoint: "/analysis/history/\(historyId)/set-current",
            method: .POST,
            body: nil,
            requiresAuth: true,
            responseType: SetCurrentVersionResponse.self
        )
        
        print("✅ 成功切換分析版本為當前版本")
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
    
    // MARK: - Prompt Template Methods
    
    func getPromptTemplates() async throws -> [PromptTemplate] {
        let response: [PromptTemplateResponse] = try await performRequest(
            endpoint: "/prompt-templates/",  // 確保有尾部斜線
            method: .GET,
            requiresAuth: true,
            responseType: [PromptTemplateResponse].self
        )
        
        return response.map { $0.toPromptTemplate() }
    }
    
    func getDefaultPromptTemplate() async throws -> PromptTemplate? {
        let response: DefaultTemplateResponse = try await performRequest(
            endpoint: "/prompt-templates/default",
            method: .GET,
            requiresAuth: true,
            responseType: DefaultTemplateResponse.self
        )
        
        return response.defaultTemplate?.toPromptTemplate()
    }
    
    func createPromptTemplate(name: String, description: String?, prompt: String) async throws -> PromptTemplate {
        let requestBody = CreatePromptTemplateRequest(
            name: name,
            description: description,
            prompt: prompt
        )
        
        let requestData = try JSONEncoder().encode(requestBody)
        
        let response: PromptTemplateResponse = try await performRequest(
            endpoint: "/prompt-templates/",  // 確保有尾部斜線
            method: .POST,
            body: requestData,
            requiresAuth: true,
            responseType: PromptTemplateResponse.self
        )
        
        return response.toPromptTemplate()
    }
    
    func updatePromptTemplate(id: Int, name: String, description: String?, prompt: String) async throws -> PromptTemplate {
        let requestBody = UpdatePromptTemplateRequest(
            name: name,
            description: description,
            prompt: prompt
        )
        
        let requestData = try JSONEncoder().encode(requestBody)
        
        let response: PromptTemplateResponse = try await performRequest(
            endpoint: "/prompt-templates/\(id)",
            method: .PUT,
            body: requestData,
            requiresAuth: true,
            responseType: PromptTemplateResponse.self
        )
        
        return response.toPromptTemplate()
    }
    
    func deletePromptTemplate(id: Int) async throws {
        let _: EmptyResponse = try await performRequest(
            endpoint: "/prompt-templates/\(id)",
            method: .DELETE,
            requiresAuth: true,
            responseType: EmptyResponse.self
        )
    }
    
    func setDefaultPromptTemplate(id: Int) async throws {
        let _: PromptTemplateResponse = try await performRequest(
            endpoint: "/prompt-templates/\(id)/set-default",
            method: .PUT,
            requiresAuth: true,
            responseType: PromptTemplateResponse.self
        )
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

struct RecordingListResponse: Decodable {
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
struct RecordingSummaryList: Codable {
    let recordings: [RecordingSummary]
    let total: Int
    let page: Int
    let per_page: Int
}

// 添加後端錄音詳情響應模型
struct RecordingResponse: Decodable {
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
    let srt_content: String?
    let has_timestamps: Bool?
    let timestamps_data: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, format, status, transcript, summary
        case original_filename
        case mime_type
        case duration
        case file_size
        case created_at
        case srt_content
        case has_timestamps
        case timestamps_data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        original_filename = try container.decode(String.self, forKey: .original_filename)
        format = try container.decode(String.self, forKey: .format)
        mime_type = try container.decode(String.self, forKey: .mime_type)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        file_size = try container.decode(Int.self, forKey: .file_size)
        status = try container.decode(String.self, forKey: .status)
        created_at = try container.decode(String.self, forKey: .created_at)
        transcript = try container.decodeIfPresent(String.self, forKey: .transcript)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        srt_content = try container.decodeIfPresent(String.self, forKey: .srt_content)
        has_timestamps = try container.decodeIfPresent(Bool.self, forKey: .has_timestamps)
        
        // Handle timestamps_data as generic JSON
        // Since we can't directly decode [String: Any], we'll leave it nil for now
        // The actual timestamp data will be handled at the frontend level
        timestamps_data = nil
    }
}

// MARK: - Analysis Models
/// 重新生成響應
struct RegenerateResponse: Codable {
    let taskId: String
    let message: String
    let status: String?
    
    enum CodingKeys: String, CodingKey {
        case taskId = "history_id"  // 後端返回的是 history_id
        case message
        case status
    }
}

// MARK: - Network Service Delegate
class NetworkServiceDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        print("🔄 NetworkService 處理重定向: \(response.statusCode) -> \(request.url?.absoluteString ?? "unknown")")
        
        // 創建新請求，保留原始請求的所有標頭
        var newReq = request
        
        // 複製原始請求的授權標頭
        if let originalRequest = task.originalRequest,
           let authHeader = originalRequest.value(forHTTPHeaderField: "Authorization") {
            newReq.setValue(authHeader, forHTTPHeaderField: "Authorization")
            print("🔑 重定向時保留授權標頭")
        }
        
        completionHandler(newReq)
    }
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