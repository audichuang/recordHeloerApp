import Foundation
import SwiftUI

@MainActor
class PromptTemplateManager: ObservableObject {
    @Published var templates: [PromptTemplate] = []
    @Published var defaultTemplate: PromptTemplate?
    @Published var isLoading = false
    @Published var error: String?
    
    private let networkService = NetworkService.shared
    private var hasLoadedInitialTemplates = false
    
    init() {
        // 不要在初始化時載入模板，等到需要時再載入
    }
    
    // MARK: - Load Templates
    func loadTemplates() async {
        isLoading = true
        error = nil
        
        do {
            let response = try await networkService.getPromptTemplates()
            self.templates = response
            
            // 找出默認模板
            self.defaultTemplate = response.first { $0.isUserDefault }
            
            print("✅ 成功加載 \(templates.count) 個模板")
            hasLoadedInitialTemplates = true
        } catch {
            self.error = "載入模板失敗：\(error.localizedDescription)"
            print("❌ 載入模板失敗: \(error)")
            
            // 如果是認證錯誤，不要標記為已載入
            if case NetworkError.unauthorized = error {
                hasLoadedInitialTemplates = false
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Ensure Templates Loaded
    func ensureTemplatesLoaded() async {
        guard !hasLoadedInitialTemplates else { return }
        await loadTemplates()
    }
    
    // MARK: - Get Default Template
    func loadDefaultTemplate() async {
        do {
            let response = try await networkService.getDefaultPromptTemplate()
            self.defaultTemplate = response
        } catch {
            print("❌ 載入默認模板失敗: \(error)")
        }
    }
    
    // MARK: - Create Template
    func createTemplate(name: String, description: String?, prompt: String) async -> Bool {
        isLoading = true
        error = nil
        
        do {
            let newTemplate = try await networkService.createPromptTemplate(
                name: name,
                description: description,
                prompt: prompt
            )
            
            // 添加到本地列表
            templates.append(newTemplate)
            
            print("✅ 成功創建模板: \(name)")
            isLoading = false
            return true
        } catch {
            self.error = "創建模板失敗：\(error.localizedDescription)"
            print("❌ 創建模板失敗: \(error)")
            isLoading = false
            return false
        }
    }
    
    // MARK: - Update Template
    func updateTemplate(_ template: PromptTemplate, name: String, description: String?, prompt: String) async -> Bool {
        isLoading = true
        error = nil
        
        do {
            let updatedTemplate = try await networkService.updatePromptTemplate(
                id: template.id,
                name: name,
                description: description,
                prompt: prompt
            )
            
            // 更新本地列表
            if let index = templates.firstIndex(where: { $0.id == template.id }) {
                templates[index] = updatedTemplate
            }
            
            // 如果更新的是默認模板，也更新默認模板引用
            if template.id == defaultTemplate?.id {
                defaultTemplate = updatedTemplate
            }
            
            print("✅ 成功更新模板: \(name)")
            isLoading = false
            return true
        } catch {
            self.error = "更新模板失敗：\(error.localizedDescription)"
            print("❌ 更新模板失敗: \(error)")
            isLoading = false
            return false
        }
    }
    
    // MARK: - Delete Template
    func deleteTemplate(_ template: PromptTemplate) async -> Bool {
        guard !template.isSystemTemplate else {
            self.error = "系統模板不能刪除"
            return false
        }
        
        isLoading = true
        error = nil
        
        do {
            try await networkService.deletePromptTemplate(id: template.id)
            
            // 從本地列表移除
            templates.removeAll { $0.id == template.id }
            
            // 如果刪除的是默認模板，清除默認模板
            if template.id == defaultTemplate?.id {
                defaultTemplate = nil
                // 重新加載默認模板
                await loadDefaultTemplate()
            }
            
            print("✅ 成功刪除模板: \(template.name)")
            isLoading = false
            return true
        } catch {
            self.error = "刪除模板失敗：\(error.localizedDescription)"
            print("❌ 刪除模板失敗: \(error)")
            isLoading = false
            return false
        }
    }
    
    // MARK: - Set Default Template
    func setDefaultTemplate(_ template: PromptTemplate) async -> Bool {
        isLoading = true
        error = nil
        
        do {
            try await networkService.setDefaultPromptTemplate(id: template.id)
            
            // 更新本地狀態
            for i in templates.indices {
                templates[i].isUserDefault = (templates[i].id == template.id)
            }
            
            defaultTemplate = template
            
            print("✅ 成功設置默認模板: \(template.name)")
            isLoading = false
            return true
        } catch {
            self.error = "設置默認模板失敗：\(error.localizedDescription)"
            print("❌ 設置默認模板失敗: \(error)")
            isLoading = false
            return false
        }
    }
    
    // MARK: - Helper Methods
    func getSystemTemplates() -> [PromptTemplate] {
        return templates.filter { $0.isSystemTemplate }
    }
    
    func getUserTemplates() -> [PromptTemplate] {
        return templates.filter { !$0.isSystemTemplate }
    }
    
    func getTemplate(by id: Int) -> PromptTemplate? {
        return templates.first { $0.id == id }
    }
}