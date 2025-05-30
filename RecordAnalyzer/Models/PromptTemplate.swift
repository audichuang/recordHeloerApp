import Foundation

// MARK: - Prompt Template Model
struct PromptTemplate: Codable, Identifiable {
    let id: Int
    var name: String
    var description: String?
    var prompt: String
    var isSystemTemplate: Bool
    var isUserDefault: Bool
    let userId: UUID?
    let createdAt: Date
    var updatedAt: Date
    
    // 計算屬性
    var isEditable: Bool {
        !isSystemTemplate
    }
    
    var displayIcon: String {
        if isSystemTemplate {
            switch name {
            case "標準會議摘要":
                return "doc.text"
            case "簡潔重點摘要":
                return "list.bullet"
            case "學術演講摘要":
                return "graduationcap"
            case "客戶訪談摘要":
                return "person.2"
            default:
                return "doc"
            }
        } else {
            return "doc.badge.plus"
        }
    }
}

// MARK: - Create/Update Request
struct CreatePromptTemplateRequest: Codable {
    let name: String
    let description: String?
    let prompt: String
}

struct UpdatePromptTemplateRequest: Codable {
    let name: String
    let description: String?
    let prompt: String
}

// MARK: - Response
struct PromptTemplateResponse: Codable {
    let id: Int
    let name: String
    let description: String?
    let prompt: String
    let isSystemTemplate: Bool
    let isUserDefault: Bool
    let userId: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, prompt
        case isSystemTemplate = "is_system_template"
        case isUserDefault = "is_user_default"
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    func toPromptTemplate() -> PromptTemplate {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return PromptTemplate(
            id: id,
            name: name,
            description: description,
            prompt: prompt,
            isSystemTemplate: isSystemTemplate,
            isUserDefault: isUserDefault,
            userId: userId != nil ? UUID(uuidString: userId!) : nil,
            createdAt: dateFormatter.date(from: createdAt) ?? Date(),
            updatedAt: dateFormatter.date(from: updatedAt) ?? Date()
        )
    }
}

// MARK: - Default Template Response
struct DefaultTemplateResponse: Codable {
    let defaultTemplate: PromptTemplateResponse?
    
    enum CodingKeys: String, CodingKey {
        case defaultTemplate = "default_template"
    }
}