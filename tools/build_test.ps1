# x16-PRos test build for Windows (NASM + Python FAT12 builder)
# Builds bootloader, kernel and all programs, then creates a bootable
# test floppy image with setup wizard and logo display disabled.

$ErrorActionPreference = "SilentlyContinue"
$nasmDir = "C:\Users\User\AppData\Local\bin\NASM"
$env:Path = "$nasmDir;$env:Path"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

New-Item -ItemType Directory -Force -Path "bin", "disk_img", "build" | Out-Null
New-Item -ItemType Directory -Force -Path "build\test_conf" | Out-Null

function Invoke-Nasm($src, $out, $inc = $null) {
    $args = @("-f", "bin")
    if ($inc) { $args += @("-I", $inc) }
    $args += @($src, "-o", $out)
    & nasm @args 2>&1 | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) { throw "NASM failed: $src" }
}

Write-Host "== Compiling bootloader =="
Invoke-Nasm "src/bootloader/boot.asm" "bin/BOOT.BIN"

Write-Host "== Compiling kernel =="
Invoke-Nasm "src/kernel/kernel.asm" "bin/KERNEL.BIN"
$kernelSize = (Get-Item "bin/KERNEL.BIN").Length
Write-Host "KERNEL.BIN size: $kernelSize bytes (limit 43008, warn 40960)"
if ($kernelSize -gt 43008) { throw "KERNEL.BIN too large!" }

$programsRoot = @{
    "programs/autoexec.asm"   = "AUTOEXEC.BIN"
    "programs/setup/setup.asm" = "SETUP.BIN"
}

$programsBin = @{
    "programs/grep.asm"       = "GREP.BIN"
    "programs/tail.asm"       = "TAIL.BIN"
    "programs/cpu.asm"        = "CPU.BIN"
    "programs/dlist.asm"      = "DLIST.BIN"
    "programs/theme.asm"      = "THEME.BIN"
    "programs/fetch.asm"      = "FETCH.BIN"
    "programs/credits.asm"    = "CREDITS.BIN"
    "programs/write.asm"      = "WRITER.BIN"
    "programs/barchart.asm"   = "BCHART.BIN"
    "programs/brainf.asm"     = "BRAINF.BIN"
    "programs/calc.asm"       = "CALC.BIN"
    "programs/memory.asm"     = "MEMORY.BIN"
    "programs/mine.asm"       = "MINE.BIN"
    "programs/snake.asm"      = "SNAKE.BIN"
    "programs/space.asm"      = "SPACE.BIN"
    "programs/procentc.asm"   = "PROCENTC.BIN"
    "programs/pong.asm"       = "PONG.BIN"
    "programs/flappy.asm"     = "FLAPPY.BIN"
    "programs/hexedit.asm"    = "HEXEDIT.BIN"
    "programs/clock.asm"      = "CLOCK.BIN"
    "programs/tetris.asm"     = "TETRIS.BIN"
    "programs/chars.asm"      = "CHARS.BIN"
    "programs/eye.asm"        = "EYE.BIN"
    "programs/ed.asm"         = "ED.BIN"
    "programs/font.asm"       = "FONT.BIN"
    "programs/tree.asm"       = "TREE.BIN"
    "programs/print.asm"      = "PRINT.BIN"
    "programs/calendar.asm"   = "CALENDAR.BIN"
    "programs/dump.asm"       = "DUMP.BIN"
    "programs/uptime.asm"     = "UPTIME.BIN"
}

Write-Host "== Compiling programs =="
$all = @{}
foreach ($k in $programsRoot.Keys) { $all[$k] = $programsRoot[$k] }
foreach ($k in $programsBin.Keys) { $all[$k] = $programsBin[$k] }
foreach ($src in $all.Keys) {
    $out = "bin/$($all[$src])"
    if (Test-Path $src) {
        Invoke-Nasm $src $out
        Write-Host "  $src -> $out"
    } else {
        Write-Host "  SKIP (missing): $src"
    }
}

Write-Host "== Creating test configs =="
Set-Content -Path "build/test_conf/FIRST_B.CFG" -Value "0" -NoNewline
Set-Content -Path "build/test_conf/SYSTEM.CFG" -Value @(
    "# x16-PRos System Configuration (test build)",
    "LOGO=FALSE",
    "LOGO_STRETCH=FALSE",
    "START_SOUND=FALSE"
) -Encoding ASCII
Copy-Item "src/kernel/configs/USER.CFG" "build/test_conf/USER.CFG"
Copy-Item "src/kernel/configs/PASSWORD.CFG" "build/test_conf/PASSWORD.CFG"
Copy-Item "src/kernel/configs/TIMEZONE.CFG" "build/test_conf/TIMEZONE.CFG"
Copy-Item "src/kernel/configs/PROMPT.CFG" "build/test_conf/PROMPT.CFG"
Copy-Item "src/kernel/configs/THEME.CFG" "build/test_conf/THEME.CFG"
Copy-Item "src/kernel/configs/FONT.CFG" "build/test_conf/FONT.CFG"

Write-Host "== Building image =="
$placements = @(
    "bin/KERNEL.BIN:/KERNEL.BIN"
    "bin/AUTOEXEC.BIN:/AUTOEXEC.BIN"
    "bin/SETUP.BIN:/SETUP.BIN"
    "build/test_conf/SYSTEM.CFG:/SYSTEM.CFG"
    "assets/fonts/DEFAULT.FNT:/FONTS.DIR/DEFAULT.FNT"
    "assets/fonts/BOLD.FNT:/FONTS.DIR/BOLD.FNT"
    "assets/fonts/THIN.FNT:/FONTS.DIR/THIN.FNT"
    "assets/fonts/ITALIC.FNT:/FONTS.DIR/ITALIC.FNT"
    "assets/themes/DEFAULT.THM:/THEMES.DIR/DEFAULT.THM"
    "build/test_conf/USER.CFG:/CONF.DIR/USER.CFG"
    "build/test_conf/FIRST_B.CFG:/CONF.DIR/FIRST_B.CFG"
    "build/test_conf/PASSWORD.CFG:/CONF.DIR/PASSWORD.CFG"
    "build/test_conf/TIMEZONE.CFG:/CONF.DIR/TIMEZONE.CFG"
    "build/test_conf/PROMPT.CFG:/CONF.DIR/PROMPT.CFG"
    "build/test_conf/THEME.CFG:/CONF.DIR/THEME.CFG"
    "build/test_conf/FONT.CFG:/CONF.DIR/FONT.CFG"
)
foreach ($k in $all.Keys) {
    if (Test-Path $k) { $placements += "bin/$($all[$k]):/BIN.DIR/$($all[$k])" }
}
$placements += "src/txt/README.TXT:/DOCS.DIR/README.TXT"

python tools/build_image.py disk_img/x16pros.img bin @placements
if ($LASTEXITCODE -ne 0) { throw "Image build failed" }

Write-Host "== Build complete =="
Write-Host "disk_img/x16pros.img ready for QEMU"
