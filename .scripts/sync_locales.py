#!/usr/bin/env python3
"""
Sync non-English locale/template strings.cfg files to match keys in en/strings.cfg.

Removes EXTRA keys, inserts MISSING keys after the best predecessor (en file order).

Dry-run by default; pass --write to modify files.

Usage (from mod root):
  python .scripts/sync_locales.py
  python .scripts/sync_locales.py --write
  python .scripts/sync_locales.py --write --placeholder english
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import List, Optional, Set, Tuple

_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

from _locale_parser import (  # noqa: E402
    ROOT_SECTION,
    LineRecord,
    flatten_en_order,
    load_parsed,
)


def detect_newline(raw: str) -> str:
    if "\r\n" in raw[:4000]:
        return "\r\n"
    return "\n"


def collect_sections(lines: List[LineRecord]) -> Set[str]:
    out: Set[str] = {ROOT_SECTION}
    for rec in lines:
        if rec.kind == "section" and rec.section:
            out.add(rec.section)
    return out


def keys_in_lines(lines: List[LineRecord]) -> Set[str]:
    s: Set[str] = set()
    for rec in lines:
        if rec.kind == "entry" and rec.key:
            s.add(rec.key)
    return s


def line_index_for_key(lines: List[LineRecord], key: str) -> Optional[int]:
    for i, rec in enumerate(lines):
        if rec.kind == "entry" and rec.key == key:
            return i
    return None


def remove_extra_entries(lines: List[LineRecord], en_keys: Set[str]) -> Tuple[List[LineRecord], List[str]]:
    removed: List[str] = []
    kept: List[LineRecord] = []
    for rec in lines:
        if rec.kind == "entry" and rec.key and rec.key not in en_keys:
            removed.append(rec.key)
            continue
        kept.append(rec)
    return kept, removed


def find_predecessor_key(
    en_flat: List[Tuple[str, str, str]],
    missing_idx: int,
    keys_in_file: Set[str],
) -> Optional[str]:
    for j in range(missing_idx - 1, -1, -1):
        pk = en_flat[j][1]
        if pk in keys_in_file:
            return pk
    return None


def sync_file(
    path: Path,
    en_flat: List[Tuple[str, str, str]],
    en_keys: Set[str],
    placeholder: str,
    dry_run: bool,
) -> Tuple[bool, List[str], List[str]]:
    """
    Returns (changed, removed_keys, inserted_keys)
    """
    raw, lines, _, _ = load_parsed(path)
    file_nl = detect_newline(raw)
    nl = file_nl

    is_template = path.name == "template_strings.cfg"

    new_lines, removed = remove_extra_entries(lines, en_keys)
    keys_now = keys_in_lines(new_lines)

    inserted: List[str] = []
    changed = bool(removed)

    # Insert missing keys in en file order
    for idx, (sec, key, val_en) in enumerate(en_flat):
        if key in keys_now:
            continue

        pred = find_predecessor_key(en_flat, idx, keys_now)
        if pred is not None:
            li = line_index_for_key(new_lines, pred)
            if li is None:
                raise RuntimeError(f"{path}: predecessor {pred} not found after prune")
            pos = li + 1
        else:
            pos = 0

        need_section_header = sec != ROOT_SECTION and sec not in collect_sections(new_lines)

        # Value for new entry
        if is_template or placeholder == "empty":
            val = ""
        else:
            val = val_en

        to_insert: List[LineRecord] = []
        if need_section_header:
            to_insert.append(
                LineRecord(
                    kind="section",
                    text=f"[{sec}]{nl}",
                    section=sec,
                )
            )
        to_insert.append(
            LineRecord(
                kind="entry",
                text=f"{key}={val}{nl}",
                section=sec,
                key=key,
                value=val,
            )
        )

        # Insert section+entry at pos; if need header, both in order
        for i, block in enumerate(to_insert):
            new_lines.insert(pos + i, block)

        keys_now.add(key)
        inserted.append(key)
        changed = True

    if changed and not dry_run:
        out = "".join(rec.text for rec in new_lines)
        path.write_text(out, encoding="utf-8")

    return changed, removed, inserted


def main() -> int:
    ap = argparse.ArgumentParser(description="Sync locale files to match en/strings.cfg keys")
    ap.add_argument(
        "--write",
        action="store_true",
        help="Actually modify files (default: dry-run)",
    )
    ap.add_argument(
        "--placeholder",
        choices=("empty", "english"),
        default="empty",
        help="Fill inserted keys with empty string or English text (template always empty)",
    )
    ap.add_argument(
        "--locale-root",
        type=Path,
        default=None,
        help="Path to locale/ (default: <repo>/locale)",
    )
    args = ap.parse_args()

    repo = Path(__file__).resolve().parents[1]
    locale_root = args.locale_root or (repo / "locale")
    en_path = locale_root / "en" / "strings.cfg"
    if not en_path.is_file():
        print(f"ERROR: {en_path} not found", file=sys.stderr)
        return 2

    en_flat = flatten_en_order(en_path)
    en_keys = {t[1] for t in en_flat}

    targets: List[Path] = [locale_root / "template_strings.cfg"]
    for d in sorted(locale_root.iterdir(), key=lambda p: p.name):
        if not d.is_dir() or d.name == "en":
            continue
        p = d / "strings.cfg"
        if p.is_file():
            targets.append(p)

    dry_run = not args.write
    if dry_run:
        print("DRY RUN (use --write to apply)\n")

    any_changed = False
    for path in targets:
        try:
            rel = path.relative_to(repo)
        except ValueError:
            rel = path
        changed, removed, inserted = sync_file(path, en_flat, en_keys, args.placeholder, dry_run)
        if changed:
            any_changed = True
            print(f"{rel}:")
            if removed:
                print(f"  removed EXTRA ({len(removed)}): {', '.join(removed)}")
            if inserted:
                print(f"  inserted MISSING ({len(inserted)}): {', '.join(inserted)}")
        else:
            print(f"{rel}: (no changes)")

    if dry_run and any_changed:
        print("\nRe-run with --write to apply.")
    elif not dry_run and any_changed:
        print("\nFiles updated.")
    elif not any_changed:
        print("\nAll files already in sync.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
