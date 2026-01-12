; ==================================================================
; x16-PRos - FAT12 file system functions for x16-PRos kernel
; Copyright (C) 2025 PRoX2011
; ==================================================================

; =======================================================================
; FS_GET_FILE_LIST - Gets a list of files in the current directory
; IN : AX = pointer to the buffer for the list
; OUT : BX = total size of files (low word)
; CX = total size of files (high word)
; DX = number of files
; CF = 0 if successful
; =======================================================================
fs_get_file_list:
    pusha

    mov word [.file_list_tmp], ax
    mov word [.total_size], 0
    mov word [.total_size+2], 0
    mov word [.file_count], 0
    mov word [.files_in_row], 0

    cmp byte [current_directory], 0
    je .list_root_dir
    
    jmp .list_subdir

.list_root_dir:
    mov eax, 0
    call fs_reset_floppy

    mov ax, 19
    call fs_convert_l2hts

    mov si, disk_buffer
    mov bx, si

    mov ah, 2
    mov al, 14

    pusha

.read_root_dir:
    popa
    pusha

    stc
    int 13h
    call fs_reset_floppy
    jnc .show_dir_init

    call fs_reset_floppy
    jnc .read_root_dir
    jmp .done

.show_dir_init:
    popa

    mov ax, 0
    mov si, disk_buffer
    jmp .process_entries

.list_subdir:
    mov ax, current_directory
    call string_string_uppercase
    call int_dirname_convert
    jc .done
    
    push ax
    call fs_read_root_dir
    pop ax
    
    mov di, disk_buffer
    call fs_get_root_entry
    jc .done
    
    mov ax, [di+26]
    mov [.current_cluster], ax
    cmp ax, 0
    je .done

    add ax, 31
    call fs_convert_l2hts
    
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .done
    
    mov si, disk_buffer + 64 

.process_entries:
    mov word di, [.file_list_tmp]

.start_entry:
    cmp byte [current_directory], 0
    jne .check_subdir_end
    jmp .check_root_end

.check_subdir_end:
    mov ax, si
    sub ax, disk_buffer
    cmp ax, 512
    jl .check_entry
    
    mov ax, [.current_cluster]
    call fs_get_next_directory_cluster
    jc .done
    
    mov [.current_cluster], ax
    mov si, disk_buffer
    jmp .check_entry

.check_root_end:

.check_entry:
    mov al, [si+11]
    cmp al, 0Fh
    je .skip

    test al, 0x08  
    jnz .skip

    mov al, [si]
    cmp al, 229
    je .skip

    cmp al, 0
    je .done

    inc word [.file_count]

    mov al, [si+11]
    test al, 0x10
    jnz .is_directory

    mov bx, [si+28]        
    add word [.total_size], bx
    adc word [.total_size+2], 0 

.is_directory:
    mov cx, 1
    mov dx, si
    mov word [.name_length], 0 
    
    mov al, [si+11]
    mov [.current_attr], al

.testdirentry:
    inc si
    mov al, [si]
    cmp al, ' '
    jl .nxtdirentry
    cmp al, '~'
    ja .nxtdirentry

    inc cx
    cmp cx, 11
    je .gotfilename
    jmp .testdirentry

.gotfilename:
    mov si, dx
    mov cx, 0

.loopy:
    mov byte al, [si]
    cmp al, ' '
    je .ignore_space
    
    mov byte [di], al
    
.next_char:
    inc word [.name_length]
    inc si
    inc di
    inc cx
    cmp cx, 8
    je .pad_name
    cmp cx, 11
    je .done_copy
    jmp .loopy

.ignore_space:
    inc si
    inc cx
    cmp cx, 8
    je .pad_name
    jmp .loopy

.pad_name:
    mov ax, 9
    sub ax, [.name_length]
    mov cx, ax
    jcxz .write_extension
.add_spaces:
    mov byte [di], ' '
    inc di
    loop .add_spaces
    jmp .write_extension

.write_extension:
    mov cx, 8
.extension_loop:
    mov byte al, [si]
    cmp al, ' '
    je .done_copy
    
    mov byte [di], al
    
.next_ext_char:
    inc si
    inc di
    inc cx
    cmp cx, 11
    je .done_copy
    jmp .extension_loop

.done_copy:
    mov byte [di], ' '
    inc di
    mov byte [di], ' '
    inc di

    mov si, dx
    mov al, [si+11]
    test al, 0x10
    jnz .print_dir_marker

    mov ax, [si+28]      
    mov bx, [si+30]    
    push si
    push dx
    push bx
    push ax
    call .convert_to_decimal
    pop ax
    pop bx
    pop dx
    pop si
    jmp .after_size

.print_dir_marker:
    mov si, .dir_marker
    mov cx, 5
.copy_dir_loop:
    lodsb
    mov byte [di], al
    inc di
    loop .copy_dir_loop
    mov word [.size_length], 5 

.after_size:
    inc word [.files_in_row]

    cmp word [.files_in_row], 3
    je .add_newline

    mov ax, 14
    sub ax, [.size_length]
    sub ax, 2
    mov cx, ax
    jcxz .nxtdirentry
.add_column_spaces:
    mov byte [di], ' '
    inc di
    loop .add_column_spaces
    jmp .nxtdirentry

.add_newline:
    mov word [.files_in_row], 0
    mov byte [di], 13
    inc di
    mov byte [di], 10
    inc di
    jmp .nxtdirentry

.convert_to_decimal:
    mov cx, 0
    mov dx, 0
    mov word [.size_length], 0
.setup:
    cmp ax, 0
    je .check_zero
    mov bx, 10
    div bx
    push dx
    inc cx
    inc word [.size_length]
    xor dx, dx
    jmp .setup
.check_zero:
    cmp cx, 0
    jne .print_digits
    mov byte [di], '0'
    inc di
    inc word [.size_length]
    ret
.print_digits:
    pop dx
    add dl, '0'
    mov byte [di], dl
    inc di
    dec cx
    jnz .print_digits
    ret

.nxtdirentry:
    mov si, dx

.skip:
    add si, 32
    jmp .start_entry

.done:
    cmp word [.files_in_row], 1
    je .add_final_newline
    cmp word [.files_in_row], 2  
    je .add_final_newline
    jmp .no_final_newline
.add_final_newline:
    mov byte [di], 13
    inc di
    mov byte [di], 10
    inc di
.no_final_newline:
    mov byte [di], 0

    popa
    mov bx, [.total_size]
    mov cx, [.total_size+2]
    mov dx, [.file_count]
    clc
    ret

.file_list_tmp   dw 0
.total_size      dd 0
.file_count      dw 0
.name_length     dw 0
.files_in_row    dw 0
.size_length     dw 0
.current_attr    db 0
.current_cluster dw 0
.dir_marker      db '<DIR>', 0

