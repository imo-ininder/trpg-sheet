#!/usr/bin/env python3
"""
parse_affixes.py
從 D100 詞綴速查表 CSV 解析為標準化 JSON

Usage:
    python parse_affixes.py affixes_source.csv -o ../data/affixes.json
"""

import csv
import json
import re
import sys
from typing import List, Dict, Any, Optional

# ── 槽位名稱對照表 ────────────────────────────────────
SLOT_MAP = {
    "武器": "weapon",
    "鎧甲": "armor",
    "盾牌": "shield",
    "法杖": "staff",
    "魔導槍械": "gun",
    "頭環": "headband",
    "手套": "gloves",
    "手環": "bracelet",
    "披風": "cloak",
    "腰帶": "belt",
    "鞋子": "boots",
    "項鍊": "necklace",
    "戒指": "ring",
    "主要裝備": "weapon",  # 特殊：可能指主手
    "武器(弓)": "weapon",
}

# ── Stat 關鍵字偵測 ───────────────────────────────────
STAT_PATTERNS = {
    # 屬性
    "STR": r"STR|力量",
    "DEX": r"DEX|敏捷",
    "SKI": r"SKI|技巧",
    "CON": r"CON|體質",
    "RES": r"RES|抗性(?!增加)",  # 排除「抗性增加」詞綴名稱
    "INT": r"INT|智力",
    "WIS": r"WIS|感知",
    "CHA": r"CHA|魅力",
    "SPI": r"SPI|靈魂",
    # HP/MP
    "hp_bonus": r"HP上限|血量|生命值",
    "mp_bonus": r"SP上限|魔力|法力值",
    # 戰鬥數值
    "combat_move": r"移動格數|移動速度",
    "combat_dodge": r"閃避",
    "combat_attack": r"攻擊命中",
    # 抗性
    "phys_resist": r"物抗",
    "magic_resist": r"法抗",
    "res_ice": r"冰抗",
    "res_fire": r"火抗",
    "res_lightning": r"電抗",
    "res_acid": r"酸抗",
    "res_sound": r"音波|音抗",
    "res_light": r"光抗",
    "res_dark": r"暗抗",
}

# 特殊詞綴：明確知道是 special type（純效果）
SPECIAL_AFFIXES = {
    "光亮", "迴力", "及遠", "狂斬", "投擲", "活化", "無相",
    "追擊", "追蹤", "適行", "光能", "靈化", "牽亡", "舞空",
    "鏡映", "斬首", "天命", "避矢", "囤法", "破敵", "護命",
    "三願", "王者", "金屬偵測感知", "雷鳴閃電", "枯萎",
    "偵測敵人", "醫療強效", "警示", "不動", "烈士意志",
    "空行", "水面行走", "飛翔之翼", "位移斗篷", "繭化",
    "鏡影複製", "空間跳躍", "北地", "游泳、攀爬", "儲物",
    "賢者之手", "豹爪", "防禦精熟", "大小變換", "弓杖",
    "重力", "幽影", "連線", "幽冥", "超魔法", "神射",
    "瓦解", "引箭", "聚焦", "致命精確", "欺詐", "歌唱",
    "流星", "爆擊球", "狂怒球", "耐力球", "隱形",
    # 元素穿透視為 special（因為效果是穿透，不是直接加數值）
    "冰冷穿透", "火焰穿透", "閃電穿透", "酸蝕穿透",
    # 元素攻擊效果
    "電擊", "凍寒", "炙燄", "慈悲", "捨命", "護身",
    "猛擊", "目盲", "鋒利", "冰爆", "電爆", "燄爆",
    "雷鳴", "神聖", "守序", "邪惡", "混沌",
    "寒冰增幅", "電擊增幅", "火焰增幅",
    "冰爆增幅", "電爆增幅", "焰爆增幅",
    "游擊", "重拳【打臉】", "精準", "暗影", "滑溜", "躡行",
    "防禦",  # 雖然有數值，但效果描述較複雜
}


