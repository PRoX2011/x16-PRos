<div align="center">

<img src="docs/assets/baner.jpg" width=100%>

<h1>x16-PRos Operating System</h1>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](#license)
[![Version](https://img.shields.io/badge/version-0.6.5-blue.svg)](#)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)](#contributing)

**A minimalistic 16-bit operating system written in NASM for x86 architecture**

[Website](https://x16-pros.prosdev.org/) • [Programs Repository](https://github.com/PRoX2011/programs4pros/) • [API Documentation](docs/API.md)

<img src="docs/screenshots/terminal.png" width=75%>

---

</div>


## Overview

**x16-PRos** is a lightweight real-mode operating system designed for the x86 architecture and written entirely in NASM assembly. It features a command-line interface, supports the FAT12 file system, and includes a large standard software suite. This OS demonstrates fundamental operating system design principles, including booting, file system management, interrupt handling, and hardware interaction.

Designed for simplicity and educational value, x16-PRos provides a platform for low-level programming enthusiasts to explore bare-metal development on x86 systems.

> [!IMPORTANT]  
> The project needs contributors. Now only I, PRoX2011, is working on the kernel, but I can’t do everything alone. I would like to ask you how to help the project.
> - Programs
> - Development of a compatibility layer with MS DOS
> - Improved documentation and instructions
>   
> If you help - thank you so much

<div style="display: flex; flex-direction: row; gap: 20px">
  <img src="docs/screenshots/setup.png" width=45%>
  <img src="docs/screenshots/file_managment.png" width=45%>
</div>
<br>
<div style="display: flex; flex-direction: row; gap: 20px">
  <img src="docs/screenshots/view_comand.png" width=45%>
  <img src="docs/screenshots/password_screen.png" width=45%>
</div>

---

[![Stargazers over time](https://starchart.cc/PRoX2011/x16-PRos.svg?variant=adaptive)](https://starchart.cc/PRoX2011/x16-PRos)

---


## Key Features

- **MS-DOS Compatibility**: Native support for running standard MS-DOS `.COM` executables.
- **Encrypted Password System**: XOR-based password encryption with custom key
- **User Authentication**: Login system with configurable user account
- **Password Protection**: Encrypted PASSWORD.CFG prevents plaintext password storage
- **Customizable Prompts**: User-defined command prompt via PROMPT.CFG
- **Username Support**: Personalized user sessions stored in USER.CFG
- **Color Themes**: Multiple color palettes (DEFAULT, GROOVYBOX, UBUNTU) and fully customizable THEME.CFG if 3 standard themes are not enough for you
- **First-Boot Setup**: Automated SETUP.BIN execution on initial startup
- **Auto-Execution**: AUTOEXEC.BIN support for startup scripts
- **Mouse Driver**: Full PS/2 and USB mouse support
- **Directory Support**: Create, delete, and navigate directories (MKDIR, DELDIR, CD)
- **File Management**: Complete CRUD operations on files
- **File Operations**: COPY, REN, DEL, TOUCH, WRITE commands
- **File Inspection**: CAT, SIZE, HEAD, TAIL, GREP utilities
- **BMP Image Viewer**: 256-color BMP rendering with 2x upscaling support
- **Parameter Passing**: Command-line argument support for applications
- **API Access**: Comprehensive kernel API for file, string, and output operations
- **Debugging Tools**: CPU info display, memory viewer, register inspection

---


## 🖥️ PRos Terminal

The system includes a powerful terminal - **PRos Terminal**. It not only allows you to launch programs but also offers a wide range of built-in commands and utilities.

> [!NOTE]  
> To run a program, enter the name of the executable file (.BIN or .COM) with or without an extension. Programs will be launched from any directory if its file is placed in the BIN/ directory, and if the program file is not found there, the system will try to find the program in the current, working directory

<div style="display: flex; flex-direction: row; gap: 20px">
  <img src="docs/screenshots/dir.png" width=45%>
  <img src="docs/screenshots/fetch.png" width=45%>
</div>
<br>
<div style="display: flex; flex-direction: row; gap: 20px">
  <img src="docs/screenshots/help_menu.png" width=45%>
  <img src="docs/screenshots/cpu_comand.png" width=45%>
</div>

#### Basic Commands
| Command | Description |
|---------|-------------|
| `help` | Display categorized command reference with navigation |
| `info` | Show system information and OS details |
| `cls` | Clear terminal screen |
| `ver` | Display PRos terminal version |
| `exit` | Exit to bootloader |

#### System Information
| Command | Description |
|---------|-------------|
| `cpu` | Display detailed CPU information (family, model, cores, cache) |
| `date` | Show current date (DD/MM/YY format) |
| `time` | Show current time (HH:MM:SS format, UTC) |

#### File Operations
| Command | Syntax | Description |
|---------|--------|-------------|
| `dir` | `dir` | List files in current directory with size info |
| `cat` | `cat <filename>` | Display file contents |
| `size` | `size <filename>` | Show file size in bytes |
| `del` | `del <filename>` | Delete a file (kernel.bin protected) |
| `copy` | `copy <source> <dest>` | Copy file (root directory only) |
| `ren` | `ren <old> <new>` | Rename file (root directory only) |
| `touch` | `touch <filename>` | Create empty file |
| `write` | `write <file> <text>` | Write text to file |

#### Text Processing
| Command | Syntax | Description |
|---------|--------|-------------|
| `head` | `head <filename>` | Display first 10 lines of file |
| `tail` | `tail <filename>` | Display last 10 lines of file |

#### Directory Operations
| Command | Syntax | Description |
|---------|--------|-------------|
| `cd` | `cd <dirname>` | Change directory (use `..` for parent, `/` for root) |
| `mkdir` | `mkdir <dirname>` | Create new directory |
| `deldir` | `deldir <dirname>` | Delete empty directory |

#### Media & Display
| Command | Syntax | Description |
|---------|--------|-------------|
| `view` | `view <file> [-upscale] [-stretch]` | Display BMP image with optional 2x scaling |

#### Power Management
| Command | Description |
|---------|-------------|
| `shut` | Shutdown system via APM |
| `reboot` | Restart system |

---


## ⚙️ Configuration Files

x16-PRos uses several configuration files in the CONF directory:

| File | Purpose | Format |
|------|---------|--------|
| `SYSTEM.CFG` | System boot settings | Key=Value properties |
| `FIRST_B.CFG` | First boot flag | `0` or `1` (triggers SETUP.BIN on `1`) |
| `USER.CFG` | Username | Plain text (max 31 chars) |
| `PASSWORD.CFG` | Encrypted password | XOR-encrypted password |
| `PROMPT.CFG` | Command prompt format | Template string (max 63 chars)<br>Supports `$user` placeholder |
| `THEME.CFG` | Active color theme |16 lines, each containing the RGB code for a particular terminal color. |
| `TIMEZONE.CFG` | Timezone offset | Integer value (hours from UTC) |

### Prompt Customization
In the x16-PRos operating system, the command line prompt is configured using the PROMPT.CFG file, which is located in the CONF directory of the drive.

By default, if the PROMPT.CFG file is missing, a prompt of the following format is used:
`[$username@PRos] >`
(where the `$username` is taken from the `USER.CFG` file created during the first boot via SETUP).

#### How to create or edit a prompt

1. Create (or edit an existing) file `PROMPT.CFG` in the CONF directory.
2. Write a prompt string without the terminating null byte (plain text) into it.
3. The maximum string length is 63 characters. Anything longer will be truncated.
4. Reboot the OS.

### System Configuration (SYSTEM.CFG)
This file controls the visual and audio aspects of the boot process.
- **LOGO**: Path to the BMP file displayed at startup (e.g., `LOGO=BMP/LOGO.BMP`).
- **LOGO_STRETCH**: Scales the logo to full screen if set to `TRUE`.
- **START_SOUND**: Enables (`TRUE`) or disables (`FALSE`) the startup melody.

### Password Encryption
Passwords are encrypted using XOR cipher with a custom key defined in `src/kernel/features/encrypt.asm`. To set a password:
1. Use SETUP.BIN on first boot, or
2. Manually create PASSWORD.CFG with encrypted content

---


## 📦 Standard Software Package

x16-PRos includes a comprehensive collection of built-in applications:

<table>
<tr>
  <td width="33%" align="center">
    <img src="docs/screenshots/writer.png" width="100%"><br>
    <b>WRITER.BIN</b><br>
    Simple editor for text files
  </td>
  <td width="33%" align="center">
    <img src="docs/screenshots/bchart.png" width="100%"><br>
    <b>BCHART.BIN</b><br>
    Barchart software for creating simple diagrams
  </td>
  <td width="33%" align="center">
    <img src="docs/screenshots/brainf.png" width="100%"><br>
    <b>BRAINF.BIN</b><br>
    Brainfuck interpreter
  </td>
</tr>
<tr>
  <td width="33%" align="center">
    <img src="docs/screenshots/mine.png" width="100%"><br>
    <b>MINE.BIN</b><br>
    Minesweeper game
  </td>
  <td width="33%" align="center">
    <img src="docs/screenshots/piano.png" width="100%"><br>
    <b>PIANO.BIN</b><br>
    Simple piano to play melodies using PC Speaker
  </td>
  <td width="33%" align="center">
    <img src="docs/screenshots/procentc.png" width="100%"><br>
    <b>PROCENTC.BIN</b><br>
    Percentages calculator
  </td>
</tr>
<tr>
  <td width="33%" align="center">
    <img src="docs/screenshots/space.png" width="100%"><br>
    <b>SPACE.BIN</b><br>
    Space arcade game
  </td>
  <td width="33%" align="center">
    <img src="docs/screenshots/calc.png" width="100%"><br>
    <b>CALC.BIN</b><br>
    Simple calculator
  </td>
  <td width="33%" align="center">
    <img src="docs/screenshots/memory.png" width="100%"><br>
    <b>MEMORY.BIN</b><br>
    Memory viewer
  </td>
</tr>
<tr>
  <td width="33%" align="center">
    <img src="docs/screenshots/paint.png" width="100%"><br>
    <b>PAINT.BIN</b><br>
    Paint program
  </td>
  <td width="33%" align="center">
    <img src="docs/screenshots/pong.png" width="100%"><br>
    <b>PONG.BIN</b><br>
    Pong game
  </td>
  <td width="33%" align="center">
    <img src="docs/screenshots/fetch.png" width="100%"><br>
    <b>FETCH.BIN</b><br>
    Print system fetch (I use PRos btw)
  </td>
</tr>
<tr>
  <td width="33%" align="center">
    <img src="docs/screenshots/imfplay.png" width="100%"><br>
    <b>IMFPLAY.BIN</b><br>
    IMF music player
  </td>
  <td width="33%" align="center">
    <img src="docs/screenshots/clock.png" width="100%"><br>
    <b>CLOCK.BIN</b><br>
    Clock application
  </td>
  <td width="33%" align="center">
    <img src="docs/screenshots/hexedit.png" width="100%"><br>
    <b>HEXEDIT.BIN</b><br>
    Hex editor
  </td>
</tr>
<tr>
  <td width="33%" align="center">
    <img src="docs/screenshots/tetris.png" width="100%"><br>
    <b>TETRIS.BIN</b><br>
    Tetris game 
  </td>
  <td width="33%" align="center">
    <img src="docs/screenshots/mandel.png" width="100%"><br>
    <b>MANDEL.BIN</b><br>
    Mandelbrot-Menge
  </td>
  <td width="33%" align="center">
    <br>
    <b>And more...</b><br>
    SNAKE.BIN, CREDITS.BIN, AUTOEXEC.BIN, GREP.BIN, THEME.BIN, CHARS.BIN, WAVPLAY.BIN, ED.BIN, HELLO.COM, FRACTAL.COM
  </td>
</tr>
</table>

**Developing Your Own Programs**

You can create custom programs using NASM and the PRos API.

---


## 🛠️ Building from Source

### Packages required for compilation

- NASM
- mtools
- dosfstools
- cdrtools (optional for OS ISO image)

---

#### Installing packages:

##### Ubuntu/Debian
```
sudo apt install nasm mtools dosfstools genisoimage
```

> [!NOTE]  
> cdrtools (including the original mkisofs) is not included in the official Debian/Ubuntu repositories due to licensing issues. Genisoimage (a fork that provides compatibility with mkisofs via symlink) is used instead.

##### Arch Linux / Manjaro
```
sudo pacman -Syu nasm mtools dosfstools cdrtools
```

> [!NOTE]  
> Arch has a native cdrtools package available, which provides mkisofs.

##### Fedora / CentOS
```
sudo dnf install nasm mtools dosfstools genisoimage
```

---

### Compilation Steps

1. **Clone the repository:**
```bash
git clone https://github.com/PRoX2011/x16-PRos.git
cd x16-PRos
```

2. **Make build script executable:**
```bash
chmod +x build-linux.sh
```

3. **Build the project:**
```bash
./build-linux.sh
```

> [!FOR ADVANSED USERS]\
> build-linux have special flags:
> ```
> -quiet            - disable all script messages, but not disable nasm's warnings and errors
> -no-music         - do not add music files in system build
> -no-txt           - do not add text files in system build
> -no-boot-recomp   - do not compiling bootloader, in system build using old compiled bootloader from bin/ directory
> -no-kernel-recomp - do not compiling kernel, in system build using old compiled kernel from bin/ directory
> ```

### Build Output

- `disk_img/x16pros.img` - Bootable floppy disk image (1.44MB)
- `build/` - Compiled binaries and intermediate files

---


## 🚀 Running x16-PRos

### QEMU (Recommended)

#### Install QEMU:

##### Debian/Ubuntu
```bash
sudo apt install qemu-system-x86
```

##### ArchLinux/Manjaro
```bash
sudo pacman -S qemu-system-x86
```

##### Fedora
```bash
sudo dnf install qemu-system-x86
```

#### Run with QEMU

##### Run using a command:
```bash
qemu-system-x86_64 \
    -display gtk \
    -fda disk_img/x16pros.img \
    -machine pcspk-audiodev=snd0 \
    -device adlib,audiodev=snd0 \
    -audiodev pa,id=snd0
```

##### Run using a script (recommended):
```bash
chmod +x run-linux.sh
./run-linux.sh
```

### Online Emulation

Try x16-PRos in your browser using [v86 emulator](https://copy.sh/v86/):
1. Upload `x16pros.img` as floppy or hard disk
2. Boot the system

### Real Hardware

1. Write image to USB drive:
```bash
sudo dd if=disk_img/x16pros.img of=/dev/sdX bs=512
```

2. Boot from USB drive (BIOS mode)

**UEFI Systems**: Enable "CSM Support" or "Legacy Boot" in BIOS settings

> [!NOTE]  
> More detailed launch instructions are available on the project website: <https://x16-pros.prosdev.org/>

---


## Contributors

[<img src="https://wsrv.nl/?url=github.com/akbe2020.png?w=64&h=64&mask=circle&fit=cover&maxage=1w" width="64" height="64" alt="akbe2020" />](https://github.com/akbe2020)
[<img src="https://wsrv.nl/?url=github.com/ilnarildarovuch2.png?w=64&h=64&mask=circle&fit=cover&maxage=1w" width="64" height="64" alt="ilnarildarovuch2" />](https://github.com/ilnarildarovuch2)
[<img src="https://wsrv.nl/?url=github.com/dexoron.png?w=64&h=64&mask=circle&fit=cover&maxage=1w" width="64" height="64" alt="dexoron" />](https://github.com/dexoron)
[<img src="https://wsrv.nl/?url=github.com/realtomokokuroki.png?w=64&h=64&mask=circle&fit=cover&maxage=1w" width="64" height="64" alt="realtomokokuroki" />](https://github.com/realtomokokuroki)
[<img src="https://wsrv.nl/?url=https://github.com/leonardo-ono.png?w=64&h=64&mask=circle&fit=cover&maxage=1w" width="64" height="64" alt="leo-ono" />](https://github.com/leonardo-ono)


We welcome contributions! Special thanks to all who have submitted:
- Bug reports and fixes
- Documentation improvements
- Feature suggestions
- Program development

---


## 🤝 Contributing

### How to Contribute

1. **Report Bugs**: Open an issue on [GitHub Issues](https://github.com/PRoX2011/x16-PRos/issues)
2. **Submit Code**: Fork, develop, and create pull requests
3. **Write Programs**: Develop applications using the [PRos API](docs/API.md)
4. **Improve Docs**: Email suggestions to prox.dev.code@gmail.com

**More about contributing:** [contributing guide](CONTRIBUTING.md)

> [!IMPORTANT]  
> Please use English when commenting on code and describing changes. This project is designed to be multinational and accessible to everyone.

### Development Guidelines

- Follow existing code style (NASM assembly conventions)
- Test changes in QEMU before submitting
- Document new features in comments
- Update README.md for user-facing changes

### Support the Project

<a href="https://dalink.to/proxdev">
  <img src="https://img.shields.io/badge/Support%20Development-blue.svg?style=for-the-badge" height="35">
</a>

---


## 📄 License

x16-PRos is distributed under the **MIT License**.
```
Copyright (c) 2025 PRoX2011

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

<div align="center">

**Made with ❤️ by PRoX**

</div>
