# 台股看盤 iOS App

此專案將原有 Streamlit 看盤頁面重製為原生 SwiftUI app（iOS 16+）。功能包含台股代碼搜尋、歷史區間、最新 OHLCV 指標、K 線、MA5/20/60、成交量與技術面摘要。

## 在 Mac 上開啟

1. 安裝 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`
2. 在此資料夾執行：`xcodegen generate`
3. 以 Xcode 開啟 `TaiwanStockViewer.xcodeproj`，選擇 iPhone Simulator 後執行。

## 在瀏覽器上開啟

打開 https://zmavm.github.io/WebPreview_Stock/WebPreview/


資料由 Yahoo Finance chart endpoint 取得；它封裝在 `YahooFinanceService`，要換成已授權的券商或行情資料 API 時，只需替換該服務。

> 僅供資訊展示，不構成投資建議。
