import Foundation
import AuthenticationServices
import CryptoKit

@MainActor
final class AppleAuthenticationManager: NSObject, ObservableObject {
    @Published var isSigningIn = false
    @Published var error: String?
    
    private var currentNonce: String?
    
    func signInWithApple(presentationAnchor: ASPresentationAnchor, completion: @escaping (Result<AppleAuthResult, Error>) -> Void) {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = AppleSignInDelegate(nonce: nonce, completion: completion)
        authorizationController.presentationContextProvider = AppleSignInPresentationProvider(anchor: presentationAnchor)
        authorizationController.performRequests()
        
        isSigningIn = true
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

struct AppleAuthResult {
    let userID: String
    let email: String?
    let fullName: PersonNameComponents?
    let identityToken: String
    let authorizationCode: String
}

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let nonce: String
    private let completion: (Result<AppleAuthResult, Error>) -> Void
    
    init(nonce: String, completion: @escaping (Result<AppleAuthResult, Error>) -> Void) {
        self.nonce = nonce
        self.completion = completion
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let authCodeData = appleIDCredential.authorizationCode,
                  let authCode = String(data: authCodeData, encoding: .utf8) else {
                completion(.failure(AppleAuthError.invalidCredential))
                return
            }
            
            let result = AppleAuthResult(
                userID: appleIDCredential.user,
                email: appleIDCredential.email,
                fullName: appleIDCredential.fullName,
                identityToken: identityToken,
                authorizationCode: authCode
            )
            
            completion(.success(result))
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                // 用戶取消了登入
                completion(.failure(AppleAuthError.unknownError))
            case .failed:
                // 授權失敗
                completion(.failure(AppleAuthError.invalidCredential))
            case .invalidResponse:
                // 無效的響應
                completion(.failure(AppleAuthError.invalidCredential))
            case .notHandled:
                // 未處理的授權請求
                completion(.failure(AppleAuthError.unknownError))
            case .unknown:
                // 未知錯誤 - 在模擬器上常見
                #if targetEnvironment(simulator)
                completion(.failure(AppleAuthError.simulatorNotSupported))
                #else
                completion(.failure(AppleAuthError.unknownError))
                #endif
            @unknown default:
                completion(.failure(AppleAuthError.unknownError))
            }
        } else {
            completion(.failure(error))
        }
    }
}

private class AppleSignInPresentationProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    private let anchor: ASPresentationAnchor
    
    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return anchor
    }
}

enum AppleAuthError: LocalizedError {
    case invalidCredential
    case missingToken
    case unknownError
    case simulatorNotSupported
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "無效的 Apple ID 憑證"
        case .missingToken:
            return "缺少身份驗證令牌"
        case .unknownError:
            return "未知的錯誤"
        case .simulatorNotSupported:
            return "Sign in with Apple 在模擬器上可能無法正常運作。請在實體設備上測試。"
        }
    }
}