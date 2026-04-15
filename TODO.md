TODO
- Item 的福文刻畫
- 高級詞墜用 check box enable 高級詞墜 selection
- 永恆聖器詞墜 check box enable 永恆聖器詞墜 selection
- 福文刻畫導致原本的 type 的詞墜擴充


*Affix or 道具效果會跟 item 最大加值互動時的草案*
  ---
  JSON 格式

  在 modifier 裡加兩個選填欄位：

  {
    "type": "add",
    "stat": "STR",
    "value": 0,
    "scale_by": "max_bonus",
    "scale_factor": 1.0
  }

  value 做常數基底（通常填 0），實際值 = value + max_bonus * scale_factor。沒有 scale_by 的話行為完全不變，向下相容。

  ---
  程式改動

  只需要把 max_bonus 沿呼叫鏈傳下去：

  collect_modifiers
    └─ _collect_from_modifier(modifier, result, source, item_max_bonus)
         └─ _collect_single_mod(mod, result, source, item_max_bonus)

  collect_modifiers 在拿到 item 之後已經能讀 item.get("max_bonus", 0)，所以只需要往下傳，不需要改簽名以外的邏輯。

  _collect_single_mod 裡加一行：

  var actual_value := float(mod.get("value", 0))
  if mod.get("scale_by", "") == "max_bonus":
      actual_value += float(item_max_bonus) * float(mod.get("scale_factor", 1.0))

  然後後面用 actual_value 取代原本的 mod.get("value", 0)。
