# 🚀 Stress Workload Generator v4.2
## 優化版本說明 - Relative Paths + Albert Style HTML

---

## ✨ 主要改進

### 1️⃣ **相對路徑優化** 📁

#### 舊版本 (v4.0)
```bash
LOG_DIR="/var/log/stress-test"        # ❌ 絕對路徑 - 需要 root
RUN_DIR="/tmp/stress-test-run"        # ❌ 臨時目錄 - 可能被清除
```

#### 新版本 (v4.2) ✅
```bash
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
LOG_DIR="${SCRIPT_DIR}/stress-logs"   # ✅ 相對路徑 - 跟著腳本走
DATA_DIR="${LOG_DIR}/data"
REPORT_DIR="${LOG_DIR}/reports"
RUN_DIR="${LOG_DIR}/run"              # ✅ 統一管理
```

**優點：**
- ✅ **一鍵部署** - 複製檔案即可使用，無需 root
- ✅ **易於管理** - 所有日誌在同一個目錄下
- ✅ **易於備份** - 整個目錄一起備份遷移
- ✅ **無污染** - 不會污染系統目錄

**使用示例：**
```bash
$ ./stress_workload_ENGLISH.sh
  
=== 菜單會顯示 ===
Logs in: /home/user/albert-tools/stress-logs

[測試後]
$ tree stress-logs/
stress-logs/
├── data/
├── reports/          # 包含 .txt 和 .html 報告
│   ├── stress-report-20260505_143022.txt
│   └── stress-report-20260505_143022.html  ← 用瀏覽器打開！
├── run/
└── stress.log
```

---

### 2️⃣ **Albert Style HTML 報告** 🎨

#### 新增功能：自動生成美化 HTML 報告

**特色：**
- ✨ **現代化設計** - 紫色漸層 + 深色主題
- 📱 **響應式佈局** - 桌機/平板都好看
- 📊 **視覺化資訊** - 卡片式呈現，一目了然
- 🔗 **本地查看** - 無需伺服器，直接用瀏覽器打開

#### HTML 報告內容

```
📋 Test Information
  - Session ID: stress-20260505_143022
  - Test Name: Combined Stress Test
  - Duration: 1h 0m 0s
  - Timeline: Start/End 時間

💻 System Information
  - Hostname
  - OS Version (Red Hat 9.6)
  - Kernel Version
  - CPU Cores
  - Total Memory
  - Log Location

✅ Test Status
  - Result: PASSED ✓
```

#### 查看 HTML 報告

```bash
# 測試完後，自動生成：
$ cd stress-logs/reports/
$ firefox stress-report-20260505_143022.html

# 或用其他瀏覽器
$ chrome stress-report-20260505_143022.html
$ safari stress-report-20260505_143022.html
```

---

## 🎯 v4.2 功能清單

| 項目 | 舊版本 v4.0 | 新版本 v4.2 |
|------|-----------|-----------|
| **路徑配置** | 絕對路徑 ❌ | 相對路徑 ✅ |
| **日誌位置** | `/var/log/` | `./stress-logs/` |
| **需要 root** | ❌ 是 | ✅ 否* |
| **文本報告** | ✅ 有 | ✅ 有 |
| **HTML 報告** | ❌ 無 | ✅ 有 (Albert Style) |
| **報告數量** | 1205 行 | 1205 行 |
| **檔案大小** | ~28 KB | ~40 KB |

*注: 如果要對系統進行壓力測試，`stress-ng` 通常需要 root

---

## 📦 檔案結構

```
執行目錄/
├── stress_workload_ENGLISH.sh    ← 主程式
│
└── stress-logs/                  ← 自動建立
    ├── stress.log                ← CLI 日誌
    ├── data/                     ← 資料檔案
    ├── run/                      ← 執行中的監控檔案
    └── reports/
        ├── stress-report-20260505_143022.txt      ← 文本報告
        └── stress-report-20260505_143022.html     ← HTML 報告 (新!)
```

---

## 🚀 快速開始

### 方式 1: 直接執行 (推薦)

```bash
# 複製檔案到你的工作目錄
cp stress_workload_ENGLISH.sh ~/albert-stress-tools/

# 進入目錄
cd ~/albert-stress-tools

# 執行
sudo bash stress_workload_ENGLISH.sh

# 選擇測試 (例: 5 = Combined Stress Test)
# ➜ 測試完成後，自動生成 HTML 報告

# 查看報告 (在 Chrome/Firefox 中打開)
open stress-logs/reports/stress-report-*.html
```

