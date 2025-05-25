# GPS String Format and Rules

- **GPS values must always be strings** in the format `xxx.yyy.s`:
  - `xxx`: X coordinate (may be negative, always zero-padded to a number of digits equal to `Constants.settings.GPS_PAD_NUMBER` (default: 3), sign included if negative)
  - `yyy`: Y coordinate (may be negative, always zero-padded to a number of digits equal to `Constants.settings.GPS_PAD_NUMBER` (default: 3), sign included if negative)
  - `s`: Surface index (always an integer, always positive, never padded)
- **Padding:** The X and Y values are always zero-padded to `Constants.settings.GPS_PAD_NUMBER` digits (e.g. `099`, `-001`). For values with more digits than the pad number, all digits are shown (e.g. `2048`, `-6000`).
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
<!--
Original user note for reference:
why am i seeing gps=[gps=bad,20,1]? a gps value, and we have been overr this before, so please update the docs with this note:
gps should only ever be a string, not a table, etc. The string should always be of the format "xxx.yyy.s" where the x and y values are padded to a constant value. If the values are more than 3 digits, then show all of the digits. Also, when a number is negative, a minus sign should prepend the number. surfaces are always positive so no need for the check there. so it is reasonable to see things such as "-xxx.yyy.s" or "xxx.-yyy.s" or "-xxx.-yyy.s" or "xxx.yyy.s", these are all valid. There are various formatting methods to return certain parts of the string and some of them may parse the string into tables, but those tables should never be the format of a gps string
-->