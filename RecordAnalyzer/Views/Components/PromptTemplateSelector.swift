import SwiftUI

struct PromptTemplateSelector: View {
    @Binding var selectedTemplate: PromptTemplate?
    @ObservedObject var templateManager: PromptTemplateManager
    
    var body: some View {
        Menu {
            // 系統模板區
            Section("系統模板") {
                ForEach(templateManager.getSystemTemplates()) { template in
                    Button {
                        selectedTemplate = template
                    } label: {
                        HStack {
                            Label(template.name, systemImage: template.displayIcon)
                            if template.id == selectedTemplate?.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            // 自定義模板區
            if !templateManager.getUserTemplates().isEmpty {
                Section("我的模板") {
                    ForEach(templateManager.getUserTemplates()) { template in
                        Button {
                            selectedTemplate = template
                        } label: {
                            HStack {
                                Label(template.name, systemImage: template.displayIcon)
                                if template.id == selectedTemplate?.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: selectedTemplate?.displayIcon ?? "doc.text")
                    .foregroundColor(AppTheme.Colors.primary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("摘要模板")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text(templateDisplayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
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
        .onAppear {
            // 如果還沒選擇，設置默認模板
            if selectedTemplate == nil {
                selectedTemplate = templateManager.defaultTemplate
            }
        }
    }
    
    private var templateDisplayName: String {
        if let template = selectedTemplate {
            return template.name
        } else if let defaultTemplate = templateManager.defaultTemplate {
            // 如果有預設模板但還未加載，顯示預設模板名稱
            return defaultTemplate.name
        } else {
            return "選擇模板"
        }
    }
}

// 簡化版選擇器（用於緊湊空間）
struct CompactPromptTemplateSelector: View {
    @Binding var selectedTemplate: PromptTemplate?
    @ObservedObject var templateManager: PromptTemplateManager
    
    var body: some View {
        Menu {
            // 系統模板
            ForEach(templateManager.getSystemTemplates()) { template in
                Button {
                    selectedTemplate = template
                } label: {
                    Label(template.name, systemImage: template.displayIcon)
                }
            }
            
            // 分隔線
            if !templateManager.getUserTemplates().isEmpty {
                Divider()
            }
            
            // 用戶模板
            ForEach(templateManager.getUserTemplates()) { template in
                Button {
                    selectedTemplate = template
                } label: {
                    Label(template.name, systemImage: template.displayIcon)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedTemplate?.displayIcon ?? "doc.text")
                    .font(.system(size: 14))
                Text(selectedTemplate?.name ?? "選擇模板")
                    .font(.system(size: 14))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .foregroundColor(AppTheme.Colors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.primary.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PromptTemplateSelector(
            selectedTemplate: .constant(nil),
            templateManager: PromptTemplateManager()
        )
        
        CompactPromptTemplateSelector(
            selectedTemplate: .constant(nil),
            templateManager: PromptTemplateManager()
        )
    }
    .padding()
}