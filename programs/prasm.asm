; ==================================================================
; x16-PRos -- PRASM. Native two-pass assembler.
; Copyright (C) 2026 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

SRCBUF  equ 0x2000
SRCMAX  equ 0x3E00
SYMTAB  equ 0x6000
SYMENT  equ 18
SYMMAX  equ 220
OUTTOP  equ 0xF000

start:
    cld
    mov [paramp], si

    mov ah, 0x05
    int 0x21
    
    mov si, m_banner
    mov ah, 0x01
    int 0x21

    mov si, [paramp]
    test si, si
    jz usage
    call skipsp
    test al, al
    jz usage

    ; ---- src file name ----
    mov di, srcname
    xor cx, cx
.cs:
    mov al, [si]
    test al, al
    jz .cse
    cmp al, ' '
    je .cse
    cmp al, 9
    je .cse
    cmp cx, 12
    jae usage
    call upcase
    mov [di], al
    inc di
    inc si
    inc cx
    jmp .cs
.cse:
    mov byte [di], 0

    ; ---- optional output name ----
    call skipsp
    test al, al
    jz .derive
    mov di, outname
    xor cx, cx
.co:
    mov al, [si]
    test al, al
    jz .coe
    cmp al, ' '
    je .coe
    cmp al, 9
    je .coe
    cmp cx, 12
    jae usage
    call upcase
    mov [di], al
    inc di
    inc si
    inc cx
    jmp .co
.coe:
    mov byte [di], 0
    jmp .named

.derive:               ; SRC.EXT -> SRC.BIN
    mov si, srcname
    mov di, outname
    xor cx, cx
.dl:
    mov al, [si]
    test al, al
    jz .da
    cmp al, '.'
    je .da
    cmp cx, 8
    jae .da
    mov [di], al
    inc si
    inc di
    inc cx
    jmp .dl
.da:
    mov byte [di],   '.'
    mov byte [di+1], 'B'
    mov byte [di+2], 'I'
    mov byte [di+3], 'N'
    mov byte [di+4], 0

.named:
    mov si, srcname
    mov di, outname
    call streq
    jc err_same
    mov si, outname
    mov di, m_kern
    call streq
    jc err_kern

    ; ---- load source ----
    mov si, srcname
    mov ah, 0x08
    int 0x22
    jc err_nofile
    cmp bx, SRCMAX
    ja err_srcbig
    mov [srcsize], bx

    mov si, srcname
    mov cx, SRCBUF
    mov ah, 0x02
    int 0x22
    jc err_nofile
    mov bx, [srcsize]
    mov byte [SRCBUF+bx], 0

    ; ---- two passes ----
    mov word [symcnt], 0
    mov byte [passno], 1
    call run_pass
    jc report_err
    mov byte [passno], 2
    call run_pass
    jc report_err

    cmp word [outidx], 0
    je err_empty

    ; ---- write output ----
    mov si, outname
    mov bx, outbuf
    mov cx, [outidx]
    mov ah, 0x03
    int 0x22
    jc err_wfail

    mov si, m_ok
    mov ah, 0x02
    int 0x21
    mov si, outname
    mov ah, 0x01
    int 0x21
    mov si, m_par1
    mov ah, 0x01
    int 0x21
    mov ax, [outidx]
    call print_u16
    mov si, m_par2
    mov ah, 0x01
    int 0x21
    ret

usage:
    mov si, m_usage
    mov ah, 0x01
    int 0x21
    ret

err_nofile:
    mov si, m_nofile
    mov ah, 0x04
    int 0x21
    ret
err_srcbig:
    mov si, m_srcbig
    mov ah, 0x04
    int 0x21
    ret
err_wfail:
    mov si, m_wfail
    mov ah, 0x04
    int 0x21
    ret
err_same:
    mov si, m_same
    mov ah, 0x04
    int 0x21
    ret
err_kern:
    mov si, m_kernno
    mov ah, 0x04
    int 0x21
    ret
err_empty:
    mov si, m_empty
    mov ah, 0x04
    int 0x21
    ret

; ==================================================================
; "Error, line N: message"
; ==================================================================
report_err:
    mov si, m_el1
    mov ah, 0x04
    int 0x21
    mov ax, [lineno]
    call print_u16
    mov si, m_el2
    mov ah, 0x04
    int 0x21
    mov si, [errp]
    mov ah, 0x04
    int 0x21
    mov ah, 0x05
    int 0x21
    ret

; ==================================================================
; run_pass -- assemble the whole source once (pass in [passno])
; OUT: CF = 1 on error ([errp], [lineno] describe it)
; ==================================================================
run_pass:
    mov word [srcp], SRCBUF
    mov word [lineno], 1
    mov word [lc], 0x8000
    mov word [outidx], 0
    mov byte [ovf], 0
.line:
    call do_line
    jc .bad
    call advance_line
    jnc .line
    clc
    ret
.bad:
    stc
    ret

; ==================================================================
; advance_line -- move [srcp] past the rest of the current line
; OUT: CF = 1 when end of source reached
; ==================================================================
advance_line:
    push si
    mov si, [srcp]
.f:
    mov al, [si]
    test al, al
    jz .end
    cmp al, 10
    je .nl
    inc si
    jmp .f
