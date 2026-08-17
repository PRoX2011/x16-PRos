; ==================================================================
; x16-PRos - FAT12 file system functions for x16-PRos kernel
; Copyright (C) 2025 PRoX2011
; ==================================================================

; ==================================================================
; Some of the low-level FAT12 routines below are taken from MikeOS
;
; In its current form, most of the functions have been completely 
; or almost completely redesigned, but I still express my 
; enormous gratitude to MikeOS
;
; Copyright (C) 2006-2014 MikeOS Developers (https://github.com/mig-hub/mikeOS/blob/master/doc/LICENSE.TXT)
; ==================================================================

; =======================================================================
; FS_GET_FILE_LIST - Gets a list of files in the current directory
; IN : AX = pointer to the buffer for the list
; OUT : BX = total size of files (low word)
;       CX = total size of files (high word)
;       DX = number of files
;       CF = 0 if successful
;
; Buffer format: array of 18-byte entries:
;   Bytes 0-11:  Display name (12 bytes, "NAME     EXT" format)
;   Bytes 12-13: File size (low word)
;   Bytes 14-15: File size (high word)
;   Byte 16:     File attributes
;   Byte 17:     Reserved (0)
; End of list: first byte = 0
; =======================================================================
fs_get_file_list:
    push es
    pusha

    push ax
    mov ax, KERNEL_WORK_SEG
    mov es, ax
    pop ax

    mov word [.file_list_tmp], ax
    mov bx, ax
    add bx, 8188
    mov word [.file_list_limit], bx
    mov word [.total_size], 0
    mov word [.total_size+2], 0
    mov word [.file_count], 0

    cmp word [current_dir_cluster], 0
    je .list_root_dir

    jmp .list_subdir

.list_root_dir:
    call fs_reset_floppy

    mov ax, [fs_root_lba]
    call fs_convert_l2hts

    mov si, disk_buffer
    mov bx, si

    mov ah, 2
    mov al, [fs_root_secs]
    mov byte [.read_retries], 5
    pusha

.read_root_dir:
    popa
    pusha

    push ds
    pop es
    stc
    int 13h
    jnc .show_dir_init

    dec byte [.read_retries]
    jz .root_read_fail
    call fs_reset_floppy
    jnc .read_root_dir
    jmp .root_read_fail

.root_read_fail:
    popa
    jmp .done

.show_dir_init:
    popa

    mov ax, KERNEL_WORK_SEG
    mov es, ax
    xor ax, ax
    mov si, disk_buffer
    jmp .process_entries

.list_subdir:
    mov ax, [current_dir_cluster]
    call fs_cluster_lba
    mov [.current_cluster], ax

    call fs_convert_l2hts

    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    push ds
    pop es
    stc
    int 13h
    jc .done

    push ax
    mov ax, KERNEL_WORK_SEG
    mov es, ax
    pop ax

    mov si, disk_buffer + 64

.process_entries:
    mov word di, [.file_list_tmp]

.start_entry:
    mov bx, [.file_list_limit]
    cmp di, bx
    jae .done

    cmp word [current_dir_cluster], 0
    jne .check_subdir_end
    jmp .check_root_end

.check_subdir_end:
    mov ax, si
    sub ax, disk_buffer
    cmp ax, 512
    jl .check_entry

    mov ax, [.current_cluster]
    call fs_next_dir_sector
    jc .done

    mov [.current_cluster], ax
    call fs_convert_l2hts
    push es
    push ds
    pop es
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    pop es
    jc .done
    mov ax, KERNEL_WORK_SEG
    mov es, ax
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
    mov bx, [si+30]
    adc word [.total_size+2], bx

.is_directory:
    mov cx, 1
    mov dx, si
    mov word [.name_length], 0

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
    xor cx, cx

.loopy:
    mov byte al, [si]
    cmp al, ' '
    je .ignore_space

    mov byte [es:di], al

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
    mov byte [es:di], ' '
    inc di
    loop .add_spaces
    jmp .write_extension

.write_extension:
    mov cx, 8
.extension_loop:
    mov byte al, [si]
    cmp al, ' '
    je .pad_ext

    mov byte [es:di], al
    inc si
    inc di
    inc cx
    cmp cx, 11
    je .done_copy
    jmp .extension_loop

.pad_ext:
    mov byte [es:di], ' '
    inc di
    inc cx
    cmp cx, 11
    je .done_copy
    jmp .pad_ext

.done_copy:
    mov si, dx
    mov ax, [si+28]
    mov [es:di], ax
    mov ax, [si+30]
    mov [es:di+2], ax
    mov al, [si+11]
    mov [es:di+4], al
    mov byte [es:di+5], 0
    add di, 6

.nxtdirentry:
    mov si, dx

.skip:
    add si, 32
    jmp .start_entry

.done:
    push ax
    mov ax, KERNEL_WORK_SEG
    mov es, ax
    pop ax
    mov byte [es:di], 0

    popa
    pop es
    mov bx, [.total_size]
    mov cx, [.total_size+2]
    mov dx, [.file_count]
    clc
    ret

.file_list_tmp   dw 0
.file_list_limit dw 0
.total_size      dd 0
.file_count      dw 0
.name_length     dw 0
.current_cluster dw 0
.read_retries    db 0

; ========================================================================
; FS_LOAD_FILE - Loads a file from the current directory
; IN : AX = file name, CX = load address
; OUT : BX = file size, CF = error flag
; ========================================================================
fs_load_file:
    push ax
    push cx
    push dx

    mov dx, ds
    call fs_load_huge_file
    jc .failed

    mov bx, ax
    pop dx
    pop cx
    pop ax
    clc
    ret

.failed:
    pop dx
    pop cx
    pop ax
    stc
    ret

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
    cmp word [current_dir_cluster], 0
    je .search_root
    jmp .search_subdir

.search_root:
    mov ax, [fs_root_lba]
    call fs_convert_l2hts
    mov si, disk_buffer
    mov bx, si
    mov ah, 2
    mov al, [fs_root_secs]
    stc
    int 13h
    jc .error_exit

    mov cx, [fs_root_ents]
    xor bx, bx

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
    mov ax, [current_dir_cluster]
    call fs_cluster_lba
    mov [.huge_curr_cluster], ax

.load_subdir_sector:
    mov ax, [.huge_curr_cluster]
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .error_exit

    xor bx, bx
    mov cx, 16

.scan_subdir_loop:
    mov di, disk_buffer
    add di, bx
    mov al, [di]
    cmp al, 0
    je .error_exit
    cmp al, 0E5h
    je .next_sub
    mov al, [di+11]
    cmp al, 0Fh
    je .next_sub
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
    call fs_next_dir_sector
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
    mov ax, [.huge_filesize_low]
    mov dx, [.huge_filesize_high]
    add ax, 511
    adc dx, 0
    mov cl, 9
    shr ax, cl
    mov cl, 7
    shl dx, cl
    or ax, dx
    mov [.huge_secs_left], ax

    call fs_read_fat

    mov di, .chain_buf
    mov ax, [.huge_cluster]
    mov word [.chain_len], 0

.build_chain:
    mov [di], ax
    add di, 2
    inc word [.chain_len]
    cmp word [.chain_len], 128
    jae .chain_built

    call fs_fat_next_cluster
    jc .chain_built
    jmp .build_chain

.chain_built:
    mov word [.chain_idx], 0

.load_chain_loop:
    mov si, .chain_buf
    add si, [.chain_idx]
    mov ax, [si]

    call fs_cluster_lba
    mov [.sec_lba], ax
    mov ax, [fs_spc]
    mov [.sec_left], ax

.chain_sector:
    mov ax, [.sec_lba]
    call fs_convert_l2hts

    mov ax, [.huge_segment]
    shl ax, 4
    add ax, [.huge_offset]
    cmp ax, 0xFE00
    jbe .chain_direct_load

.chain_via_buffer:
    mov ax, FS_STAGE_SEG
    mov es, ax
    mov bx, FS_STAGE_OFF
    call fs_read_sector_retry
    jc .error_exit
    push ds
    mov es, [.huge_segment]
    mov di, [.huge_offset]
    mov ax, FS_STAGE_SEG
    mov ds, ax
    mov si, FS_STAGE_OFF
    mov cx, 256
    rep movsw
    pop ds
    jmp .chain_after_load

.chain_direct_load:
    mov es, [.huge_segment]
    mov bx, [.huge_offset]
    call fs_read_sector_retry

.chain_after_load:
    push ds
    pop es

    jc .error_exit

    add word [.huge_offset], 512
    jnc .chain_no_wrap
    add word [.huge_segment], 0x1000

.chain_no_wrap:
    dec word [.huge_secs_left]
    jz .success_exit

    inc word [.sec_lba]
    dec word [.sec_left]
    jnz .chain_sector

    add word [.chain_idx], 2
    mov ax, [.chain_idx]
    shr ax, 1
    cmp ax, [.chain_len]
    jae .chain_exhausted
    jmp .load_chain_loop

.chain_exhausted:
    cmp word [.chain_len], 128
    jb .success_exit

    call fs_read_fat

    mov si, .chain_buf
    add si, [.chain_idx]
    sub si, 2
    mov ax, [si]
    call fs_fat_next_cluster
    jc .success_exit
    mov [.huge_cluster], ax

.direct_load_loop:
    mov ax, word [.huge_cluster]
    call fs_cluster_lba
    mov [.sec_lba], ax
    mov ax, [fs_spc]
    mov [.sec_left], ax

.direct_sector:
    mov ax, [.sec_lba]
    call fs_convert_l2hts

    mov ax, [.huge_segment]
    shl ax, 4
    add ax, [.huge_offset]
    cmp ax, 0xFE00
    jbe .direct_load_to_dest

.direct_via_buffer:
    mov ax, FS_STAGE_SEG
    mov es, ax
    mov bx, FS_STAGE_OFF
    call fs_read_sector_retry
    jc .error_exit
    push ds
    mov es, [.huge_segment]
    mov di, [.huge_offset]
    mov ax, FS_STAGE_SEG
    mov ds, ax
    mov si, FS_STAGE_OFF
    mov cx, 256
    rep movsw
    pop ds
    jmp .direct_after_load

.direct_load_to_dest:
    mov es, [.huge_segment]
    mov bx, [.huge_offset]
    call fs_read_sector_retry

.direct_after_load:
    push ds
    pop es

    jc .error_exit

    add word [.huge_offset], 512
    jnc .direct_check_next
    add word [.huge_segment], 0x1000

.direct_check_next:
    dec word [.huge_secs_left]
    jz .success_exit

    inc word [.sec_lba]
    dec word [.sec_left]
    jnz .direct_sector

    mov ax, [.huge_cluster]
    call fs_fat_next_cluster
    mov word [.huge_cluster], ax
    jc .success_exit
    jmp .direct_load_loop

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
.chain_buf           times 128 dw 0
.chain_len           dw 0
.chain_idx           dw 0
.huge_secs_left      dw 0
.sec_lba             dw 0
.sec_left            dw 0

; ========================================================================
; FS_WRITE_HUGE_FILE - Writes a large file from arbitrary segment:offset
; IN : AX = filename, CX = source offset, DX = source segment
;      BX = filesize low word, DI = filesize high word
; OUT : CF = error flag
; ========================================================================
fs_write_huge_file:
    push bx
    push cx
    push si
    push di
    push es
    push ds

    mov [.wh_src_offset], cx
    mov [.wh_src_segment], dx
    mov [.wh_size_low], bx
    mov [.wh_size_high], di

    call string_string_uppercase
    call int_filename_convert
    jc .wh_error

    push es
    push si
    push di
    push cx
    push ds
    pop es
    mov si, ax
    mov di, .wh_name
    mov cx, 12
    cld
    rep movsb
    pop cx
    pop di
    pop si
    pop es
    mov word [.wh_filename], .wh_name

    call fs_reset_floppy
    jc .wh_error

    ; Remove existing file if present
    mov ax, [.wh_filename]
    call fs_file_exists
    jc .wh_no_existing
    mov ax, [.wh_filename]
    call fs_remove_file
    jc .wh_error

.wh_no_existing:
    ; Handle zero size - just create empty file
    mov ax, [.wh_size_low]
    or ax, [.wh_size_high]
    jnz .wh_calc_clusters

    mov ax, [.wh_filename]
    call fs_create_file
    jc .wh_error
    jmp .wh_success

.wh_calc_clusters:
    ; clusters_needed = ceil(filesize / 512)
    ; (size_high:size_low + 511) >> 9
    mov ax, [.wh_size_low]
    mov dx, [.wh_size_high]
    add ax, 511
    adc dx, 0
    ; shift DX:AX right by 9
    shr ax, 1
    mov cl, 8
    shr ax, cl
    push dx
    mov cl, 7
    shl dx, cl
    or ax, dx
    pop dx
    mov cx, [fs_spc]
    cmp cx, 1
    jbe .wh_spc_one
    add ax, cx
    dec ax
    xor dx, dx
    div cx
.wh_spc_one:
    mov [.wh_clusters_needed], ax

    ; Create empty file entry in directory
    mov ax, [.wh_filename]
    call fs_create_file
    jc .wh_error

    mov word [.wh_clusters_done], 0
    mov word [.wh_first_cluster], 0
    mov word [.wh_prev_last], 0

.wh_next_batch:
    ; Clean free_clusters buffer
    pusha
    mov di, .wh_free_clusters
    push cx
    mov cx, 128
.wh_clean:
    mov word [di], 0
    add di, 2
    loop .wh_clean
    pop cx
    popa

    mov ax, [.wh_clusters_needed]
    sub ax, [.wh_clusters_done]
    cmp ax, 128
    jbe .wh_batch_ok
    mov ax, 128
.wh_batch_ok:
    mov [.wh_batch_size], ax

    call fs_read_fat

    mov si, disk_buffer + 3
    mov bx, 2
    mov cx, [.wh_batch_size]
    xor dx, dx

.wh_find_free:
    lodsw
    and ax, 0FFFh
    jz .wh_free_even
.wh_next_odd:
    inc bx
    dec si
    lodsw
    shr ax, 4
    or ax, ax
    jz .wh_free_odd
.wh_next_even:
    inc bx
    jmp .wh_find_free

.wh_free_even:
    push si
    mov si, .wh_free_clusters
    add si, dx
    mov [si], bx
    pop si
    dec cx
    jz .wh_batch_found
    add dx, 2
    jmp .wh_next_odd

.wh_free_odd:
    push si
    mov si, .wh_free_clusters
    add si, dx
    mov [si], bx
    pop si
    dec cx
    jz .wh_batch_found
    add dx, 2
    jmp .wh_next_even

.wh_batch_found:
    ; Record first cluster of the whole file
    cmp word [.wh_first_cluster], 0
    jne .wh_link_prev
    mov ax, [.wh_free_clusters]
    mov [.wh_first_cluster], ax
    jmp .wh_build_chain

.wh_link_prev:
    ; Link previous batch last -> this batch first
    mov ax, [.wh_prev_last]
    xor dx, dx
    call fs_fat12_cluster_offset
    mov si, disk_buffer
    add si, ax
    mov ax, [ds:si]
    or dx, dx
    jz .wh_lnk_even
    and ax, 000Fh
    mov bx, [.wh_free_clusters]
    shl bx, 4
    or ax, bx
    mov [ds:si], ax
    jmp .wh_build_chain
.wh_lnk_even:
    and ax, 0F000h
    mov bx, [.wh_free_clusters]
    or ax, bx
    mov [ds:si], ax

.wh_build_chain:
    xor cx, cx
    mov word [.wh_chain_pos], 1

.wh_chain_loop:
    mov ax, [.wh_chain_pos]
    cmp ax, [.wh_batch_size]
    jae .wh_chain_last

    mov di, .wh_free_clusters
    add di, cx
    mov bx, [di]
    mov ax, bx
    xor dx, dx
    call fs_fat12_cluster_offset
    mov si, disk_buffer
    add si, ax
    mov ax, [ds:si]
    or dx, dx
    jz .wh_ch_even

    and ax, 000Fh
    mov di, .wh_free_clusters
    add di, cx
    mov bx, [di+2]
    shl bx, 4
    or ax, bx
    mov [ds:si], ax
    inc word [.wh_chain_pos]
    add cx, 2
    jmp .wh_chain_loop

.wh_ch_even:
    and ax, 0F000h
    mov di, .wh_free_clusters
    add di, cx
    mov bx, [di+2]
    or ax, bx
    mov [ds:si], ax
    inc word [.wh_chain_pos]
    add cx, 2
    jmp .wh_chain_loop

.wh_chain_last:
    ; Save last cluster of this batch for linking
    mov di, .wh_free_clusters
    add di, cx
    mov ax, [di]
    mov [.wh_prev_last], ax

    ; If this is the final batch, mark EOF
    mov ax, [.wh_clusters_done]
    add ax, [.wh_batch_size]
    cmp ax, [.wh_clusters_needed]
    jb .wh_write_fat

    ; Mark EOF on last cluster
    mov ax, [.wh_prev_last]
    xor dx, dx
    call fs_fat12_cluster_offset
    mov si, disk_buffer
    add si, ax
    mov ax, [ds:si]
    or dx, dx
    jz .wh_eof_even
    and ax, 000Fh
    or ax, 0FF80h
    mov [ds:si], ax
    jmp .wh_write_fat
.wh_eof_even:
    and ax, 0F000h
    or ax, 0FF8h
    mov [ds:si], ax

.wh_write_fat:
    call fs_write_fat
    jc .wh_error

    xor cx, cx

.wh_write_loop:
    mov di, .wh_free_clusters
    add di, cx
    mov ax, [di]
    test ax, ax
    jz .wh_batch_done

    mov [.wh_write_idx], cx
    mov [.wh_cur_cluster], ax
    mov word [.wh_sec_idx], 0

.wh_sector:
    push cx
    mov ax, [.wh_src_segment]
    mov cl, 4
    shl ax, cl
    add ax, [.wh_src_offset]
    pop cx
    cmp ax, 0xFE00
    ja .wh_via_buf

    mov ax, [.wh_cur_cluster]
    call fs_cluster_lba
    add ax, [.wh_sec_idx]
    call fs_convert_l2hts
    mov es, [.wh_src_segment]
    mov bx, [.wh_src_offset]
    mov ah, 3
    mov al, 1
    stc
    int 13h
    push ds
    pop es
    jc .wh_error
    jmp .wh_advance

.wh_via_buf:
    ; Stage 512 bytes from the source through the transfer buffer
    mov si, [.wh_src_offset]
    mov ax, [.wh_src_segment]
    push ds
    push es
    mov ds, ax
    mov ax, FS_STAGE_SEG
    mov es, ax
    mov di, FS_STAGE_OFF
    mov cx, 256
    rep movsw
    pop es
    pop ds

    mov ax, [.wh_cur_cluster]
    call fs_cluster_lba
    add ax, [.wh_sec_idx]
    call fs_convert_l2hts
    push es
    mov ax, FS_STAGE_SEG
    mov es, ax
    mov bx, FS_STAGE_OFF
    mov ah, 3
    mov al, 1
    stc
    int 13h
    pop es
    jc .wh_error

.wh_advance:
    add word [.wh_src_offset], 512
    jnc .wh_no_wrap
    add word [.wh_src_segment], 0x1000
.wh_no_wrap:
    mov ax, [.wh_sec_idx]
    inc ax
    mov [.wh_sec_idx], ax
    cmp ax, [fs_spc]
    jb .wh_sector

    mov cx, [.wh_write_idx]
    add cx, 2
    mov ax, cx
    shr ax, 1
    cmp ax, [.wh_batch_size]
    jb .wh_write_loop

.wh_batch_done:
    mov ax, [.wh_batch_size]
    add [.wh_clusters_done], ax
    mov ax, [.wh_clusters_done]
    cmp ax, [.wh_clusters_needed]
    jb .wh_next_batch

    ; Update directory entry with first cluster and 32-bit file size
    cmp word [current_dir_cluster], 0
    je .wh_update_root
    jmp .wh_update_subdir

.wh_update_root:
    call fs_read_root_dir
    jc .wh_error

    mov ax, [.wh_filename]
    mov di, disk_buffer
    call fs_get_root_entry
    jc .wh_error

    mov ax, [.wh_first_cluster]
    mov [di+26], ax
    mov ax, [.wh_size_low]
    mov [di+28], ax
    mov ax, [.wh_size_high]
    mov [di+30], ax

    call fs_write_root_dir
    jc .wh_error
    jmp .wh_success

.wh_update_subdir:
    mov ax, [current_dir_cluster]
    call fs_cluster_lba
    mov [.wh_dir_cluster], ax

.wh_dir_read:
    mov ax, [.wh_dir_cluster]
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .wh_error

    mov ax, [.wh_filename]
    mov di, disk_buffer
    call fs_get_subdir_entry
    jnc .wh_entry_found

    mov ax, [.wh_dir_cluster]
    call fs_next_dir_sector
    jc .wh_error
    mov [.wh_dir_cluster], ax
    jmp .wh_dir_read

.wh_entry_found:
    mov ax, [.wh_first_cluster]
    mov [di+26], ax
    mov ax, [.wh_size_low]
    mov [di+28], ax
    mov ax, [.wh_size_high]
    mov [di+30], ax

    mov ax, [.wh_dir_cluster]
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 3
    mov al, 1
    stc
    int 13h
    jc .wh_error

.wh_success:
    pop ds
    pop es
    pop di
    pop si
    pop cx
    pop bx
    clc
    ret

.wh_error:
    pop ds
    pop es
    pop di
    pop si
    pop cx
    pop bx
    stc
    ret

.wh_filename         dw 0
.wh_src_segment      dw 0
.wh_src_offset       dw 0
.wh_size_low         dw 0
.wh_size_high        dw 0
.wh_clusters_needed  dw 0
.wh_clusters_done    dw 0
.wh_batch_size       dw 0
.wh_first_cluster    dw 0
.wh_prev_last        dw 0
.wh_chain_pos        dw 0
.wh_write_idx        dw 0
.wh_sec_idx          dw 0
.wh_cur_cluster      dw 0
.wh_dir_cluster      dw 0
.wh_name             times 13  db 0
.wh_free_clusters    times 128 dw 0

; ========================================================================
; FS_WRITE_FILE - Writes a file to the current directory
; IN : AX = file name, BX = data address, CX = size
; OUT : CF = error flag
; ========================================================================
fs_write_file:
    pusha

    mov dx, ds
    xchg bx, cx
    xor di, di
    call fs_write_huge_file
    jc .failed

    popa
    clc
    ret

.failed:
    popa
    stc
    ret

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
    test ax, ax
    je .fail_ret
    pop ax

    cmp word [current_dir_cluster], 0
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

    mov ax, [current_dir_cluster]
    call fs_cluster_lba
    mov [.current_cluster], ax

.scan_cluster:
    mov ax, [.current_cluster]
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
    call fs_next_dir_sector
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

    cmp word [current_dir_cluster], 0
    je .create_in_root
    jmp .create_in_subdir

.create_in_root:
    mov di, disk_buffer
    mov cx, [fs_root_ents]

.find_entry:
    mov byte al, [di]
    cmp al, 0
    je .found_free_entry
    cmp al, 0E5h
    je .found_free_entry
    add di, 32
    loop .find_entry
    jmp .exists_error
.create_in_subdir:
    mov ax, [current_dir_cluster]
    call fs_cluster_lba
    mov [.subdir_cluster], ax

.sub_read:
    mov ax, [.subdir_cluster]
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .exists_error

    mov di, disk_buffer
    mov cx, 16
.sub_find:
    mov byte al, [di]
    cmp al, 0
    je .found_free_entry
    cmp al, 0E5h
    je .found_free_entry
    add di, 32
    loop .sub_find

    mov ax, [.subdir_cluster]
    call fs_next_dir_sector
    jc .exists_error
    mov [.subdir_cluster], ax
    jmp .sub_read

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

    cmp word [current_dir_cluster], 0
    je .write_root

    mov ax, [.subdir_cluster]
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

    cmp word [current_dir_cluster], 0
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
    mov ax, [current_dir_cluster]
    mov [.subdir_cluster], ax
    call fs_cluster_lba
    mov [.current_cluster], ax

.scan_subdir_loop:
    mov ax, [.current_cluster]
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
    call fs_next_dir_sector
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
    test ax, ax
    je .nothing_to_do
    call fs_fat12_cluster_offset
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

    cmp word [current_dir_cluster], 0
    jne .rename_in_subdir

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

.rename_in_subdir:
    mov ax, [current_dir_cluster]
    mov [.rename_cluster], ax
    call fs_cluster_lba
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .fail_read_sub

    mov di, disk_buffer
    pop ax
    call string_string_uppercase
    call int_filename_convert
    call fs_get_subdir_entry
    jc .fail_read
    pop bx
    mov ax, bx
    call string_string_uppercase
    call int_filename_convert
    mov si, ax
    mov cx, 11
    rep movsb

    mov ax, [.rename_cluster]
    call fs_cluster_lba
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 3
    mov al, 1
    stc
    int 13h
    jc .fail_write
    clc
    ret

.fail_read_sub:
    pop ax
.fail_read:
    pop ax
    stc
    ret

.fail_write:
    stc
    ret

.rename_cluster dw 0

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

    cmp word [current_dir_cluster], 0
    je .size_in_root
    jmp .size_in_subdir

.size_in_root:
    call fs_read_root_dir
    jc .failure_pushed
    pop ax
    mov di, disk_buffer
    call fs_get_root_entry
    jc .failure
    jmp .get_size

.size_in_subdir:
    mov ax, [current_dir_cluster]
    call fs_cluster_lba
    call fs_convert_l2hts

    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .failure_pushed

    pop ax
    mov di, disk_buffer
    call fs_get_subdir_entry
    jc .failure

.get_size:
    mov ebx, [di+28]
    mov [.tmp], ebx
    mov bx, [di+26]
    mov [.clus], bx
    popa
    mov ebx, [.tmp]
    mov dx, [.tmp+2]
    mov cx, [.clus]
    clc
    ret
    
.failure_pushed:
    pop ax

.failure:
    popa
    stc
    ret

.tmp dd 0
.clus dw 0

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
    test ax, ax
    je .failure
    mov dx, ax
    mov di, .dest_string
    xor cx, cx

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
    test cx, cx
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
; FS_GET_DIR_ENTRY - Searches disk_buffer for a directory entry
; IN : AX = file name (8.3 format)
;      CX = entries to scan
;      DI = first entry
; OUT : DI = entry, CF = error flag
; ========================================================================
fs_get_dir_entry:
    pusha
    mov word [.filename], ax
    xor ax, ax

.to_next_entry:
    xchg cx, dx
    mov word si, [.filename]
    mov cx, 11
    rep cmpsb
    je .found_file
    add ax, 32
    mov di, disk_buffer
    add di, ax
    xchg dx, cx
    loop .to_next_entry
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

; ========================================================================
; FS_GET_ROOT_ENTRY - Searches the root directory held in disk_buffer
; IN : AX = file name (8.3 format)
;      DI = first entry
; OUT : DI = entry
;       CF = error flag
; ========================================================================
fs_get_root_entry:
    push cx
    mov cx, [fs_root_ents]
    call fs_get_dir_entry
    pop cx
    ret

; ========================================================================
; FS_GET_SUBDIR_ENTRY - Searches one subdirectory sector in disk_buffer
; IN : AX = file name (8.3 format)
;      DI = first entry
; OUT : DI = entry
;       CF = error flag
; ========================================================================
fs_get_subdir_entry:
    push cx
    mov cx, 16
    call fs_get_dir_entry
    pop cx
    ret

fs_read_fat:
    push es
    pusha
    mov ax, [fs_fat_lba]
    call fs_convert_l2hts
    mov si, disk_buffer
    mov bx, ds
    mov es, bx
    mov bx, si
    mov ah, 2
    mov al, [fs_fat_secs]
    mov byte [.retries], 5
    pusha

.read_fat_loop:
    popa
    pusha
    stc
    int 13h
    jnc .fat_done
    dec byte [.retries]
    jz .retry_exhausted
    call fs_reset_floppy
    jnc .read_fat_loop

.retry_exhausted:
    popa
    jmp .read_failure

.fat_done:
    popa
    popa
    pop es
    clc
    ret

.read_failure:
    popa
    pop es
    stc
    ret

.retries db 0

fs_write_fat:
    pusha
    mov ax, [fs_fat_lba]
    call fs_convert_l2hts
    mov si, disk_buffer
    mov bx, ds
    mov es, bx
    mov bx, si
    mov ah, 3
    mov al, [fs_fat_secs]
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
    mov ax, [fs_root_lba]
    call fs_convert_l2hts
    mov si, disk_buffer
    mov bx, ds
    mov es, bx
    mov bx, si
    mov ah, 2
    mov al, [fs_root_secs]
    mov byte [.retries], 5
    pusha

.read_root_dir_loop:
    popa
    pusha
    stc
    int 13h
    jnc .root_dir_finished
    dec byte [.retries]
    jz .retry_exhausted
    call fs_reset_floppy
    jnc .read_root_dir_loop

.retry_exhausted:
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

.retries db 0

fs_write_root_dir:
    pusha
    mov ax, [fs_root_lba]
    call fs_convert_l2hts
    mov si, disk_buffer
    mov bx, ds
    mov es, bx
    mov bx, si
    mov ah, 3
    mov al, [fs_root_secs]
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
    xor ax, ax
    mov dl, [current_disk]
    stc
    int 13h
    pop dx
    pop ax
    ret

; ========================================================================
; FS_READ_SECTOR_RETRY - Reads one sector, retrying a few times
; IN : CX, DX as fs_convert_l2hts left them, ES:BX = destination
; OUT : CF = 1 only if every attempt failed
; ========================================================================
fs_read_sector_retry:
    push ax
    push cx
    push dx
    mov byte [.tries], 5
.attempt:
    push cx
    push dx
    mov ah, 0x02
    mov al, 0x01
    stc
    int 13h
    pop dx
    pop cx
    jnc .ok
    dec byte [.tries]
    jz .fail
    push bx
    push cx
    push dx
    call fs_reset_floppy
    pop dx
    pop cx
    pop bx
    jmp .attempt
.ok:
    pop dx
    pop cx
    pop ax
    clc
    ret
.fail:
    pop dx
    pop cx
    pop ax
    stc
    ret
.tries db 0

; ========================================================================
; FS_NEXT_DIR_SECTOR - Steps one sector along a directory
; IN : AX = LBA of the current directory sector
; OUT : AX = LBA of the next one
;       CF = 1 once the directory ends
; ========================================================================
fs_next_dir_sector:
    push bx
    push cx
    push dx

    mov bx, ax
    sub ax, [fs_clus_base]
    xor dx, dx
    div word [fs_spc]

    inc dx
    cmp dx, [fs_spc]
    jb .same_cluster

    push ax
    call fs_read_fat
    pop ax
    jc .end
    call fs_fat_next_cluster
    jc .end
    call fs_cluster_lba
    jmp .out

.same_cluster:
    mov ax, bx
    inc ax
.out:
    pop dx
    pop cx
    pop bx
    clc
    ret
.end:
    pop dx
    pop cx
    pop bx
    stc
    ret

; ========================================================================
; FS_CLUSTER_LBA - First sector of a cluster on the mounted volume
; IN : AX = cluster number
; OUT : AX = LBA
;
; NOTE: on a floppy this is the familiar cluster + 31, but a hard disk
; is formatted with several sectors to a cluster, so the multiply has
; to stay.
; ========================================================================
fs_cluster_lba:
    push dx
    mul word [fs_spc]
    add ax, [fs_clus_base]
    pop dx
    ret

fs_convert_l2hts:
	push bx
	push ax
	mov bx, ax
	xor dx, dx
	div word [SecsPerTrack]
	add dl, 01h
	mov cl, dl
	mov ax, bx
	xor dx, dx
	div word [SecsPerTrack]
	xor dx, dx
	div word [Sides]
	mov dh, dl
	mov ch, al
	pop ax
	pop bx
	mov dl, [current_disk]
	ret

; ========================================================================
; FS_FAT_NEXT_CLUSTER - Follows the FAT12 chain one link along
; IN : AX = cluster, FAT already read into disk_buffer
; OUT : AX = next cluster
;       CF = 1 at the end of the chain
; ========================================================================
fs_fat_next_cluster:
    push cx
    push dx
    push si

    call fs_fat12_cluster_offset
    mov si, disk_buffer
    add si, ax
    mov ax, word [ds:si]
    or dx, dx
    jz .even
    mov cl, 4
    shr ax, cl
    jmp .check
.even:
    and ax, 0FFFh
.check:
    cmp ax, 0FF8h
    jae .end

    pop si
    pop dx
    pop cx
    clc
    ret

.end:
    pop si
    pop dx
    pop cx
    stc
    ret

; ========================================================================
; FS_FAT12_CLUSTER_OFFSET - Converts FAT12 cluster to FAT table entry offset
; IN : AX = cluster
; OUT: AX = FAT entry offset, DX = odd/even selector
; ========================================================================
fs_fat12_cluster_offset:
    push bx
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    pop bx
    ret

; ========================================================================
; FS_CLUS_TO_KB - Converts a cluster count into kilobytes
; IN : AX = clusters
; OUT : AX = kilobytes
; ========================================================================
fs_clus_to_kb:
    push dx
    mul word [fs_spc]
    shr dx, 1
    rcr ax, 1
    pop dx
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

	mov ax, [.sectors_read]
	cmp ax, [fs_total_clus]
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
    mov bx, 2

.find_free_cluster:
    mov ax, bx
    call fs_fat12_cluster_offset   ; ax = byte offset in FAT, dx = 0 (even) or 1 (odd)
    mov si, disk_buffer
    add si, ax
    mov ax, word [ds:si]
    or dx, dx
    jz .ffc_even
    shr ax, 4
.ffc_even:
    and ax, 0FFFh
    jz .found_free_cluster
    inc bx
    jmp .find_free_cluster

.found_free_cluster:
    mov [.cluster], bx

    mov ax, bx
    xor dx, dx
    call fs_fat12_cluster_offset
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

    mov di, disk_buffer
    mov cx, 512
    xor ax, ax
    rep stosb

    mov di, disk_buffer
    mov byte [di], '.'
    inc di
    mov cx, 10
    mov al, ' '
    rep stosb

    mov byte [di], 0x10
    add di, 15
    mov ax, [.cluster]
    mov word [di], ax

    mov di, disk_buffer + 32
    mov byte [di], '.'
    mov byte [di+1], '.'
    add di, 2
    mov cx, 9
    mov al, ' '
    rep stosb

    mov byte [di], 0x10
    add di, 15
    mov ax, [current_dir_cluster]
    mov word [di], ax

    mov ax, [.cluster]
    call fs_cluster_lba
    mov [.dir_lba], ax
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 3
    mov al, 1
    stc
    int 13h
    jc .failure
    mov word [.dir_left], 1
.blank_rest:
    mov ax, [.dir_left]
    cmp ax, [fs_spc]
    jae .blanked

    mov di, disk_buffer
    mov cx, 512
    xor al, al
    rep stosb

    mov ax, [.dir_lba]
    add ax, [.dir_left]
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 3
    mov al, 1
    stc
    int 13h
    jc .failure

    inc word [.dir_left]
    jmp .blank_rest
.blanked:

    cmp word [current_dir_cluster], 0
    jne .create_entry_in_subdir

    call fs_read_root_dir
    mov di, disk_buffer
    mov cx, [fs_root_ents]

.find_free_entry:
    mov al, [di]
    cmp al, 0
    je .found_entry
    cmp al, 0E5h
    je .found_entry
    add di, 32
    loop .find_free_entry
    jmp .failure

.create_entry_in_subdir:
    mov ax, [current_dir_cluster]
    mov [.parent_cluster], ax
    call fs_cluster_lba
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .failure

    mov di, disk_buffer
    mov cx, 16

.find_free_entry_sub:
    mov al, [di]
    cmp al, 0
    je .found_entry_sub
    cmp al, 0E5h
    je .found_entry_sub
    add di, 32
    loop .find_free_entry_sub
    jmp .failure

.found_entry_sub:
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

    cmp word [current_dir_cluster], 0
    jne .write_entry_sub

    call fs_write_root_dir
    jc .failure
    jmp .mkdir_done

.write_entry_sub:
    mov ax, [.parent_cluster]
    call fs_cluster_lba
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 3
    mov al, 1
    stc
    int 13h
    jc .failure

.mkdir_done:
    popa
    clc
    ret

.failure:
    popa
    stc
    ret

.dirname_converted  dw 0
.cluster            dw 0
.parent_cluster     dw 0
.dir_lba        dw 0
.dir_left       dw 0
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

    cmp word [current_dir_cluster], 0
    jne .check_in_subdir

    push ax
    call fs_read_root_dir
    pop ax

    mov di, disk_buffer
    call fs_get_root_entry
    jc .not_found
    jmp .check_attr

.check_in_subdir:
    mov [.isdir_file], ax

    mov ax, [current_dir_cluster]
    call fs_cluster_lba
    mov [.isdir_cluster], ax

.isdir_scan_cluster:
    mov ax, [.isdir_cluster]
    call fs_convert_l2hts

    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .not_found

    mov di, disk_buffer
    mov cx, 16

.isdir_search_loop:
    mov al, [di]
    cmp al, 0
    je .not_found
    cmp al, 0E5h
    je .isdir_next_entry

    mov al, [di+11]
    cmp al, 0Fh
    je .isdir_next_entry

    push di
    push cx
    mov si, [.isdir_file]
    mov cx, 11
    repe cmpsb
    pop cx
    pop di
    je .check_attr

.isdir_next_entry:
    add di, 32
    dec cx
    jnz .isdir_search_loop

    mov ax, [.isdir_cluster]
    call fs_next_dir_sector
    jc .not_found

    mov [.isdir_cluster], ax
    jmp .isdir_scan_cluster

.check_attr:
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

.isdir_file    dw 0
.isdir_cluster dw 0

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
    test ax, ax
    je .failure

    mov dx, ax
    mov di, .dest_string
    xor cx, cx
    mov si, ax
    mov si, [esp + 14]

    push si
    xor bx, bx
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

    test bx, bx
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
    xor cx, cx

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
    test cx, cx
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

    cmp word [current_dir_cluster], 0
    jne .rmdir_in_subdir

    ; --- Remove from root ---
    call fs_read_root_dir
    mov ax, [.dirname]
    call fs_get_root_entry
    jc .failure

    mov al, [di+11]
    test al, 0x10
    jz .failure

    mov ax, [di+26]
    mov [.cluster], ax
    test ax, ax
    je .failure
    mov [.dir_entry_pos], di
    mov byte [.rmdir_in_sub], 0

    jmp .rmdir_check_empty

.rmdir_in_subdir:
    ; --- Remove from subdirectory ---
    mov ax, [current_dir_cluster]
    mov [.parent_clust], ax
    call fs_cluster_lba
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .failure

    mov ax, [.dirname]
    mov di, disk_buffer
    call fs_get_subdir_entry
    jc .failure

    mov al, [di+11]
    test al, 0x10
    jz .failure

    mov ax, [di+26]
    mov [.cluster], ax
    test ax, ax
    je .failure
    mov [.dir_entry_pos], di
    mov byte [.rmdir_in_sub], 1

.rmdir_check_empty:
    mov ax, [.cluster]
    call fs_cluster_lba
    call fs_convert_l2hts

    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .failure

    mov si, disk_buffer + 64
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

    cmp byte [.rmdir_in_sub], 0
    jne .rmdir_reload_subdir

    ; Re-read root, mark entry deleted, write back
    call fs_read_root_dir
    mov di, [.dir_entry_pos]
    mov byte [di], 0E5h
    inc di
    mov cx, 31
    xor al, al
    rep stosb
    call fs_write_root_dir
    jc .failure
    jmp .rmdir_free_fat

.rmdir_reload_subdir:
    ; Re-read parent cluster, mark entry deleted, write back
    mov ax, [.parent_clust]
    call fs_cluster_lba
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .failure

    mov di, [.dir_entry_pos]
    mov byte [di], 0E5h
    inc di
    mov cx, 31
    xor al, al
    rep stosb

    mov ax, [.parent_clust]
    call fs_cluster_lba
    call fs_convert_l2hts
    mov bx, disk_buffer
    mov ah, 3
    mov al, 1
    stc
    int 13h
    jc .failure

.rmdir_free_fat:

    call fs_read_fat
    jc .failure

    mov ax, [.cluster]
    call fs_fat12_cluster_offset
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
.parent_clust    dw 0
.rmdir_in_sub    db 0
.original_name   times 32 db 0

; =========================================================================
; FS_CHANGE_DIRECTORY - Changes the current directory
; IN : AX = pointer to the directory name (single component, e.g. "BIN.DIR")
; OUT : CF = 0 if successful, CF = 1 if error
;       Updates current_dir_cluster and appends to current_directory path
; =======================================================================
fs_change_directory:
    pusha

    ; Save uppercased name before 8.3 conversion
    mov si, ax
    mov di, .cd_orig_name
    call string_string_copy
    mov ax, .cd_orig_name
    call string_string_uppercase

    push ax
    call string_string_length
    cmp ax, 12
    jg .length_failure
    pop ax

    ; Convert name to 8.3 format for searching
    call string_string_uppercase
    call int_filename_convert
    jc .failure
    mov [.cd_search_name], ax

    cmp word [current_dir_cluster], 0
    jne .cd_search_in_subdir

    ; Search in root directory
    push ax
    call fs_read_root_dir
    pop ax
    jc .failure

    mov di, disk_buffer
    call fs_get_root_entry
    jc .failure
    jmp .cd_check_is_dir

.cd_search_in_subdir:
    mov ax, [current_dir_cluster]
    call fs_cluster_lba
    mov [.cd_scan_cluster], ax

.cd_scan_loop:
    mov ax, [.cd_scan_cluster]
    call fs_convert_l2hts

    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .failure

    mov di, disk_buffer
    mov cx, 16

.cd_search_entry:
    mov al, [di]
    cmp al, 0
    je .failure
    cmp al, 0E5h
    je .cd_next_entry

    mov al, [di+11]
    cmp al, 0Fh
    je .cd_next_entry

    push di
    push cx
    mov si, [.cd_search_name]
    mov cx, 11
    repe cmpsb
    pop cx
    pop di
    je .cd_check_is_dir

.cd_next_entry:
    add di, 32
    dec cx
    jnz .cd_search_entry

    mov ax, [.cd_scan_cluster]
    call fs_next_dir_sector
    jc .failure

    mov [.cd_scan_cluster], ax
    jmp .cd_scan_loop

.cd_check_is_dir:
    ; DI points to directory entry
    mov al, [di+11]
    test al, 0x10
    jz .failure

    mov ax, [di+26]
    test ax, ax
    je .failure

    ; Update current_dir_cluster
    mov [current_dir_cluster], ax

    ; Append directory name to current_directory path
    mov di, current_directory
    cmp byte [di], 0
    je .cd_append_name

    ; Find end and add separator
.cd_find_end:
    cmp byte [di], 0
    je .cd_add_sep
    inc di
    jmp .cd_find_end
.cd_add_sep:
    mov byte [di], '/'
    inc di

.cd_append_name:
    ; Copy the saved original name
    mov si, .cd_orig_name
.cd_copy_name:
    lodsb
    stosb
    cmp al, 0
    jne .cd_copy_name

    popa
    clc
    ret

.length_failure:
    pop ax

.failure:
    popa
    stc
    ret

.cd_search_name  dw 0
.cd_scan_cluster dw 0
.cd_orig_name    times 16 db 0

; =========================================================================
; FS_PARENT_DIRECTORY - Go to the parent directory
; OUT : CF = 0 if successful, CF = 1 if already in the root
; =========================================================================
fs_parent_directory:
    pusha

    cmp word [current_dir_cluster], 0
    je .already_root

    mov ax, [current_dir_cluster]
    call fs_cluster_lba
    call fs_convert_l2hts

    mov bx, disk_buffer
    mov ah, 2
    mov al, 1
    stc
    int 13h
    jc .already_root

    mov di, disk_buffer + 32
    cmp byte [di], '.'
    jne .already_root
    cmp byte [di+1], '.'
    jne .already_root

    mov ax, [di+26]
    mov [current_dir_cluster], ax

    mov si, current_directory
    xor bx, bx
.pd_scan:
    cmp byte [si], 0
    je .pd_scan_done
    cmp byte [si], '/'
    jne .pd_not_sep
    mov bx, si
.pd_not_sep:
    inc si
    jmp .pd_scan

.pd_scan_done:
    test bx, bx
    je .pd_clear_all

    mov byte [bx], 0
    jmp .pd_done

.pd_clear_all:
    mov byte [current_directory], 0

.pd_done:
    popa
    clc
    ret

.already_root:
    popa
    stc
    ret

save_current_dir:
    pusha
    mov al, [current_disk]
    mov [saved_disk], al
    mov al, [current_drive_char]
    mov [saved_drive_char], al

    mov ax, [current_dir_cluster]
    mov [saved_dir_cluster], ax

    mov si, current_directory
    mov di, save_dir_buffer
.copy_path:
    lodsb
    stosb
    cmp al, 0
    jne .copy_path

    popa
    ret

restore_current_dir:
    pusha
    mov al, [saved_disk]
    mov [current_disk], al
    mov al, [saved_drive_char]
    mov [current_drive_char], al

    mov ax, [saved_dir_cluster]
    mov [current_dir_cluster], ax

    call fs_update_geometry

    mov si, save_dir_buffer
    mov di, current_directory
.copy_path:
    lodsb
    stosb
    cmp al, 0
    jne .copy_path

    popa
    ret

enter_bin_dir:
    pusha
    mov ax, bin_dir_name
    call fs_change_directory
    popa
    ret

cd_internal:
    pusha
    mov ax, si
    call fs_change_directory
    popa
    ret

fs_get_next_directory_cluster:
    push bx
    push cx
    push dx
    push si

    mov [.saved_cluster], ax

    call fs_read_fat

    mov ax, [.saved_cluster]
    call fs_fat_next_cluster
    jc .end_of_chain

    mov [.next_cluster], ax

    call fs_cluster_lba
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

; ==================================================================
; FS_INIT_DRIVES - Detects every available drive
; OUT: Fills drives_table / drive_count
; ==================================================================
fs_init_drives:
    pusha
    push es
    mov byte [drive_count], 0
    mov di, drives_table

    ; --- Floppy slots 0x00 and 0x01 ---
    mov dl, 0x00
    call .probe_present
    jc .floppy_b
    mov dl, 0x00
    mov dh, 1
    call .add_drive
.floppy_b:
    mov dl, 0x01
    call .probe_present
    jc .hdd_enum
    mov dl, 0x01
    mov dh, 1
    call .add_drive
.hdd_enum:
    push es
    xor ax, ax
    mov es, ax
    xor di, di
    mov ah, 0x08
    mov dl, 0x80
    int 13h
    pop es
    jc .hdd_count_bda
    movzx cx, dl
    jmp .hdd_count_ready
.hdd_count_bda:
    push ds
    xor ax, ax
    mov ds, ax
    mov al, [0x0475]
    pop ds
    movzx cx, al

.hdd_count_ready:
    movzx ax, byte [drive_count]
    mov bx, 3
    mul bx
    mov di, drives_table
    add di, ax

    test cx, cx
    jz .done_init
    cmp cx, MAX_HDD
    jbe .hdd_loop_init
    mov cx, MAX_HDD
.hdd_loop_init:
    mov dl, 0x80
.hdd_loop:
    call .probe_present
    jc .hdd_skip
    mov dh, 2
    call .add_drive
.hdd_skip:
    inc dl
    cmp dl, 0x80 + MAX_HDD
    jae .done_init
    dec cx
    jnz .hdd_loop

.done_init:
    call fs_reset_floppy
    pop es
    popa
    ret
.probe_present:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    xor ax, ax
    mov es, ax
    xor di, di
    mov ah, 0x08
    int 13h
    jc .pp_absent
    test ah, ah
    jnz .pp_absent
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.pp_absent:
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret
.add_drive:
    cmp byte [drive_count], MAX_DRIVES
    jae .ad_full
    mov al, dl
    cmp al, 0x80
    jae .ad_hdd
    add al, 'A'                   ; 0x00 -> A, 0x01 -> B
    jmp .ad_store
.ad_hdd:
    sub al, 0x80
    add al, 'C'                   ; 0x80 -> C, 0x81 -> D, ...
.ad_store:
    mov [di], al
    mov [di+1], dl
    mov [di+2], dh
    add di, 3
    inc byte [drive_count]
.ad_full:
    ret

; ========================================================================
; FS_LIST_DRIVES - Prints available drives with filesystem details
; ========================================================================
fs_list_drives:
    pusha

    mov al, [current_disk]
    mov [.saved_disk], al
    mov ax, [SecsPerTrack]
    mov [.saved_spt], ax
    mov ax, [Sides]
    mov [.saved_sides], ax

    call print_newline
    mov si, .header_msg
    call print_string_cyan
    call print_newline
    mov si, .separator
    call print_string
    call print_newline

    xor cx, cx
    mov cl, [drive_count]
    mov si, drives_table

.list_loop:
    test cx, cx
    je .done_list

    push cx
    push si

    ; --- Print drive letter ---
    mov al, [si]
    mov ah, 0Eh
    int 10h
    mov al, ':'
    mov ah, 0Eh
    int 10h

    push si
    mov si, .col_pad
    call print_string
    pop si

    ; --- Print drive type ---
    cmp byte [si+2], 1
    je .pr_floppy
    cmp byte [si+2], 2
    je .pr_hdd
    jmp .pr_type_done
.pr_floppy:
    push si
    mov si, .type_floppy
    call print_string
    pop si
    jmp .pr_type_pad_done
.pr_hdd:
    push si
    mov si, .type_hdd
    call print_string
    mov si, .type_pad
    call print_string
    pop si
.pr_type_pad_done:
.pr_type_done:
    push si
    mov si, .col_pad
    call print_string
    pop si

    mov dl, [si+1]
    mov [current_disk], dl
    mov byte [.retries], 3

.read_boot_retry:
    push es
    push ds
    pop es
    mov bx, disk_buffer
    mov ah, 02h
    mov al, 1
    mov ch, 0
    mov cl, 1
    mov dh, 0
    mov dl, [current_disk]
    stc
    int 13h
    pop es
    jnc .read_ok
    dec byte [.retries]
    jz .read_failed
    mov ah, 0
    mov dl, [current_disk]
    int 13h
    jmp .read_boot_retry

.read_ok:
    mov bx, disk_buffer

    ; Validate BPB: spc and total_sectors must be nonzero
    cmp byte [bx + 13], 0
    je .read_failed_mid

    mov ax, [bx + 19]
    cmp ax, 0
    jne .got_total
    mov ax, [bx + 32]
.got_total:
    test ax, ax
    je .read_failed_mid
    mov [.total_sectors], ax

    mov al, [bx + 13]
    mov [.spc], al

    mov ax, [bx + 22]
    mov [.spf], ax

    mov ax, [bx + 14]
    mov [.reserved], ax

    mov al, [bx + 16]
    mov [.num_fats], al

    mov ax, [bx + 17]
    mov [.root_entries], ax

    mov ax, [bx + 24]
    test ax, ax
    je .use_default_geom
    mov [SecsPerTrack], ax
    mov ax, [bx + 26]
    test ax, ax
    je .use_default_geom
    mov [Sides], ax
    jmp .geom_ready
.use_default_geom:
    mov word [SecsPerTrack], 18
    mov word [Sides], 2
.geom_ready:

    ; --- Calculate total KB = total_sectors / 2 ---
    mov ax, [.total_sectors]
    shr ax, 1
    mov [.total_kb], ax

    ; --- Count free clusters via FAT ---
    ; data_start = reserved + (num_fats * spf) + (root_entries * 32 / 512)
    xor ax, ax
    mov al, [.num_fats]
    mul word [.spf]
    add ax, [.reserved]
    push ax
    mov ax, [.root_entries]
    shr ax, 4
    pop bx
    add ax, bx
    mov [.data_start], ax

    ; total_data_clusters = (total_sectors - data_start) / spc
    mov ax, [.total_sectors]
    sub ax, [.data_start]
    xor dx, dx
    xor bx, bx
    mov bl, [.spc]
    div bx
    mov [.total_clusters], ax

    call fs_read_fat
    jc .read_failed_mid

    mov si, disk_buffer
    xor cx, cx
    mov word [.free_count], 0
    mov dx, [.total_clusters]

.fat_scan:
    cmp cx, dx
    jge .fat_scan_done

    mov ax, [si]
    mov bh, [si + 1]
    mov bl, [si + 2]
    rol ax, 4
    and ah, 0Fh
    and bh, 0Fh

    cmp cx, dx
    jge .fat_scan_done
    test ax, ax
    jnz .not_free_1
    inc word [.free_count]
.not_free_1:
    inc cx

    cmp cx, dx
    jge .fat_scan_done
    test bx, bx
    jnz .not_free_2
    inc word [.free_count]
.not_free_2:
    inc cx

    add si, 3
    jmp .fat_scan
.fat_scan_done:

    ; free_kb = free_count * spc / 2
    mov ax, [.free_count]
    xor bx, bx
    mov bl, [.spc]
    mul bx
    shr ax, 1
    mov [.free_kb], ax

    ; used_kb = total_kb - free_kb
    mov ax, [.total_kb]
    sub ax, [.free_kb]
    mov [.used_kb], ax

    ; --- Print Size column ---
    mov ax, [.total_kb]
    call print_decimal
    push si
    mov si, .kb_suffix
    call print_string
    mov si, .col_pad
    call print_string
    pop si

    ; --- Print Used column ---
    mov ax, [.used_kb]
    call print_decimal
    push si
    mov si, .kb_suffix
    call print_string
    pop si

    jmp .next_item

.read_failed:
    push si
    mov si, .na_str
    call print_string
    mov si, .col_pad
    call print_string
    mov si, .na_str
    call print_string
    pop si
    jmp .next_item

.read_failed_mid:
    push si
    mov si, .na_str
    call print_string
    mov si, .col_pad
    call print_string
    mov si, .na_str
    call print_string
    pop si

.next_item:
    pop si
    pop cx
    call print_newline
    add si, 3
    dec cx
    jmp .list_loop

.done_list:
    call print_newline

    mov al, [.saved_disk]
    mov [current_disk], al
    call fs_update_geometry

    popa
    ret

.header_msg     db 'Drive        Type             Size          Used', 0
.separator      db '-----        ----             ----          ----', 0
.col_pad        db '        ', 0
.type_pad       db '  ', 0
.type_floppy    db 'Floppy Disk', 0
.type_hdd       db 'Hard Disk', 0
.kb_suffix      db 'KB', 0
.na_str         db 'N/A', 0
.retries        db 0
.saved_disk     db 0
.saved_spt      dw 0
.saved_sides    dw 0
.total_sectors  dw 0
.spc            db 0
.spf            dw 0
.reserved       dw 0
.num_fats       db 0
.root_entries   dw 0
.data_start     dw 0
.total_clusters dw 0
.free_count     dw 0
.total_kb       dw 0
.free_kb        dw 0
.used_kb        dw 0

; ========================================================================
; FS_CHANGE_DRIVE_LETTER - Switch drive by letter (AL = Char)
; IN: AL = Drive letter
; OUT: CF = 1 if error, 0 if success
; ========================================================================
fs_change_drive_letter:
    pusha
    
    cmp al, 'a'
    jb .find_drive
    cmp al, 'z'
    ja .find_drive
    sub al, 32

.find_drive:
    mov si, drives_table
    xor cx, cx
    mov cl, [drive_count]

.scan_loop:
    test cx, cx
    je .not_found

    cmp al, [si]
    je .found
    add si, 3
    dec cx
    jmp .scan_loop

.found:
    mov bl, [si+1]
    mov [current_disk], bl
    mov bl, [si]
    mov [current_drive_char], bl

    mov byte [current_directory], 0
    mov word [current_dir_cluster], 0

    call fs_reset_floppy
    call fs_update_geometry

    popa
    clc
    ret

.not_found:
    popa
    stc
    ret

; ========================================================================
; FS_UPDATE_GEOMETRY - Reads Sector 0 to update Sides/SecsPerTrack
; ========================================================================
fs_update_geometry:
    pusha

    call fs_set_floppy_layout

    mov ah, 0
    mov dl, [current_disk]
    int 13h

    push es
    xor ax, ax
    mov es, ax
    xor di, di
    mov ah, 0x08
    mov dl, [current_disk]
    int 13h
    pop es
    jc .keep_default
    test ah, ah
    jnz .keep_default

    push cx
    and cl, 0x3F
    xor ch, ch
    test cx, cx
    jz .pop_default
    mov [SecsPerTrack], cx
    pop cx

    xor ax, ax
    mov al, dh
    inc ax
    mov [Sides], ax

    mov ah, 02h
    mov al, 1
    mov ch, 0
    mov cl, 1
    mov dh, 0
    mov dl, [current_disk]
    mov bx, disk_buffer
    int 13h
    jc .error

    call fs_layout_from_bpb
    jc .keep_default

    popa
    ret

.error:
    popa
    ret

.pop_default:
    pop cx
.keep_default:
    call fs_set_floppy_layout
    popa
    ret

; ========================================================================
; FS_SET_FLOPPY_LAYOUT - Restores the fixed 1.44 MB FAT12 layout
; IN : nothing
; OUT : the fs_* layout variables describe a 1.44 MB floppy
; ========================================================================
fs_set_floppy_layout:
    mov word [SecsPerTrack], 18
    mov word [Sides], 2
    mov word [fs_fat_lba], 1
    mov word [fs_fat_secs], 9
    mov word [fs_root_lba], 19
    mov word [fs_root_secs], 14
    mov word [fs_root_ents], 224
    mov word [fs_spc], 1
    mov word [fs_clus_base], 31
    mov word [fs_total_clus], 2847
    ret

; ========================================================================
; FS_LAYOUT_FROM_BPB - Works out the FAT12 layout of the mounted volume
; IN : disk_buffer holding the boot sector
; OUT : the fs_* layout variables describe the volume
;       CF = 1 if the BPB is unusable, layout left untouched
; ========================================================================
fs_layout_from_bpb:
    push ax
    push bx
    push cx
    push dx

    mov bx, disk_buffer

    cmp word [bx + 11], 512
    jne .bad

    xor ah, ah
    mov al, [bx + 13]
    test al, al
    jz .bad
    mov [.spc], ax

    mov ax, [bx + 14]
    test ax, ax
    jz .bad
    mov [.fat], ax

    mov ax, [bx + 22]
    test ax, ax
    jz .bad
    cmp ax, DISK_BUFFER_SIZE / 512
    ja .bad
    mov [.fatsecs], ax

    xor ch, ch
    mov cl, [bx + 16]
    test cl, cl
    jz .bad
    mul cx
    add ax, [.fat]
    mov [.root], ax

    mov ax, [bx + 17]
    test ax, ax
    jz .bad
    mov [.ents], ax
    add ax, 15
    mov cl, 4
    shr ax, cl
    cmp ax, DISK_BUFFER_SIZE / 512
    ja .bad
    mov [.rootsecs], ax

    add ax, [.root]
    mov [.data], ax

    mov ax, [.spc]
    add ax, ax
    mov bx, [.data]
    sub bx, ax
    mov [.base], bx

    mov bx, disk_buffer
    mov ax, [bx + 19]
    test ax, ax
    jnz .have_total
    mov ax, [bx + 32]
    mov dx, [bx + 34]
    test dx, dx
    jnz .bad
.have_total:
    sub ax, [.data]
    jbe .bad
    xor dx, dx
    div word [.spc]
    mov [.clus], ax

    mov ax, [.fat]
    mov [fs_fat_lba], ax
    mov ax, [.fatsecs]
    mov [fs_fat_secs], ax
    mov ax, [.root]
    mov [fs_root_lba], ax
    mov ax, [.rootsecs]
    mov [fs_root_secs], ax
    mov ax, [.ents]
    mov [fs_root_ents], ax
    mov ax, [.spc]
    mov [fs_spc], ax
    mov ax, [.base]
    mov [fs_clus_base], ax
    mov ax, [.clus]
    mov [fs_total_clus], ax

    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.bad:
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret
.spc      dw 0
.fat      dw 0
.fatsecs  dw 0
.root     dw 0
.rootsecs dw 0
.ents     dw 0
.data     dw 0
.base     dw 0
.clus     dw 0

MAX_HDD      equ 14
MAX_DRIVES   equ 16

drive_count db 0
drives_table times (MAX_DRIVES * 3) db 0