; ========================================================================
; FS_LOAD_FILE - Loads a file from the current directory
; IN : AX = file name, CX = load address
; OUT : BX = file size, CF = error flag
; ========================================================================
fs_load_file:
    call string_string_uppercase
    call int_filename_convert

    mov [.filename_loc], ax
    mov [.load_position], cx

    mov eax, 0
    call fs_reset_floppy
    jnc .floppy_ok
    stc 
    ret

.floppy_ok:
    cmp byte [current_directory], 0
    je .search_in_root
    jmp .search_in_subdir

.search_in_root:
    mov ax, 19
    call fs_convert_l2hts
    mov si, disk_buffer
    mov bx, si
    mov ah, 2
    mov al, 14
    stc
    int 13h
    jc .root_problem
    mov cx, 224
    mov bx, -32
    jmp .search_entries_loop

.search_in_subdir:
    mov ax, current_directory
    push ax
    call string_string_uppercase
    call int_dirname_convert
    pop bx
    jc .root_problem
    
    push ax
    call fs_read_root_dir
    pop ax
    
    mov di, disk_buffer
    call fs_get_root_entry
    jc .root_problem
    
    mov ax, [di+26] 
    mov [.current_cluster], ax
    cmp ax, 0
    je .root_problem

.load_search_sector:
    mov ax, [.current_cluster]
    add ax, 31
    call fs_convert_l2hts
    
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .root_problem

    mov bx, 0         
    mov cx, 16     

.search_entries_sub_loop:
    mov di, disk_buffer
    add di, bx
    
    mov al, [di]
    cmp al, 0
    je .file_not_found_subdir 
    
    cmp al, 0E5h
    je .next_entry_sub
    
    mov al, [di+11]
    cmp al, 0Fh
    je .next_entry_sub
    test al, 0x08
    jnz .next_entry_sub
    test al, 0x10
    jnz .next_entry_sub

    push di
    push bx
    mov byte [di+11], 0
    mov ax, di
    call string_string_uppercase
    mov si, [.filename_loc]
    call string_string_compare
    pop bx
    pop di
    jc .found_file_to_load

.next_entry_sub:
    add bx, 32
    dec cx
    cmp cx, 0
    jg .continue_loop

    mov ax, [.current_cluster]
    call fs_get_next_directory_cluster
    jc .file_not_found_subdir 
    
    mov [.current_cluster], ax
    jmp .load_search_sector

.continue_loop:
    jmp .search_entries_sub_loop

.file_not_found_subdir:
    jmp .root_problem

.search_entries_loop:
    add bx, 32
    mov di, disk_buffer
    add di, bx
    mov al, [di]
    cmp al, 0
    je .root_problem
    cmp al, 229
    je .next_root_entry
    mov al, [di+11]
    cmp al, 0Fh
    je .next_root_entry
    test al, 18h
    jnz .next_root_entry
    
    mov byte [di+11], 0
    mov ax, di
    call string_string_uppercase
    mov si, [.filename_loc]
    call string_string_compare
    jc .found_file_to_load
.next_root_entry:
    loop .search_entries_loop
    jmp .root_problem

.root_problem:
    stc 
    ret

.found_file_to_load:
    mov ax, [di+28]
    mov word [.file_size], ax
    cmp ax, 0
    je .end_load
    mov ax, [di+26]
    mov word [.cluster], ax
    
    call fs_read_fat
    
.load_file_sector_loop:
    mov ax, word [.cluster]
    add ax, 31
    call fs_convert_l2hts
    mov bx, [.load_position]
    mov ah, 02
    mov al, 01
    stc
    int 13h
    jc .root_problem 

    mov ax, [.cluster]
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    mov si, disk_buffer
    add si, ax
    mov ax, word [ds:si]
    or dx, dx
    jz .even_file
.odd_file:
    shr ax, 4
    jmp .cont_file
.even_file:
    and ax, 0FFFh
.cont_file:
    mov word [.cluster], ax
    cmp ax, 0FF8h
    jae .end_load
    
    add word [.load_position], 512
    jmp .load_file_sector_loop

.end_load:
    mov bx, [.file_size]
    clc
    ret

.filename_loc dw 0
.load_position dw 0
.file_size dw 0
.cluster dw 0
.current_cluster dw 0

; ========================================================================
; FS_LOAD_HUGE_FILE - Loads a large file across segment boundaries
; IN : AX = file name, CX = load offset address, DX = load segment address 
; OUT : DX:AX = file size (DX=High, AX=Low), CF = error flag
; ========================================================================
fs_load_huge_file:
    push bx
    push cx
    push si
    push di
    push es
    push ds

    mov [.huge_offset], cx
    mov [.huge_segment], dx
    
    call string_string_uppercase
    call int_filename_convert
    mov [.huge_filename], ax

    call fs_reset_floppy
    jnc .floppy_ok
    jmp .error_exit

.floppy_ok:
    cmp byte [current_directory], 0
    je .search_root
    jmp .search_subdir

.search_root:
    mov ax, 19
    call fs_convert_l2hts
    mov si, disk_buffer
    mov bx, si
    mov ah, 2
    mov al, 14
    stc
    int 13h
    jc .error_exit
    
    mov cx, 224       
    mov bx, 0        

.scan_root_loop:
    mov di, disk_buffer
    add di, bx
    
    mov al, [di]
    cmp al, 0         
    je .error_exit
    cmp al, 0E5h       
    je .next_root
    
    mov al, [di+11]   
    cmp al, 0Fh        
    je .next_root
    test al, 18h      
    jnz .next_root
    
    push di
    push bx       
    mov byte [di+11], 0
    mov ax, di
    call string_string_uppercase
    mov si, [.huge_filename]
    call string_string_compare
    pop bx             
    pop di
    jc .found_file

.next_root:
    add bx, 32
    loop .scan_root_loop
    jmp .error_exit

.search_subdir:
    mov ax, current_directory
    call string_string_uppercase
    call int_dirname_convert
    jc .error_exit
    
    push ax
    call fs_read_root_dir
    pop ax
    
    mov di, disk_buffer
    call fs_get_root_entry
    jc .error_exit
    
    mov ax, [di+26]
    mov [.huge_curr_cluster], ax
    cmp ax, 0
    je .error_exit

.load_subdir_sector:
    mov ax, [.huge_curr_cluster]
    add ax, 31
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .error_exit
    
    mov bx, 64           
    mov cx, 14

