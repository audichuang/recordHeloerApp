# 錄音分析助手 iOS APP

一個功能完整的 iOS 應用程式，可以將錄音文件轉換為逐字稿和智能摘要。

## 功能特色

### ✨ 核心功能
- **錄音上傳**: 支援多種音頻格式 (MP3, M4A, WAV 等)
- **逐字稿轉換**: 將錄音轉換為精確的文字記錄
- **智能摘要**: 自動生成錄音內容的重點摘要
- **分享整合**: 可從其他錄音 APP 直接分享到本應用

### 👤 用戶管理
- **用戶註冊/登入**: 完整的身份認證系統
- **個人資料**: 查看使用統計和管理帳戶
- **資料持久化**: 自動保存登入狀態

### 📚 歷史記錄
- **完整列表**: 查看所有上傳的錄音記錄
- **智能搜索**: 根據標題、檔名、內容搜索
- **多種排序**: 按日期、標題、時長排序
- **詳細視圖**: 查看完整逐字稿和摘要

### 🎨 用戶界面
- **現代設計**: 採用 SwiftUI 現代化界面
- **直觀操作**: 簡潔易用的用戶體驗
- **響應式**: 支援 iPhone 和 iPad
- **繁體中文**: 完全本地化界面

## 技術架構

### 前端技術
- **SwiftUI**: 現代化 iOS 開發框架
- **Combine**: 響應式程式設計
- **MVVM**: 清晰的架構模式
- **@StateObject/@ObservableObject**: 狀態管理

### 數據管理
- **UserDefaults**: 本地設定存儲
- **FileManager**: 文件管理
- **Codable**: 數據序列化

### UI 組件
- **TabView**: 主要導航
- **NavigationView**: 頁面導航
- **Sheet/Alert**: 模態界面
- **ProgressView**: 上傳進度顯示

## 測試說明

### 測試帳戶
```
Email: test@example.com
Password: password
```

### 假資料
應用包含完整的假資料，包括：
- 3個範例錄音記錄
- 完整的逐字稿和摘要
- 用戶統計資訊

### 模擬功能
- 上傳進度模擬
- API 調用模擬 (1秒延遲)
- 錄音分析結果模擬

## 目錄結構

```
RecordAnalyzer/
├── RecordAnalyzerApp.swift          # 應用入口點
├── ContentView.swift                # 主視圖
├── Models/
│   └── RecordingModel.swift         # 數據模型
├── Managers/
│   ├── AuthenticationManager.swift  # 認證管理
│   └── RecordingManager.swift       # 錄音管理
├── Views/
│   ├── Authentication/
│   │   ├── LoginView.swift          # 登入頁面
│   │   └── RegisterView.swift       # 註冊頁面
│   ├── Home/
│   │   └── HomeView.swift           # 首頁
│   ├── History/
│   │   └── HistoryView.swift        # 歷史記錄
│   ├── Recording/
│   │   └── RecordingDetailView.swift # 錄音詳情
│   ├── Profile/
│   │   └── ProfileView.swift        # 個人資料
│   └── Components/
│       └── RecordingRowView.swift   # 錄音列表項目
├── Assets.xcassets/                 # 資源文件
└── Info.plist                       # 應用配置
```

## 主要畫面

### 🏠 首頁
- 歡迎訊息和用戶資訊
- 錄音上傳功能
- 上傳進度顯示
- 最近錄音預覽

### 📖 歷史記錄
- 所有錄音列表
- 搜索和篩選功能
- 排序選項
- 錄音統計

### 🎵 錄音詳情
- 錄音基本資訊
- 完整逐字稿 (可選取複製)
- 智能摘要
- 分析統計
- 分享功能

### 👤 個人資料
- 用戶資訊顯示
- 使用統計圖表
- 設定選項
- 登出功能

## 分享整合

應用支援從其他錄音 APP 接收分享的音頻文件：

1. 在其他錄音 APP 中點選「分享」
2. 選擇「錄音分析助手」
3. 輸入錄音標題
4. 自動上傳並分析

## 未來擴展

### 後端整合準備
- 完整的 API 調用結構
- 錯誤處理機制
- 網絡狀態管理
- 離線功能支援

### 功能擴展
- 即時錄音功能
- 多語言支援
- 雲端同步
- 高級分析功能

## 開發環境

- **Xcode**: 15.0+
- **iOS**: 17.0+
- **Swift**: 5.9+
- **SwiftUI**: 5.0+

## 安裝說明

1. 打開 Xcode
2. 載入 `RecordAnalyzerApp.xcodeproj`
3. 選擇目標設備或模擬器
4. 點擊 Run 按鈕

## 注意事項

- 本版本包含完整的 UI 和假資料
- 所有網絡調用都已模擬
- 準備好與 Flask 後端整合
- 支援檔案分享和 URL Scheme

這個 iOS APP 提供了完整的用戶體驗，展示了錄音分析助手的所有功能。您可以直接在 Xcode 中運行並體驗完整的應用流程。 