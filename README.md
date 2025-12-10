<div align="center">

  <h1>x16-PRos operating system</h1>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](#)
[![Version](https://img.shields.io/badge/version-0.4.9-blue.svg)](#)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)](#)

  <img src="https://github.com/PRoX2011/x16-PRos/raw/main/docs/assets/preview.gif" width="65%">


**x16-PRos**
is a minimalistic 16-bit operating system written in NASM for x86 architecture. It supports a text interface, loading
programs from disk, and basic
system functions such as displaying CPU information, time, and date.

 <img src="https://github.com/PRoX2011/x16-PRos/raw/main/docs/screenshots/1.png" width="75%">
 
---

<div align="center">
 <a href="https://x16-pros.netlify.app/">
  <img src="https://img.shields.io/badge/x16%20PRos-web%20site-blue.svg?style=for-the-badge&logoWidth=40&labelWidth=100&fontSize=20" height="50">
</a>
 <br>
<a href="https://github.com/PRoX2011/programs4pros/">
  <img src="https://img.shields.io/badge/Programs%20for%20PRos-red.svg?style=for-the-badge&logoWidth=40&labelWidth=100&fontSize=20" height="50">
</a>
</div>


</div>

---

## 📋 Supported commands in x16 PRos terminal

- **help** display list of commands
- **info** brief system information
- **cls** clear screen
- **shut** shut down the system
- **reboot** restart the system
- **date** display date
- **time** show time (UTC)
- **CPU** CPU information
- **dir** List files on disk
- **cat <filename>** Display file contents
- **del <filename>** Delete a file
- **copy <filename1> <filename2>** Copy a file
- **ren <filename1> <filename2>** Rename a file
- **size <filename>** Get file size
- **touch <filename>** Create an empty file
- **write <filename> <text>** Write text to a file

---

## 📦 x16 PRos Software Package

Basic x16 PRos software package includes:

<div align="center">
  <table>
    <tr>
      <td align="center">
        <strong>Notepad</strong><br>
        <em>for writing and saving texts to disk sectors</em><br>
        <img src="https://github.com/PRoX2011/x16-PRos/raw/main/docs/screenshots/3.png" width="85%">
      </td>
      <td align="center">
        <strong>Brainf IDE</strong><br>
        <em>for working with Brainf*ck language</em><br>
        <img src="https://github.com/PRoX2011/x16-PRos/raw/main/docs/screenshots/4.png" width="85%">
      </td>
    </tr>
    <tr>
      <td align="center">
        <strong>Barchart</strong><br>
        <em>program for creating simple diagrams</em><br>
        <img src="https://github.com/PRoX2011/x16-PRos/raw/main/docs/screenshots/5.png" width="85%">
      </td>
      <td align="center">
        <strong>Snake</strong><br>
        <em>classic Snake game</em><br>
        <img src="https://github.com/PRoX2011/x16-PRos/raw/main/docs/screenshots/6.png" width="95%">
      </td>
    </tr>
    <tr>
      <td colspan="2" align="center">
        <strong>Calc</strong><br>
        <em>help with simple mathematical calculations</em><br>
        <img src="https://github.com/PRoX2011/x16-PRos/raw/main/docs/screenshots/7.png" width="57.5%">
      </td>
    </tr>
   <tr>
      <td align="center">
        <strong>memory</strong><br>
        <em>to view memory in real time</em><br>
        <img src="https://github.com/PRoX2011/x16-PRos/raw/main/docs/screenshots/10.png" width="85%">
      </td>
      <td align="center">
        <strong>mine</strong><br>
        <em>classic minesweeper game</em><br>
        <img src="https://github.com/PRoX2011/x16-PRos/raw/main/docs/screenshots/11.png" width="85%">
      </td>
    </tr>
   <tr>
      <td align="center">
        <strong>piano</strong><br>
        <em>to play simple melodies using PC Speaker</em><br>
        <img src="https://github.com/PRoX2011/x16-PRos/raw/main/docs/screenshots/12.png" width="85%">
      </td>
      <td align="center">
        <strong>space</strong><br>
        <em>space arcade game</em><br>
        <img src="https://github.com/PRoX2011/x16-PRos/raw/main/docs/screenshots/13.png" width="85%">
      </td>
    </tr>
   <tr>
    <td colspan="2" align="center">
        <strong>Percentages</strong><br>
        <em>percentages calculator</em><br>
        <img src="https://github.com/PRoX2011/x16-PRos/raw/main/docs/screenshots/14.png" width="57.5%">
      </td>
   </tr>
  </table>
</div>

---

## 🛠 Adding programs

x16 PRos includes a small set of built-in programs. You can add your own program to the system image, and then run it by
entering the filename of your program in the terminal.

Here's how you can add a program:

```bash
mcopy -i disk_img/x16pros.img PROGRAM.BIN ::/
```

Also, PRos has its own API for software developers. See **docs/API.md**

You can read more about the software development process for x16-PRos on the project website:
[x16-PRos website](https://x16-pros.netlify.app/)


---

## 🛠 Compilation

First, clone the repository:

```bash
git clone https://github.com/PRoX2011/x16-PRos.git
cd x16-PRos
```

To compile the project, you will need NASM and some other pakages.
Example command for Ubuntu:

```bash
sudo apt install nasm
sudo apt install mtools
sudo apt install dosfstools
```

And finally:

```bash
chmod +x build.sh
./build.sh
```

---

## 🚀 Launching

To launch x16 PRos, use emulators such as **QEMU**,**Bochs** or online emulator like [v86](https://copy.sh/v86/).
Example command for **QEMU**:

```bash
qemu-system-x86_64 -audiodev pa,id=snd0 -machine pcspk-audiodev=snd0 -hda disk_img/x16pros.img
```

or

```bash
# qemu-system-x86
chmod +x run.sh
./run.sh
```

> [!NOTE]  
> To run the emulator with audio support in Arch Linux, install the `qemu-audio-pa` package for PulseAudio:
> ```bash
> sudo pacman -S qemu-audio-pa
> ```


You can also try running x16-PRos on a **real PC** (preferably with BIOS, not UEFI)

If you still want to run x16-PRos on a UEFI PC, you will need to enable "CSM support" in your BIOS. It may be called
slightly differently.

---

## ⚙ Running x16-PRos on windows

### Installation Steps

1. Open PowerShell as Administrator and run:

```powershell
winget install nasm
winget install qemu
```

2. Add NASM and QEMU to System Path by running:

```powershell
setx PATH "%PATH%;C:\Program Files\NASM;C:\Program Files\qemu"
```

3. Reboot your PC for the PATH changes to take effect.

4. Run the build script:

```batch
build.ps1
```

**Note**: Make sure to restart your terminal or IDE after modifying the PATH variable.

### Troubleshooting

- If commands are not recognized, verify the installation paths
- Ensure PowerShell was run as Administrator during installation
- Check if PATH was updated correctly by running `echo %PATH%`

---

## 👨‍💻 x16-PRos Developers

- **PRoX (Faddey Kabanov)** lead developer. Creator of the kernel, command interpreter, writer, brainf, snake programs.
- **Loxsete** developer of the barchart program.
- **Saeta** developer of the calculation logic in the program "Calculator."
- **Qwez** developer of the "space arcade" game.
- **Gabriel** developer of "Percentages" program.

---

## 🤝 Contribute to the Project

If you want to contribute to the development of x16 PRos, you can:

- Report bugs via GitHub Issues.
- Suggest improvements or new features on GitHub.
- Help with documentation by emailing us at prox.dev.code@gmail.com.
- Develop new programs for the system.

## License

The project is distributed under the **MIT** License. This permissive free software license allows users to freely use, **modify**, **distribute**, and **sublicense** the code, with the only requirement **being the inclusion of the original copyright notice and license text**.

The license also applies to **all programs and components created by the OS developer**, unless explicitly stated otherwise. This means that any software built by the original author and included in the OS inherits the same open and flexible licensing terms.

For more details, refer to the full text of the MIT License (LICENSE.TXT).

---

<a href="https://www.donationalerts.com/r/proxdev">
  <img src="https://img.shields.io/badge/Support%20me-blue.svg?style=for-the-badge&logoWidth=40&labelWidth=100&fontSize=20" height="35">
</a>

0.5 will be released soon: December 15th