.nl:
    inc si
    mov [srcp], si
    inc word [lineno]
    pop si
    clc
    ret
.end:
    mov [srcp], si
    pop si
    stc
    ret

; ==================================================================
; do_line -- parse and assemble one line
; OUT: CF = 1 on error
; ==================================================================
do_line:
    mov word [errp], e_syntax
    call next_token
    jc .err
    cmp byte [tok_type], 0
    je .ok
    cmp byte [tok_type], 1
    jne .err

    ; label?
    call peek_char
    cmp al, ':'
    jne .mnem
    inc word [srcp]
    cmp byte [passno], 1
    jne .aftlab
    mov ax, [lc]
    call sym_add
    jc .err
.aftlab:
    call next_token
    jc .err
    cmp byte [tok_type], 0
    je .ok
    cmp byte [tok_type], 1
    jne .err

.mnem:
    ; NAME EQU value?
    mov si, tokbuf
    mov di, namebuf
    mov cx, 16
    rep movsb
    mov ax, [srcp]
    mov [equ_sp], ax
    call next_token
    jc .err
    cmp byte [tok_type], 1
    jne .noequ
    cmp word [tokbuf], 'EQ'
    jne .noequ
    cmp word [tokbuf+2], 'U'
    jne .noequ
    call next_token
    jc .err
    call val_strict
    jc .err
    cmp byte [passno], 1
    jne .endchk
    push ax
    mov si, namebuf
    mov di, tokbuf
    mov cx, 16
    rep movsb
    pop ax
    call sym_add
    jc .err
    jmp .endchk
.noequ:
    mov ax, [equ_sp]
    mov [srcp], ax
    mov si, namebuf
    mov di, tokbuf
    mov cx, 16
    rep movsb

    call dispatch_mnem
    jc .err

.endchk:
    mov word [errp], e_syntax
    call next_token
    jc .err
    cmp byte [tok_type], 0
    jne .err

    cmp byte [ovf], 0
    je .ok
    mov word [errp], e_ovf
    jmp .err
.ok:
    clc
    ret
.err:
    stc
    ret

; ==================================================================
; dispatch_mnem -- look up tokbuf in mtable and run its handler
; OUT: CF = 1 on error ([errp] set)
; ==================================================================
dispatch_mnem:
    mov di, mtable
.scan:
    cmp byte [di], 0
    je .bad
    push di
    mov si, tokbuf
    mov cx, 8
    repe cmpsb
    pop di
    je .found
    add di, 12
    jmp .scan
.bad:
    mov word [errp], e_mnem
    stc
    ret
.found:
    mov [entp], di
    call [di+8]
    ret

; ==================================================================
; Instruction handlers. Table params: p1 = [entp]+10, p2 = [entp]+11.
; All return CF = 1 on error.
; ==================================================================

; ---- no-operand opcode (p1) ----
h_none:
    mov bx, [entp]
    mov al, [bx+10]
    call emit_b
    clc
    ret

; ---- ADD OR AND SUB XOR CMP: p1 = base opcode, p2 = /n ----
h_alu:
    call next_token
    jc .r
    call parse_reg_cur
    jc .syn
    mov [dstreg], al
    mov [dstsz], ah
    call expect_comma
    jc .r
    call next_token
    jc .r
    call parse_reg_cur
    jc .imm
    cmp ah, [dstsz]
    jne .siz
    mov [srcreg], al
    mov bx, [entp]
    mov al, [bx+10]
    cmp byte [dstsz], 0
    je .rr
    inc al
.rr:
    call emit_b
    mov al, [srcreg]
    mov cl, 3
    shl al, cl
    or al, 0xC0
    or al, [dstreg]
    call emit_b
    clc
    ret
.imm:
    call val_cur
    jc .r
    mov [memval], ax
    cmp byte [dstreg], 0
    jne .gen
    mov bx, [entp]
    mov al, [bx+10]
    cmp byte [dstsz], 0
    je .s8
    add al, 5
    call emit_b
    mov ax, [memval]
    call emit_w
    clc
    ret
.s8:
    add al, 4
    call emit_b
    mov ax, [memval]
    call emit_b
    clc
    ret
.gen:
    mov bx, [entp]
    mov ah, [bx+11]
    cmp byte [dstsz], 0
    je .g8
    mov al, 0x81
    call emit_b
    call .modn
    mov ax, [memval]
    call emit_w
    clc
    ret
.g8:
    mov al, 0x80
    call emit_b
    call .modn
    mov ax, [memval]
    call emit_b
    clc
    ret
.modn:
    mov al, ah
    mov cl, 3
    shl al, cl
    or al, 0xC0
    or al, [dstreg]
    call emit_b
    ret
.siz:
    mov word [errp], e_size
    stc
    ret
.syn:
    mov word [errp], e_syntax
    stc
    ret
.r:
    ret

; ---- TEST r,r / r,imm ----
h_test:
    call next_token
    jc .r
    call parse_reg_cur
    jc .syn
    mov [dstreg], al
    mov [dstsz], ah
    call expect_comma
    jc .r
    call next_token
    jc .r
    call parse_reg_cur
    jc .imm
    cmp ah, [dstsz]
    jne .siz
    mov [srcreg], al
    mov al, 0x84
    cmp byte [dstsz], 0
    je .t1
    inc al
