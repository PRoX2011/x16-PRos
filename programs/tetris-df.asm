; ==================================================================
; x16-PRos -- TETRIS
; Original design by Alexey Pajitnov
;
; Made by DrunkFly( Nikolay Zapolnov)
; source https://github.com/drunkfly/8086tetris/blob/master/TETRIS.ASM
; Conversion for x16-PRos by  Alex Pricker  (Aleksey Shilo)
; https://github.com/chiefexb
; See more on https://github.com/GeeksLore
; ==================================================================

;  NASM
 [BITS 16]
 [ORG 0x8000]

FIELD_X equ 10
FIELD_Y equ 1
FIELD_WIDTH equ 10
FIELD_HEIGHT equ 20

FIGURE_WIDTH equ 4
FIGURE_HEIGHT equ 4

SCREEN_SKIP_CHAR equ 2
SCREEN_SKIP_ROW equ 160

BLACK equ 00h
WHITE equ 0fh

CHAR_SPACE equ 20h
CHAR_FULL_BLOCK equ 0dbh
CHAR_BOTTOM_LEFT_CORNER equ 0c0h
CHAR_BOTTOM_RIGHT_CORNER equ 0d9h
CHAR_HORIZ_LINE equ 0c4h
CHAR_VERTICAL_LINE equ 0b3h

KEY_ESC equ 011bh
KEY_LEFT equ 04b00h
KEY_RIGHT equ 04d00h
KEY_UP equ 04800h



start:          mov     ax, 0003h       ; AH=0 - set video mode, AL=3 80x25 text mode
                int     10h

@@spawnFigure:  mov     ax, (0*256)+(FIELD_WIDTH/2)
                mov     word  [cur_x], ax

                mov     al, byte  [next_figure]
                inc     al
                cmp     al, 7
                jb      @@okFigure
                xor     al, al
@@okFigure:     mov     byte  [next_figure], al

                mov     ah, 0
                shl     ax, 1
                mov     si, ax

                mov si, figure_list
                add si, ax          ; ax содержит смещение
                mov si, [si]        ; взять слово по адресу
                mov     di,  fig_width
                mov     ax, ds
                mov     es, ax
                mov     cx, FIGURE_WIDTH*FIGURE_HEIGHT+2
                rep     movsb

                mov     si,  cur_figure
                call    CheckCollides
                jc      @@exit

@@fallLoop:     call    DrawField
                call    DrawFigure

                mov     ah, 86h         ; wait
                mov     dx, 04240h      ; 0f4240h == 1 000 000 microseconds
                mov     cx, 0000fh
                int     15h

@@keyLoop:      mov     ah, 01h         ; check key press
                int     16h
                jz      @@noKey
                mov     ah, 00h         ; read key press
                int     16h
                cmp     ax, KEY_ESC
                je      @@exit
                cmp     ax, KEY_UP
                je      @@rotate
                cmp     ax, KEY_LEFT
                je      @@moveLeft
                cmp     ax, KEY_RIGHT
                je      @@moveRight
                jmp     @@keyLoop

@@noKey:        mov     al, byte  [cur_y]
                inc     al
                mov     byte  [cur_y], al
                mov     si,  cur_figure
                call    CheckCollides
                jnc     @@fallLoop
                dec     byte  [cur_y]
                call    FixateFigure

                call    RemoveLines

                jmp     @@spawnFigure

@@exit:         ret


@@rotate:       call    RotateFigure
                jmp     @@keyLoop

@@moveLeft:     mov     al, byte  [cur_x]
                or      al, al
                jz      @@keyLoop
                dec     al
                mov     byte  [cur_x], al
                mov     si,  cur_figure
                call    CheckCollides
                jnc     @@keyLoop
                inc     byte  [cur_x]
                jmp     @@keyLoop

@@moveRight:    mov     al, byte  [cur_x]
                inc     al
                mov     byte  [cur_x], al
                mov     si,  cur_figure
                call    CheckCollides
                jnc     @@keyLoop
                dec     byte  [cur_x]
                jmp     @@keyLoop

DrawField:      mov     bx, FIELD_HEIGHT
                mov     si,  field; DS:SI -> field
                mov     ax, 0b800h
                mov     es, ax          ; ES:DI -> video ram
                mov     di, FIELD_Y*SCREEN_SKIP_ROW+FIELD_X*SCREEN_SKIP_CHAR
