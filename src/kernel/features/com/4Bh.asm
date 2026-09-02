EXEC_HEAP_GAP equ 0x2000

com_4Bh:
    push bp
    mov bp, sp

    test al, al
    jnz .unsupported

    push ds
    push es
    push si
    push di

    mov [cs:com_exec_blk_seg], es
    mov [cs:com_exec_blk_off], bx

    call com_copy_path_from_caller

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax

    call com_exec_tail
    call com_exec_path
    jc .fail
    mov [.name], si

    mov ax, [program_seg_runtime]
    call dosmem_find
    jc .fixed_base
    mov ax, [si + DM_START]
    add ax, [si + DM_PARAS]
    jmp short .have_base
.fixed_base:
    mov ax, [program_seg_runtime]
    add ax, 0x1000
.have_base:
    mov [dosmem_env_seg], ax
    add ax, DOSMEM_ENV_PARAS
    mov [exe_psp_seg], ax

    add ax, 0x10 + EXEC_HEAP_GAP
    mov [exe_load_seg], ax


    mov ax, [program_seg_runtime]
    mov [exe_parent_psp], ax

    mov byte [exe_nested], 1
    mov ax, [.name]
    call exe_execute

    mov byte [exe_nested], 0
    mov word [exe_psp_seg], EXE_PSP_SEG
    mov word [exe_load_seg], EXE_LOAD_SEG

.fail:
    pop di
    pop si
    pop es
    pop ds
    mov ax, 0x0002
    or word [bp+6], 1
    pop bp
    iret

.unsupported:
    mov ax, 0x0001
    or word [bp+6], 1
    pop bp
    iret

.name    dw 0

com_exec_blk_seg dw 0
com_exec_blk_off dw 0

com_exec_tail:
    pusha
    push es

    mov byte [com_exec_args], 0
    mov word [param_list], com_exec_args
    mov word [exe_tail_seg], 0

    mov ax, [cs:com_exec_blk_seg]
    test ax, ax
    jz .done

    mov es, ax
    mov bx, [cs:com_exec_blk_off]
    mov ax, [es:bx + 4]
    mov si, [es:bx + 2]
    test ax, ax
    jz .done

    mov [exe_tail_seg], ax
    mov [exe_tail_off], si

.done:
    pop es
    popa
    ret

; ==================================================================
; COM_EXEC_PATH - reduce "C:NAME.EXT" to a bare name on the right drive
; IN : com_path_buffer = the caller's path
;      DS = KERNEL_DATA_SEG
; OUT: SI = the bare name
;      CF = 1 if the drive is unknown or the path names a directory
; ==================================================================
com_exec_path:
    mov si, com_path_buffer

    cmp byte [si + 1], ':'
    jne .no_drive
    mov al, [si]
    cmp al, 'a'
    jb .have_letter
    cmp al, 'z'
    ja .have_letter
    sub al, 32
.have_letter:
    cmp al, [current_drive_char]
    je .same_drive
    call fs_change_drive_letter
    jc .bad
.same_drive:
    add si, 2

.no_drive:
    cmp byte [si], '\'
    je .skip_root
    cmp byte [si], '/'
    jne .check
.skip_root:
    inc si

.check:
    push si
.scan:
    lodsb
    test al, al
    jz .plain
    cmp al, '\'
    je .has_dir
    cmp al, '/'
    jne .scan
.has_dir:
    pop si
    jmp .bad
.plain:
    pop si
    clc
    ret
.bad:
    stc
    ret

com_exec_args times 128 db 0

com_strip_path:
    mov si, com_path_buffer

    cmp byte [si + 1], ':'
    jne .no_drive
    mov al, [si]
    cmp al, 'a'
    jb .have_letter
    cmp al, 'z'
    ja .have_letter
    sub al, 32
.have_letter:
    cmp al, [current_drive_char]
    jne .bad
    add si, 2

.no_drive:
    cmp byte [si], '\'
    je .skip_root
    cmp byte [si], '/'
    jne .check
.skip_root:
    inc si

.check:
    push si
.scan:
    lodsb
    test al, al
    jz .plain
    cmp al, '\'
    je .has_dir
    cmp al, '/'
    jne .scan
.has_dir:
    pop si
    jmp .bad
.plain:
    pop si
    clc
    ret
.bad:
    stc
    ret