.t1:
    call emit_b
    mov al, [srcreg]
    mov cl, 3
    shl al, cl
    or al, 0xC0
    or al, [dstreg]
    call emit_b
    clc
    ret
.imm:
    call val_cur
    jc .r
    mov [memval], ax
    cmp byte [dstreg], 0
    jne .gen
    cmp byte [dstsz], 0
    je .a8
    mov al, 0xA9
    call emit_b
    mov ax, [memval]
    call emit_w
    clc
    ret
.a8:
    mov al, 0xA8
    call emit_b
    mov ax, [memval]
    call emit_b
    clc
    ret
.gen:
    cmp byte [dstsz], 0
    je .g8
    mov al, 0xF7
    call emit_b
    mov al, [dstreg]
    or al, 0xC0
    call emit_b
    mov ax, [memval]
    call emit_w
    clc
    ret
.g8:
    mov al, 0xF6
    call emit_b
    mov al, [dstreg]
    or al, 0xC0
    call emit_b
    mov ax, [memval]
    call emit_b
    clc
    ret
.siz:
    mov word [errp], e_size
    stc
    ret
.syn:
    mov word [errp], e_syntax
    stc
    ret
.r:
    ret

; ---- MOV (r,r / r,imm / r,[mem] / [mem],r) ----
h_mov:
    call next_token
    jc .r
    cmp byte [tok_type], 4
    jne .todst
    cmp byte [tok_char], '['
    jne .syn
    call mem_operand
    jc .r
    call expect_comma
    jc .r
    call next_token
    jc .r
    call parse_reg_cur
    jc .syn
    mov [srcreg], al
    mov [srcsz], ah
    cmp byte [memdirect], 1
    jne .stgen
    cmp byte [srcreg], 0
    jne .stgen
    mov al, 0xA2
    cmp byte [srcsz], 0
    je .sta
    inc al
.sta:
    call emit_b
    mov ax, [memval]
    call emit_w
    clc
    ret
.stgen:
    mov al, 0x88
    cmp byte [srcsz], 0
    je .st1
    inc al
.st1:
    call emit_b
    mov al, [srcreg]
    call emit_mem_modrm
    clc
    ret

.todst:
    call parse_reg_cur
    jc .syn
    mov [dstreg], al
    mov [dstsz], ah
    call expect_comma
    jc .r
    call next_token
    jc .r
    cmp byte [tok_type], 4
    jne .src2
    cmp byte [tok_char], '['
    jne .syn
    call mem_operand
    jc .r
    cmp byte [memdirect], 1
    jne .ldgen
    cmp byte [dstreg], 0
    jne .ldgen
    mov al, 0xA0
    cmp byte [dstsz], 0
    je .lda
    inc al
.lda:
    call emit_b
    mov ax, [memval]
    call emit_w
    clc
    ret
.ldgen:
    mov al, 0x8A
    cmp byte [dstsz], 0
    je .ld1
    inc al
.ld1:
    call emit_b
    mov al, [dstreg]
    call emit_mem_modrm
    clc
    ret

.src2:
    call parse_reg_cur
    jc .immsrc
    cmp ah, [dstsz]
    jne .siz
    mov [srcreg], al
    mov al, 0x88
    cmp byte [dstsz], 0
    je .rr1
    inc al
.rr1:
    call emit_b
    mov al, [srcreg]
    mov cl, 3
    shl al, cl
    or al, 0xC0
    or al, [dstreg]
    call emit_b
    clc
    ret
.immsrc:
    call val_cur
    jc .r
    mov [memval], ax
    cmp byte [dstsz], 0
    je .mi8
    mov al, 0xB8
    add al, [dstreg]
    call emit_b
    mov ax, [memval]
    call emit_w
    clc
    ret
.mi8:
    mov al, 0xB0
    add al, [dstreg]
    call emit_b
    mov ax, [memval]
    call emit_b
    clc
    ret
.siz:
    mov word [errp], e_size
    stc
    ret
.syn:
    mov word [errp], e_syntax
    stc
    ret
.r:
    ret

; ---- INT imm8 ----
h_int:
    call next_token
    jc .r
    call val_cur
    jc .r
    push ax
    mov al, 0xCD
    call emit_b
    pop ax
    call emit_b
    clc
    ret
.r:
    ret

; ---- JMP/CALL rel16 (p1 = opcode) ----
h_rel16:
    call next_token
    jc .r
    call val_cur
    jc .r
    sub ax, [lc]
    sub ax, 3
    push ax
    mov bx, [entp]
    mov al, [bx+10]
    call emit_b
    pop ax
    call emit_w
    clc
    ret
.r:
    ret

; ---- Jcc/LOOP/JCXZ rel8 (p1 = opcode) ----
h_jcc:
    call next_token
    jc .r
    call val_cur
    jc .r
    sub ax, [lc]
    sub ax, 2
    cmp byte [passno], 2
    jne .go
    mov bx, ax
    add bx, 128
    cmp bx, 255
    ja .rng
.go:
    push ax
    mov bx, [entp]
    mov al, [bx+10]
    call emit_b
    pop ax
    call emit_b
    clc
    ret
