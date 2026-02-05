; ==================================================================
; x16-PRos -- MINE. Minesweeper game.
; Copyright (C) 2025 PRoX2011
;
; Made by PRoX-dev
; =================================================================

[BITS 16]
[ORG 0x8000]

%assign WordSize 2
%assign TextBuf.Seg 0xb800
%assign TextBuf.Width 40
%assign TextBuf.Height 25
%assign TextBuf.Size (TextBuf.Width * TextBuf.Height)
%define TextBuf.Index(y, x) ((y) * TextBuf.Width * 2 + (x) * 2)
%assign Dirs.Len 8

; --- SCANCODES ---
%assign Key.ScanCode.Space 0x39
%assign Key.ScanCode.Up 0x48
%assign Key.ScanCode.Down 0x50
%assign Key.ScanCode.Left 0x4b
%assign Key.ScanCode.Right 0x4d
%assign Key.ScanCode.Enter 0x1c
%assign Key.Ascii.RestartGame 'r'
%assign Key.Ascii.Esc 0x1b      ; Добавлен код ESC

%define VgaChar(color, ascii) (((color) << 8) | (ascii))

; --- COLORS ---
%assign Color.Veiled 0x00
%assign Color.Unveiled 0xf0
%assign Color.Cursor 0x77
%assign Color.Flag 0xcc
%assign Color.GameWinText 0x20
%assign Color.GameOverText 0xc0
%assign BombFreq 0b111

Mine:
  mov ah, 0x01
  mov si, help_msg
  int 0x21

  mov ah, 0x01
  mov si, any_key_msg
  int 0x21

  mov ah, 0x05
  int 0x21

  mov ah, 0
  int 16h

  ; Setting up videomode
  mov ax, 0x01
  int 0x10

  ; Setting up cursor
  mov ah, 0x01
  mov ch, 0x3f
  int 0x10

  mov dx, 0x03DA
  in al, dx
  mov dx, 0x03C0
  mov al, 0x30
  out dx, al
  inc dx
  in al, dx
  and al, 0xF7
  dec dx
  out dx, al

RunGame:
  mov dx, TextBuf.Seg
  mov es, dx
  mov ds, dx

ZeroTextBuf:
  xor di, di
  mov cx, TextBuf.Size
  mov ax, VgaChar(Color.Veiled, '0')
.Loop:
  stosw
  loop .Loop

PopulateTextBuf:
  mov bx, TextBuf.Height - 2

.LoopY:
  mov cx, TextBuf.Width - 2

.LoopX:
  call GetTextBufIndex
  rdtsc
  and al, BombFreq
  setz dl
  mov bp, Dirs.Len
  jnz .LoopDir
  mov byte [di], '*'
.LoopDir:
  push di
  movsx ax, byte [cs:bp + Dirs - 1]
  add di, ax
  mov al, [di]
  cmp al, '*'
  je .LoopDirIsMine
  add [di], dl
.LoopDirIsMine:
  pop di
  dec bp
  jnz .LoopDir
  loop .LoopX
  dec bx
  jnz .LoopY

mov dl, Color.Veiled

GameLoop:
  xor ax, ax
  int 0x16

  cmp al, Key.Ascii.Esc
  je ExitGame

  call GetTextBufIndex
  mov [di + 1], dl

DetectWin:
  xor si, si
  push ax
  push cx
  mov cx, TextBuf.Size
.Loop:
  lodsw
  cmp ah, Color.Veiled
  je .CheckMine
  cmp ah, Color.Flag
  jne .Continue
.CheckMine:
  cmp al, '*'
  jne .Break
.Continue:
  loop .Loop
  jmp GameWin
.Break:
  pop cx
  pop ax

CmpUp:
  cmp ah, Key.ScanCode.Up
  jne CmpDown
  dec bx
  jmp WrapCursor
CmpDown:
  cmp ah, Key.ScanCode.Down
  jne CmpLeft
  inc bx
  jmp WrapCursor
CmpLeft:
  cmp ah, Key.ScanCode.Left
  jne CmpRight
  dec cx
  jmp WrapCursor
CmpRight:
  cmp ah, Key.ScanCode.Right
  jne CmpEnter
  inc cx
  jmp WrapCursor