.scan_subdir_loop:
    mov di, disk_buffer
    add di, bx
    mov al, [di]
    cmp al, 0
    je .error_exit
    cmp al, 0E5h
    je .next_sub
    mov al, [di+11]
    test al, 0x18
    jnz .next_sub

    push di
    push bx
    mov byte [di+11], 0
    mov ax, di
    call string_string_uppercase
    mov si, [.huge_filename]
    call string_string_compare
    pop bx
    pop di
    jc .found_file

.next_sub:
    add bx, 32
    dec cx
    jnz .scan_subdir_loop
    
    mov ax, [.huge_curr_cluster]
    call fs_get_next_directory_cluster
    jc .error_exit
    mov [.huge_curr_cluster], ax
    jmp .load_subdir_sector

.found_file:
    mov ax, [di+28]        
    mov word [.huge_filesize_low], ax
    mov ax, [di+30]       
    mov word [.huge_filesize_high], ax
    
    mov ax, [di+26]
    mov word [.huge_cluster], ax
    
    cmp word [.huge_filesize_low], 0
    jne .start_load
    cmp word [.huge_filesize_high], 0
    jne .start_load
    jmp .success_exit_empty  
    
.start_load:
    call fs_read_fat 

.load_loop:
    mov ax, word [.huge_cluster]
    add ax, 31
    call fs_convert_l2hts
    
    mov es, [.huge_segment] 
    mov bx, [.huge_offset]  
    
    mov ah, 02
    mov al, 01
    stc
    int 13h
    
    push ds
    pop es
    
    jc .error_exit

    add word [.huge_offset], 512
    jnc .check_next_cluster
    
    add word [.huge_segment], 0x1000 

.check_next_cluster:
    mov ax, [.huge_cluster]
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    mov si, disk_buffer
    add si, ax
    mov ax, word [ds:si]
    or dx, dx
    jz .even_cluster
.odd_cluster:
    shr ax, 4
    jmp .got_next_cluster
.even_cluster:
    and ax, 0FFFh
.got_next_cluster:
    mov word [.huge_cluster], ax
    cmp ax, 0FF8h
    jae .success_exit
    
    jmp .load_loop

.success_exit:
    mov ax, [.huge_filesize_low]
    mov dx, [.huge_filesize_high]
    
    pop ds
    pop es
    pop di
    pop si
    pop cx
    pop bx
    clc
    ret

.success_exit_empty:
    xor ax, ax
    xor dx, dx
    pop ds
    pop es
    pop di
    pop si
    pop cx
    pop bx
    clc
    ret

.error_exit:
    pop ds
    pop es
    pop di
    pop si
    pop cx
    pop bx
    stc
    ret

.huge_filename       dw 0
.huge_segment        dw 0
.huge_offset         dw 0
.huge_filesize_low   dw 0 
.huge_filesize_high  dw 0
.huge_cluster        dw 0
.huge_curr_cluster   dw 0

; ========================================================================
; FS_WRITE_FILE - Writes a file to the current directory
; IN : AX = file name, BX = data address, CX = size
; OUT : CF = error flag
; ========================================================================
fs_write_file:
    pusha

    mov si, ax
    call string_string_length
    cmp ax, 0
    je near .failure
    mov ax, si

    call string_string_uppercase
    call int_filename_convert
    jc near .failure

    mov word [.filesize], cx
    mov word [.location], bx
    mov word [.filename], ax

    call fs_file_exists
    jc .create_new_file
    
    mov ax, [.filename]
    call fs_remove_file
    jc .failure

.create_new_file:
    pusha
    mov di, .free_clusters
    mov cx, 128
.clean_free_loop:
    mov word [di], 0
    inc di
    inc di
    loop .clean_free_loop
    popa

    mov ax, cx
    mov dx, 0
    mov bx, 512
    div bx
    cmp dx, 0
    jg .add_a_bit
    jmp .carry_on

.add_a_bit:
    add ax, 1
.carry_on:
    mov word [.clusters_needed], ax

    mov word ax, [.filename]
    call fs_create_file
    jc near .failure

    mov word bx, [.filesize]
    cmp bx, 0
    je near .finished

    call fs_read_fat
    mov si, disk_buffer + 3
    mov bx, 2
    mov word cx, [.clusters_needed]
    mov dx, 0

.find_free_cluster:
    lodsw
    and ax, 0FFFh
    jz .found_free_even
.more_odd:
    inc bx
    dec si
    lodsw
    shr ax, 4
    or ax, ax
    jz .found_free_odd
.more_even:
    inc bx
    jmp .find_free_cluster

.found_free_even:
    push si
    mov si, .free_clusters
    add si, dx
    mov word [si], bx
    pop si
    dec cx
    cmp cx, 0
    je .finished_list
    inc dx
    inc dx
    jmp .more_odd

.found_free_odd:
    push si
    mov si, .free_clusters
    add si, dx
    mov word [si], bx
    pop si
    dec cx
    cmp cx, 0
    je .finished_list
    inc dx
    inc dx
    jmp .more_even

.finished_list:
    mov cx, 0
    mov word [.count], 1

.chain_loop:
    mov word ax, [.count]
    cmp word ax, [.clusters_needed]
    je .last_cluster

    mov di, .free_clusters
    add di, cx
    mov word bx, [di]
    mov ax, bx
    mov dx, 0
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    mov si, disk_buffer
    add si, ax
    mov ax, word [ds:si]
    or dx, dx
    jz .even

.odd:
    and ax, 000Fh
    mov di, .free_clusters
    add di, cx
    mov word bx, [di+2]
    shl bx, 4
    add ax, bx
    mov word [ds:si], ax
    inc word [.count]
    inc cx
    inc cx
    jmp .chain_loop

.even:
    and ax, 0F000h
    mov di, .free_clusters
    add di, cx
    mov word bx, [di+2]
    add ax, bx
    mov word [ds:si], ax
    inc word [.count]
    inc cx
    inc cx
    jmp .chain_loop

.last_cluster:
    mov di, .free_clusters
    add di, cx
    mov word bx, [di]
    mov ax, bx
    mov dx, 0
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    mov si, disk_buffer
    add si, ax
    mov ax, word [ds:si]
    or dx, dx
    jz .even_last

.odd_last:
    and ax, 000Fh
    add ax, 0FF80h
    jmp .finito

.even_last:
    and ax, 0F000h
    add ax, 0FF8h

.finito:
    mov word [ds:si], ax
    
    call fs_write_fat
    jc .failure
    
    mov cx, 0
.save_loop:
    mov di, .free_clusters
    add di, cx
    mov word ax, [di]
    cmp ax, 0
    je near .write_entry
    
    pusha
    add ax, 31
    call fs_convert_l2hts
    mov word bx, [.location]
    mov ah, 3
    mov al, 1
    stc
    int 13h
    popa
    jc .failure
    
    add word [.location], 512
    inc cx
    inc cx
    jmp .save_loop

