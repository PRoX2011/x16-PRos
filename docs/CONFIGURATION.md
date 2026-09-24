# x16-PRos Configuration Guide

x16-PRos uses configuration files stored in `CONF.DIR` (except `SYSTEM.CFG`, which is at root).

## Configuration Files

| File | Purpose | Format / Notes |
|---|---|---|
| `SYSTEM.CFG` | Boot visual/audio behavior | `KEY=VALUE` lines |
| `FIRST_B.CFG` | First boot flag | `0` or `1` |
| `USER.CFG` | Username | Plain text, max 31 chars |
| `PASSWORD.CFG` | Encrypted password | XOR-encrypted payload |
| `PROMPT.CFG` | Shell prompt template | Max 63 chars |
| `THEME.CFG` | Terminal color palette | 16 lines of `index, r, g, b` |
| `TIMEZONE.CFG` | Timezone offset | Integer hours from UTC |
| `FONT.CFG` | Active font filename | Plain text, max 15 chars |

---

## PROMPT.CFG

`PROMPT.CFG` configures the shell prompt.

Default fallback prompt:

```text
[$username@PRos] >
```

### Supported placeholders

- `$username` - value from `USER.CFG`
- `%XX` - raw byte from a two-digit hex code, e.g. `%0A` (line feed) or `%20` (space).
  An invalid hex sequence is emitted as a literal `%`.

### How to edit

1. Open/create `PROMPT.CFG` in `CONF.DIR`
2. Write plain text template (no null byte)
3. Keep length <= 63 characters (the kernel truncates longer prompts)
4. Reboot the OS

---

## SYSTEM.CFG

Controls startup logo and sound.

### Keys

- `LOGO=<path>`
  Path to BMP logo, e.g. `LOGO=BMP/LOGO.BMP`. Default: `BMP/LOGO.BMP`

- `LOGO_STRETCH=TRUE|FALSE`
  Stretch logo to full screen. Default: `FALSE`

- `START_SOUND=TRUE|FALSE`
  Enable/disable startup melody. Default: `TRUE`

Boolean values are matched on the first character only and are case-insensitive:
`T`/`t` means true, anything else means false. Lines beginning with `#` are treated as
comments and skipped.

Example:

```text
LOGO=BMP/LOGO.BMP
LOGO_STRETCH=FALSE
START_SOUND=TRUE
```

---

## USER.CFG

Stores the username used in prompt and user-facing UI.

- Plain text

---

## PASSWORD.CFG

Stores XOR-encrypted password data.  
Encryption key is defined in `src/kernel/features/encrypt.asm`.

Set password by:

1. Running `SETUP.BIN` on first boot (recommended), or
2. Writing encrypted content manually (advanced)

---

## FIRST_B.CFG

Controls first-boot setup behavior.

- `1` -> run setup flow (`SETUP.BIN`)
- `0` -> normal boot

---

## THEME.CFG

Defines terminal palette.

- Exactly 16 lines, one per palette index
- Each line has the form `index, r, g, b`
  - `index` - palette slot `0`-`15`
  - `r`, `g`, `b` - decimal color components, `0`-`255`
  - Separators are commas; surrounding spaces/tabs are allowed

Example line:

```text
0, 0, 0, 0
1, 0, 0, 170
```

---

## TIMEZONE.CFG

Defines timezone offset

Write a signed integer (hours from UTC) to the file to change your time zone. For example
`5` for UTC+5 or `-3` for UTC-3.

---

## FONT.CFG

Stores the filename of the active console font.

- Plain text, first line only
- Max 15 characters (longer names are trimmed)
- The font is loaded from `FONTS.DIR/<name>`
- If the file is missing or empty, the kernel falls back to `FONTS.DIR/DEFAULT.FNT`
- A font file must be exactly 4096 bytes (256 CP866 glyphs x 8x16 pixels)