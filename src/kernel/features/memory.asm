; ==================================================================
; x16-PRos - Dynamic Memory Allocator
; Copyright (C) 2026 PRoX2011
; ==================================================================

[BITS 16]

heap_seg equ 0x9000

memory_init:
    pusha
    push es
    
    xor ax, ax
    mov es, ax
    mov word [es:0x23*4], int23_handler
    mov word [es:0x23*4+2], cs
    
    mov ax, heap_seg
    mov es, ax
    mov word [es:0], 0xFFF0    ; Initial block size
    mov byte [es:2], 0         ; Status: Free
    mov word [es:3], 0         ; Next: Null
    
    pop es
    popa
    ret

int23_handler:
    push ds
    push es
    pusha
    mov bp, sp
    
    mov bx, heap_seg
    mov ds, bx
    mov es, bx
    
    mov ah, [bp+15]            ; Function code
    mov cx, [bp+12]            ; Requested size
    
    cmp ah, 0x01
    je .malloc
    cmp ah, 0x02
    je .free
    jmp .done

.malloc:
    cmp cx, 0
    je .m_error
    cmp cx, 0xFFF0 - 5
    ja .m_error

    add cx, 5
    xor si, si
.m_loop:
    mov ax, [si]
    mov dl, [si+2]
    cmp dl, 0
    jne .m_next
    cmp ax, cx
    jae .m_found
.m_next:
    mov si, [si+3]
    cmp si, 0
    je .m_error
    jmp .m_loop

.m_found:
    mov dx, ax
    sub dx, cx
    cmp dx, 10                 ; Minimum split threshold
    jb .m_no_split
    
    mov di, si
    add di, cx
    mov [di], dx
    mov byte [di+2], 0
    mov ax, [si+3]
    mov [di+3], ax
    
    mov [si], cx
    mov [si+3], di

.m_no_split:
    mov byte [si+2], 1
    add si, 5
    mov [bp+14], si
    jmp .done

.m_error:
    mov word [bp+14], 0
    jmp .done

.free:
    mov bx, [bp+8]
    cmp bx, 5                  ; Null check
    jb .done
    
    sub bx, 5
    mov si, bx
    
    cmp byte [si+2], 0         ; Double-free check
    je .done
    
    mov byte [si+2], 0
    
    xor si, si
.f_coalesce:
    mov di, [si+3]
    cmp di, 0
    je .done
    
    cmp byte [si+2], 0
    jne .f_next
    cmp byte [di+2], 0
    jne .f_next
    
    mov ax, [di]
    add [si], ax
    mov ax, [di+3]
    mov [si+3], ax
    jmp .f_coalesce

.f_next:
    mov si, di
    jmp .f_coalesce

.done:
    popa
    pop es
    pop ds
    iret
