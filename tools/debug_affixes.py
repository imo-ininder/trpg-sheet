#!/usr/bin/env python3
"""
debug_affixes.py - Quick debug tool for affixes.json

Parses affixes.json and outputs a table showing each affix's variants,
their modifiers (type, stat, value), and descriptions.
"""

import json
import sys
from pathlib import Path

def format_modifier(mod):
    """Format a single modifier dict into readable string"""
    if isinstance(mod, dict):
        mod_type = mod.get("type", "?")
        if mod_type == "special":
            return f"[special: {mod.get('key', '?')}]"
        stat = mod.get("stat", "?")
        value = mod.get("value", "?")
        return f"{mod_type}({stat}, {value})"
    return str(mod)

def format_modifiers(modifier):
    """Format modifier (can be dict or array) into readable string"""
    if isinstance(modifier, list):
        return " | ".join(format_modifier(m) for m in modifier)
    return format_modifier(modifier)

def main():
    json_path = Path(__file__).parent.parent / "data" / "affixes.json"

    if not json_path.exists():
        print(f"Error: {json_path} not found", file=sys.stderr)
        sys.exit(1)

    with open(json_path, 'r', encoding='utf-8') as f:
        affixes = json.load(f)

    print(f"Total affixes: {len(affixes)}\n")
    print("=" * 140)

    for affix in affixes:
        affix_id = affix.get("id", "?")
        affix_name = affix.get("affix_name", "?")
        slots = ", ".join(affix.get("slots", []))
        variants = affix.get("variants", [])

        print(f"\n[{affix_id}] {affix_name}")
        print(f"  Slots: {slots}")
        print(f"  Variants: {len(variants)}")
        print("-" * 140)

        # Table header
        print(f"  {'Cost':<6} {'Modifier':<60} {'Description':<70}")
        print("  " + "-" * 138)

        for variant in variants:
            cost = variant.get("cost", "?")
            modifier = variant.get("modifier")
            description = variant.get("description", "")

            mod_str = format_modifiers(modifier)

            # Truncate description if too long
            if len(description) > 68:
                description = description[:65] + "..."

            print(f"  {str(cost):<6} {mod_str:<60} {description:<70}")

    print("\n" + "=" * 140)

    # Summary statistics
    total_variants = sum(len(a.get("variants", [])) for a in affixes)
    multi_stat_count = 0
    special_count = 0

    for affix in affixes:
        for variant in affix.get("variants", []):
            modifier = variant.get("modifier")
            if isinstance(modifier, list):
                multi_stat_count += 1
            elif isinstance(modifier, dict) and modifier.get("type") == "special":
                special_count += 1

    print(f"\nSummary:")
    print(f"  Total affixes: {len(affixes)}")
    print(f"  Total variants: {total_variants}")
    print(f"  Multi-stat variants: {multi_stat_count}")
    print(f"  Special variants: {special_count}")

if __name__ == "__main__":
    main()
