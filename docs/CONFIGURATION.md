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
| `THEME.CFG` | Terminal color palette | 16 lines of RGB values |
| `TIMEZONE.CFG` | Timezone offset | Integer hours from UTC |

---

## PROMPT.CFG

`PROMPT.CFG` configures the shell prompt.

Default fallback prompt:

```text
[$username@PRos] >
```

### Supported placeholders

- `$username` - value from `USER.CFG`

### How to edit

1. Open/create `PROMPT.CFG` in `CONF.DIR`
2. Write plain text template (no null byte)
3. Keep length <= 63 characters
4. Reboot the OS

---

## SYSTEM.CFG

Controls startup logo and sound.

### Keys

- `LOGO=<path>`  
  Path to BMP logo, e.g. `LOGO=BMP/LOGO.BMP`

- `LOGO_STRETCH=TRUE|FALSE`  
  Stretch logo to full screen

- `START_SOUND=TRUE|FALSE`  
  Enable/disable startup melody

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
- Recommended max: 31 characters

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

- 16 lines
- Each line is one RGB entry for a palette index

Use `THEME.BIN` for easier theme switching when available.

---

## TIMEZONE.CFG

Defines timezone offset

Write an integer to the file to change your time zone. For example `5` for UTC+5 or `-3` for UTC-3