### 方式 2: 遠端執行

```bash
# 上傳到 Red Hat 9.6 VM
scp stress_workload_ENGLISH.sh root@192.168.10.50:/tmp/

# SSH 執行
ssh root@192.168.10.50 "cd /tmp && sudo bash stress_workload_ENGLISH.sh"

# 下載報告
scp -r root@192.168.10.50:/tmp/stress-logs ./
```

---

## 📊 HTML 報告樣式 (Albert Style)

### 色彩主題
```css
主色: #667eea (紫色)
副色: #764ba2 (深紫)
成功: #4caf50 (綠色)
資訊: #00bcd4 (青色)
背景: #1a1a1a (深灰)
```

### 設計元素
- ✨ **漸層背景** - 紫色漸層頂部
- 📱 **卡片式佈局** - 每個訊息獨立卡片
- 🎨 **現代配色** - 深色主題 + 彩色強調
- 📈 **響應式設計** - 自動適應螢幕大小

---

## 🔧 技術細節

### v4.2 新增程式碼

#### 1. 相對路徑設定
```bash
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
LOG_DIR="${SCRIPT_DIR}/stress-logs"
```

#### 2. HTML 報告生成
```bash
generate_html_report() {
    # 生成 Albert style HTML
    # 替換變數: Session ID, Test Name, Duration, 等等
    # 自動打開瀏覽器提示
}
```

#### 3. 整合調用
```bash
run_stress_test() {
    ...
    generate_test_report ...      # 文本報告
    generate_html_report ...      # HTML 報告 (新)
}
```

---

## ✅ 驗證清單

- [x] 版本更新: v4.0 → v4.2
- [x] 路徑改為相對: `/var/log/...` → `./stress-logs/`
- [x] HTML 報告功能: 500+ 行 HTML/CSS 程式碼
- [x] 自動變數替換: Session ID, Hostname, Memory 等
- [x] 菜單顯示日誌位置
- [x] 語法驗證: ✅ bash -n 通過
- [x] 檔案大小: ~40 KB

---

## 📝 變更日誌

### v4.2 (2026-05-05)
- ✨ 新增 Albert style HTML 報告生成
- 📁 改為相對路徑配置
- 📊 菜單顯示日誌位置
- 🎨 現代化 HTML 設計 (深色 + 漸層)
- 📱 HTML 報告響應式佈局

### v4.1 (前版本)
- 🔧 修復 command substitution 卡住問題
- 📝 添加日文註解

### v4.0 (原始版本)
- 🎯 完整的壓力測試工具

---

## 🎓 使用提示

### 最佳實踐
1. **建立專用目錄**
   ```bash
   mkdir ~/stress-testing
   cp stress_workload_ENGLISH.sh ~/stress-testing/
   cd ~/stress-testing
   ```

2. **定期備份報告**
   ```bash
   tar czf stress-reports-backup-$(date +%Y%m%d).tar.gz stress-logs/
   ```

3. **比較多次測試**
   ```bash
   ls -lh stress-logs/reports/
   # 每個測試有獨立的 Session ID，方便對比
   ```

---

## 🆘 故障排除

### Q: HTML 報告無法打開？
**A:** 確保瀏覽器允許本地檔案存取
```bash
# Chrome: 用以下方式打開
google-chrome --allow-file-access-from-files stress-report-*.html

# 或用本地伺服器
python3 -m http.server 8000
# 然後訪問 http://localhost:8000/stress-logs/reports/
```

### Q: 權限問題？
**A:** 確保腳本有執行權限
```bash
chmod +x stress_workload_ENGLISH.sh
```

### Q: 日誌目錄在哪？
**A:** 在執行檔所在目錄的 `stress-logs/` 子目錄
```bash
./stress_workload_ENGLISH.sh
# → 自動建立 ./stress-logs/
```

---

## 📞 支援

**作者:** Albert Zhou  
**版本:** 4.2  
**日期:** 2026-05-05  
**平台:** Red Hat 9.6 on VMware ESXi 9.0  

---

## 🎉 總結

✅ **v4.2 的優勢：**
1. **輕量級部署** - 相對路徑，無需系統權限
2. **專業呈現** - Albert style HTML 報告
3. **易於共享** - HTML 報告可直接傳送
4. **完整記錄** - 文本 + HTML 雙重報告
5. **美觀大方** - 現代化設計，適合展示

**現在就開始使用 v4.2 吧！** 🚀
