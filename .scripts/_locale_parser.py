#!/usr/bin/env python3
"""
Shared parser for Factorio-style locale strings.cfg files.
Used by audit_locales.py and sync_locales.py.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Literal, Optional, Tuple

# Synthetic section id for lines before the first [section] header.
ROOT_SECTION = "<root>"

SECTION_RE = re.compile(r"^\s*\[([^\]]+)\]\s*$")
# Keys: letters, digits, underscore, dot, hyphen (matches plan + Factorio conventions).
ENTRY_RE = re.compile(r"^([A-Za-z0-9_.\-]+)\s*=(.*)$")


@dataclass
class LineRecord:
    kind: Literal["raw", "blank", "comment", "section", "entry"]
    text: str  # full line including newline if present
    section: Optional[str] = None  # current section after this line is processed (for entry)
    key: Optional[str] = None
    value: Optional[str] = None


def _strip_bom(s: str) -> str:
    if s.startswith("\ufeff"):
        return s[1:]
    return s


def is_comment_line(line: str) -> bool:
    s = _strip_bom(line).strip()
    return bool(s) and (s.startswith("#") or s.startswith(";"))


def parse_lines(text: str) -> Tuple[List[LineRecord], Dict[str, str], List[Tuple[str, str]]]:
    """
    Parse file text into line records and key metadata.

    Returns:
      - lines: LineRecord per input line (kind + entry metadata)
      - key_to_section: last section each key appears in (duplicates: last wins)
      - ordered_pairs: (section, key) in file order for each entry line
    """
    # Preserve line endings by splitting with keepends
    parts = text.splitlines(keepends=True)
    lines: List[LineRecord] = []
    current_section = ROOT_SECTION
    key_to_section: Dict[str, str] = {}
    ordered_pairs: List[Tuple[str, str]] = []

    for part in parts:
        if not part:
            lines.append(LineRecord(kind="blank", text="\n"))
            continue
        nl = ""
        body = part
        if body.endswith("\r\n"):
            nl = "\r\n"
            body = body[:-2]
        elif body.endswith("\n"):
            nl = "\n"
            body = body[:-1]
        elif body.endswith("\r"):
            nl = "\r"
            body = body[:-1]

        if not body.strip():
            lines.append(LineRecord(kind="blank", text=part))
            continue

        if is_comment_line(body):
            lines.append(LineRecord(kind="comment", text=part))
            continue

        msec = SECTION_RE.match(body.strip())
        if msec:
            current_section = msec.group(1).strip()
            lines.append(LineRecord(kind="section", text=part, section=current_section))
            continue

        ment = ENTRY_RE.match(body)
        if ment:
            k = ment.group(1)
            v = ment.group(2)
            key_to_section[k] = current_section
            ordered_pairs.append((current_section, k))
            lines.append(
                LineRecord(
                    kind="entry",
                    text=part,
                    section=current_section,
                    key=k,
                    value=v,
                )
            )
            continue

        # Unrecognized — keep as raw passthrough
        lines.append(LineRecord(kind="raw", text=part))

    return lines, key_to_section, ordered_pairs


def load_parsed(path: Path) -> Tuple[str, List[LineRecord], Dict[str, str], List[Tuple[str, str]]]:
    raw = path.read_text(encoding="utf-8")
    lines, key_to_section, ordered_pairs = parse_lines(raw)
    return raw, lines, key_to_section, ordered_pairs


def en_key_order(ordered_pairs: List[Tuple[str, str]]) -> List[str]:
    return [k for _, k in ordered_pairs]


def ordered_entries_with_values(lines: List[LineRecord]) -> List[Tuple[str, str, str]]:
    """(section, key, value) for each entry line, in file order."""
    out: List[Tuple[str, str, str]] = []
    for rec in lines:
        if rec.kind == "entry" and rec.key is not None and rec.value is not None:
            sec = rec.section if rec.section is not None else ROOT_SECTION
            out.append((sec, rec.key, rec.value))
    return out


def flatten_en_order(path: Path) -> List[Tuple[str, str, str]]:
    """Return list of (section, key, value) for each entry in file order."""
    _, lines, _, _ = load_parsed(path)
    return ordered_entries_with_values(lines)
