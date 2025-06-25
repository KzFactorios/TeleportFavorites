# GPS String Format and Rules

- **GPS values must always be strings** in the format `xxx.yyy.s`:
  - `xxx`: X coordinate (may be negative, always zero-padded to a number of digits equal to `Constants.settings.GPS_PAD_NUMBER` (default: 3), sign included if negative)
  - `yyy`: Y coordinate (may be negative, always zero-padded to a number of digits equal to `Constants.settings.GPS_PAD_NUMBER` (default: 3), sign included if negative)
  - `s`: Surface index (always an integer, always positive, never padded)
- **Padding:** The X and Y values are always zero-padded to `Constants.settings.GPS_PAD_NUMBER` digits (e.g. `099`, `-001`). For values with more digits than the pad number, all digits are shown (e.g. `2048`, `-6000`).

```
┌───────────────────────────────────────────────────────────┐
│                     GPS String Format                     │
├───────────────┬───────────────────┬───────────────────────┤
│      xxx      │        yyy        │          s            │
│  X Coordinate │   Y Coordinate    │    Surface Index      │
│ (Zero-padded) │  (Zero-padded)    │   (Not padded)        │
├───────────────┴───────────────────┴───────────────────────┤
│                                                           │
│    "099.100.1"     "010.005.1"      "-123.456.2"          │
│                                                           │
└───────────────────────────────────────────────────────────┘

┌─────────────────────┬───────────────────────────────────┐
│ TeleportFavorites   │        Vanilla Factorio           │
│      Format         │            Format                 │
├─────────────────────┼───────────────────────────────────┤
│    "099.100.1"      │      "[gps=99,100,1]"             │
│    "-010.005.2"     │      "[gps=-10,5,2]"              │
└─────────────────────┴───────────────────────────────────┘
```
- **Negative numbers:** When a GPS string is constructed from a table or parsed from vanilla format, negative numbers may appear without padding (e.g. `-123.456.1`). This is valid and canonical for Factorio, and is the expected output for negative values. Do not expect negative numbers to be zero-padded after the minus sign.
- **Valid examples:**
  - `-123.456.1`      (x=-123, y=456, s=1)
  - `123.-456.1`      (x=123, y=-456, s=1)
  - `-123.-456.1`     (x=-123, y=-456, s=1)
  - `123.456.1`       (x=123, y=456, s=1)
  - `099.099.1`       (x=99, y=99, s=1)
  - `-100.099.1`      (x=-100, y=99, s=1)
  - `-101.050.1`      (x=-101, y=50, s=1)
  - `005.010.1`       (x=5, y=10, s=1)
  - `-005.-010.1`     (x=-5, y=-10, s=1)
  - `099.-001.1`      (x=99, y=-1, s=1)
  - `2048.-6000.1`    (x=2048, y=-6000, s=1)
- **GPS must never be a table or any other type.**
- If a GPS string is not valid, helpers will return `nil` or a blank GPS value. Always validate GPS strings before use.
- If a GPS string is encountered in the vanilla `[gps=x,y,s]` format, it will be normalized to the canonical string format on construction. **This vanilla format should never be passed around or stored elsewhere in the codebase; always convert immediately.**
- Helpers may parse GPS strings into tables for internal use, but the canonical value for all storage, comparison, and API is always a string.

---

# IMPORTANT: GPS String Format in TeleportFavorites (NOT Factorio gps_tag)

**The `gps` string used throughout the TeleportFavorites mod is NOT the same as Factorio's built-in `gps_tag` or `[gps=...]` rich text tags.**

- **TeleportFavorites `gps` format:**
  - Always a string in the format: `xxx.yyy.s` (e.g., `123.456.1`)
  - Where `xxx` = x coordinate, `yyy` = y coordinate, `s` = surface index
  - Used for persistent storage, lookups, and all favorite/tag logic in this mod.
  - See `core/utils/gps_helpers.lua` for parsing and formatting helpers.

- **Factorio's built-in `gps_tag`/rich text:**
  - Format: `[gps=x,y,surface]` (e.g., `[gps=123,456,1]`)
  - Used for chat, tooltips, and map pings in vanilla Factorio.
  - Not used for persistent storage or as a key in this mod.

## Why This Matters
- **Do NOT confuse the two formats!**
- All code, helpers, and persistent data in TeleportFavorites expect the `xxx.yyy.s` string format.
- If you need to display a clickable GPS in chat or a tooltip, use the helpers in `core/gps/gps.lua` to convert to/from Factorio's `[gps=...]` format as needed.
- Never store or pass a table or `[gps=...]` string as a favorite's `gps` value—always use the `xxx.yyy.s` string.

## Workaround/Advice
- If you need to interoperate with other mods or vanilla Factorio features that expect `[gps=...]`, always convert using the provided helpers.
- If you see code or documentation referring to `gps_tag`, `gps rich text`, or `[gps=...]`, remember this is **not** the same as the `gps` string in this mod.

---
<!--
Original user note for reference:
why am i seeing gps=[gps=bad,20,1]? a gps value, and we have been overr this before, so please update the docs with this note:
gps should only ever be a string, not a table, etc. The string should always be of the format "xxx.yyy.s" where the x and y values are padded to a constant value. If the values are more than 3 digits, then show all of the digits. Also, when a number is negative, a minus sign should prepend the number. surfaces are always positive so no need for the check there. so it is reasonable to see things such as "-xxx.yyy.s" or "xxx.-yyy.s" or "-xxx.-yyy.s" or "xxx.yyy.s", these are all valid. There are various formatting methods to return certain parts of the string and some of them may parse the string into tables, but those tables should never be the format of a gps string
-->