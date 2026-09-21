# Colony Empire 教學 — 第 10e 課
## 開始畫面、新遊戲設定、高解析度

| 新功能 | 說明 |
|---|---|
| **標題畫面** | 背景是一張隨機生成、全部探索過的地圖，緩慢左右平移；左邊是標題和選單（New Game / Continue / Settings / Quit） |
| **新遊戲設定** | 選國家（四張卡片：國家色的殖民者、國名、國家特性）、地圖大小（小／標準／大）、對手數量（1–3） |
| **設定** | 視窗或全螢幕、介面大小 85% / 100% / 115%，存在 `user://settings.cfg` |
| **高解析度** | 以 1600×900 排版，依實際螢幕解析度清晰繪製；啟動時視窗最大化；F11 切換全螢幕 |
| **更清晰的圖** | 3D 圖重新渲染成較高解析度：單位 256px、城市 320px、山 288px，描邊也加粗 |
| **遊戲內選單** | 新增 Main Menu（回標題畫面）、Fullscreen、Quit Game；結算視窗也有 Play Again 和 Main Menu |

| 地圖 | 大小 | 預設對手 | 部落 | 每族村莊 |
|---|---|---|---|---|
| Small | 50 × 32 | 1 | 3 | 4 |
| Standard | 70 × 44 | 2 | 4 | 5 |
| Large | 92 × 58 | 3 | 4 | 7 |

---

## Step 1：更新

1. 貼上新的 `main.gd`、`hud.gd`、`tools/render_sprites.gd`。
2. `assets/sprites/` 換成新的高解析度圖。
3. `project.godot` 新增了一段設定（已經幫你加好）：

```ini
[display]
window/size/viewport_width=1600
window/size/viewport_height=900
window/size/mode=2                  ; 啟動時最大化
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

---

## Step 2：解析度是怎麼運作的

- **viewport 1600×900** 是「排版尺寸」：所有 UI 和地圖都以這個大小來設計。
- **stretch mode = canvas_items**：Godot 會把畫面放大到實際視窗大小，而且**用螢幕的真實解析度重新繪製**，不是把一張小圖拉大。1080p 螢幕放大 1.2 倍，2K 放大 1.6 倍，4K 放大 2.4 倍，文字和線條都一樣清楚。
- **aspect = expand**：螢幕比例不是 16:9（例如 16:10 或超寬螢幕）時，多出來的空間會直接顯示更多地圖，不會出現黑邊。
- **介面大小**是在這個縮放上再乘一次：`get_window().content_scale_factor = ui_scale`。

因為畫面最多會放大到 2.4 倍（4K）再加上地圖縮放，所以 3D 圖都重新渲染成較大的尺寸：

```
godot --path . -s res://tools/render_sprites.gd
```

---

## Step 3：遊戲狀態：標題畫面 → 遊戲中

`main.gd` 新增一個旗標 `in_menu`：

```gdscript
func go_to_menu():      # 產生背景地圖（全部探索過），顯示標題畫面
func start_game(nation, size, rivals):   # 套用設定 → _restart() → 開始遊戲
func continue_game():   # 讀取存檔 → 開始遊戲
```

`in_menu` 為 true 時，`_process()` 只負責讓鏡頭慢慢平移（碰到地圖邊緣就反向），鍵盤和滑鼠操作都不會傳給遊戲。

原本的常數 `MAP_W`、`MAP_H`、`AI_COUNT`、`PLAYER_NATION` 改成**變數**，由設定畫面決定。地圖尺寸也寫進存檔，讀檔時會用同樣的尺寸重建地形。

---

## Step 4：設定畫面的 UI 技巧

- **一組只能選一個**：`Button.toggle_mode = true` 加上同一個 `ButtonGroup`，按下一個，其他會自動彈起。
- **選中的樣式**：替 `pressed` 和 `hover_pressed` 設定亮黃銅邊框的樣式。
- **國家卡片**：卡片本身是一個按鈕，裡面放 `MarginContainer → VBox → 頭像、國名、特性`。子節點都設成 `MOUSE_FILTER_IGNORE`，點擊才會傳到按鈕本身。頭像直接用遊戲裡的「上色」函式，把殖民者塗成該國顏色。
- **標題畫面背景**：用 `GradientTexture2D`（徑向漸層）做暗角，再加一條半透明色帶墊在文字後面，讓標題在任何地圖上都看得清楚。
- **設定存檔**：用 `ConfigFile` 存成 `user://settings.cfg`，下次啟動時自動套用。

---

## 小練習

1. 在設定畫面加一個「地圖種子」輸入框（`LineEdit`），輸入同一個數字就能重玩同一張地圖。
2. 新增「超大」地圖（110 × 70）。記得檢查 AI 的建城搜尋範圍（16 格）夠不夠。
3. 標題畫面背景改成讓 AI 自己玩 30 回合的地圖，這樣就會出現城市和道路。
