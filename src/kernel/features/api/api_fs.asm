; ==================================================================
; x16-PRos - Kernel File System API (Interrupt-Driven)
; Copyright (C) 2025 PRoX2011
;
; Function codes in AH:
;   0x00: Initialize file system 
;   0x01: Get file list (SI = buffer, returns BX = size low, CX = size high, DX = file count)
;   0x02: Load file (SI = filename, CX = load position, returns BX = file size)
;   0x03: Write file (SI = filename, BX = buffer, CX = size)
;   0x04: Check if file exists (SI = filename)
;   0x05: Create empty file (SI = filename)
;   0x06: Remove file (SI = filename)
;   0x07: Rename file (SI = old name, DI = new name)
;   0x08: Get file size (SI = filename, returns BX = size)
; ==================================================================

[BITS 16]

api_fs_init:
    pusha
    push es
    xor ax, ax
    mov es, ax
    cli
    mov word [es:0x22*4], int22_handler
    mov word [es:0x22*4+2], cs
    sti
    mov ax, 0
    call fs_reset_floppy
    pop es
    popa
    ret

int22_handler:
    pusha
    push ds
    push es
    
    mov bp, cs
    mov ds, bp
    mov es, bp
    
    mov al, ah
    
    cmp al, 0x00
    je .init
    cmp al, 0x01  
    je .get_file_list
    cmp al, 0x02
    je .load_file
    cmp al, 0x03
    je .write_file  
    cmp al, 0x04
    je .file_exists
    cmp al, 0x05
    je .create_file
    cmp al, 0x06
    je .remove_file
    cmp al, 0x07
    je .rename_file
    cmp al, 0x08
    je .get_file_size
    
    stc
    jmp .done

.init:
    mov ax, 0
    call fs_reset_floppy  
    jmp .done

.get_file_list:
    mov ax, si
    call fs_get_file_list
    jc .done
    mov [.saved_bx], bx
    mov [.saved_cx], cx  
    mov [.saved_dx], dx

    mov bp, sp
    mov bx, [.saved_bx]
    mov [bp+14], bx
    mov cx, [.saved_cx] 
    mov [bp+12], cx
    mov dx, [.saved_dx]
    mov [bp+10], dx
    jmp .done

.load_file:
    mov ax, si

    call fs_load_file
    jc .done

    mov bp, sp
    mov [bp+14], bx
    jmp .done

.write_file:
    mov ax, si

    call fs_write_file
    jmp .done

.file_exists:
    mov ax, si
    call fs_file_exists
    jmp .done

.create_file:
    mov ax, si
    call fs_create_file  
    jmp .done

.remove_file:
    mov ax, si
    call fs_remove_file
    jmp .done

.rename_file:
    mov ax, si
    mov bx, di
    call fs_rename_file
    jmp .done

.get_file_size:
    mov ax, si
    call fs_get_file_size
    jc .done

    mov bp, sp
    mov [bp+14], bx
    jmp .done

.done:
    pop es
    pop ds
    popa
    iret

.saved_bx dw 0
.saved_cx dw 0  
.saved_dx dw 0