.write_entry:
    mov ax, [.free_clusters]    
    mov [.first_cluster], ax
    mov cx, [.filesize]       
    mov [.file_size_backup], cx
    
    cmp byte [current_directory], 0
    je .write_to_root
    jmp .write_to_subdir

.write_to_root:
    call fs_read_root_dir
    jc .failure
    
    mov word ax, [.filename]
    mov di, disk_buffer
    call fs_get_root_entry
    jc .failure
    
    mov ax, [.first_cluster]
    mov word [di+26], ax
    mov cx, [.file_size_backup]
    mov word [di+28], cx
    mov byte [di+30], 0
    mov byte [di+31], 0
    
    call fs_write_root_dir
    jc .failure
    jmp .finished

.write_to_subdir:
    mov ax, current_directory
    call string_string_uppercase
    call int_dirname_convert
    jc .failure
    
    push ax
    call fs_read_root_dir
    jc .failure_pop
    pop ax
    
    mov di, disk_buffer
    call fs_get_root_entry
    jc .failure
    
    mov ax, [di+26]
    cmp ax, 0
    je .failure
    
    mov [.dir_cluster], ax
    
    add ax, 31
    call fs_convert_l2hts
    
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .failure
    
    mov word ax, [.filename]
    mov di, disk_buffer 
    call fs_get_root_entry
    jc .failure
    
    mov ax, [.first_cluster]
    mov word [di+26], ax
    mov cx, [.file_size_backup]
    mov word [di+28], cx
    mov byte [di+30], 0
    mov byte [di+31], 0
    
    mov ax, [.dir_cluster]
    add ax, 31
    call fs_convert_l2hts
    
    mov bx, disk_buffer
    mov ah, 3
    mov al, 1
    stc
    int 13h
    jc .failure

.finished:
    popa
    clc
    ret

.failure_pop:
    pop ax
.failure:
    popa
    stc
    ret

.filesize          dw 0
.cluster           dw 0
.count             dw 0
.location          dw 0
.clusters_needed   dw 0
.filename          dw 0
.first_cluster     dw 0
.file_size_backup  dw 0
.dir_cluster       dw 0
.free_clusters     times 128 dw 0

; =========================================================================
; FS_FILE_EXISTS - Checks if a file exists in the current directory
; IN : AX = file name
; OUT : CF = 0 if exists, CF = 1 if not
; =======================================================================
fs_file_exists:
    call string_string_uppercase
    call int_filename_convert
    push ax
    call string_string_length
    cmp ax, 0
    je .fail_ret
    pop ax
    
    cmp byte [current_directory], 0
    je .check_in_root
    jmp .check_in_subdir

.check_in_root:
    push ax
    call fs_read_root_dir
    pop ax
    mov di, disk_buffer
    call fs_get_root_entry
    ret

.check_in_subdir:
    push ax
    mov [.search_file], ax
    
    mov ax, current_directory
    call string_string_uppercase
    call int_dirname_convert
    jc .fail_ret_pop
    
    push ax
    call fs_read_root_dir
    pop ax
    
    mov di, disk_buffer
    call fs_get_root_entry
    jc .fail_ret_pop
    
    mov ax, [di+26]
    mov [.current_cluster], ax
    cmp ax, 0
    je .fail_ret_pop

.scan_cluster:
    mov ax, [.current_cluster]
    add ax, 31
    call fs_convert_l2hts
    
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .fail_ret_pop
    
    mov di, disk_buffer 
    mov cx, 16    

.search_loop_sub:
    mov al, [di]
    cmp al, 0
    je .not_found_pop
    cmp al, 0E5h
    je .next_entry
    
    mov al, [di+11]
    cmp al, 0Fh
    je .next_entry
    test al, 0x08
    jnz .next_entry
    
    push di
    push cx
    mov byte [di+11], 0
    mov ax, di
    call string_string_uppercase
    
    mov si, [.search_file]
    mov cx, 11
    rep cmpsb
    pop cx
    pop di
    je .found_pop
    
.next_entry:
    add di, 32
    dec cx
    cmp cx, 0
    jg .search_loop_sub
    
    mov ax, [.current_cluster]
    call fs_get_next_directory_cluster
    jc .not_found_pop
    
    mov [.current_cluster], ax
    jmp .scan_cluster
    
.found_pop:
    pop ax 
    clc
    ret

.fail_ret_pop:
    pop ax
.fail_ret:
    stc
    ret

.not_found_pop:
    pop ax
    stc
    ret

.search_file dw 0
.current_cluster dw 0

; ========================================================================
; FS_CREATE_FILE - Creates a file in the current directory
; IN : AX = file name (8.3 format)
; OUT : CF = error flag
; ========================================================================
fs_create_file:
    clc
    call string_string_uppercase
    call int_filename_convert
    pusha
    push ax
    call fs_file_exists
    jnc .exists_error
    
    cmp byte [current_directory], 0
    je .create_in_root
    jmp .create_in_subdir

.create_in_root:
    mov di, disk_buffer
    mov cx, 224
    jmp .find_entry

.create_in_subdir:
    mov ax, current_directory
    call string_string_uppercase
    call int_dirname_convert
    jc .exists_error
    
    push ax
    call fs_read_root_dir
    pop ax
    
    mov di, disk_buffer
    call fs_get_root_entry
    jc .exists_error
    
    mov ax, [di+26]
    cmp ax, 0
    je .exists_error
    
    push ax
    add ax, 31
    call fs_convert_l2hts
    
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    pop ax
    jc .exists_error
    
    mov [.subdir_cluster], ax
    mov di, disk_buffer 
    mov cx, 14

.find_entry:
    mov byte al, [di]
    cmp al, 0
    je .found_free_entry
    cmp al, 0E5h
    je .found_free_entry
    add di, 32
    loop .find_entry

.exists_error:
    pop ax
    popa
    stc
    ret

.found_free_entry:
    pop si
    mov cx, 11
    rep movsb
    sub di, 11
    mov byte [di+11], 0
    mov byte [di+12], 0
    mov byte [di+13], 0
    mov byte [di+14], 0C6h
    mov byte [di+15], 07Eh
    mov byte [di+16], 0
    mov byte [di+17], 0
    mov byte [di+18], 0
    mov byte [di+19], 0
    mov byte [di+20], 0
    mov byte [di+21], 0
    mov byte [di+22], 0C6h
    mov byte [di+23], 07Eh
    mov byte [di+24], 0
    mov byte [di+25], 0
    mov byte [di+26], 0
    mov byte [di+27], 0
    mov byte [di+28], 0
    mov byte [di+29], 0
    mov byte [di+30], 0
    mov byte [di+31], 0
    
    cmp byte [current_directory], 0
    je .write_root
    
    mov ax, [.subdir_cluster]
    add ax, 31
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 3
    mov al, 1
    stc
    int 13h
    jc .failure
    popa
    clc
    ret
    
