com_50h:
    mov [cs:dos_current_psp], bx
    call dosvars_stamp_psp
    iret
