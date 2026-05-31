# Colony Empire 開發教學 — 第二課
## 加入資源系統與 UI:讓遊戲開始有「取捨」

第一課你做出了能蓋房、拆房的等距地圖。但那還不是「遊戲」——因為沒有限制,玩家想蓋幾棟就幾棟,沒有任何決策。

這一課我們加入**木材資源**。蓋房要花木材、木材不夠就蓋不了;而每棟蓋好的房子會持續產出木材。這一來一往,就形成你 GDD 裡寫的核心循環雛形:**投入資源 → 建造 → 產出 → 再投入**。

---

## Step 1:更新程式

最簡單的方式:用我更新好的 `godot_starter/main.gd` 整個取代你現在的內容。

1. 在 Godot 編輯器打開 `main.gd`。
2. 全選(Ctrl+A)刪掉,貼上新版內容。
3. 存檔(Ctrl+S),按 F5 試玩。

你會看到畫面左上角多了文字:**木材數量、操作說明、房子數**。開局有 50 木材,每蓋一棟花 10,木材不夠時會跳紅字「木材不足」。蓋好房子後等幾秒,木材會自己增加——那是房子在產出。

> 如果你想保留第一課的版本對照,可以先把舊的另存成 `main_lesson1.gd` 再貼新版。

---

## Step 2:看懂新增了什麼(這才是學習)

對照程式,第二課其實只加了四件事:

### 1. 經濟參數(最上面的 const 區)

```gdscript
const START_WOOD := 50      # 開局木材
const BUILD_COST := 10      # 蓋一棟要花多少
const REFUND := 5           # 拆房退多少
const WOOD_PER_HOUSE := 1   # 每棟每次產多少
const PRODUCE_INTERVAL := 2.0   # 每幾秒產一次
```

把遊戲的「數值」集中放在最上面,是好習慣。之後要調整平衡(難度),只改這裡就好,不必翻整份程式。**這就是遊戲設計師說的「調參數」。**

### 2. 遊戲狀態變數

```gdscript
var wood := START_WOOD      # 目前有多少木材
var produce_timer := 0.0    # 計時用
```

`wood` 就是遊戲的核心數字。所有經營遊戲的本質,都是「玩家在管理一堆數字」。

### 3. 房子會產出木材(在 `_process` 裡)

```gdscript
if buildings.size() > 0:
    produce_timer += delta          # delta 是「距離上一幀過了幾秒」
    if produce_timer >= PRODUCE_INTERVAL:
        produce_timer -= PRODUCE_INTERVAL
        wood += buildings.size() * WOOD_PER_HOUSE
        queue_redraw()
```

**重點概念 `delta`**:遊戲每秒跑幾十幀,每一幀的 `_process` 都會拿到「這一幀過了多少時間」。我們把它累加起來,湊滿 2 秒就產一次木材。這是遊戲裡做「定時事件」最標準的寫法。

### 4. 蓋房前先檢查條件(在 `_unhandled_input` 裡)

```gdscript
if buildings.has(cell):
    _show_message("這格已經有建築了")
    return
if wood < BUILD_COST:
    _show_message("木材不足!需要 %d" % BUILD_COST)
    return
wood -= BUILD_COST
buildings[cell] = true
```

這段就是「規則」。遊戲好不好玩,很大程度取決於這些限制設計得好不好。`return` 的意思是「條件不符,直接結束、什麼都不做」。

### 5. 在畫面上畫文字(`_draw_ui`)

```gdscript
var font := ThemeDB.fallback_font   # 借用 Godot 內建字型
draw_string(font, Vector2(20, 36), "木材: %d" % wood, ...)
```

我們用 `draw_string` 直接把字畫到畫面上,借用引擎內建字型,所以不必匯入任何字型檔。`%d` 是「把後面的數字填進來」,`%.0f` 是「填一個不帶小數的浮點數」。

---

## Step 3:動手調整,體會「遊戲平衡」

現在你能像真正的遊戲設計師一樣調數值了。每改一次存檔 + F5:

1. 把 `BUILD_COST` 改成 `30`、`START_WOOD` 改成 `40` → 開局只夠蓋一棟,壓力變大。
2. 把 `WOOD_PER_HOUSE` 改成 `3` → 經濟滾得更快,容易進入「蓋越多賺越多」的爽感(但也可能太簡單)。
3. 把 `PRODUCE_INTERVAL` 改成 `0.5` → 產出變超快。

**思考題**:怎樣的數值會讓玩家「需要想一下才蓋」、而不是「無腦狂蓋」或「卡死蓋不動」?這就是經營遊戲設計的核心難題,沒有標準答案,要靠測試手感。

---

## Step 4(選做)挑戰:加入第二種資源

試著仿照 `wood`,自己加一個 `var stone := 0`。讓:

- 蓋房子除了花木材,也要花一點石頭。
- 在 `_draw_ui` 多畫一行顯示石頭數量。

卡住沒關係,把你寫的貼給我,我幫你看。

---

## 你這一課學到的

- 把遊戲數值集中成參數,方便調平衡。
- 用 `delta` 累加做「定時事件」(房子定期產出)。
- 用 `if ... return` 設計遊戲規則與限制。
- 用 `draw_string` 把狀態顯示給玩家。
- 最重要的:**遊戲的本質是管理數字 + 設計限制**。

---

## 第三課預告

到目前為止畫面都是手繪方塊。第三課我們會:

- 換上真正的圖片素材(從免費素材庫 Kenney.nl 抓等距資產),讓畫面變漂亮。
- 學會用 `Sprite2D` 節點與 Y-sort(讓前後的房子正確遮擋)。
- 把「建築種類」做成資料,開始有不只一種建築。

準備好就跟我說「第三課」。