.write_root:
    call fs_write_root_dir
    jc .failure
    popa
    clc
    ret

.failure:
    popa
    stc
    ret

.subdir_cluster dw 0

; =========================================================================
; FS_REMOVE_FILE - Removes a file from the current directory
; IN : AX = file name
; OUT : CF = error flag
; =========================================================================
fs_remove_file:
    pusha
    call string_string_uppercase
    call int_filename_convert
    mov [.target_file], ax
    clc
    
    cmp byte [current_directory], 0
    je .remove_from_root
    jmp .remove_from_subdir

.remove_from_root:
    call fs_read_root_dir
    mov di, disk_buffer
    mov ax, [.target_file]
    call fs_get_root_entry
    jc .failure
    jmp .do_remove_root

.remove_from_subdir:
    mov ax, current_directory
    call string_string_uppercase
    call int_dirname_convert
    jc .failure
    
    push ax
    call fs_read_root_dir
    pop ax
    
    mov di, disk_buffer
    call fs_get_root_entry
    jc .failure
    
    mov ax, [di+26]
    mov [.subdir_cluster], ax
    cmp ax, 0
    je .failure
    
    mov [.current_cluster], ax

.scan_subdir_loop:
    mov ax, [.current_cluster]
    add ax, 31
    call fs_convert_l2hts
    
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .failure
    
    mov di, disk_buffer
    mov cx, 16

.search_entry:
    mov al, [di]
    cmp al, 0
    je .failure
    cmp al, 0E5h
    je .next_entry
    
    mov al, [di+11]
    test al, 0x08
    jnz .next_entry
    test al, 0x10
    jnz .next_entry

    push di
    push cx
    push si
    mov si, [.target_file]
    mov cx, 11
    repe cmpsb
    pop si
    pop cx
    pop di
    je .found_in_subdir

.next_entry:
    add di, 32
    loop .search_entry
    
    mov ax, [.current_cluster]
    call fs_get_next_directory_cluster
    jc .failure
    
    mov [.current_cluster], ax
    jmp .scan_subdir_loop

.found_in_subdir:
    mov ax, word [di+26]
    mov word [.cluster], ax
    
    mov byte [di], 0E5h
    inc di
    mov cx, 30
    mov al, 0
    rep stosb
    
    mov ax, [.current_cluster]
    add ax, 31
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 3
    mov al, 1
    stc
    int 13h
    jc .failure
    
    jmp .free_fat_chain

.do_remove_root:
    mov ax, word [di+26]
    mov word [.cluster], ax
    
    mov byte [di], 0E5h
    inc di
    mov cx, 30
    mov al, 0
    rep stosb
    
    call fs_write_root_dir
    jc .failure

.free_fat_chain:
    call fs_read_fat
    
.more_clusters:
    mov word ax, [.cluster]
    cmp ax, 0
    je .nothing_to_do
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    mov si, disk_buffer
    add si, ax
    mov ax, word [ds:si]
    or dx, dx
    jz .even

.odd:
    push ax
    and ax, 000Fh
    mov word [ds:si], ax
    pop ax
    shr ax, 4
    jmp .calculate_cluster_cont

.even:
    push ax
    and ax, 0F000h
    mov word [ds:si], ax
    pop ax
    and ax, 0FFFh

.calculate_cluster_cont:
    mov word [.cluster], ax
    cmp ax, 0FF8h
    jae .end
    jmp .more_clusters

.end:
    call fs_write_fat
    jc .failure

.nothing_to_do:
    popa
    clc
    ret

.failure:
    popa
    stc
    ret

.cluster dw 0
.subdir_cluster dw 0
.current_cluster dw 0
.target_file dw 0

fs_rename_file:
    push bx
    push ax
    clc
    call fs_read_root_dir
    mov di, disk_buffer
    pop ax
    call string_string_uppercase
    call int_filename_convert
    call fs_get_root_entry
    jc .fail_read
    pop bx
    mov ax, bx
    call string_string_uppercase
    call int_filename_convert
    mov si, ax
    mov cx, 11
    rep movsb
    call fs_write_root_dir
    jc .fail_write
    clc
    ret

.fail_read:
    pop ax
    stc
    ret

.fail_write:
    stc
    ret

; ========================================================================
; FS_GET_FILE_SIZE - Gets the size of a file from the current directory
; IN : AX = file name
; OUT : EBX = size, CF = error flag
; =======================================================================
fs_get_file_size:
    pusha
    call string_string_uppercase
    call int_filename_convert
    clc
    push ax
    
    cmp byte [current_directory], 0
    je .size_in_root
    jmp .size_in_subdir

.size_in_root:
    call fs_read_root_dir
    jc .failure
    pop ax
    call fs_get_root_entry
    jc .failure
    jmp .get_size

.size_in_subdir:
    mov ax, current_directory
    call string_string_uppercase
    call int_dirname_convert
    pop bx
    push bx
    jc .failure
    
    push ax
    call fs_read_root_dir
    pop ax
    jc .failure
    
    mov di, disk_buffer
    call fs_get_root_entry
    jc .failure
    
    mov ax, [di+26]
    cmp ax, 0
    je .failure
    
    add ax, 31
    call fs_convert_l2hts
    
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .failure
    
    pop ax
    mov di, disk_buffer 
    call fs_get_root_entry
    jc .failure

.get_size:
    mov ebx, [di+28]
    mov [.tmp], ebx
    popa
    mov ebx, [.tmp]
    clc
    ret

.failure:
    popa
    stc
    ret

.tmp dd 0

fs_fatal_error:
    pusha
    mov si, ax               
    call print_string_red     
    call print_newline       
    popa
    jmp get_cmd             

int_filename_convert:
    pusha
    mov si, ax
    call string_string_length
    cmp ax, 14
    jg .failure
    cmp ax, 0
    je .failure
    mov dx, ax
    mov di, .dest_string
    mov cx, 0

.copy_loop:
    lodsb
    cmp al, '.'
    je .extension_found
    stosb
    inc cx
    cmp cx, dx
    jg .failure
    jmp .copy_loop

.extension_found:
    cmp cx, 0
    je .failure
    cmp cx, 8
    je .do_extension
.add_spaces:
    mov byte [di], ' '
    inc di
    inc cx
    cmp cx, 8
    jl .add_spaces
.do_extension:
    lodsb
    cmp al, 0
    je .failure
    stosb
    lodsb
    cmp al, 0
    je .failure
    stosb
    lodsb
    cmp al, 0
    je .failure
    stosb
    mov byte [di], 0
    popa
    mov ax, .dest_string
    clc
    ret

