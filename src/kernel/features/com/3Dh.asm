; =========================================================
; INT 21h AH=3Dh — Open file
; IN:  DS:DX -> ASCIIZ filename
;      AL = access mode (ignored)
; OUT: AX = fake handle (0)
; CF=0 success / CF=1 error
; =========================================================

com_3Dh:
    ; копіюємо шлях
    call com_copy_path_from_caller
    mov si, ax                      ; DS:SI = filename

    ; перевіряємо існування файлу
    ; PRos FS: AH=0x04 — Check if File Exists (INT 0x22)
    mov ah, 0x04
    int 0x22
    jc .error

    xor ax, ax                      ; fake file handle
    clc
    iret

.error:
    xor ax, ax
    stc
    iret
