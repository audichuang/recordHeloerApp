import SwiftUI

struct UploadDialogView: View {
    @Binding var fileURL: URL?
    @Binding var uploadTitle: String
    @Binding var selectedTemplate: PromptTemplate?
    @ObservedObject var templateManager: PromptTemplateManager
    let onUpload: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTitleFocused: Bool
    
    private var isValid: Bool {
        fileURL != nil && !uploadTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 頂部文件信息
                if let url = fileURL {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Text(url.lastPathComponent)
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        HStack(spacing: AppTheme.Spacing.m) {
                            if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber {
                                Label(formatFileSize(fileSize.intValue), systemImage: "doc")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            Label(url.pathExtension.uppercased(), systemImage: "music.note")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.top, AppTheme.Spacing.xl)
                    .padding(.bottom, AppTheme.Spacing.l)
                }
                
                Divider()
                
                // 表單內容
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                        // 標題輸入
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                            Text("錄音標題")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            TextField("為您的錄音命名", text: $uploadTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($isTitleFocused)
                        }
                        
                        // 模板選擇
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                            Text("摘要模板")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            PromptTemplateSelector(
                                selectedTemplate: $selectedTemplate,
                                templateManager: templateManager
                            )
                        }
                        
                        // 模板預覽（如果選擇了模板）
                        if let template = selectedTemplate {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                                HStack {
                                    Text("模板預覽")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    
                                    Spacer()
                                    
                                    if !template.isSystemTemplate {
                                        NavigationLink(destination: PromptTemplateEditView(mode: .edit(template))) {
                                            Text("編輯")
                                                .font(.caption)
                                                .foregroundColor(AppTheme.Colors.primary)
                                        }
                                    }
                                }
                                
                                Text(template.prompt)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                    .lineLimit(3)
                                    .padding(AppTheme.Spacing.m)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                                            .fill(AppTheme.Colors.surfaceLight)
                                    )
                            }
                        }
                    }
                    .padding(AppTheme.Spacing.l)
                }
                
                Divider()
                
                // 底部按鈕
                HStack(spacing: AppTheme.Spacing.m) {
                    Button("取消") {
                        onCancel()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                    )
                    
                    Button {
                        onUpload()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("上傳")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                .fill(isValid ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                        )
                    }
                    .disabled(!isValid)
                }
                .padding(AppTheme.Spacing.l)
            }
            .navigationTitle("上傳錄音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
            }
        }
        .onAppear {
            isTitleFocused = true
            
            Task {
                // 確保模板已載入
                await templateManager.ensureTemplatesLoaded()
                
                // 設置默認模板
                if selectedTemplate == nil {
                    selectedTemplate = templateManager.defaultTemplate
                }
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        
        if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.0f KB", kb)
        }
    }
}

#Preview {
    UploadDialogView(
        fileURL: .constant(URL(fileURLWithPath: "/test/audio.mp3")),
        uploadTitle: .constant(""),
        selectedTemplate: .constant(nil),
        templateManager: PromptTemplateManager(),
        onUpload: {},
        onCancel: {}
    )
}