CmpEnter:
  cmp ah, Key.ScanCode.Enter
  jne CmpSpace
  mov dl, Color.Flag
  mov [di + 1], dl
  jmp GameLoop
CmpSpace:
  cmp ah, Key.ScanCode.Space
  jne GameLoop

ClearCell:
  mov ax, [di]
  call UnveilCell
.CmpEmpty:
  cmp al, '0'
  jne .CmpMine
  call Flood
  jmp GameLoop
.CmpMine:
  cmp al, '*'
  jne GameLoop
  jmp GameOver

WrapCursor:
.Y:
  cmp bx, TextBuf.Height
  jb .X
  xor bx, bx
.X:
  cmp cx, TextBuf.Width
  jb SetCursorPos
  xor cx, cx
SetCursorPos:
  call GetTextBufIndex
  mov dl, Color.Cursor
  xchg dl, [di + 1]
  jmp GameLoop

GetTextBufIndex:
  push cx
  imul di, bx, TextBuf.Width * 2
  imul cx, cx, 2
  add di, cx
  pop cx
  ret

UnveilCell:
  mov dl, al
  xor dl, '0' ^ Color.Unveiled
  mov [di + 1], dl
  ret

Flood:
  call GetTextBufIndex
  mov ax, [di]
  cmp bx, TextBuf.Height
  jae .Ret
  cmp cx, TextBuf.Width
  jae .Ret
  cmp al, ' '
  je .Ret
  cmp al, '*'
  je .Ret
  call UnveilCell
  cmp al, '0'
  jne .Ret
  mov byte [di], ' '
  dec bx
  call Flood
  inc bx
  inc bx
  call Flood
  dec bx
  dec cx
  call Flood
  inc cx
  inc bx
  dec bx
  dec cx
  call Flood
  inc cx
  dec bx
  inc bx
  inc bx
  inc cx
  call Flood
  dec cx
  dec bx
.Ret:
  ret

Dirs:
  db TextBuf.Index(-1, -1)
  db TextBuf.Index(-1,  0)
  db TextBuf.Index(-1, +1)
  db TextBuf.Index( 0, +1)
  db TextBuf.Index(+1, +1)
  db TextBuf.Index(+1,  0)
  db TextBuf.Index(+1, -1)
  db TextBuf.Index( 0, -1)

GameWinStr:
  db 'YOU WIN!'
%assign GameWinStr.Len $ - GameWinStr

GameOverStr:
  db 'GAME OVER'
%assign GameOverStr.Len $ - GameOverStr

GameWin:
  mov cx, GameWinStr.Len
  mov bp, GameWinStr
  mov bx, Color.GameWinText
  jmp GameEndHelper

GameOver:
  mov cx, GameOverStr.Len
  mov bp, GameOverStr
  mov bx, Color.GameOverText

GameEndHelper:
  mov di, cs
  mov es, di
  mov ax, 0x1300
  mov dx, ((TextBuf.Height / 2) << 8) | (TextBuf.Width / 2 - GameOverStr.Len / 2)
  int 0x10

WaitRestart:
  xor ax, ax
  int 0x16
  cmp al, Key.Ascii.RestartGame
  je RunGame
  cmp al, Key.Ascii.Esc
  je ExitGame
  jmp WaitRestart

ExitGame:
  mov ax, 0x12
  int 0x10
  ret

help_msg    db 0xC9, 51 dup(0xCD), 0xBB, 10, 13
            db 0xBA, '  PRos minesweeper                                 ', 0xBA, 10, 13
            db 0xC3, 51 dup(0xC4), 0xB4, 10, 13
            db 0xBA, '  ARROWS   - move the cursor                       ', 0xBA, 10, 13
            db 0xBA, '  SPACE    - open the cage on the field            ', 0xBA, 10, 13
            db 0xBA, '  ENTER    - place a flag                          ', 0xBA, 10, 13
            db 0xBA, '  R        - restart the game                      ', 0xBA, 10, 13
            db 0xC3, 51 dup(0xC4), 0xB4, 10, 13
            db 0xBA, '  Press ESC to quit                                ', 0xBA, 10, 13
            db 0xC0, 51 dup(0xCD), 0xBC, 10, 13, 0

any_key_msg db 'Press any key to start the game...', 10, 12, 0