@@row:          mov     ax, (WHITE*256)+CHAR_VERTICAL_LINE
                stosw                   ; AX -> ES:DI
                mov     cx, FIELD_WIDTH
@@col:          lodsb                   ; read byte from field into AL
                or      al, al
                jz      @@empty
@@full:         mov     ah, al
                mov     al, CHAR_FULL_BLOCK
                stosw                   ; AX -> ES:DI
                stosw
                loop    @@col
                jmp     @@end
@@empty:        mov     ax, (BLACK*256)+CHAR_SPACE
                stosw
                stosw
                loop    @@col
@@end:          mov     ax, (WHITE*256)+CHAR_VERTICAL_LINE
                stosw
                add     di, SCREEN_SKIP_ROW-((2+FIELD_WIDTH*2)*SCREEN_SKIP_CHAR)
                dec     bx
                jnz     @@row
                ; draw bottom border
                mov     ax, (WHITE*256)+CHAR_BOTTOM_LEFT_CORNER
                stosw
                mov     al, CHAR_HORIZ_LINE
                mov     cx, FIELD_WIDTH*2
                rep     stosw
                mov     al, CHAR_BOTTOM_RIGHT_CORNER
                stosw
                ret

DrawFigure:     mov     bx, word  [cur_x]    ; BL = cur_x, BH = cur_y
                ; cur_y * 160
                mov     al, bh
                add     al, FIELD_Y
                mov     ah, SCREEN_SKIP_ROW
                mul     ah
                ; += (cur_x * 2 + 1) * 2
                mov     bh, 0
                shl     bx, 1
                add     bx, FIELD_X+1
                shl     bx, 1                   ; SCREEN_SKIP_CHAR
                add     ax, bx                  ; AX = cur_y * 160 + (cur_x * 2 + 1) * 2
                ;
                mov     di, ax
                mov     ax, 0b800h
                mov     es, ax                  ; ES:DI -> video ram

                mov     si,  cur_figure
                mov     bx, FIGURE_HEIGHT
@@rowF:         mov     cx, FIGURE_WIDTH
@@colF:         lodsb
                or      al, al
                jz      @@skipF
                mov     ah, al
                mov     al, CHAR_FULL_BLOCK
                stosw
                stosw
                loop    @@colF
                jmp     @@endF
@@skipF:        add     di, SCREEN_SKIP_CHAR*2
                loop    @@colF
@@endF:         add     di, SCREEN_SKIP_ROW-(FIGURE_WIDTH*SCREEN_SKIP_CHAR*2)
                dec     bx
                jnz     @@rowF
                ret

CheckCollides:  mov     bx, word  [cur_x]    ; BL = cur_x, BH = cur_y
                ; cur_y * FIELD_WIDTH
                mov     al, bh
                mov     ah, FIELD_WIDTH
                mul     ah
                ; += cur_x
                mov     ch, 0
                mov     cl, bl
                add     ax, cx
                add     ax,  field
                mov     di, ax
                ;
                mov     dx, FIGURE_HEIGHT
@@rowC:         mov     cx, FIGURE_WIDTH
@@colC:         lodsb
                or      al, al
                jz      @@skipC
                cmp     bl, FIELD_WIDTH
                jae     @@collides
                cmp     bh, FIELD_HEIGHT
                jae     @@collides
                mov     al, byte  [di]
                or      al, al
                jnz     @@collides
@@skipC:        inc     bl
                inc     di
                loop    @@colC
                add     di, FIELD_WIDTH-FIGURE_WIDTH
                sub     bl, FIGURE_WIDTH
                inc     bh
                dec     dx
                jnz     @@rowC
                clc
                ret
@@collides:     stc
                ret

FixateFigure:   mov     bx, word  [cur_x]    ; BL = cur_x, BH = cur_y
                ; cur_y * FIELD_WIDTH
                mov     al, bh
                mov     ah, FIELD_WIDTH
                mul     ah
                ; += cur_x
                mov     bh, 0
                add     ax, bx
                add     ax,  field
                mov     di, ax
                ;
                mov     si,  cur_figure
                ;
                mov     dx, FIGURE_HEIGHT
