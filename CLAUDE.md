# CLAUDE.md — D100 腳色卡專案

## 專案概述

Godot 4 製作的 D100 TRPG 腳色卡管理工具，視窗大小 1440×900。
所有 UI 由 GDScript 動態建立（無場景樹拖拉），角色資料存為 `.tres` Resource 檔。

## 技術棧

- **引擎**：Godot 4.4，Forward Plus 渲染
- **語言**：GDScript
- **資料格式**：Godot Resource（`.tres`），存於 `user://characters/`

## 架構

```
scripts/
  CharacterData.gd     # Resource 子類，儲存所有角色欄位與計算函式
  CharacterManager.gd  # Autoload（全域單例），管理多角色的 CRUD
  CharacterSheet.gd    # UI 控制器，動態建立所有欄位，load_data / flush_to_data 雙向同步
  MainScene.gd         # 主場景入口，連接按鈕與 CharacterSheet
scenes/
  MainScene.tscn       # 主場景，包含 TopBar 按鈕與 SheetContainer
```

### 資料流

1. `CharacterData`（Resource）是唯一的資料來源
2. `CharacterSheet.load_data(data)` → 把 data 寫入所有 UI 欄位
3. `CharacterSheet.flush_to_data()` → 把 UI 欄位回寫到 data
4. `CharacterManager.save_character(data)` → 用 `ResourceSaver` 寫入磁碟

### CharacterData 欄位結構

| 分類 | 欄位 | 說明 |
|------|------|------|
| 基本資訊 | `char_name`, `race`, `char_class`, `age`, `alignment` | 字串 |
| 屬性 | `attr_base/equip/temp/bonus` | Dictionary，key = STR/DEX/SKI/CON/RES/INT/WIS/CHA/SPI |
| 判定複合數值 | `compound_adj/temp` | Dictionary，key = 戰鬥/運動/操作/感知/知識/交涉，base=39 |
| 抗性 | `resist_adj/temp` | Dictionary，key = 抗毒素/抗控制/抗轉化/抗噴吐/抗魔法，base=26 |
| 生命/魔力 | `hp_base/bonus/cp/current`，`mp_*` | 整數，max = base+bonus+cp |
| 戰鬥數值 | `combat_attack/dodge/move`, `magic_resist`, `phys_resist`, `fortitude/spirit/soul` | 整數 |
| 元素抗性 | `res_fire/ice/lightning/acid/sound/psychic` | 整數 |
| 施法 | `cast_base_rate`(39), `cast_cumulative_penalty` | 整數 |
| 裝備 | `equipment` | Dictionary，14 個固定 slot |
| 技能 | `skills` | Dictionary，6 類 × 6 行，每行 `{name, difficulty, level}` |
| 其他效果 | `other_effects` | Array，每項 `{name, effect, note}` |
| 貨幣 | `currency_platinum/gold/silver/copper` | 整數 |
| 備註 | `notes` | String |

## 首次開啟步驟（必做）

1. 用 Godot 4 開啟 `project.godot`
2. **Project → Project Settings → Autoload**
3. 新增 `res://scripts/CharacterManager.gd`，命名 `CharacterManager`

沒有設定 Autoload 則存讀檔功能無法運作。

## 待實作功能（已知 TODO）

- `MainScene.gd _on_new()`：彈出輸入角色名稱的對話框（目前用時間戳自動命名）
- `MainScene.gd _on_open()`：彈出角色選擇清單（目前只載入第一個）
- `CharacterData.gd`：判定複合數值的正確計算公式（目前 base 固定為 39）
- 主題樣式：顏色、字型調整
- 法術書頁面

## 開發注意事項

- UI 全部動態生成於 `CharacterSheet._build_ui()`，**不要**在 `MainScene.tscn` 裡手動拖放 CharacterSheet 的子節點
- `flush_to_data()` 目前尚未回寫技能、其他效果、戰鬥數值、施法欄位，新增功能時需補齊
- `_recalc_*` 系列函式只更新 Label，不寫回 `_data`，存檔前必須呼叫 `flush_to_data()`
- 角色名稱是存檔路徑的一部分（`user://characters/<name>.tres`），改名需要刪舊建新
