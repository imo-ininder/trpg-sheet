# D100 腳色卡 — Godot 4 專案

## 專案結構

```
dnd_sheet/
├── project.godot          ← 專案設定
├── scenes/
│   └── MainScene.tscn     ← 主場景
├── scripts/
│   ├── CharacterData.gd   ← 角色資料結構（Resource）
│   ├── CharacterManager.gd← 全域管理器（Autoload）
│   ├── MainScene.gd       ← 主場景邏輯
│   └── CharacterSheet.gd  ← 腳色卡 UI
└── resources/             ← 之後放字型、主題等
```

## 開啟前必做的設定（一次性）

1. 用 Godot 4 打開 `project.godot`
2. 到 **Project → Project Settings → Autoload**
3. 點「+」，路徑選 `res://scripts/CharacterManager.gd`，
   Name 填 `CharacterManager`，按 Add

這樣全域存讀檔功能才會啟用。

## 目前實作的功能

- 所有屬性欄位（STR/DEX/SKI 等）可輸入，總和自動計算
- 判定複合數值（戰鬥/運動等）調整值 + 臨時值，自動加總
- 抗性數值同上
- 生命/魔力：最大值自動算，HP/MP 進度條即時更新
- 裝備欄位、貨幣、備註
- 技能六類，每類 6 行（可填名稱/難度/等級）
- 其他效果：可動態新增列
- 施法成功率即時計算
- 角色資料存到 `user://characters/` 目錄（`.tres` 格式）

## 待補的東西（下一步討論）

- 新增/開啟角色的對話框 UI
- 判定複合數值的正確計算公式（需要你提供）
- 主題樣式（顏色、字型調整）
- 法術書頁面