.rng:
    mov word [errp], e_range
    stc
.r:
    ret

; ---- PUSH/POP r16 (p1 = base) ----
h_pushpop:
    call next_token
    jc .r
    call parse_reg_cur
    jc .syn
    cmp ah, 1
    jne .syn
    mov bx, [entp]
    add al, [bx+10]
    call emit_b
    clc
    ret
.syn:
    mov word [errp], e_syntax
    stc
.r:
    ret

; ---- INC/DEC (p1 = r16 base, p2 = /n for r8) ----
h_incdec:
    call next_token
    jc .r
    call parse_reg_cur
    jc .syn
    cmp ah, 1
    jne .r8
    mov bx, [entp]
    add al, [bx+10]
    call emit_b
    clc
    ret
.r8:
    push ax
    mov al, 0xFE
    call emit_b
    pop ax
    mov bx, [entp]
    mov ah, [bx+11]
    mov cl, 3
    shl ah, cl
    or al, ah
    or al, 0xC0
    call emit_b
    clc
    ret
.syn:
    mov word [errp], e_syntax
    stc
.r:
    ret

; ---- SHL/SHR/SAR r,imm / r,CL (p1 = /n) ----
h_shift:
    call next_token
    jc .r
    call parse_reg_cur
    jc .syn
    mov [dstreg], al
    mov [dstsz], ah
    call expect_comma
    jc .r
    call next_token
    jc .r
    call parse_reg_cur
    jc .immsh
    cmp ax, 0x0001
    jne .syn
    mov al, 0xD2
    cmp byte [dstsz], 0
    je .c1
    inc al
.c1:
    call emit_b
    call .mod
    clc
    ret
.immsh:
    call val_cur
    jc .r
    cmp byte [tok_type], 2
    jne .imn
    cmp ax, 1
    jne .imn
    mov al, 0xD0
    cmp byte [dstsz], 0
    je .o1
    inc al
.o1:
    call emit_b
    call .mod
    clc
    ret
.imn:
    mov [memval], ax
    mov al, 0xC0
    cmp byte [dstsz], 0
    je .i1
    inc al
.i1:
    call emit_b
    call .mod
    mov ax, [memval]
    call emit_b
    clc
    ret
.mod:
    mov bx, [entp]
    mov al, [bx+10]
    mov cl, 3
    shl al, cl
    or al, 0xC0
    or al, [dstreg]
    call emit_b
    ret
.syn:
    mov word [errp], e_syntax
    stc
    ret
.r:
    ret

; ---- DB ----
h_db:
.n:
    call next_token
    jc .r
    cmp byte [tok_type], 3
    je .str
    call val_cur
    jc .r
    call emit_b
    jmp .sep
.str:
    cmp word [tok_len], 0
    je .syn
    xor bx, bx
.sl:
    cmp bx, [tok_len]
    jae .sep
    mov al, [tokbuf+bx]
    push bx
    call emit_b
    pop bx
    inc bx
    jmp .sl
.sep:
    call next_token
    jc .r
    cmp byte [tok_type], 0
    je .done
    cmp byte [tok_type], 4
    jne .syn
    cmp byte [tok_char], ','
    jne .syn
    jmp .n
.done:
    clc
    ret
.syn:
    mov word [errp], e_syntax
    stc
.r:
    ret

; ---- DW ----
h_dw:
.n:
    call next_token
    jc .r
    call val_cur
    jc .r
    call emit_w
    call next_token
    jc .r
    cmp byte [tok_type], 0
    je .done
    cmp byte [tok_type], 4
    jne .syn
    cmp byte [tok_char], ','
    jne .syn
    jmp .n
.done:
    clc
    ret
.syn:
    mov word [errp], e_syntax
    stc
.r:
    ret

; ---- ORG n----
h_org:
    call next_token
    jc .r
    cmp byte [tok_type], 2
    jne .syn
    mov ax, [tok_val]
    mov [lc], ax
    clc
    ret
.syn:
    mov word [errp], e_syntax
    stc
.r:
    ret

; ---- TIMES n <instruction> ----
h_times:
    cmp byte [in_times], 0
    jne .syn
    call next_token
    jc .r
    call val_strict
    jc .r
    mov [tms_cnt], ax
    test ax, ax
    jz .skipline
    mov byte [in_times], 1
    mov ax, [srcp]
    mov [tms_sp], ax
.loop:
    mov word [errp], e_syntax
    call next_token
    jc .fail
    cmp byte [tok_type], 1
    jne .fail
    call dispatch_mnem
    jc .fail
    dec word [tms_cnt]
    jz .done
    mov ax, [tms_sp]
    mov [srcp], ax
    jmp .loop
.done:
    mov byte [in_times], 0
    clc
    ret
.fail:
    mov byte [in_times], 0
    stc
    ret
.skipline:
    push si
    mov si, [srcp]
.sw:
    mov al, [si]
    test al, al
    jz .swd
    cmp al, 10
    je .swd
    cmp al, 13
    je .swd
    inc si
    jmp .sw
.swd:
    mov [srcp], si
    pop si
    clc
    ret
.syn:
    mov word [errp], e_syntax
    stc
.r:
    ret

