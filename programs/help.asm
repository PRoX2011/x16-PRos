; ==================================================================
; x16-PRos -- HELP. Help program. Shows all kshell commands
; Copyright (C) 2025 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

start:
    mov ah, 0x06
    int 0x21

    call string_get_cursor_pos
    mov [.saved_row], dh
    mov [.saved_col], dl
    
    mov word [current_category], 0
    call .show_current_category

.key_loop:
    mov ah, 0    
    int 16h    
    ; Check for navigation keys
    cmp ah, 0x48    ; Up arrow
    je .prev_category
    cmp ah, 0x4B    ; Left arrow
    je .prev_category
    cmp ah, 0x50    ; Down arrow
    je .next_category
    cmp ah, 0x4D    ; Right arrow
    je .next_category
    cmp al, 27      ; ESC key
    je .exit_help
    
    jmp .key_loop   ; Ignore other keys

.prev_category:
    ; Can't go before first category
    cmp word [current_category], 0
    je .key_loop
    dec word [current_category]
    jmp .update_category

.next_category:
    mov si, help_categories
    mov bx, [current_category]
    shl bx, 1      
    add si, bx
    add si, 2      
    cmp word [si], 0
    je .key_loop  
    inc word [current_category]

.update_category:
    call .show_current_category
    jmp .key_loop

.show_current_category:
    mov dh, [.saved_row]
    mov dl, [.saved_col]
    call string_move_cursor

    mov dh, [.saved_row]
    mov dl, [.saved_col]
    call string_move_cursor
    
    mov ah, 0x02
    mov si, help_categories
    mov bx, [current_category]
    shl bx, 1   
    add si, bx
    mov si, [si]   
    int 0x21
    ret

.exit_help:
    mov dh, [.saved_row]
    add dh, 22     
    mov dl, 0
    call string_move_cursor
    ret 

.saved_row db 0
.saved_col db 0

string_get_cursor_pos:
    pusha
    mov ah, 0x03
    mov bh, 0
    int 0x10
    mov [.tmp_dl], dl
    mov [.tmp_dh], dh
    popa
    mov dl, [.tmp_dl]
    mov dh, [.tmp_dh]
    ret

.tmp_dl db 0
.tmp_dh db 0

string_move_cursor:
    pusha
    mov ah, 0x02
    mov bh, 0
    int 0x10
    popa
    ret

help_categories:
    dw  help_menu_1, help_menu_2, help_menu_3, help_menu_4, help_menu_5                                         
    dw 0 

current_category dw 0

help_menu_1 db 0xC9, 18 dup(0xCD), ' PRos help ', 18 dup(0xCD), 0xBB, 10, 13
     db 0xBA, ' Basic Commands                          [1/6] ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, '  help   - get list of the commands            ', 0xBA, 10, 13
     db 0xBA, '  info   - print system information            ', 0xBA, 10, 13
     db 0xBA, '  ver    - print PRos terminal version         ', 0xBA, 10, 13
     db 0xBA, '  cls    - clear terminal                      ', 0xBA, 10, 13
     db 0xBA, '  hist   - show command history                ', 0xBA, 10, 13
     db 0xBA, '  shut   - shutdown PC                         ', 0xBA, 10, 13
     db 0xBA, '  reboot - restart system                      ', 0xBA, 10, 13
     db 0xBA, '  date   - print current date (DD/MM/YY)       ', 0xBA, 10, 13
     db 0xBA, '  time   - print current time (HH:MM:SS)       ', 0xBA, 10, 13
     db 0xBA, '  cpu    - print CPU information               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, ' <-- Back   |  Press ESC to exit   |  Next --> ', 0xBA, 10, 13
     db 0xC8, 47 dup(0xCD), 0xBC, 0

help_menu_2 db 0xC9, 18 dup(0xCD), ' PRos help ', 18 dup(0xCD), 0xBB, 10, 13
     db 0xBA, ' File Operations                         [2/6] ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, '  dir               - list files on disk       ', 0xBA, 10, 13
     db 0xBA, '  size  <filename>  - get file size            ', 0xBA, 10, 13
     db 0xBA, '  cat   <filename>  - display file contents    ', 0xBA, 10, 13
     db 0xBA, '  del   <filename>  - delete a file            ', 0xBA, 10, 13
     db 0xBA, '  copy  <f1> <f2>   - copy a file (only root)  ', 0xBA, 10, 13
     db 0xBA, '  ren   <f1> <f2>   - rename a file (only root)', 0xBA, 10, 13
     db 0xBA, '  touch <filename>  - create empty file        ', 0xBA, 10, 13
     db 0xBA, '  write <f> <text>  - write text to file       ', 0xBA, 10, 13
     db 0xBA, '  view  <filename>  - view BMP image           ', 0xBA, 10, 13
     db 0xBA, '  head  <filename>  - show first 10 lines      ', 0xBA, 10, 13
     db 0xBA, '                      of a TXT file            ', 0xBA, 10, 13
     db 0xBA, '  tail  <filename>  - show last 10 lines       ', 0xBA, 10, 13
     db 0xBA, '                      of a TXT file            ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, ' <-- Back   |  Press ESC to exit   |  Next --> ', 0xBA, 10, 13
     db 0xC8, 47 dup(0xCD), 0xBC, 0

help_menu_3 db 0xC9, 18 dup(0xCD), ' PRos help ', 18 dup(0xCD), 0xBB, 10, 13
     db 0xBA, ' Directories Operations                  [3/6] ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, '  cd     <dirname>  - change directory         ', 0xBA, 10, 13
     db 0xBA, '  mkdir  <dirname>  - create directory         ', 0xBA, 10, 13
     db 0xBA, '  deldir <dirname>  - delete directory         ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, ' <-- Back   |  Press ESC to exit   |  Next --> ', 0xBA, 10, 13
     db 0xC8, 47 dup(0xCD), 0xBC, 0

help_menu_4 db 0xC9, 18 dup(0xCD), ' PRos help ', 18 dup(0xCD), 0xBB, 10, 13
     db 0xBA, ' Image Operations                        [4/6] ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, '  view  <filename> <flags>  - view image file  ', 0xBA, 10, 13
     db 0xBA, '                      ---                      ', 0xBA, 10, 13
     db 0xBA, '  The VIEW command allows you to view BMP      ', 0xBA, 10, 13
     db 0xBA, '  image files with or without 2x upscaling.    ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '  To enable 2x upscaling when displaying,      ', 0xBA, 10, 13
     db 0xBA, '  add the -UPSCALE flag                        ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '  To enable stretch when displaying,           ', 0xBA, 10, 13
     db 0xBA, '  add the -STRETCH flag                        ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, ' <-- Back   |  Press ESC to exit   |  Next --> ', 0xBA, 10, 13
     db 0xC8, 47 dup(0xCD), 0xBC, 0

help_menu_5 db 0xC9, 18 dup(0xCD), ' PRos help ', 18 dup(0xCD), 0xBB, 10, 13
     db 0xBA, ' Other stuff                             [5/6] ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, '  exit            - exit to boot loader        ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, ' <-- Back   |  Press ESC to exit   |  Next --> ', 0xBA, 10, 13
     db 0xC8, 47 dup(0xCD), 0xBC, 0