.failure:
    popa
    stc
    ret

.dest_string times 13 db 0

fs_get_root_entry:
    pusha
    mov word [.filename], ax
    mov cx, 224
    mov ax, 0

.to_next_root_entry:
    xchg cx, dx
    mov word si, [.filename]
    mov cx, 11
    rep cmpsb
    je .found_file
    add ax, 32
    mov di, disk_buffer
    add di, ax
    xchg dx, cx
    loop .to_next_root_entry
    popa
    stc
    ret

.found_file:
    sub di, 11
    mov word [.tmp], di
    popa
    mov word di, [.tmp]
    clc
    ret

.filename dw 0
.tmp dw 0

fs_read_fat:
    pusha
    mov ax, 1
    call fs_convert_l2hts
    mov si, disk_buffer
    mov bx, ds
    mov es, bx
    mov bx, si
    mov ah, 2
    mov al, 9
    pusha

.read_fat_loop:
    popa
    pusha
    stc
    int 13h
    jnc .fat_done
    call fs_reset_floppy
    jnc .read_fat_loop
    popa
    jmp .read_failure

.fat_done:
    popa
    popa
    clc
    ret

.read_failure:
    popa
    stc
    ret

fs_write_fat:
    pusha
    mov ax, 1
    call fs_convert_l2hts
    mov si, disk_buffer
    mov bx, ds
    mov es, bx
    mov bx, si
    mov ah, 3
    mov al, 9
    stc
    int 13h
    jc .write_failure
    popa
    clc
    ret

.write_failure:
    popa
    stc
    ret

fs_read_root_dir:
    pusha
    mov ax, 19
    call fs_convert_l2hts
    mov si, disk_buffer
    mov bx, ds
    mov es, bx
    mov bx, si
    mov ah, 2
    mov al, 14
    pusha

.read_root_dir_loop:
    popa
    pusha
    stc
    int 13h
    jnc .root_dir_finished
    call fs_reset_floppy
    jnc .read_root_dir_loop
    popa
    jmp .read_failure

.root_dir_finished:
    popa
    popa
    clc
    ret

.read_failure:
    popa
    stc
    ret

fs_write_root_dir:
    pusha
    mov ax, 19
    call fs_convert_l2hts
    mov si, disk_buffer
    mov bx, ds
    mov es, bx
    mov bx, si
    mov ah, 3
    mov al, 14
    stc
    int 13h
    jc .write_failure
    popa
    clc
    ret

.write_failure:
    popa
    stc
    ret

fs_reset_floppy:
    push ax
    push dx
    mov ax, 0
    mov dl, [bootdev]
    stc
    int 13h
    pop dx
    pop ax
    ret
    
fs_convert_l2hts:
	push bx
	push ax
	mov bx, ax		
	mov dx, 0		
	div word [SecsPerTrack]		
	add dl, 01h			
	mov cl, dl			
	mov ax, bx
	mov dx, 0		
	div word [SecsPerTrack]		
	mov dx, 0
	div word [Sides]		
	mov dh, dl		
	mov ch, al
	pop ax
	pop bx
	mov dl, [bootdev]
	ret

fs_free_space:
	pusha
	mov word [.counter], 0
	mov word [.sectors_read], 0
	
	call fs_read_fat
	mov si, disk_buffer
	
.loop:
	mov ax, [si]		
	mov bh, [si + 1]		
	mov bl, [si + 2]
	
	rol ax, 4				
	
	and ah, 0Fh	
	and bh, 0Fh			
		
	test ax, ax
	jnz .no_increment_1
	
	inc word [.counter]
	
.no_increment_1:
	test bx, bx
	jnz .no_increment_2
	
	inc word [.counter]
	
.no_increment_2:
	add si, 3			
	add word [.sectors_read], 2		
	
	cmp word [.sectors_read], 2847	
	jl .loop
	
	popa
	mov ax, [.counter]

	ret
	
	.counter		dw 0
	.sectors_read	dw 0


; =========================================================================
; FS_CREATE_DIRECTORY - Creates a new directory
; IN : AX = pointer to directory name
; OUT : CF = 0 if successful, CF = 1 if error
; ======================================================================
fs_create_directory:
    pusha

    mov si, ax
    mov di, .dir_name_buffer
    call string_string_copy

    mov ax, .dir_name_buffer
    call string_string_uppercase
    call int_dirname_convert    
    jc .failure
    
    mov [.dirname_converted], ax

    mov ax, [.dirname_converted]
    call fs_file_exists
    jnc .failure

    call fs_read_fat
    mov si, disk_buffer + 3
    mov bx, 2
    
.find_free_cluster:
    lodsw
    and ax, 0FFFh
    jz .found_free_cluster
    inc bx
    jmp .find_free_cluster
    
.found_free_cluster:
    mov [.cluster], bx
    
    mov ax, bx
    mov dx, 0
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    mov si, disk_buffer
    add si, ax
    
    or dx, dx
    jz .mark_even
    
.mark_odd:
    mov ax, word [ds:si]
    and ax, 000Fh
    add ax, 0FF80h
    mov word [ds:si], ax
    jmp .marked
    
.mark_even:
    mov ax, word [ds:si]
    and ax, 0F000h
    add ax, 0FF8h
    mov word [ds:si], ax
    
.marked:
    call fs_write_fat
    jc .failure
    
    mov di, 32768
    mov cx, 512
    xor ax, ax
    rep stosb
    
    mov di, 32768
    mov byte [di], '.'
    mov cx, 10
    mov al, ' '
.fill_dot_name:
    inc di
    stosb
    loop .fill_dot_name
    
    mov byte [di], 0x10 
    add di, 15
    mov ax, [.cluster]
    mov word [di], ax      
    
    mov di, 32768 + 32
    mov byte [di], '.'
    mov byte [di+1], '.'
    mov cx, 9
    mov al, ' '
    add di, 2
.fill_dotdot_name:
    stosb
    inc di
    loop .fill_dotdot_name
    
    mov byte [di], 0x10   
    add di, 15
    mov word [di], 0        
    
    mov ax, [.cluster]
    add ax, 31
    call fs_convert_l2hts
    mov bx, 32768
    mov ah, 3
    mov al, 1
    stc
    int 13h
    jc .failure

    call fs_read_root_dir
    mov di, disk_buffer
    mov cx, 224
    
.find_free_entry:
    mov al, [di]
    cmp al, 0
    je .found_entry
    cmp al, 0E5h
    je .found_entry
    add di, 32
    loop .find_free_entry
    jmp .failure
    