; ---- RESB n ----
h_resb:
    call next_token
    jc .r
    call val_strict
    jc .r
    mov cx, ax
    jcxz .z
.l:
    push cx
    xor al, al
    call emit_b
    pop cx
    loop .l
.z:
    clc
.r:
    ret

; ---- MUL/IMUL/DIV/IDIV reg (p1 = /n) ----
h_muldiv:
    call next_token
    jc .r
    call parse_reg_cur
    jc .syn
    push ax
    mov al, 0xF6
    cmp ah, 0
    je .op
    inc al
.op:
    call emit_b
    pop ax
    mov bx, [entp]
    mov ah, [bx+10]
    mov cl, 3
    shl ah, cl
    or al, ah
    or al, 0xC0
    call emit_b
    clc
    ret
.syn:
    mov word [errp], e_syntax
    stc
.r:
    ret

; ---- REP/REPE/REPNE <string op> (p1 = prefix byte) ----
h_rep:
    mov bx, [entp]
    mov al, [bx+10]
    call emit_b
    mov word [errp], e_syntax
    call next_token
    jc .r
    cmp byte [tok_type], 1
    jne .syn
    call dispatch_mnem
    ret
.syn:
    mov word [errp], e_syntax
    stc
.r:
    ret

; ==================================================================
; mem_operand -- parse the inside of [...] + the closing bracket
; OUT: [memdirect]=1 & [memval], or [memdirect]=0 & [memrm]
; ==================================================================
mem_operand:
    call next_token
    jc .r
    cmp byte [tok_type], 1
    jne .val
    call parse_reg_cur
    jc .val
    cmp ah, 1
    jne .bad
    cmp al, 6
    je .rsi
    cmp al, 7
    je .rdi
    cmp al, 3
    je .rbx
    jmp .bad
.rsi:
    mov byte [memrm], 4
    jmp .gotrm
.rdi:
    mov byte [memrm], 5
    jmp .gotrm
.rbx:
    mov byte [memrm], 7
.gotrm:
    mov byte [memdirect], 0
    jmp .close
.val:
    call val_cur
    jc .r
    mov [memval], ax
    mov byte [memdirect], 1
.close:
    call next_token
    jc .r
    cmp byte [tok_type], 4
    jne .bad
    cmp byte [tok_char], ']'
    jne .bad
    clc
    ret
.bad:
    mov word [errp], e_addr
    stc
.r:
    ret

emit_mem_modrm:
    mov cl, 3
    shl al, cl
    cmp byte [memdirect], 0
    je .rm
    or al, 0x06
    call emit_b
    mov ax, [memval]
    call emit_w
    ret
.rm:
    or al, [memrm]
    call emit_b
    ret

expect_comma:
    call next_token
    jc .r
    cmp byte [tok_type], 4
    jne .bad
    cmp byte [tok_char], ','
    jne .bad
    clc
    ret
.bad:
    mov word [errp], e_syntax
    stc
.r:
    ret

; ==================================================================
; next_token -- tokenizer
; OUT: [tok_type] 0=EOL 1=ident 2=number 3=string 4=punct
;      ident: tokbuf (uppercased, NUL-padded to 16), [tok_len]
;      number: [tok_val]; string: tokbuf raw, [tok_len]; punct: [tok_char]
;      CF = 1 on malformed token
; ==================================================================
next_token:
    push si
    push di
    push bx
    push cx
    push dx
.skip:
    mov si, [srcp]
    mov al, [si]
    cmp al, ' '
    je .adv
    cmp al, 9
    je .adv
    jmp .cls
.adv:
    inc word [srcp]
    jmp .skip
.cls:
    test al, al
    jz .eol
    cmp al, 10
    je .eol
    cmp al, 13
    je .eol
    cmp al, ';'
    je .eol
    cmp al, ','
    je .punct
    cmp al, ':'
    je .punct
    cmp al, '['
    je .punct
    cmp al, ']'
    je .punct
    cmp al, '"'
    je .string
    cmp al, 39
    je .string
    cmp al, '-'
    je .number
    cmp al, '0'
    jb .idq
    cmp al, '9'
    jbe .number
.idq:
    call is_idstart
    jc .ident
    mov word [errp], e_char
    stc
    jmp .out

.eol:
    mov byte [tok_type], 0
    clc
    jmp .out

.punct:
    mov [tok_char], al
    mov byte [tok_type], 4
    inc word [srcp]
    clc
    jmp .out

.string:
    mov ah, al
    inc si
    mov di, tokbuf
    xor bx, bx
.sl:
    mov al, [si]
    test al, al
    jz .badstr
    cmp al, 10
    je .badstr
    cmp al, 13
    je .badstr
    cmp al, ah
    je .sdone
    cmp bx, 60
    jae .badstr
    mov [di], al
    inc di
    inc si
    inc bx
    jmp .sl
.sdone:
    inc si
    mov [srcp], si
    mov [tok_len], bx
    mov byte [di], 0
    mov byte [tok_type], 3
    clc
    jmp .out
.badstr:
    mov word [errp], e_string
    stc
    jmp .out

.number:
    mov byte [negf], 0
    cmp al, '-'
    jne .nn
    mov byte [negf], 1
    inc si
    mov al, [si]
    cmp al, '0'
    jb .badnum
    cmp al, '9'
    ja .badnum