def parse_cost_values(cost_str: str) -> List[int]:
    """
    解析加值字串，支援：
    - "1~6" → [1,2,3,4,5,6]
    - "1、3、5" → [1,3,5]
    - "2、4、6、8、10" → [2,4,6,8,10]
    - "3（鎧甲、盾牌）\n2（武器）" → [3, 2] (取不重複)
    """
    cost_str = cost_str.strip()

    # 處理多行格式（不同部位不同加值），取所有唯一值
    if '\n' in cost_str or '（' in cost_str:
        # 提取所有數字
        numbers = re.findall(r'\d+', cost_str)
        unique = sorted(set(int(n) for n in numbers))
        return unique if unique else [0]

    # 範圍格式 "1~6"
    if '~' in cost_str:
        match = re.match(r'(\d+)~(\d+)', cost_str)
        if match:
            start, end = int(match.group(1)), int(match.group(2))
            return list(range(start, end + 1))

    # 離散值 "1、3、5"
    if '、' in cost_str:
        numbers = cost_str.split('、')
        return [int(n.strip()) for n in numbers if n.strip().isdigit()]

    # 單一值
    if cost_str.isdigit():
        return [int(cost_str)]

    # 預設
    return [0]


def parse_slots(slots_str: str) -> List[str]:
    """解析部位字串，支援多行和頓號分隔"""
    slots_str = slots_str.replace('\n', '、').replace(',', '、')
    parts = slots_str.split('、')

    result = []
    for part in parts:
        part = part.strip()
        if part in SLOT_MAP:
            slot_key = SLOT_MAP[part]
            if slot_key not in result:
                result.append(slot_key)

    return result if result else ["unknown"]


def detect_stats_from_effect(affix_name: str, effect: str) -> List[str]:
    """從效果描述中偵測影響的 stat keys"""
    detected = []

    # 特殊處理：屬性增加類直接從名稱提取
    for stat in ["STR", "DEX", "SKI", "CON", "RES", "INT", "WIS", "CHA", "SPI"]:
        if f"{stat} 增加" in affix_name or f"{stat}增加" in affix_name:
            return [stat]

    # 從效果文字中偵測
    for stat_key, pattern in STAT_PATTERNS.items():
        if re.search(pattern, effect, re.IGNORECASE):
            if stat_key not in detected:
                detected.append(stat_key)

    return detected


def extract_value_from_effect(effect: str, cost: int, affix_name: str) -> Optional[int]:
    """
    從效果描述中提取數值
    例如：「增加基本STR數值（最高到＋6）」→ 取 cost 作為 value
    """
    # 如果描述中有「增加X點」「+X」等，嘗試提取
    # 但大多數情況下 value = cost

    # 特殊：HP/MP 增福 - 格式：「（6、12、18點HP。）」
    # 需要根據 cost 來決定使用哪個數字
    if "HP上限" in effect or "SP上限" in effect or "血量增福" in affix_name or "魔力增福" in affix_name:
        # 提取所有數字（6、12、18）
        numbers = re.findall(r'(\d+)點', effect)
        if numbers:
            # 根據 cost 對應：cost 1→6, cost 3→12, cost 5→18
            # 使用簡單映射
            cost_to_index = {1: 0, 3: 1, 5: 2}
            idx = cost_to_index.get(cost, 0)
            if idx < len(numbers):
                return int(numbers[idx])

    # 抗性增加 (百分比) - 格式：「（5%、10%、15%、20%、25%）」
    if "抗性增加" in affix_name and "%" in effect:
        numbers = re.findall(r'(\d+)%', effect)
        if numbers:
            # cost 1~5 對應 index 0~4
            idx = cost - 1
            if idx < len(numbers):
                return int(numbers[idx])

    # 移動力 - cost = value（已經正確）

    # 預設：cost = value
    return cost


def is_special_affix(affix_name: str, effect: str) -> bool:
    """判斷是否為 special type（純效果）"""
    if affix_name in SPECIAL_AFFIXES:
        return True

    # 效果描述超長且沒有簡單數值加成
    if len(effect) > 100 and not re.search(r'增加\d+|＋\d+', effect):
        return True

    return False


