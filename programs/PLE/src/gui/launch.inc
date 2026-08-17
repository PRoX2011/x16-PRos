open_window:
    pusha
    xor bx, bx
.fw:
    cmp bx, MAX_WIN
    jae .full
    cmp byte [w_open + bx], 0
    je .got
    inc bx
    jmp .fw
.full:
    popa
    ret
.got:
    mov [.slot], bl
    mov si, bx
    add si, si
    mov ax, [wtile_x + si]
    mov [w_x + si], ax
    mov ax, [wtile_y + si]
    mov [w_y + si], ax
    mov ax, [launch_idx]
    mov [w_icon + bx], al
    mov word [w_w + si], WW
    mov word [w_h + si], WH
    mov byte [w_max + bx], 0

    mov ah, 0x0E
    int 0x22
.ow_root:
    mov ah, 0x0A
    int 0x22
    jnc .ow_root
    mov ah, 0x09
    mov si, pledir_name
    int 0x22
    jc .ow_fail
    mov ah, 0x09
    mov si, guidir_name
    int 0x22
    jc .ow_fail

    mov ax, [launch_idx]
    shl ax, 4
    mov si, icon_names
    add si, ax
    mov ah, 0x11
    int 0x23
    jc .ow_fail
    xor bh, bh
    mov bl, [.slot]
    mov [w_task + bx], al
    mov byte [w_open + bx], 1

    mov ah, 0x0F
    int 0x22

    mov al, [.slot]
    call publish_window
    call full_repaint
    popa
    ret
.ow_fail:
    mov ah, 0x0F
    int 0x22
    popa
    ret
.slot db 0

close_window:
    pusha
    xor ah, ah
    mov bx, ax
    mov bl, [w_task + bx]
    mov ah, 0x32
    int 0x23
    xor bh, bh
    mov bl, [close_slot]
    cmp bl, MAX_WIN
    jae .skip
    mov byte [w_open + bx], 0
.skip:
    call full_repaint
    popa
    ret

reap_dead_windows:
    pusha
    mov byte [.changed], 0
    mov word [.i], 0
.rl:
    mov bx, [.i]
    cmp bx, MAX_WIN
    jae .fin
    cmp byte [w_open + bx], 0
    je .next
    mov bl, [w_task + bx]
    xor bh, bh
    mov ah, 0x17
    int 0x23
    jc .dead
    test al, al
    jnz .next
.dead:
    mov bx, [.i]
    mov byte [w_open + bx], 0
    mov byte [.changed], 1
.next:
    inc word [.i]
    jmp .rl
.fin:
    cmp byte [.changed], 0
    je .ret
    call full_repaint
.ret:
    popa
    ret
.changed db 0
.i       dw 0

toggle_maximize:
    pusha
    xor ah, ah
    mov bx, ax
    mov si, ax
    add si, si
    cmp byte [w_max + bx], 0
    jne .restore
    mov ax, [w_x + si]
    mov [w_rx + si], ax
    mov ax, [w_y + si]
    mov [w_ry + si], ax
    mov ax, [w_w + si]
    mov [w_rw + si], ax
    mov ax, [w_h + si]
    mov [w_rh + si], ax
    mov word [w_x + si], 0
    mov word [w_y + si], MENUBAR_H
    mov word [w_w + si], 640
    mov word [w_h + si], 480 - MENUBAR_H
    mov byte [w_max + bx], 1
    jmp .apply
.restore:
    mov ax, [w_rx + si]
    mov [w_x + si], ax
    mov ax, [w_ry + si]
    mov [w_y + si], ax
    mov ax, [w_rw + si]
    mov [w_w + si], ax
    mov ax, [w_rh + si]
    mov [w_h + si], ax
    mov byte [w_max + bx], 0
.apply:
    mov al, bl
    call publish_window
    call full_repaint
    popa
    ret

adopt_tasks:
    pusha
    mov ah, 0x15
    int 0x23
    mov [.self], al
    mov byte [.id], 1
.scan:
    cmp byte [.id], MAX_TASKS
    jae .done
    mov al, [.id]
    cmp al, [.self]
    je .next

    mov bl, [.id]
    mov ah, 0x17
    int 0x23
    jc .next
    test al, al
    jz .next
    test ah, 0x80
    jnz .next

    call adopt_one
.next:
    inc byte [.id]
    jmp .scan
.done:
    popa
    ret
.self db 0
.id   db 0

adopt_one:
    pusha
    xor bx, bx
.fw:
    cmp bx, MAX_WIN
    jae .full
    cmp byte [w_open + bx], 0
    je .got
    inc bx
    jmp .fw
.full:
    popa
    ret
.got:
    mov [.slot], bl
    mov si, bx
    add si, si
    mov ax, [wtile_x + si]
    mov [w_x + si], ax
    mov ax, [wtile_y + si]
    mov [w_y + si], ax
    mov word [w_w + si], WW
    mov word [w_h + si], WH
    mov byte [w_max + bx], 0

    xor bh, bh
    mov bl, [.slot]
    mov al, [adopt_tasks.id]
    mov [w_task + bx], al
    mov byte [w_open + bx], 1

    mov bl, [adopt_tasks.id]
    mov di, adopt_name
    mov ah, 0x19
    int 0x23
    jc .titled
    call adopt_match_icon
.titled:
    mov al, [.slot]
    call publish_window
    popa
    ret
.slot db 0

adopt_match_icon:
    pusha
    xor bh, bh
    mov bl, [adopt_one.slot]
    mov byte [w_icon + bx], 0

    mov word [.i], 0
.probe:
    mov ax, [.i]
    cmp ax, [icon_count]
    jae .done
    shl ax, 4
    mov si, icon_names
    add si, ax
    mov di, adopt_name
.cmp:
    mov al, [si]
    cmp al, [di]
    jne .nomatch
    test al, al
    jz .hit
    inc si
    inc di
    jmp .cmp
.nomatch:
    inc word [.i]
    jmp .probe
.hit:
    xor bh, bh
    mov bl, [adopt_one.slot]
    mov ax, [.i]
    mov [w_icon + bx], al
.done:
    popa
    ret
.i dw 0

adopt_name times 16 db 0
