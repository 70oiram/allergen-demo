# 過敏原 Demo（第三版）

以 Godot 4.3 製作的遊戲 Demo。

## 下載遊玩（Windows）
到 [Releases](https://github.com/70oiram/allergen-demo/releases/latest) 下載 `AllergenDemo-v3-Windows.exe`，直接雙擊執行，不需安裝 Godot。

## 線上遊玩
直接在瀏覽器開啟：https://70oiram.github.io/allergen-demo/ （首次載入約 90 MB）

## 執行
1. 安裝 [Godot 4.3](https://godotengine.org/download)。
2. 以 Godot 開啟此資料夾中的 `project.godot`（首次開啟會自動匯入素材）。
3. 按 F5 執行；主選單有「開始遊戲」與「遊戲教學」。

## 操作
- 抬頭時按住桌上的盤子往下拖，把盤子拉到面前；低頭後拿起叉子進食。
- 低頭時滑鼠靠近盤子左側，按住往右拖可推開盤子。
- W／S 抬頭／低頭（空白鍵或右側箭頭按鈕也可切換）；左上角筆記本記錄不能吃的東西。

## 結構
- `scripts/`：遊戲腳本（主要流程在 `game.gd`）
- `scenes/`：主選單與遊戲場景
- `assets/`：圖片、音效與音樂素材
- `tools/`：開發工具（教學圖片產生器，不會被匯出）

## 授權
- 字型：Noto Sans TC（SIL Open Font License 1.1，見 `assets/字型/OFL.txt`）