def generate_affix_id(affix_name: str) -> str:
    """產生 affix id（拼音或簡化）"""
    # 移除特殊字元
    clean = re.sub(r'[【】\(\)（）、]', '', affix_name)
    clean = clean.replace(' ', '_').lower()

    # 簡單的中文轉拼音（這裡簡化為直接用中文，或自行擴展拼音庫）
    # 實際使用時可引入 pypinyin 庫
    return clean if clean else f"affix_{hash(affix_name) % 10000}"


def generate_description(modifier, affix_name: str, effect: str) -> str:
    """產生簡短描述（優先從 effect 提取關鍵部分）"""
    # Special type 直接用 effect
    if isinstance(modifier, dict) and modifier.get("type") == "special":
        # 截取前 100 字
        return effect[:100] + ("..." if len(effect) > 100 else "")

    # 數值型：從 modifier 生成
    if isinstance(modifier, list):
        parts = []
        for mod in modifier:
            stat = mod.get("stat", "")
            value = mod.get("value", 0)
            parts.append(f"{stat.upper()} +{value}")
        return "、".join(parts)
    elif isinstance(modifier, dict):
        stat = modifier.get("stat", "")
        value = modifier.get("value", 0)
        mod_type = modifier.get("type", "add")

        if mod_type == "add":
            return f"{stat.upper()} +{value}"
        elif mod_type == "multiply":
            return f"{stat.upper()} +{int(value*100)}%"
        else:
            return effect[:50]

    return effect[:50]


def parse_affix(row: Dict[str, str]) -> Optional[Dict[str, Any]]:
    """解析單一詞綴列"""
    affix_name = row.get("名稱", "").strip()
    if not affix_name or affix_name == "名稱":
        return None

    slots_str = row.get("部位", "")
    cost_str = row.get("所需加值兌換", "")
    effect = row.get("效果", "").strip()

    # Parse
    slots = parse_slots(slots_str)
    costs = parse_cost_values(cost_str)
    stats = detect_stats_from_effect(affix_name, effect)
    is_special = is_special_affix(affix_name, effect)

    # Generate variants
    variants = []
    for cost in costs:
        if is_special:
            # Special type
            variant = {
                "cost": cost,
                "modifier": {
                    "type": "special",
                    "key": generate_affix_id(affix_name)
                },
                "description": effect[:150]
            }
        else:
            # 數值型
            if not stats:
                # 無法偵測 stat，標記為 special
                variant = {
                    "cost": cost,
                    "modifier": {
                        "type": "special",
                        "key": generate_affix_id(affix_name)
                    },
                    "description": effect[:150]
                }
            else:
                # 有 stat
                value = extract_value_from_effect(effect, cost, affix_name)

                modifiers = []
                for stat in stats:
                    modifiers.append({
                        "stat": stat,
                        "type": "add",
                        "value": value
                    })

                # 單 stat → dict，多 stat → array
                modifier = modifiers[0] if len(modifiers) == 1 else modifiers

                variant = {
                    "cost": cost,
                    "modifier": modifier,
                    "description": generate_description(modifier, affix_name, effect)
                }

        variants.append(variant)

    return {
        "id": generate_affix_id(affix_name),
        "affix_name": affix_name,
        "slots": slots,
        "variants": variants
    }


def main():
    if len(sys.argv) < 2:
        print("Usage: python parse_affixes.py <input.csv> [-o output.json]")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[3] if len(sys.argv) > 3 and sys.argv[2] == '-o' else "affixes.json"

    print(f"=== Affix Parser ===")
    print(f"Reading: {input_file}")

    affixes = []

    with open(input_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for i, row in enumerate(reader, start=2):
            affix = parse_affix(row)
            if affix:
                affixes.append(affix)
                print(f"  [{i}] {affix['affix_name']} → {len(affix['variants'])} variants")

    # Output JSON
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(affixes, f, ensure_ascii=False, indent=2)

    print(f"✓ 解析完成：{len(affixes)} 個詞綴")
    print(f"輸出至：{output_file}")


if __name__ == "__main__":
    main()