@@rowX:         mov     cx, FIGURE_WIDTH
@@colX:         lodsb
                or      al, al
                jz      @@skipX
                mov     byte  [di], al
@@skipX:        inc     di
                loop    @@colX
                add     di, FIELD_WIDTH-FIGURE_WIDTH
                dec     dx
                jnz     @@rowX
                ret

RemoveLines:    std
                mov     si,  field+(FIELD_WIDTH*FIELD_HEIGHT)-1
@@removeLoop:   mov     dl, 1
                mov     cx, FIELD_WIDTH
                mov     di, si
@@scanLine:     lodsb
                or      al, al
                jnz     @@continue
                xor     dl, dl
@@continue:     loop    @@scanLine
                or      dl, dl
                jz      @@nextLine
                mov     ax, ds
                mov     es, ax
                push    di
                mov     cx, si
                sub     cx,  field
                inc     cx
                rep     movsb
                mov     cx, FIELD_WIDTH
                xor     al, al
                rep     stosb
                pop     si
@@nextLine:     cmp     si,  field-1
                jne     @@removeLoop
                cld
                ret

RotateFigure:   mov     bx, word  [fig_width]
                mov     ax, ds
                mov     es, ax
                mov     si,  cur_figure
                mov     di,  rotated_figure
                mov     cx, FIGURE_WIDTH*FIGURE_HEIGHT
                xor     al, al
                rep     stosb
                mov     di,  rotated_figure
                ; BP = FIGURE_WIDTH - fig_width
                mov     al, FIGURE_WIDTH
                sub     al, bl
                xor     ah, ah
                mov     bp, ax
                ; DX = (FIGURE_HEIGHT - fig_height) * FIGURE_WIDTH
                ;mov     al, FIGURE_HEIGHT
                ;sub     al, bh
                ;xor     ah, ah
                ;mov     dx, FIGURE_WIDTH
                ;mul     dx
                ;mov     dx, ax
                ;sub     dx, FIGURE_WIDTH*FIGURE_HEIGHT
                ;
@@rotateRow:    mov     cl, bl
                xor     ch, ch
                push    di
@@rotateCol:    lodsb
                stosb
                add     di, FIGURE_WIDTH-1
                loop    @@rotateCol
                add     si, bp
                pop     di
                inc     di
                dec     bh
                jnz     @@rotateRow

                mov     si,  rotated_figure
                call    CheckCollides
                jc      @@cantRotate

                mov     si,  rotated_figure
                mov     di,  cur_figure
                mov     cx, FIGURE_WIDTH*FIGURE_HEIGHT
                rep     movsb
                mov     ax, word  (fig_width)
                xchg    al, ah

                mov [fig_width], ax

@@cantRotate:   ret
field times (FIELD_WIDTH*FIELD_HEIGHT) db 0


fig_width       db      0
fig_height      db      0
cur_figure  times       FIGURE_WIDTH*FIGURE_HEIGHT db  0
rotated_figure times    FIGURE_WIDTH*FIGURE_HEIGHT db 0

cur_x           db      0
cur_y           db      0

figure_list     dw       square
                dw       line
                dw       s_figure
                dw       t_figure
                dw       z_figure
                dw       l_figure
                dw       reverse_l

next_figure     db      0

square          db      2,2
                db      3,3,0,0
                db      3,3,0,0
                db      0,0,0,0
                db      0,0,0,0

line            db      1,4
                db      5,0,0,0
                db      5,0,0,0
                db      5,0,0,0
                db      5,0,0,0

s_figure        db      2,3
                db      6,0,0,0
                db      6,6,0,0
                db      0,6,0,0
                db      0,0,0,0

z_figure        db      2,3
                db      0,7,0,0
                db      7,7,0,0
                db      7,0,0,0
                db      0,0,0,0

t_figure        db      3,2
                db      0,9,0,0
                db      9,9,9,0
                db      0,0,0,0
                db      0,0,0,0

l_figure        db      2,3
                db      4,0,0,0
                db      4,0,0,0
                db      4,4,0,0
                db      0,0,0,0

reverse_l       db      2,3
                db      0,2,0,0
                db      0,2,0,0
                db      2,2,0,0
                db      0,0,0,0
