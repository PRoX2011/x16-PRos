; x16-PRos C interface implementation.
;
; Copyright (c) 2026 Alexander Zubov
;
; The x16-PRos project is licensed under the MIT License.

[BITS 16]

section .text

; Global functions
global int86

; /* x86-16 interrupt. Returns CFLAG. */
; int int86(unsigned char int_no,
;           union REGS __far *in_regs,
;           union REGS __far *out_regs);
int86:
    ; Prologue
    push bp
    mov bp, sp
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    ; ------------------  Arguments  ------------------
    ; Type              Ptr     Name        Location
    ;
    ; unsigned char             int_no      [bp + 4]
    ; union REGS        far     in_regs     [bp + 6]
    ; union REGS        far     out_regs    [bp + 10]
    ; -------------------------------------------------

    ; Get interrupt handler pointer from IVT
    xor bh, bh                  ; BX = int_no
    mov bl, [bp + 4]
    shl bx, 2                   ; BX *= 4 = offset
    xor ax, ax                  ; DS = 0 = segment
    mov ds, ax
    mov ax, [bx]                ; DX:AX = interrupt handler address
    mov dx, [bx + 2]
    push dx                     ; Push it onto stack
    push ax

    ; Set registers
    mov ds, [bp + 8]            ; DS:SI = *in_regs
    mov si, [bp + 6]
    mov ax, [si + 12]           ; Push DS and SI values onto stack
    push ax
    mov ax, [si + 8]
    push ax
    mov ax, [si + 0]            ; Set other registers
    mov bx, [si + 2]
    mov cx, [si + 4]
    mov dx, [si + 6]
    mov di, [si + 10]
    mov es, [si + 14]
    pop si                      ; Pop SI and DS from stack
    pop ds

    ; Interrupt (SP points to interrupt handler address)
    push bp
    mov bp, sp
    pushf
    call far [bp + 2]
    pop bp

    ; Save results
    push ds                     ; Push DS and DI onto stack
    push di
    mov ds, [bp + 12]           ; DS:DI = *out_regs
    mov di, [bp + 10]
    mov [di + 0], ax            ; Save other registers
    mov [di + 2], bx
    mov [di + 4], cx
    mov [di + 6], dx
    mov [di + 8], si
    mov [di + 14], es
    pop ax                      ; Save DI and DS from stack
    mov [di + 10], ax
    pop ax
    mov [di + 12], ax

    ; Return value (AX) = CFLAG
    jc .cf_set
    xor ax, ax
    jmp .done
    .cf_set: mov ax, 1
    .done:

    ; Remove interrupt handler address from stack
    add sp, 4

    ; Epilogue
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop bp
    ret
