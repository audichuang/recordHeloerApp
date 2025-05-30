import SwiftUI

struct PromptTemplateEditView: View {
    enum Mode {
        case create
        case edit(PromptTemplate)
    }
    
    let mode: Mode
    @EnvironmentObject var templateManager: PromptTemplateManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var prompt = ""
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.l) {
                    // 基本信息
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                        Text("基本信息")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                            Text("模板名稱 *")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            TextField("例如：會議記錄模板", text: $name)
                                .textFieldStyle(ModernTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                            Text("描述（選填）")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            TextField("簡單描述這個模板的用途", text: $description)
                                .textFieldStyle(ModernTextFieldStyle())
                        }
                    }
                    
                    // Prompt 內容
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                        HStack {
                            Text("Prompt 內容 *")
                                .font(.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Spacer()
                            
                            Text("\(prompt.count) 字")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        
                        TextEditor(text: $prompt)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .padding(AppTheme.Spacing.m)
                            .frame(minHeight: 200)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                    .fill(AppTheme.Colors.surfaceLight)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                    .stroke(AppTheme.Colors.border, lineWidth: 1)
                            )
                        
                        // 提示說明
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Label("提示", systemImage: "lightbulb")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.info)
                            
                            Text("• 請詳細描述您希望 AI 如何生成摘要")
                                .font(.caption2)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            Text("• 可以指定格式、重點、風格等要求")
                                .font(.caption2)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            Text("• 建議長度：50-500 字")
                                .font(.caption2)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .padding(AppTheme.Spacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                                .fill(AppTheme.Colors.info.opacity(0.1))
                        )
                    }
                    
                    // 範例模板
                    if case .create = mode {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                            Text("參考範例")
                                .font(.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppTheme.Spacing.m) {
                                    ForEach(examplePrompts, id: \.title) { example in
                                        ExamplePromptCard(
                                            title: example.title,
                                            prompt: example.prompt
                                        ) {
                                            prompt = example.prompt
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("儲存") {
                        saveTemplate()
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .alert("錯誤", isPresented: $showingError) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                setupInitialValues()
            }
        }
    }
    
    private var navigationTitle: String {
        switch mode {
        case .create:
            return "新增模板"
        case .edit:
            return "編輯模板"
        }
    }
    
    private func setupInitialValues() {
        switch mode {
        case .create:
            // 新建模板，使用空值
            break
        case .edit(let template):
            name = template.name
            description = template.description ?? ""
            prompt = template.prompt
        }
    }
    
    private func saveTemplate() {
        isSaving = true
        
        Task {
            do {
                switch mode {
                case .create:
                    let success = await templateManager.createTemplate(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                        prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    
                    if success {
                        dismiss()
                    } else {
                        errorMessage = templateManager.error ?? "創建失敗"
                        showingError = true
                    }
                    
                case .edit(let template):
                    let success = await templateManager.updateTemplate(
                        template,
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                        prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    
                    if success {
                        dismiss()
                    } else {
                        errorMessage = templateManager.error ?? "更新失敗"
                        showingError = true
                    }
                }
            }
            
            isSaving = false
        }
    }
}

// MARK: - Example Prompts
private let examplePrompts = [
    (
        title: "詳細會議記錄",
        prompt: "請將這段會議錄音整理成詳細的會議記錄，包含：\n\n1. 會議主題和目的\n2. 各參與者的主要觀點和發言\n3. 討論的關鍵議題\n4. 達成的共識和決議\n5. 待辦事項和負責人\n6. 下次會議安排（如有）\n\n請使用條列式呈現，並標註重要內容。"
    ),
    (
        title: "學習重點整理",
        prompt: "請將這段學習內容整理成易於複習的筆記，包含：\n\n1. 核心概念定義\n2. 重要知識點（使用編號列表）\n3. 關鍵公式或原理\n4. 實際應用範例\n5. 相關延伸知識\n\n請用簡潔清晰的語言，並突出重點內容。"
    ),
    (
        title: "醫療諮詢記錄",
        prompt: "請將這段醫療諮詢對話整理成專業的醫療記錄，包含：\n\n1. 主訴症狀\n2. 病史詢問重點\n3. 醫師診斷說明\n4. 治療建議\n5. 用藥指導\n6. 注意事項\n7. 複診安排\n\n請保持專業術語的準確性。"
    )
]

// MARK: - Example Prompt Card
struct ExamplePromptCard: View {
    let title: String
    let prompt: String
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(prompt)
                .font(.caption2)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .lineLimit(3)
            
            Spacer()
            
            Button {
                onSelect()
            } label: {
                Text("使用此範例")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .padding(AppTheme.Spacing.m)
        .frame(width: 200, height: 150)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .fill(AppTheme.Colors.surfaceLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Modern Text Field Style
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(AppTheme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(AppTheme.Colors.surfaceLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )
    }
}

#Preview {
    PromptTemplateEditView(mode: .create)
        .environmentObject(PromptTemplateManager())
}