com_4Bh:
    push es
    push ds
    push bp
    push di
    push si
    push dx
    push cx
    push bx
    push ax
    mov bp, sp

    test al, al
    jnz .unsupported

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

    mov ax, si
    call fs_get_file_size
    jc .fail
    add ebx, 15
    shr ebx, 4
    add ebx, 0x10
    cmp ebx, 0xFFFF
    ja .no_mem
    mov [.need], bx

    mov bx, DOSMEM_ENV_PARAS
    call dosmem_alloc
    jc .no_mem
    mov [.env], ax
    mov bx, 0xFFFF
    call dosmem_alloc
    cmp bx, [.need]
    jb .no_mem_env
    call dosmem_alloc
    jc .no_mem_env

    mov [exe_psp_seg], ax
    add bx, ax
    mov [exe_mem_end], bx
    add ax, 0x10
    mov [exe_load_seg], ax
    mov ax, [.env]
    mov [dosmem_env_seg], ax

    mov bx, [exe_psp_seg]
    call dosmem_set_owner
    mov ax, bx
    call dosmem_set_owner

    mov ax, [dos_current_psp]
    mov [exe_parent_psp], ax
    push es
    mov es, ax
    mov [es:0x2E], bp
    mov [es:0x30], ss
    pop es

    mov byte [exe_nested], 1
    mov ax, [.name]
    call exe_execute

    push es
    mov es, [exe_parent_psp]
    mov word [es:0x30], 0
    pop es
    mov byte [exe_nested], 0
    mov ax, [exe_psp_seg]
    call dosmem_free
    mov word [exe_psp_seg], EXE_PSP_SEG
    mov word [exe_load_seg], EXE_LOAD_SEG
    mov word [dosmem_env_seg], DOSMEM_ENV_SEG
    mov ax, [.env]
    call dosmem_free

.fail:
    mov ax, 0x0002
    jmp .error
.no_mem_env:
    mov ax, [.env]
    call dosmem_free
.no_mem:
    mov ax, 0x0008
    jmp .error
.unsupported:
    mov ax, 0x0001
.error:
    call exec_restore_dir
    mov [cs:dos_last_error], ax
    mov [bp], ax
    or word [bp + 22], 1
    jmp dos_frame_iret

.name    dw 0
.need    dw 0
.env     dw 0

; ==================================================================
; DOS_FRAME_IRET - leave INT 21h through a DOS register frame
; IN : SS:SP = AX, BX, CX, DX, SI, DI, BP, DS, ES, IP, CS, FLAGS
; ==================================================================
dos_frame_iret:
    pop ax
    pop bx
    pop cx
    pop dx
    pop si
    pop di
    pop bp
    pop ds
    pop es
    iret

; ==================================================================
; EXEC_RESTORE_DIR - return to the caller's directory once a child
;                    named by a path has been loaded
; IN : DS = KERNEL_DATA_SEG
; ==================================================================
exec_restore_dir:
    cmp byte [cs:exec_dir_split], 0
    je .done
    mov byte [cs:exec_dir_split], 0
    call path_restore
.done:
    ret

exec_dir_split   db 0

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
; COM_EXEC_PATH - switch to the drive and directory the caller's path
;                 names and reduce it to a bare file name
; IN : com_path_buffer = the caller's path
;      DS = KERNEL_DATA_SEG
; OUT: SI = the bare name, the named directory is current until
;      exec_restore_dir
;      CF = 1 if the drive or a directory along the way is unknown
; ==================================================================
com_exec_path:
    mov si, com_path_buffer

    cmp byte [si + 1], ':'
    jne .split
    mov al, [si]
    cmp al, 'a'
    jb .have_letter
    cmp al, 'z'
    ja .have_letter
    sub al, 32
.have_letter:
    cmp al, [current_drive_char]
    je .split
    call fs_change_drive_letter
    jc .bad

.split:
    call path_split
    jc .bad
    mov byte [cs:exec_dir_split], 1
    clc
    ret
.bad:
    stc
    ret

com_exec_args db 0
