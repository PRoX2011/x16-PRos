; =========================================================
; INT 21h AH=3Ch — Create file
; IN:  DS:DX -> ASCIIZ filename (8.3)
; OUT: AX = fake handle (0)
; CF=0 success / CF=1 error
; =========================================================

com_3Ch:
    ; копіюємо шлях з caller у kernel‑буфер
    call com_copy_path_from_caller
    mov si, ax                      ; DS:SI = filename (kernel)

    ; виклик PRos FS: Create Empty File
    ; Припущення: AH=0x05 — Create Empty File (INT 0x22)
    mov ah, 0x05
    int 0x22
    jc .error

    xor ax, ax                      ; fake file handle = 0
    clc
    iret

.error:
    xor ax, ax
    stc
    iret
