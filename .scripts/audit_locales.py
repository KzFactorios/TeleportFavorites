#!/usr/bin/env python3
"""
Audit locale strings.cfg files against locale/en/strings.cfg.

Usage (from mod root):
  python .scripts/audit_locales.py
  python .scripts/audit_locales.py --quiet

Exits with code 1 if any locale has MISSING, EXTRA, or MISPLACED keys
(template_strings.cfg EMPTY values are allowed).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Dict, List, Set

# Allow importing sibling _locale_parser when run as script
_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

from _locale_parser import load_parsed  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description="Audit locale files vs en/strings.cfg")
    ap.add_argument(
        "--quiet",
        action="store_true",
        help="Only print per-locale counts, not individual keys",
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
        print(f"ERROR: canonical file not found: {en_path}", file=sys.stderr)
        return 2

    _parsed = load_parsed(en_path)
    en_lines = _parsed[1]
    en_key_to_section = _parsed[2]
    en_keys: Set[str] = set(en_key_to_section.keys())
    # Map key -> expected section (from en)
    en_key_section: Dict[str, str] = dict(en_key_to_section)

    template_path = locale_root / "template_strings.cfg"
    paths: List[Path] = [template_path]
    for d in sorted(locale_root.iterdir(), key=lambda p: p.name):
        if not d.is_dir() or d.name == "en":
            continue
        p = d / "strings.cfg"
        if p.is_file():
            paths.append(p)

    total_missing = 0
    total_extra = 0
    total_misplaced = 0
    total_empty = 0
    any_drift = False

    for path in paths:
        try:
            rel = path.relative_to(repo)
        except ValueError:
            rel = path
        _, loc_lines, loc_key_to_section, _ = load_parsed(path)
        loc_keys = set(loc_key_to_section.keys())

        missing = sorted(en_keys - loc_keys)
        extra = sorted(loc_keys - en_keys)

        misplaced: List[str] = []
        for k in sorted(en_keys & loc_keys):
            if en_key_section.get(k) != loc_key_to_section.get(k):
                misplaced.append(k)

        empty: List[str] = []
        for rec in loc_lines:
            if rec.kind == "entry" and rec.key and rec.value is not None:
                if rec.value.strip() == "":
                    empty.append(rec.key)

        is_template = path.name == "template_strings.cfg"

        n_miss = len(missing)
        n_ext = len(extra)
        n_mis = len(misplaced)
        n_emp = len(empty)

        total_missing += n_miss
        total_extra += n_ext
        total_misplaced += n_mis
        total_empty += n_emp

        drift = n_miss > 0 or n_ext > 0 or n_mis > 0
        if drift:
            any_drift = True

        if args.quiet:
            flag = "DRIFT" if drift else "OK"
            print(
                f"{rel}: MISSING={n_miss} EXTRA={n_ext} MISPLACED={n_mis} EMPTY={n_emp} [{flag}]"
            )
        else:
            print(f"=== {rel} ===")
            if missing:
                print("  MISSING:")
                for k in missing:
                    print(f"    {k}  (en section: [{en_key_section.get(k, '?')}])")
            if extra:
                print("  EXTRA:")
                for k in extra:
                    print(f"    {k}")
            if misplaced:
                print("  MISPLACED:")
                for k in misplaced:
                    print(
                        f"    {k}: en=[{en_key_section.get(k)}] "
                        f"file=[{loc_key_to_section.get(k)}]"
                    )
            if empty:
                print("  EMPTY:")
                for k in empty:
                    print(f"    {k}")
            if not missing and not extra and not misplaced and not empty:
                print("  (no issues)")
            elif not missing and not extra and not misplaced and empty and is_template:
                print("  (template: empty values expected for translators)")
            print()

    print(
        "TOTAL: "
        f"MISSING={total_missing} EXTRA={total_extra} "
        f"MISPLACED={total_misplaced} EMPTY={total_empty}"
    )

    return 1 if any_drift else 0


if __name__ == "__main__":
    raise SystemExit(main())
