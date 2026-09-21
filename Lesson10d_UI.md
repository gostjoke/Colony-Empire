# Colony Empire 教學 — 第 10d 課
## 真正的遊戲 UI：Control 節點＋程式產生的主題

之前的 UI 都是在 `_draw()` 裡用 `draw_string` 直接畫字，不能點、不能排版，文字也會壓在一起。這一課改用 Godot 的 **Control 節點**，全部寫在新檔案 `hud.gd` 裡。

| 區域 | 內容 |
|---|---|
| **頂部資源列** | 國家徽章、年份與回合、金幣／研究（含每回合變化）、人口、城市數、分數與排名。滑鼠停在上面有說明 |
| **左上事件欄** | 事件以卡片形式出現，幾秒後淡出；壞消息（突襲、疾病、飢荒）用紅色邊條 |
| **中上提示** | 短提示和錯誤訊息，淡入淡出 |
| **左下單位面板** | 3D 頭像、移動點數圓點、狀態說明、行動按鈕。不能用的按鈕會變灰，滑鼠停在上面會說明原因 |
| **左下城市面板** | 糧食／生產進度條（附剩餘回合）、四種產出、已有建築、4×2 建造選單（附成本和回合數）、購買按鈕 |
| **右下** | 游標所在格子的資訊、**End Turn / Next Unit** 大按鈕、可點擊或拖曳的小地圖 |
| **視窗** | Technology（科技卡片）、Diplomacy（國家表、部落好感條）、Menu（存檔、讀檔、新地圖、操作說明）、1811 結算排名 |

字型：標題用 **Cinzel**（羅馬碑文風，適合殖民時代），內文用 **Alegreya Sans**。兩者都是 SIL Open Font License，可以放進商業遊戲，授權檔在 `assets/fonts/`。

---

## Step 1：更新

1. 貼上新的 `godot_starter/main.gd`，並加入新檔案 `godot_starter/hud.gd`。
2. 新資源：`assets/fonts/`（字型＋授權）、`assets/ui/`（11 個圖示）。
3. 按 **F5**。所有快捷鍵照舊，另外可以直接點按鈕。

---

## Step 2：UI 只送「按鍵」給遊戲

```gdscript
func _button(text, key, icon, tip) -> Button:
	...
	b.pressed.connect(_press.bind(key))

func _press(key: int) -> void:
	game._on_key(key)      # 跟按鍵盤完全一樣
	refresh(true)
```

「Found City」按鈕送出 `KEY_B`，建造選單第 3 格送出 `KEY_3`，End Turn 送出 `KEY_ENTER`。**每個動作仍然只在 `main.gd` 寫一次**，UI 只是另一種輸入方式。之後要加手把或觸控，也是同樣的做法。

按鈕都設了 `focus_mode = FOCUS_NONE`，否則按 Enter 或 Space 時，會「點到」剛才點過的按鈕。

## Step 3：用程式做主題（Theme）

`_make_theme()` 用 `StyleBoxFlat` 定義外觀：深木色底、黃銅邊、圓角、陰影。每種按鈕狀態（normal / hover / pressed / disabled）各有一個樣式。個別元件可以用 `add_theme_stylebox_override()` 覆蓋，例如金色的 End Turn、目前建造項目的亮框、各色進度條。

**改配色只要改檔案最上方的 `C_BG`、`C_BRASS`、`C_TEXT` 等常數。**

## Step 4：不能用的按鈕要說明原因

`main.gd` 新增了 `_job_problem(u, job)`，會回傳「為什麼工人不能在這裡做這件事」的原因。`_start_job()` 和 HUD 共用它：

```gdscript
var why: String = game._job_problem(u, "mine")
b.disabled = why != ""
b.tooltip_text = why          # 例："Can't mine on Grassland"
```

建城也用同樣的方式（`_found_problem`）。

## Step 5：什麼時候更新 UI

- `main.gd` 在畫面有變化時呼叫 `hud.refresh()`。
- 每個區塊都有自己的「簽名」（`sel_sig`、`top_sig`、`mini_sig`…）。簽名沒變就不重建，所以滑鼠在地圖上移動時，只有格子資訊會更新。
- 容器會在內容改變的**下一幀**才知道自己的新大小，所以 `hud._process()` 每幀把面板重新貼齊左下、右下，視窗置中。

## Step 6：滑鼠在 UI 上時不要點到地圖

```gdscript
if get_viewport().gui_get_hovered_control() != null:
	hovered = NO_CELL
```

面板本身（`MOUSE_FILTER_STOP`）會吃掉點擊，所以 `_unhandled_input` 只會收到點在地圖上的操作。

## Step 7：小地圖

每個六角格在小地圖上是 4×3 個像素，奇數列往右錯開 2 像素，跟真正的地圖一樣。顏色是地形色，混入國家或部落的顏色；城市是白點。只在回合、探索範圍或城市數改變時重建圖片。白框是目前鏡頭的範圍，點擊或拖曳可以移動鏡頭。

## 圖示

`tools/make_icons.py`（Python + cairosvg）用 SVG 畫出 11 個圖示並輸出 PNG。要改或新增圖示：編輯後執行 `python tools/make_icons.py assets/ui`。

## 小練習

1. 在頂部資源列加一個「文化」數值。
2. 城市面板加一排「被耕作的格子」小圖示。
3. 讓事件卡片可以點擊，點了就把鏡頭移到那座城市。