.found_entry:
    mov si, [.dirname_converted]
    mov cx, 11
    rep movsb
    
    sub di, 11
    mov byte [di+11], 0x10  
    mov byte [di+12], 0 
    mov byte [di+13], 0     
    mov word [di+14], 0      
    mov word [di+16], 0      
    mov word [di+18], 0   
    mov word [di+20], 0    
    mov word [di+22], 0     
    mov word [di+24], 0     
    mov ax, [.cluster]
    mov word [di+26], ax     
    mov dword [di+28], 0    
    
    call fs_write_root_dir
    jc .failure
    
    popa
    clc
    ret
    
.failure:
    popa
    stc
    ret

.dirname_converted  dw 0
.cluster            dw 0
.dir_name_buffer    times 32 db 0

; ========================================================================
; FS_IS_DIRECTORY - Checks if an element is a directory
; IN : AX = pointer to name
; OUT : CF = 0 if directory, CF = 1 if file, or not found
; AL = file attributes
; =======================================================================
fs_is_directory:
    pusha
    
    call string_string_uppercase
    call int_filename_convert
    jc .not_found
    
    push ax
    call fs_read_root_dir
    pop ax
    
    mov di, disk_buffer
    call fs_get_root_entry
    jc .not_found
    
    mov al, [di+11]
    test al, 0x10
    jz .not_directory
    
    mov [.tmp_attr], al
    popa
    mov al, [.tmp_attr]
    clc
    ret
    
.not_directory:
    popa
    stc
    ret
    
.not_found:
    popa
    stc
    ret

.tmp_attr db 0

; ======================================================================
; INT_DIRNAME_CONVERT - Converts a directory name to FAT12 format
; Automatically adds the .DIR extension if it does not exist
; IN : AX = pointer to the directory name
; OUT : AX = pointer to the converted name (8.3 format)
; CF = 0 on success, CF = 1 on error
; =======================================================================
int_dirname_convert:
    pusha
    mov si, ax
    call string_string_length
    cmp ax, 0
    je .failure
    
    mov dx, ax       
    mov di, .dest_string
    mov cx, 0
    mov si, ax
    mov si, [esp + 14]    
    
    push si
    mov bx, 0          
.check_dot:
    lodsb
    cmp al, 0
    je .no_dot_in_name
    cmp al, '.'
    je .has_dot_in_name
    jmp .check_dot
    
.has_dot_in_name:
    mov bx, 1
    
.no_dot_in_name:
    pop si
    
    cmp bx, 0
    jne .has_extension
    
.copy_name_only:
    lodsb
    cmp al, 0
    je .add_dir_extension
    cmp cx, 8
    jge .failure
    stosb
    inc cx
    jmp .copy_name_only
    
.add_dir_extension:
    cmp cx, 8
    jge .write_dir_ext
.pad_name:
    mov byte [di], ' '
    inc di
    inc cx
    cmp cx, 8
    jl .pad_name
    
.write_dir_ext:
    mov byte [di], 'D'
    inc di
    mov byte [di], 'I'
    inc di
    mov byte [di], 'R'
    inc di
    mov byte [di], 0
    popa
    mov ax, .dest_string
    clc
    ret
    
.has_extension:
    mov si, [esp + 14]  
    mov cx, 0
    
.copy_loop:
    lodsb
    cmp al, 0
    je .failure       
    cmp al, '.'
    je .extension_found
    stosb
    inc cx
    cmp cx, dx
    jg .failure
    jmp .copy_loop

.extension_found:
    cmp cx, 0
    je .failure
    cmp cx, 8
    je .do_extension
.add_spaces:
    mov byte [di], ' '
    inc di
    inc cx
    cmp cx, 8
    jl .add_spaces
    
.do_extension:
    lodsb
    cmp al, 0
    je .failure
    stosb
    lodsb
    cmp al, 0
    je .failure
    stosb
    lodsb
    cmp al, 0
    je .failure
    stosb
    mov byte [di], 0
    popa
    mov ax, .dest_string
    clc
    ret

.failure:
    popa
    stc
    ret

.dest_string times 13 db 0

; ========================================================================
; FS_REMOVE_DIRECTORY - Removes an empty directory
; IN : AX = pointer to the directory name
; OUT : CF = 0 if successful, CF = 1 if error
; ======================================================================
fs_remove_directory:
    pusha
    
    mov si, ax
    mov di, .original_name
    call string_string_copy
    
    mov ax, .original_name
    call string_string_uppercase
    call int_dirname_convert
    jc .failure
    
    mov [.dirname], ax
    
    mov ax, [.dirname]
    call fs_file_exists
    jc .failure
    
    call fs_read_root_dir
    mov ax, [.dirname]
    call fs_get_root_entry
    jc .failure
    
    mov al, [di+11]
    test al, 0x10
    jz .failure
    
    mov ax, [di+26]
    mov [.cluster], ax
    
    cmp ax, 0
    je .failure
    
    mov [.dir_entry_pos], di
    
    mov ax, [.cluster]
    add ax, 31
    call fs_convert_l2hts
    
    mov bx, 32768
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .failure
    
    mov si, 32768 + 64  
    mov cx, 14       
    
.check_empty_loop:
    mov al, [si]
    cmp al, 0
    je .next_entry
    cmp al, 0E5h
    je .next_entry
    jmp .not_empty
    
.next_entry:
    add si, 32
    loop .check_empty_loop
    
    call fs_read_root_dir
    
    mov di, [.dir_entry_pos]
    
    mov byte [di], 0E5h
    inc di
    mov cx, 31
    xor al, al
    rep stosb
    
    call fs_write_root_dir
    jc .failure
    
    call fs_read_fat
    jc .failure
    
    mov ax, [.cluster]
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    mov si, disk_buffer
    add si, ax
    
    or dx, dx
    jz .even_free
    
.odd_free:
    mov ax, word [ds:si]
    and ax, 000Fh
    mov word [ds:si], ax
    jmp .done_free
    
.even_free:
    mov ax, word [ds:si]
    and ax, 0F000h
    mov word [ds:si], ax
    
.done_free:
    call fs_write_fat
    jc .failure
    
    popa
    clc
    ret
    
.not_empty:
    popa
    stc
    ret
    
.failure:
    popa
    stc
    ret

.dirname         dw 0
.cluster         dw 0
.dir_entry_pos   dw 0
.original_name   times 32 db 0

; =========================================================================
; FS_CHANGE_DIRECTORY - Changes the current directory
; IN : AX = pointer to the directory name
; OUT : CF = 0 if successful, CF = 1 if error
; =======================================================================
fs_change_directory:
    pusha
    
    push ax
    call string_string_length
    cmp ax, 12    
    jg .length_failure 
    pop ax
    
    push ax
    call fs_file_exists
    jc .not_found
    pop ax
    
    push ax
    call fs_is_directory
    jc .not_directory
    pop ax
    
    mov si, ax
    mov di, current_directory
    call string_string_copy
    
    popa
    clc
    ret

