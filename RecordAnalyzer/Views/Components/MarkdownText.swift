import SwiftUI
import MarkdownUI

struct MarkdownText: View {
    let content: String

    var body: some View {
        Markdown(content)
            .markdownTheme(.gitHub)
            // 您可以在這裡自訂更多 MarkdownUI 的樣式和行為
            // 例如，設定字體大小、顏色等
            .markdownTextStyle { 
                FontSize(16)
            }
            .padding()
    }
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
- 設計初步UI原型
- **下次會議時間：** 下週三下午2點
""")
    }
} 