.nn:
    xor bx, bx
    cmp al, '0'
    jne .dec
    mov ah, [si+1]
    cmp ah, 'x'
    je .hex
    cmp ah, 'X'
    je .hex
.dec:
    mov al, [si]
    cmp al, '0'
    jb .ndone
    cmp al, '9'
    ja .ndone
    sub al, '0'
    xor ah, ah
    xchg ax, bx
    mov cx, 10
    mul cx
    add ax, bx
    mov bx, ax
    inc si
    jmp .dec
.hex:
    add si, 2
    xor bx, bx
    xor cx, cx
.hl:
    mov al, [si]
    call hexval
    jc .hdone
    mov dl, al
    mov cl, 4
    shl bx, cl
    xor cx, cx
    or bl, dl
    inc si
    inc cx
    jmp .hl
.hdone:
    push si
    sub si, 2
    cmp byte [si+1], 'x'
    je .hchk
    cmp byte [si+1], 'X'
    je .hchk
    pop si
    jmp .ndone
.hchk:
    pop si
    jmp .badnum
.ndone:
    mov al, [si]
    call is_idchar
    jc .badnum
    cmp byte [negf], 0
    je .npos
    neg bx
.npos:
    mov [tok_val], bx
    mov [srcp], si
    mov byte [tok_type], 2
    clc
    jmp .out
.badnum:
    mov word [errp], e_number
    stc
    jmp .out

.ident:
    mov di, tokbuf
    xor bx, bx
.il:
    mov al, [si]
    call is_idchar
    jnc .idone
    cmp bx, 15
    jae .badid
    call upcase
    mov [di], al
    inc di
    inc si
    inc bx
    jmp .il
.idone:
    mov [tok_len], bx
    mov [srcp], si
.zf:
    cmp bx, 16
    jae .zdone
    mov byte [tokbuf+bx], 0
    inc bx
    jmp .zf
.zdone:
    mov byte [tok_type], 1
    clc
    jmp .out
.badid:
    mov word [errp], e_longid
    stc

.out:
    pop dx
    pop cx
    pop bx
    pop di
    pop si
    ret

negf db 0

peek_char:
    push si
.p:
    mov si, [srcp]
    mov al, [si]
    cmp al, ' '
    je .a
    cmp al, 9
    je .a
    pop si
    ret
.a:
    inc word [srcp]
    jmp .p

is_idchar:
    cmp al, '0'
    jb is_idstart
    cmp al, '9'
    jbe idc_yes
is_idstart:
    cmp al, 'A'
    jb .n1
    cmp al, 'Z'
    jbe idc_yes
.n1:
    cmp al, 'a'
    jb .n2
    cmp al, 'z'
    jbe idc_yes
.n2:
    cmp al, '_'
    je idc_yes
    cmp al, '.'
    je idc_yes
    clc
    ret
idc_yes:
    stc
    ret

hexval:
    cmp al, '0'
    jb .no
    cmp al, '9'
    ja .af
    sub al, '0'
    clc
    ret
.af:
    cmp al, 'A'
    jb .no
    cmp al, 'F'
    jbe .hi
    cmp al, 'a'
    jb .no
    cmp al, 'f'
    ja .no
    sub al, 32
.hi:
    sub al, 'A'-10
    clc
    ret
.no:
    stc
    ret

upcase:
    cmp al, 'a'
    jb .r
    cmp al, 'z'
    ja .r
    sub al, 32
.r:
    ret

skipsp:
    mov al, [si]
    cmp al, ' '
    je .a
    cmp al, 9
    je .a
    ret
.a:
    inc si
    jmp skipsp

streq:
    push si
    push di
.l:
    mov al, [si]
    mov ah, [di]
    cmp al, ah
    jne .ne
    test al, al
    jz .eq
    inc si
    inc di
    jmp .l
.eq:
    pop di
    pop si
    stc
    ret
.ne:
    pop di
    pop si
    clc
    ret

; ==================================================================
; parse_reg_cur -- classify current ident token as a register
; OUT: AL = code 0..7, AH = 0 (8-bit) / 1 (16-bit); CF = 1 if not a reg
; ==================================================================
parse_reg_cur:
    push si
    push cx
    push bx
    cmp byte [tok_type], 1
    jne .no
    cmp word [tok_len], 2
    jne .no
    mov bx, [tokbuf]
    mov si, regs16
    xor cx, cx
.l1:
    cmp cx, 8
    jae .try8
    cmp bx, [si]
    je .f16
    add si, 2
    inc cx
    jmp .l1
.try8:
    mov si, regs8
    xor cx, cx
.l2:
    cmp cx, 8
    jae .no
    cmp bx, [si]
    je .f8
    add si, 2
    inc cx
    jmp .l2
.f16:
    mov al, cl
    mov ah, 1
    clc
    jmp .o
.f8:
    mov al, cl
    mov ah, 0
    clc
    jmp .o
.no:
    stc
.o:
    pop bx
    pop cx
    pop si
    ret

regs16 db 'AX','CX','DX','BX','SP','BP','SI','DI'
regs8  db 'AL','CL','DL','BL','AH','CH','DH','BH'

