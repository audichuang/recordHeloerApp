import SwiftUI

struct MarkdownText: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseMarkdown(content), id: \.id) { element in
                element.view
            }
        }
    }
    
    private func parseMarkdown(_ text: String) -> [MarkdownElement] {
        let lines = text.components(separatedBy: .newlines)
        var elements: [MarkdownElement] = []
        var currentListItems: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty {
                // 如果遇到空行且有列表項目，先處理列表
                if !currentListItems.isEmpty {
                    elements.append(MarkdownElement.list(currentListItems))
                    currentListItems = []
                }
                continue
            }
            
            // 標題處理
            if trimmedLine.hasPrefix("## ") {
                // 處理之前的列表
                if !currentListItems.isEmpty {
                    elements.append(MarkdownElement.list(currentListItems))
                    currentListItems = []
                }
                let title = String(trimmedLine.dropFirst(3))
                elements.append(MarkdownElement.heading2(title))
            }
            else if trimmedLine.hasPrefix("### ") {
                if !currentListItems.isEmpty {
                    elements.append(MarkdownElement.list(currentListItems))
                    currentListItems = []
                }
                let title = String(trimmedLine.dropFirst(4))
                elements.append(MarkdownElement.heading3(title))
            }
            // 列表項目
            else if trimmedLine.hasPrefix("- ") {
                let item = String(trimmedLine.dropFirst(2))
                currentListItems.append(item)
            }
            // 普通段落
            else {
                if !currentListItems.isEmpty {
                    elements.append(MarkdownElement.list(currentListItems))
                    currentListItems = []
                }
                
                // 處理表情符號和格式化文本
                elements.append(MarkdownElement.paragraph(trimmedLine))
            }
        }
        
        // 處理最後的列表項目
        if !currentListItems.isEmpty {
            elements.append(MarkdownElement.list(currentListItems))
        }
        
        return elements
    }
}

enum MarkdownElement {
    case heading2(String)
    case heading3(String)
    case paragraph(String)
    case list([String])
    
    var id: String {
        switch self {
        case .heading2(let text): return "h2_\(text)"
        case .heading3(let text): return "h3_\(text)"
        case .paragraph(let text): return "p_\(text.prefix(50))"
        case .list(let items): return "list_\(items.first?.prefix(20) ?? "")"
        }
    }
    
    @MainActor
    @ViewBuilder
    var view: some View {
        switch self {
        case .heading2(let text):
            HStack(spacing: 8) {
                extractEmoji(from: text)
                    .font(.title2)
                
                Text(removeEmoji(from: text))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
            
        case .heading3(let text):
            HStack(spacing: 8) {
                extractEmoji(from: text)
                    .font(.title3)
                
                Text(removeEmoji(from: text))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 6)
            
        case .paragraph(let text):
            if !text.isEmpty {
                Text(text)
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            
        case .list(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.body)
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                        
                        Text(items[index])
                            .font(.body)
                            .lineSpacing(4)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.leading, 8)
            .padding(.vertical, 4)
        }
    }
    
    @MainActor
    private func extractEmoji(from text: String) -> Text {
        let emoji = text.prefix { char in
            char.unicodeScalars.allSatisfy { scalar in
                CharacterSet.symbols.contains(scalar) || 
                CharacterSet(charactersIn: "🎯📝📋✅💡🔑🎙️📊⏱️🚀").contains(scalar)
            }
        }
        return Text(String(emoji))
    }
    
    private func removeEmoji(from text: String) -> String {
        let withoutEmoji = text.drop { char in
            char.unicodeScalars.allSatisfy { scalar in
                CharacterSet.symbols.contains(scalar) || 
                CharacterSet(charactersIn: "🎯📝📋✅💡🔑🎙️📊⏱️🚀").contains(scalar)
            }
        }
        return String(withoutEmoji).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    ScrollView {
        MarkdownText(content: """
## 📝 會議/對話摘要

### 🎯 主要議題
- 專案簡報策略與結構化溝通：討論如何將一個技術專案（二手登山用品平台）以金字塔理論和「以終為始」的原則，向聽眾進行有邏輯、有說服力的簡報

### 📋 重要內容
- 市場需求與商業模式驗證：強調在專案啟動前，必須透過市場調查和數據分析，證明專案的必要性
- 技術展示與情境式操作：指導團隊如何在實際操作（Demo）環節中，有效地整合技術細節的說明

### ✅ 行動項目
- 準備市場調查報告
- 完成技術原型開發

### 💡 關鍵洞察
- 簡報需要結構化和邏輯性
- 技術細節要與商業目標結合

### 🔑 關鍵字
專案管理, 市場調查, 技術展示, 商業模式, 團隊協作
""")
    }
    .padding()
} 