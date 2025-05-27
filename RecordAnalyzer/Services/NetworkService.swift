import Foundation

// MARK: - API Response Models
struct APIResponse<T: Codable>: Codable {
    let data: T?
    let message: String?
    let statusCode: Int?
}

struct LoginResponse: Codable {
    let accessToken: String
    let tokenType: String
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
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
    
    private let baseURL = "http://localhost:9527/api"
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
            
            switch httpResponse.statusCode {
            case 200...299:
                return try JSONDecoder().decode(T.self, from: data)
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
        
        saveAuthToken(response.accessToken)
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
        
        saveAuthToken(response.accessToken)
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
        guard let request = buildMultipartRequest(
            endpoint: "/recordings/upload",
            fileURL: fileURL,
            title: title
        ) else {
            throw NetworkError.invalidURL
        }
        
        // 使用URLSessionUploadTask來支援進度回調
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.uploadTask(with: request, from: request.httpBody) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: NetworkError.networkError(error.localizedDescription))
                    return
                }
                
                guard let data = data,
                      let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: NetworkError.invalidResponse)
                    return
                }
                
                do {
                    switch httpResponse.statusCode {
                    case 200...299:
                        let recording = try JSONDecoder().decode(Recording.self, from: data)
                        continuation.resume(returning: recording)
                    case 401:
                        DispatchQueue.main.async {
                            self.clearAuthToken()
                        }
                        continuation.resume(throwing: NetworkError.unauthorized)
                    default:
                        continuation.resume(throwing: NetworkError.serverError(httpResponse.statusCode))
                    }
                } catch {
                    continuation.resume(throwing: NetworkError.decodingError)
                }
            }
            
            task.resume()
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
    private func buildMultipartRequest(endpoint: String, fileURL: URL, title: String) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else { return nil }
        guard let token = getAuthToken() else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var data = Data()
        
        // 添加標題欄位
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"title\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(title)\r\n".data(using: .utf8)!)
        
        // 添加文件
        if let fileData = try? Data(contentsOf: fileURL) {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
            data.append(fileData)
            data.append("\r\n".data(using: .utf8)!)
        }
        
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = data
        
        return request
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