; ==================================================================
; val_cur -- value of the current token (number/label/char)
; OUT: AX; CF = 1 on error
; ==================================================================
val_cur:
    cmp byte [tok_type], 2
    jne .nid
    mov ax, [tok_val]
    clc
    ret
.nid:
    cmp byte [tok_type], 1
    jne .nstr
    call sym_find
    jnc .ret
    cmp byte [passno], 1
    jne .undef
    xor ax, ax
    clc
.ret:
    ret
.undef:
    mov word [errp], e_undef
    stc
    ret
.nstr:
    cmp byte [tok_type], 3
    jne .bad
    cmp word [tok_len], 1
    je .c1
    cmp word [tok_len], 2
    je .c2
    jmp .bad
.c1:
    mov al, [tokbuf]
    xor ah, ah
    clc
    ret
.c2:
    mov ax, [tokbuf]
    clc
    ret
.bad:
    mov word [errp], e_syntax
    stc
    ret

; ==================================================================
; val_strict -- like val_cur, but labels must already be defined
; OUT: AX; CF = 1 on error
; ==================================================================
val_strict:
    cmp byte [tok_type], 1
    jne val_cur
    call sym_find
    jnc .ok
    mov word [errp], e_undef
    stc
    ret
.ok:
    clc
    ret

sym_lookup:
    push si
    push cx
    push bx
    mov di, SYMTAB
    mov bx, [symcnt]
.e:
    test bx, bx
    jz .nf
    push di
    mov si, tokbuf
    mov cx, 16
    repe cmpsb
    pop di
    je .found
    add di, SYMENT
    dec bx
    jmp .e
.found:
    clc
    jmp .o
.nf:
    stc
.o:
    pop bx
    pop cx
    pop si
    ret

sym_add:
    push di
    push cx
    push si
    push dx
    call sym_lookup
    jnc .dup
    mov di, [symcnt]
    cmp di, SYMMAX
    jae .full
    push ax
    mov ax, SYMENT
    mul di
    mov di, ax
    add di, SYMTAB
    pop ax
    mov si, tokbuf
    mov cx, 16
    rep movsb
    mov [di], ax
    inc word [symcnt]
    clc
    jmp .o
.dup:
    mov word [errp], e_dup
    stc
    jmp .o
.full:
    mov word [errp], e_symful
    stc
.o:
    pop dx
    pop si
    pop cx
    pop di
    ret

sym_find:
    push di
    call sym_lookup
    jc .o
    mov ax, [di+16]
.o:
    pop di
    ret

emit_b:
    push bx
    cmp word [outidx], MAXOUT
    jae .full
    cmp byte [passno], 2
    jne .cnt
    mov bx, [outidx]
    mov [outbuf+bx], al
.cnt:
    inc word [outidx]
    inc word [lc]
    pop bx
    ret
.full:
    mov byte [ovf], 1
    inc word [outidx]
    inc word [lc]
    pop bx
    ret

emit_w:
    push ax
    call emit_b
    pop ax
    push ax
    mov al, ah
    call emit_b
    pop ax
    ret

; AX = unsigned decimal
print_u16:
    pusha
    mov di, numbuf+7
    mov byte [di], 0
    mov bx, 10
.d:
    xor dx, dx
    div bx
    add dl, '0'
    dec di
    mov [di], dl
    test ax, ax
    jnz .d
    mov si, di
    mov ah, 0x01
    int 0x21
    popa
    ret

%macro MENT 4
%%n: db %1
    times 8-($-%%n) db 0
    dw %2
    db %3, %4
%endmacro

