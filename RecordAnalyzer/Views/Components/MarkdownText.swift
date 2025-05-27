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
            .padding(.top, 12)
            .padding(.bottom, 6)
            
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
            .padding(.top, 8)
            .padding(.bottom, 4)
            
        case .paragraph(let text):
            if !text.isEmpty {
                formatText(text)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            }
            
        case .list(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.body)
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                        
                        formatText(items[index])
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.leading, 8)
            .padding(.vertical, 2)
        }
    }
    
    @MainActor
    private func formatText(_ text: String) -> Text {
        var result = Text("")
        let parts = splitTextWithFormatting(text)
        
        for part in parts {
            if part.isBold {
                result = result + Text(part.content)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            } else {
                result = result + Text(part.content)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        
        return result
    }
    
    private func splitTextWithFormatting(_ text: String) -> [TextPart] {
        var parts: [TextPart] = []
        var currentText = ""
        var isBold = false
        var i = text.startIndex
        
        while i < text.endIndex {
            // 檢查是否遇到 **
            let nextIndex = text.index(after: i)
            if nextIndex < text.endIndex, 
               text[i] == "*",
               text[nextIndex] == "*" {
                
                // 保存當前累積的文字
                if !currentText.isEmpty {
                    parts.append(TextPart(content: currentText, isBold: isBold))
                    currentText = ""
                }
                
                // 切換粗體狀態
                isBold.toggle()
                
                // 跳過 ** 兩個字符
                i = text.index(nextIndex, offsetBy: 1)
            } else {
                // 普通字符，加入當前文字
                currentText.append(text[i])
                i = text.index(after: i)
            }
        }
        
        // 添加剩餘文本
        if !currentText.isEmpty {
            parts.append(TextPart(content: currentText, isBold: isBold))
        }
        
        return parts
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

struct TextPart {
    let content: String
    let isBold: Bool
}

#Preview {
    ScrollView {
        MarkdownText(content: """
## 📝 會議摘要

### 🎯 主要議題
**專案簡報策略與結構化溝通：** 討論如何將技術專案以更具說服力的方式呈現給聽眾，強調從「為什麼」開始，而非直接切入技術細節。這包括運用**金字塔理論**和**以終為始**的思維，建立清晰的邏輯鏈。

### 📋 重要內容
**市場驗證與數據故事化：** 強調在專案介紹初期，必須透過市場數據和使用者痛點來鋪陳一個引人入勝的「故事」，證明專案的市場需求與必要性，而非僅僅是技術展示。

### ✅ 行動項目
- 準備市場調查報告
- 完成技術原型開發

### 💡 關鍵洞察
簡報需要結構化和邏輯性，技術細節要與商業目標結合

### 🔑 關鍵字
專案管理, 市場調查, 技術展示, 商業模式, 團隊協作
""")
        .padding()
    }
} 