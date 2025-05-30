import SwiftUI

struct PromptTemplateListView: View {
    @EnvironmentObject var templateManager: PromptTemplateManager
    @State private var showingCreateTemplate = false
    @State private var showingEditTemplate = false
    @State private var selectedTemplate: PromptTemplate?
    @State private var showingDeleteAlert = false
    @State private var templateToDelete: PromptTemplate?
    
    var body: some View {
        List {
            // 系統模板區
            Section {
                ForEach(templateManager.getSystemTemplates()) { template in
                    TemplateRow(
                        template: template,
                        isDefault: template.id == templateManager.defaultTemplate?.id,
                        onSetDefault: {
                            Task {
                                await templateManager.setDefaultTemplate(template)
                            }
                        }
                    )
                }
            } header: {
                Text("系統模板")
            } footer: {
                Text("系統模板不可編輯或刪除")
            }
            
            // 自定義模板區
            Section {
                ForEach(templateManager.getUserTemplates()) { template in
                    TemplateRow(
                        template: template,
                        isDefault: template.id == templateManager.defaultTemplate?.id,
                        onSetDefault: {
                            Task {
                                await templateManager.setDefaultTemplate(template)
                            }
                        },
                        onEdit: {
                            selectedTemplate = template
                            showingEditTemplate = true
                        },
                        onDelete: {
                            templateToDelete = template
                            showingDeleteAlert = true
                        }
                    )
                }
                
                // 新增模板按鈕
                Button {
                    showingCreateTemplate = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                        Text("新增模板")
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text("我的模板")
            }
        }
        .navigationTitle("摘要模板")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingCreateTemplate) {
            PromptTemplateEditView(mode: .create)
        }
        .sheet(isPresented: $showingEditTemplate) {
            if let template = selectedTemplate {
                PromptTemplateEditView(mode: .edit(template))
            }
        }
        .alert("刪除模板", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("刪除", role: .destructive) {
                if let template = templateToDelete {
                    Task {
                        await templateManager.deleteTemplate(template)
                    }
                }
            }
        } message: {
            Text("確定要刪除「\(templateToDelete?.name ?? "")」嗎？")
        }
        .refreshable {
            await templateManager.loadTemplates()
        }
        .onAppear {
            Task {
                await templateManager.ensureTemplatesLoaded()
            }
        }
    }
}

// MARK: - Template Row
struct TemplateRow: View {
    let template: PromptTemplate
    let isDefault: Bool
    let onSetDefault: () -> Void
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack {
                Image(systemName: template.displayIcon)
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(template.name)
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if isDefault {
                            Text("默認")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.success)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.Colors.success.opacity(0.1))
                                )
                        }
                    }
                    
                    if let description = template.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                if template.isEditable {
                    Menu {
                        if !isDefault {
                            Button {
                                onSetDefault()
                            } label: {
                                Label("設為默認", systemImage: "star")
                            }
                        }
                        
                        if let onEdit = onEdit {
                            Button {
                                onEdit()
                            } label: {
                                Label("編輯", systemImage: "pencil")
                            }
                        }
                        
                        if let onDelete = onDelete {
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                } else if !isDefault {
                    Button {
                        onSetDefault()
                    } label: {
                        Text("設為默認")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .stroke(AppTheme.Colors.primary, lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        PromptTemplateListView()
            .environmentObject(PromptTemplateManager())
    }
}