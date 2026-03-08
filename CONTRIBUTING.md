# Contributing to x16-PRos

Thank you for your interest in contributing to x16-PRos! This document provides guidelines for developing programs and contributing to the operating system.

---

## Coding Standards

All code must be written in **NASM assembly language** and follow these conventions:

### Naming Conventions

- **Functions**: Use lowercase with underscores
  ```nasm
  load_file:
  print_string:
  calculate_checksum:
  ```

- **Constants**: Use UPPERCASE with underscores
  ```nasm
  BUFFER_SIZE equ 512
  MAX_FILENAME_LENGTH equ 11
  VIDEO_MEMORY equ 0xB800
  ```

- **Variables**: Use lowercase with underscores
  ```nasm
  file_buffer: times 512 db 0
  current_position: dw 0
  error_flag: db 0
  ```

### Code Formatting

- Use **4 spaces** for indentation inside functions (no tabs)
- Place function labels at column 0 (no indentation)
- Add blank lines between functions for readability

**Example:**

```nasm
print_hello:
    mov ah, 0x01
    mov si, hello_msg
    int 0x21
    ret
```

### Function Documentation

For complex functions, add a documentation header using this format:

```nasm
; ========================================================================
; FUNCTION_NAME - Brief description of what the function does
; IN:  AX = input parameter description
;      BX = another input parameter
; OUT: AX = return value description
;      CF = set on error, clear on success
;
; NOTE: Additional notes, warnings, or usage examples
; ========================================================================

function_name:
    ; Function implementation with 4-space indentation
    mov ax, bx
    ret
```

### Comments

- Use comments to explain **why** code does something, not **what** it does
- Complex algorithms should have explanatory comments
- Keep comments concise and in English

**Good:**
```nasm
; Convert LBA to CHS for BIOS compatibility
mov dx, ax
```

**Avoid:**
```nasm
; Move AX to DX
mov dx, ax
```

---

## Writing Programs for x16-PRos

### Program Structure

All programs must:

1. Be written in NASM assembly
2. Use `ORG 0x8000` as the load address
3. Call PRos kernel API functions (see [API.md](docs/API.md))
4. End with `ret` to return control to the terminal
5. Be compiled to `.BIN` format

**Minimal Program Template:**

```nasm
[BITS 16]
[ORG 0x8000]

start:
    mov ah, 0x01
    mov si, hello_msg
    int 0x21
    ret

hello_msg db 'Hello, PRos!', 10, 13, 0
```

### Testing Your Program

1. Place your `.asm` file in the `programs/` directory and update build script
2. Rebuild the disk image: `./build-linux.sh`
3. Run in QEMU: `./run-linux.sh`
4. Test all functionality thoroughly
5. Handle errors gracefully

---

## Submitting Contributions

### Before Submitting

- [X] Code follows the style guidelines above
- [X] Program has been tested in QEMU
- [X] No bugs or crashes detected
- [X] Documentation updated if needed
- [X] All comments and descriptions are in **English**

### Creating Issues

When reporting bugs or suggesting features:

1. Use **English** for all communication
2. Search existing issues to avoid duplicates
3. Provide clear, descriptive titles
4. Include:
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - System information (QEMU version, etc.)
   - Screenshots if applicable

**Issue Template:**

```
**Description:**
Brief description of the bug or feature request

**Steps to Reproduce:** (for bugs)
1. Start the OS
2. Run command X
3. Observe error Y

**Expected Behavior:**
What should happen

**Actual Behavior:**
What actually happens

**Environment:**
- x16-PRos version: 0.5.9s
- Emulator: QEMU 8.0
```

### Creating Pull Requests

1. Fork the repository
2. Create a feature branch
3. Make your changes following the coding standards
4. Test thoroughly in QEMU and also (if possible) on a real computer
5. Commit with clear messages
6. Open a Pull Request with:
   - Clear title in **English**
   - Description of changes
   - Reference to related issues (if any)

**Pull Request Template:**

```
**Changes:**
- Added new program: EXAMPLE.BIN
- Fixed bug in file system driver
- Updated documentation

**Testing:**
- Tested in QEMU
- No crashes or errors detected
- All existing features still work

**Related Issues:**
Closes <link>
```

---

## Communication

### Questions and Discussions

> [!IMPORTANT]
> Do not create GitHub issues for general questions or discussions.

Instead:

- **Email**: prox.dev.code@gmail.com
- Use email for:
  - General questions about development
  - Feature suggestions (before creating issues)
  - Requests for guidance
  - Collaboration proposals

### Language Requirements

> [!IMPORTANT]
>  All code comments, issue descriptions, pull request descriptions, and documentation must be written in **English**. This ensures the project remains accessible to the international community.

**Acceptable**:
- Code comments in English
- Issue titles in English
- README updates in English

**Not Acceptable**:
- Code comments in other languages
- Issues or PRs with non-English descriptions

---


## License

By contributing to x16-PRos, you agree that your contributions will be licensed under the MIT License.

---

<div align="center">

**Thank you for contributing to x16-PRos!**

Made with ❤️ by PRoX

</div>
