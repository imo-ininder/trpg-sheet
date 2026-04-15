## StatModifier.gd
## 一個數值修飾符，由 StatEngine 在計算時收集與套用

class_name StatModifier

enum Op {
	ADD,         ## 直接加算，最後 sum
	MULTIPLY,    ## 乘算，在 ADD 之後套用，product
	OVERRIDE,    ## 覆蓋，取最大值（最高優先權）
	EXTRA_SKILL, ## 授予額外技能／能力，stat_key = 技能鍵, value = 使用次數上限
}

var stat_key: String  ## 對應的 stat 鍵值（例如 "STR", "hp_max", "phys_resist"）
var op: Op
var value: float
var source: String    ## 來源描述（用於 debug / 未來 tooltip）

func _init(k: String, o: Op, v: float, src: String = "") -> void:
	stat_key = k
	op = o
	value = v
	source = src
