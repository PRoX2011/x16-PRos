com_4Eh:
    push bp
    mov bp, sp
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    mov [cs:find_mask], cl

    call com_copy_path_from_caller

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax


    call find_resolve_dir
    jc find_ret_none

    call find_make_template
    jc find_ret_none

    mov word [cs:find_idx], 0

    call find_dta_es_di
    call find_step
    jc find_ret_none
    jmp find_ret_ok