mtable:
    MENT "MOV",   h_mov,     0,    0
    MENT "ADD",   h_alu,     0x00, 0
    MENT "OR",    h_alu,     0x08, 1
    MENT "AND",   h_alu,     0x20, 4
    MENT "SUB",   h_alu,     0x28, 5
    MENT "XOR",   h_alu,     0x30, 6
    MENT "CMP",   h_alu,     0x38, 7
    MENT "TEST",  h_test,    0,    0
    MENT "INT",   h_int,     0,    0
    MENT "JMP",   h_rel16,   0xE9, 0
    MENT "CALL",  h_rel16,   0xE8, 0
    MENT "PUSH",  h_pushpop, 0x50, 0
    MENT "POP",   h_pushpop, 0x58, 0
    MENT "INC",   h_incdec,  0x40, 0
    MENT "DEC",   h_incdec,  0x48, 1
    MENT "SHL",   h_shift,   4,    0
    MENT "SHR",   h_shift,   5,    0
    MENT "SAR",   h_shift,   7,    0
    MENT "DB",    h_db,      0,    0
    MENT "DW",    h_dw,      0,    0
    MENT "ORG",   h_org,     0,    0
    MENT "TIMES", h_times,   0,    0
    MENT "RESB",  h_resb,    0,    0
    MENT "MUL",   h_muldiv,  4,    0
    MENT "IMUL",  h_muldiv,  5,    0
    MENT "DIV",   h_muldiv,  6,    0
    MENT "IDIV",  h_muldiv,  7,    0
    MENT "REP",   h_rep,     0xF3, 0
    MENT "REPE",  h_rep,     0xF3, 0
    MENT "REPZ",  h_rep,     0xF3, 0
    MENT "REPNE", h_rep,     0xF2, 0
    MENT "REPNZ", h_rep,     0xF2, 0
    MENT "CMPSB", h_none,    0xA6, 0
    MENT "CMPSW", h_none,    0xA7, 0
    MENT "SCASB", h_none,    0xAE, 0
    MENT "SCASW", h_none,    0xAF, 0
    MENT "LOOP",  h_jcc,     0xE2, 0
    MENT "JCXZ",  h_jcc,     0xE3, 0
    MENT "JO",    h_jcc,     0x70, 0
    MENT "JNO",   h_jcc,     0x71, 0
    MENT "JB",    h_jcc,     0x72, 0
    MENT "JC",    h_jcc,     0x72, 0
    MENT "JAE",   h_jcc,     0x73, 0
    MENT "JNB",   h_jcc,     0x73, 0
    MENT "JNC",   h_jcc,     0x73, 0
    MENT "JE",    h_jcc,     0x74, 0
    MENT "JZ",    h_jcc,     0x74, 0
    MENT "JNE",   h_jcc,     0x75, 0
    MENT "JNZ",   h_jcc,     0x75, 0
    MENT "JBE",   h_jcc,     0x76, 0
    MENT "JA",    h_jcc,     0x77, 0
    MENT "JS",    h_jcc,     0x78, 0
    MENT "JNS",   h_jcc,     0x79, 0
    MENT "JP",    h_jcc,     0x7A, 0
    MENT "JNP",   h_jcc,     0x7B, 0
    MENT "JL",    h_jcc,     0x7C, 0
    MENT "JGE",   h_jcc,     0x7D, 0
    MENT "JLE",   h_jcc,     0x7E, 0
    MENT "JG",    h_jcc,     0x7F, 0
    MENT "NOP",   h_none,    0x90, 0
    MENT "RET",   h_none,    0xC3, 0
    MENT "RETF",  h_none,    0xCB, 0
    MENT "IRET",  h_none,    0xCF, 0
    MENT "HLT",   h_none,    0xF4, 0
    MENT "CLD",   h_none,    0xFC, 0
    MENT "STD",   h_none,    0xFD, 0
    MENT "CLI",   h_none,    0xFA, 0
    MENT "STI",   h_none,    0xFB, 0
    MENT "CLC",   h_none,    0xF8, 0
    MENT "STC",   h_none,    0xF9, 0
    MENT "PUSHA", h_none,    0x60, 0
    MENT "POPA",  h_none,    0x61, 0
    MENT "LODSB", h_none,    0xAC, 0
    MENT "LODSW", h_none,    0xAD, 0
    MENT "STOSB", h_none,    0xAA, 0
    MENT "STOSW", h_none,    0xAB, 0
    MENT "MOVSB", h_none,    0xA4, 0
    MENT "MOVSW", h_none,    0xA5, 0
    MENT "CBW",   h_none,    0x98, 0
    MENT "CWD",   h_none,    0x99, 0
    db 0

m_banner db 0xDA, 18 dup(0xC4), "PRASM (native assembler for x16-PRos) v0.1", 18 dup(0xC4), 0xBF
         db 0xC0, 78 dup(0xC4), 0xD9, 10, 13, 0
m_usage  db "Usage: PRASM SOURCE.ASM [OUT.BIN]", 10, 0
m_nofile db "Cannot read source file", 10, 0
m_srcbig db "Source too big (max 15872 bytes)", 10, 0
m_wfail  db "Cannot write output file", 10, 0
m_same   db "Output name equals source name", 10, 0
m_kernno db "KERNEL.BIN? No!", 10, 0
m_empty  db "Nothing to assemble", 10, 0
m_ok     db "OK: ", 0
m_par1   db " (", 0
m_par2   db " bytes)", 10, 0
m_el1    db "Error, line ", 0
m_el2    db ": ", 0
m_kern   db "KERNEL.BIN", 0

e_syntax db "Syntax error", 0
e_char   db "Bad character", 0
e_number db "Bad number", 0
e_string db "Bad string", 0
e_longid db "Name too long", 0
e_mnem   db "Unknown instruction", 0
e_dup    db "Duplicate label", 0
e_symful db "Too many labels", 0
e_undef  db "Undefined label", 0
e_size   db "Operand size mismatch", 0
e_addr   db "Bad memory operand", 0
e_range  db "Jump out of range", 0
e_ovf    db "Output too big", 0

paramp   dw 0
srcp     dw 0
lineno   dw 0
passno   db 0
lc       dw 0
outidx   dw 0
srcsize  dw 0
symcnt   dw 0
ovf      db 0
errp     dw 0
entp     dw 0

tok_type db 0
tok_char db 0
tok_len  dw 0
tok_val  dw 0
tokbuf   times 64 db 0

dstreg   db 0
dstsz    db 0
srcreg   db 0
srcsz    db 0
memrm    db 0
memdirect db 0
memval   dw 0

srcname  times 16 db 0
outname  times 16 db 0
numbuf   times 8 db 0
namebuf  times 16 db 0
equ_sp   dw 0
tms_cnt  dw 0
tms_sp   dw 0
in_times db 0

outbuf:
MAXOUT equ OUTTOP - outbuf