.length_failure:      
    pop ax          
    jmp .failure

.not_found:
    pop ax
    jmp .failure  
.not_directory:
    pop ax
    jmp .failure

.failure:
    popa
    stc
    ret

; =========================================================================
; FS_PARENT_DIRECTORY - Go to the parent directory
; OUT : CF = 0 if successful, CF = 1 if already in the root
; =========================================================================
fs_parent_directory:
    pusha
    
    cmp byte [current_directory], 0
    je .already_root
    
    mov di, current_directory
    mov byte [di], 0
    
    popa
    clc
    ret

.already_root:
    popa
    stc
    ret

save_current_dir:
    pusha
    mov si, current_directory
    mov di, saved_directory
.copy:
    lodsb
    stosb
    cmp al, 0
    jne .copy
    popa
    ret

restore_current_dir:
    pusha
    mov si, saved_directory
    mov di, current_directory
.copy:
    lodsb
    stosb
    cmp al, 0
    jne .copy
    popa
    ret

enter_bin_dir:
    pusha
    mov si, bin_dir_name
    call cd_internal        
    popa
    ret

cd_internal:
    mov di, current_directory
    call string_string_copy
    clc
    ret
.fail:
    stc
    ret

fs_get_next_directory_cluster:
    push bx
    push cx
    push dx
    push si
    
    mov [.saved_cluster], ax
    
    call fs_read_fat
    
    mov ax, [.saved_cluster]
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    mov si, disk_buffer
    add si, ax
    mov ax, word [ds:si]
    
    or dx, dx
    jz .even_cluster
.odd_cluster:
    shr ax, 4
    jmp .check_eof
.even_cluster:
    and ax, 0FFFh

.check_eof:
    cmp ax, 0FF8h  
    jae .end_of_chain
    
    mov [.next_cluster], ax
    
    add ax, 31
    call fs_convert_l2hts
    
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .read_error
    
    mov ax, [.next_cluster]
    clc            
    jmp .return

.end_of_chain:
    stc         
    jmp .return

.read_error:
    stc

.return:
    pop si
    pop dx
    pop cx
    pop bx
    ret

.saved_cluster dw 0
.next_cluster  dw 0

; ========================================================================
; FS_LOAD_COM - Loads a COM file to specific segment
; IN : AX = file name
; IN : DX = load segment address
; OUT : BX = file size, CF = error flag
; ========================================================================
fs_load_com:
    call string_string_uppercase
    call int_filename_convert
    mov [.com_filename_loc], ax
    mov [.com_load_segment], dx
    mov word [.com_load_offset], 0x0100
    mov eax, 0
    call fs_reset_floppy
    jnc .floppy_ok
    stc 
    ret
.floppy_ok:
    cmp byte [current_directory], 0
    je .search_in_root
    jmp .search_in_subdir
.search_in_root:
    mov ax, 19
    call fs_convert_l2hts
    mov si, disk_buffer
    mov bx, si
    mov ah, 2
    mov al, 14
    stc
    int 13h
    jc .root_problem
    mov cx, 224
    mov bx, -32
    jmp .search_entries_loop
.search_in_subdir:
    mov ax, current_directory
    push ax
    call string_string_uppercase
    call int_dirname_convert
    pop bx
    jc .root_problem
    push ax
    call fs_read_root_dir
    pop ax
    mov di, disk_buffer
    call fs_get_root_entry
    jc .root_problem
    mov ax, [di+26] 
    mov [.com_current_cluster], ax
    cmp ax, 0
    je .root_problem
.load_search_sector:
    mov ax, [.com_current_cluster]
    add ax, 31
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .root_problem
    mov bx, 64          
    mov cx, 14     
.search_entries_sub_loop:
    mov di, disk_buffer
    add di, bx
    mov al, [di]
    cmp al, 0
    je .file_not_found_subdir 
    cmp al, 0E5h
    je .next_entry_sub
    mov al, [di+11]
    cmp al, 0Fh
    je .next_entry_sub
    test al, 0x08
    jnz .next_entry_sub
    test al, 0x10
    jnz .next_entry_sub
    push di
    push bx
    mov byte [di+11], 0
    mov ax, di
    call string_string_uppercase
    mov si, [.com_filename_loc]
    call string_string_compare
    pop bx
    pop di
    jc .found_file_to_load
.next_entry_sub:
    add bx, 32
    dec cx
    cmp cx, 0
    jg .continue_loop
    mov ax, [.com_current_cluster]
    call fs_get_next_directory_cluster
    jc .file_not_found_subdir 
    mov [.com_current_cluster], ax
    jmp .load_search_sector
.continue_loop:
    jmp .search_entries_sub_loop
.file_not_found_subdir:
    jmp .root_problem
.search_entries_loop:
    add bx, 32
    mov di, disk_buffer
    add di, bx
    mov al, [di]
    cmp al, 0
    je .root_problem
    cmp al, 229
    je .next_root_entry
    mov al, [di+11]
    cmp al, 0Fh
    je .next_root_entry
    test al, 18h
    jnz .next_root_entry
    mov byte [di+11], 0
    mov ax, di
    call string_string_uppercase
    mov si, [.com_filename_loc]
    call string_string_compare
    jc .found_file_to_load
.next_root_entry:
    loop .search_entries_loop
    jmp .root_problem
.root_problem:
    stc 
    ret
.found_file_to_load:
    mov ax, [di+28]
    mov word [.com_file_size], ax
    cmp ax, 0
    je .end_load
    mov ax, [di+26]
    mov word [.com_cluster], ax
    call fs_read_fat
.load_file_sector_loop:
    mov ax, word [.com_cluster]
    add ax, 31
    call fs_convert_l2hts
    mov bx, [.com_load_offset]
    mov es, [.com_load_segment]
    mov ah, 02
    mov al, 01
    stc
    int 13h
    push ds
    pop es
    jc .root_problem 
    mov ax, [.com_cluster]
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    mov si, disk_buffer
    add si, ax
    mov ax, word [ds:si]
    or dx, dx
    jz .even_file
.odd_file:
    shr ax, 4
    jmp .cont_file
.even_file:
    and ax, 0FFFh
.cont_file:
    mov word [.com_cluster], ax
    cmp ax, 0FF8h
    jae .end_load
    add word [.com_load_offset], 512
    jmp .load_file_sector_loop
.end_load:
    mov bx, [.com_file_size]
    clc
    ret
.com_filename_loc dw 0
.com_load_offset dw 0
.com_load_segment dw 0
.com_file_size dw 0
.com_cluster dw 0
.com_current_cluster dw 0