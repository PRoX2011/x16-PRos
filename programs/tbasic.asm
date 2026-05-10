; ==================================================================
; x16-PRos -- TYNY BASIC 86
; Conversion for x16PRos
; by Aleksey Shilo chiefexb
;
; Original source TINY8086 https://github.com/Honneamise/TINY8086
; See more on https://github.com/GeeksLore
;==============================================================================
; Nasm directives
;==============================================================================
[CPU 8086]
[BITS 16]
[ORG 0x8000]


;==============================================================================
; Const section
;==============================================================================
STACK_SEG       EQU 1000h
STACK_OFF       EQU 0FFFFh

ROWS            EQU 25
COLS            EQU 80

FG_COLOR        EQU 0Fh
BG_COLOR        EQU 10h

DIRECT			EQU 0
RUN				EQU 1

MAX_STACK		EQU 128

;==============================================================================
; MAIN PROGRAM
;==============================================================================
START:
		call	ILM_CLEAR				;clear screen

		mov		dx,STR_WELCOME			;print welcome string
		call	PRINT_STR

		call	ILM_INIT				;init function (clear all)
		call	ILM_NLINE				;new line

CO:
		mov		sp,STACK_OFF			;clear SP (error could happened)

		mov		ax,PGM					;copy PGM address
		mov		[PGP],ax				;set PGP at beginning of program
		mov		[CURSOR],ax				;set CURSOR at beginning of line
		mov		[MODE],byte 00h			;set mode 0 (direct)

		mov		al,3Eh					;set prompt '>'
		call	ILM_GETLINE				;get line in LBUF
		call	ILM_NLINE				;new line

		cmp		[LBUF],byte 00h			;LBUF empty ?
		je		CO						;skip

		call	ILM_TSTL                ;test for line number
		cmp		al,-1					;number valid ?
		je		CO						;if not back to collection

		call	ILM_INSERT        		;insert line

		cmp		al,00h					;is direct ?
		jne		CO						;no, back to collection

XEC:
		call	ILM_XINIT             	;clear AESTACK

STMT:
		mov		dx,STR_REM				;"REM" (comment)
		call	ILM_TST
		cmp		al,00h
		je		S0

		call	ILM_NXT					;next line
		cmp		al,00h
		je		CO
		cmp		al,01h
		je		XEC

S0:
		mov		dx,STR_LET				;"LET"
		call	ILM_TST
		cmp		al,00h
		je		S1

		call	ILM_TSTV				;there is a variable ? ?
		cmp		al,-1
		je		CO
		cmp		al,00h
		je		ERROR

		mov		dx,STR_ASSIGN			;there is "=" assignement symbol ?
		call	ILM_TST
		cmp		al,00h
		je		ERROR

		call	EXPR					;evaluate expression

		call	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO

		call	ILM_STORE				;store value into variable
		cmp		al,00h
		je		CO

		call	ILM_NXT					;next line
		cmp		al,00h
		je		CO
		cmp		al,01h
		je		XEC

S1:
		mov		dx,STR_GOTO				;"GOTO"
		call	ILM_TST
		cmp		al,00h
		je		S2

		call	EXPR					;evaluate expression

		call 	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO

		call	ILM_XPER				;set PGP to new line, reset CURSOR
		cmp		al,0
		je		CO

		jmp		XEC

S2:
		mov		dx,STR_GOSUB			;"GOSUB"
		call	ILM_TST
		cmp		al,00h
		je		S3

		call 	EXPR					;evaluate expression

		call 	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO

		call	ILM_SAV					;save current line on SBRSTACK
		cmp		al,00h
		je		CO

		call	ILM_XPER				;set PGP to new line, reset CURSOR
		cmp		al,0
		je		CO

S3:
		mov		dx,STR_PRINT			;"PRINT"
		call	ILM_TST
		cmp		al,00h
		je		S8

S4:
		mov		dx,STR_QUOTES			;chack for quotes
		call	ILM_TST
		cmp		al,00h
		je		S7

		call	ILM_PRS         		;print the string
		cmp		al,00h
		je		CO

S5:
		mov		dx,STR_COMMA			;check comma for more
		call	ILM_TST
		cmp		al,00h
		je		S6

		call	ILM_SPC					;add single space

		jmp		S4

S6:
		call 	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO

        call	ILM_NLINE				;new line

        call	ILM_NXT					;next line
		cmp		al,00h
		je		CO
		cmp		al,01h
		je		XEC

S7:
		call    EXPR					;evaluate expression

		call	ILM_PRN					;print number
		cmp		al,00h
		je		CO

		jmp		S5

S8:
		mov		dx,STR_IF				;"IF"
		call	ILM_TST
		cmp		al,00h
		je		S9

		call	EXPR					;evaluate expression

		call	RELOP					;set logical operator on AESTACK

		call	EXPR					;evaluate expression

        mov		dx,STR_THEN				;check "THEN"
		call	ILM_TST
		cmp		al,00h
		je		ERROR

		call	ILM_CMPR				;perform compare
		cmp		al,-1
		je		CO
		cmp		al,00h
		jne		XEC						;match ok, execute "THEN" part

		call	ILM_NXT					;no match, next line
		cmp		al,00h
		je		CO
		cmp		al,01h
		je		XEC

S9:
		mov		dx,STR_INPUT			;"INPUT"
		call	ILM_TST
		cmp		al,00h
		je		S12

S10:
		call	ILM_TSTV				;check for Variable letter
		cmp		al,-1
		je		CO
		cmp		al,00h
		je		ERROR

		call	ILM_INNUM				;get number
		cmp		al,00h
		je		CO

        call	ILM_STORE				;store the number in the variable
		cmp		al,00h
		je		CO

        mov		dx,STR_COMMA			;check for more elements
		call	ILM_TST
		cmp		al,00h
		je		S11

        jmp		S10

S11:
		call 	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO

        call	ILM_NXT					;next line
		cmp		al,00h
		je		CO
		cmp		al,01h
		je		XEC

S12:
		mov		dx,STR_RETURN			;"RETURN"
		call	ILM_TST
		cmp		al,00h
		je		S13

		call 	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO

		call	ILM_RSTR				;restore previous line
		cmp		al,00h
		je		CO

		call	ILM_NXT					;next line
		cmp		al,00h
		je		CO
		cmp		al,01h
		je		XEC

S13:
		mov		dx,STR_END				;"END"
		call	ILM_TST
		cmp		al,00h
		je 		S14

		call	ILM_DONE				;no need to test DONE result
        jmp		CO						;always jump to collection routine

S14:
		mov		dx,STR_LIST				;"LIST"
		call	ILM_TST
		cmp		al,00h
		je		S15

		call 	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO

		cmp		byte [MODE],DIRECT		;im in DIRECT mode ?
		je		S14A

		mov		[ERROR_CODE],word ERROR_MODE
		call	ILM_ERR					;no, print error and go back to CO
		jmp		CO

S14A:
        call	ILM_LST					;print program
		jmp		CO

S15:
		mov		dx,STR_RUN				;"RUN"
		call	ILM_TST
		cmp		al,00h
		je		S16

        call 	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO

		cmp		byte [MODE],DIRECT		;im in DIRECT mode ?
		je		S15A

		mov		[ERROR_CODE],word ERROR_MODE
		call	ILM_ERR					;no, print error and go back to CO
		jmp		CO

S15A:
		mov		byte [MODE],RUN			;set RUN mode

        call	ILM_NXT					;next line
		cmp		al,00h
		je		CO
		cmp		al,01h
		je		XEC

S16:
    mov     dx,STR_RESET
    call    ILM_TST
    cmp     al,00h
    je      S17              ; ← КЛЮЧЕВОЕ: не ERROR, а S17

    ; --- это RESET ---
    call    ILM_DONE
    cmp     al,00h
    je      CO

    cmp     byte [MODE],DIRECT
    je      S16A

    mov     [ERROR_CODE],word ERROR_MODE
    call    ILM_ERR
    jmp     CO

S16A:
    jmp     START

S17:
    mov     dx,STR_EXIT
    call    ILM_TST
    cmp     al,00h
    je      ERROR            ; ни RESET, ни EXIT → ошибка

    ; --- это EXIT ---
    call    ILM_DONE
    cmp     al,00h
    je      CO

    ; выход в ОС
    ret



ERROR:
		mov		[ERROR_CODE],word ERROR_SYNTAX
		call	ILM_ERR
		jmp		CO						;back to collection routine

EXPR:
		mov		dx,STR_MINUS			;"-" (unary)
		call	ILM_TST
		cmp		al,00h
		je		E0

		call	TERM					;evaluate term

		call	ILM_NEG					;negate it
		cmp		al,00h
		je		CO

		jmp		E1

E0:
		mov		dx,STR_PLUS				;"+"  (unary)
		call	ILM_TST
		cmp		al,00h
		je		E1A

E1A:
		call	TERM   					;evaluate term

E1:
		mov		dx,STR_PLUS				;"+"
		call	ILM_TST
		cmp		al,00h
		je		E2

		call	TERM					;evaluate term

		call	ILM_ADD					;addition
		cmp		al,00h
		je		CO

		jmp		E1

E2:
		mov		dx,STR_MINUS			;test "-"
		call	ILM_TST
		cmp		al,00h
		je		E3

		call	TERM					;evaluate term

		call	ILM_SUB					;subtraction
		cmp		al,00h
		je 		CO

		jmp		E1

E3:
		ret

TERM:
		call	FACT					;evaluate factorial

T0:
		mov		dx,STR_MUL				;"*"
		call	ILM_TST
		cmp		al,00h
		je		T1

		call	FACT					;evaluate factorial

		call 	ILM_MUL					;multiply
		cmp		al,00h
		je		CO

		jmp		T0

T1:
		mov		dx,STR_DIV				;"/"
		call	ILM_TST
		cmp		al,00h
		je		T2

		call    FACT					;evaluate factorial

        call	ILM_DIV					;division
		cmp		al,00h
		je		CO

        jmp   	T0

T2:
		ret

FACT:
		call	ILM_TSTV				;is Variable ?
		cmp		al,-1
		je		CO
		cmp		al,00h
		je		F0

        call	ILM_IND                 ;swap top AESTACK with value of Variable index
        cmp		al,00h
		je		CO

		ret

F0:
		call	ILM_TSTN				;is Number ?
		cmp		al,-1
		je		CO
		cmp		al,00h
		je		F1

		ret

F1:
		mov		dx,STR_LPAREN			;"("
		call	ILM_TST
		cmp		al,00h
		je		F2

		call	EXPR					;evaluate expression

		mov		dx,STR_RPAREN			;")"
		call	ILM_TST
		cmp		al,00h
		je		F2

        ret

F2:
		mov		[ERROR_CODE],word ERROR_SYNTAX
		call	ILM_ERR
		jmp		CO						;back to collection routine

; RELOP/CODE :
; == 0
; != 1
; <= 2
; >= 3
;  < 4
;  > 5

RELOP:
		mov		dx,STR_OP_E				;test "=="
		call	ILM_TST
		cmp		al,00h
		je		R0

		mov		dx,0
		jmp		R5

R0:
		mov		dx,STR_OP_NE			;test "!="
		call	ILM_TST
		cmp		al,00h
		je		R1

		mov		dx,1
		jmp		R5

R1:
		mov		dx,STR_OP_LE			;test "<="
		call	ILM_TST
		cmp		al,00h
		je		R2

		mov		dx,2
		jmp		R5

R2:
		mov		dx,STR_OP_GE			;test ">="
		call	ILM_TST
		cmp		al,00h
		je		R3

		mov		dx,3
		jmp		R5

R3:
		mov		dx,STR_OP_L				;test "<"
		call	ILM_TST
		cmp		al,00h
		je		R4

		mov		dx,4
		jmp		R5

R4:
		mov		dx,STR_OP_G				;test ">"
		call	ILM_TST
		cmp		al,00h
		je		R6

		mov		dx,5

R5:
		call	ILM_LIT					;push DX on Aestack
		cmp		al,00h
		je		CO

		ret								;done success !

R6:
        mov		[ERROR_CODE],word ERROR_OPERATOR
		call	ILM_ERR
		jmp		CO

END:									;this point should never be reached
		cli                             ;disable interrupts
        hlt                             ;halt system

;==============================================================================
; Include section
;==============================================================================
;%INCLUDE "UTILS.ASM"					;required to use core functions
SECTION .data
buffer db "    ",0

;==============================================================================
; Expect in DX the beginning of the string
;==============================================================================

PRINT_STR:
        mov ah, 0x01     ;
        mov si, dx       ; copy the start of string in SI
        int 0x21         ; interrupt 21h

        ret

;==============================================================================
; Expect in DX the word to print (NOTE : we "consume" DX from the head)
;==============================================================================
PRINT_WORD:

        mov     ch,04h                  ;use CH as nibble counter
        mov     cl,04h                  ;use CL for 4 bit shift
        mov di, buffer

    .cycle:
        mov     al,dh                   ;copy in al the high byte of DX
        and     al,0F0h                 ;get the left nibble
        shr     al,cl                   ;shift it to right

        add     al,30h                  ;add 48 to get the printable char
        cmp     al,39h                  ;is number or letter ?
        jbe     .print                 	;if less is a number, go to print it
        add     al,07h                  ;is a letter, add 7 more

    .print:

        mov [di], al        ; сохраняем символ в буфер
        inc di              ; следующий символ


        dec     ch                      ;decrease the counter
        jz      .done                  	;if zero we have done
        shl     dx,cl                   ;advance next nibble
        jmp     .cycle                 	;repeat

    .done:
        mov al, 0
        mov [di], al
        mov ah, 0x01
        mov si, buffer
        int 0x21
        ret

;==============================================================================
; Print a number in decimal format, expect in DX the number to print
; NOTE : we use the stack to "decompose" the number
;==============================================================================
PRINT_NUMBER:
        mov di, buffer
        mov     ax,dx                   ;copy the number in AX
        cmp     ax,00h                  ;it is zero ?
        je      .zero                   ;jmp to special case

        or 		ax,ax                   ;check if negative
		jns 	.positive               ;no, continue

    .negative:

        mov     ah,0EH                  ;print the minus sign
        mov     al,2Dh
        mov     bh,00h
        mov [di], al        ; сохраняем символ в буфер
        inc di              ; следующий символ


        mov     ax,dx                   ;put in AX the absolute value
    	not 	ax
		inc 	ax

    .positive:

        mov     bx,10                   ;we use base 10
        xor     cx,cx                   ;will be counter for stack
        xor     dx,dx                   ;will hold remainder of division

    .pusher:                            ;loop to push numbers on stack

        cmp     ax,0                    ;if here finished
        je      .popper                 ;go to loop that print the numbers

        div     bx                      ;divide AX by 10

        push    dx                      ;push the remainder of division on stack

        inc     cx                      ;increase the stack counter

        xor     dx,dx                   ;clear DX for next division

        jmp     .pusher                 ;repeat popper cycle

    .popper:                            ;cycle to pop elements and print them

        cmp     cx,00h                  ;still have elements on stack ?
        je      .done                   ;no, exit

        pop     ax                      ;get the number from the stack

        mov     ah,0EH                  ;set ah for teletype print
        add     al,30h                  ;make the number an ascii value
        mov     bh,00h                  ;page 00h


        mov [di], al        ; сохраняем символ в буфер
        inc di              ; следующий символ

        dec     cx                      ;decrease the counter

        jmp     .popper                 ;repeat pop items

    .zero:                              ;special case for 0
        mov     ah,0EH
        mov     al,30h
        mov     bh,00h
        mov [di], al        ; сохраняем символ в буфер
        inc di              ; следующий символ


    .done:
        mov al, 0
        mov [di], al
        mov ah, 0x01
        mov si, buffer
        int 0x21
        ret


;==============================================================================
; Wait for a key press
;==============================================================================
WAIT_KEY:
        xor     ax,ax                   ;keyboard read function
        int     16h                     ;interrupt for keyboard I/O services
        ret
;===========




;==============================================================================
; Include: src/ILM/ILM_ADD.ASM
;==============================================================================
;==============================================================================
; ADD
; Replace top two elements of AESTK by their sum.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_ADD:
        xor     bx,bx                   ;clear bx

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,02h					;not enough elements
        jb     	.stack_err

        dec     bl						;get top stack
		shl		bl,1					;mult by 2
		add		bx,AESTACK_BASE			;add stack base address

		mov		ax,[bx]					;get second element in AX

		dec		bx						;decrease address by 2
		dec		bx

		add		[bx],ax					;store result of sum
		jo		.number_err

		dec		byte [AESTACK_POINTER]	;decrease stack pointer

		mov		al,1					;exit success

		ret

    .stack_err:
		mov		[ERROR_CODE],word ERROR_AESTACK_UNDERFLOW
		jmp		.err

	.number_err:
		mov		[ERROR_CODE],word ERROR_NUMBER_OVERFLOW

	.err:
		call	ILM_ERR						;return 0 on fail
		xor		al,al
		ret

;==============================================================================
; Include: src/ILM/ILM_CLEAR.ASM
;==============================================================================
;==============================================================================
; CLEAR
; clear the entire scren using ILM values
;==============================================================================


ILM_CLEAR:
        ; Установить текстовый режим 80x25
        mov     ax, 0x0003
        int     0x10

        ; Очистить экран (заполнить пробелами с атрибутами)
        push    es
        push    cx
        push    di

        mov     ax, 0xB800
        mov     es, ax
        xor     di, di
        mov     cx, 2000            ; 80*25 = 2000 символов
        mov     ax, 0x1F20          ; синий фон (1), белый текст (F), пробел (20)
        rep     stosw

        pop     di
        pop     cx
        pop     es

        ; Курсор в (0,0)
        mov     ah, 0x02
        mov     bh, 0x00
        mov     dx, 0x0000
        int     0x10

        ret

;==============================================================================
; Include: src/ILM/ILM_CMPR.ASM
;==============================================================================
;==============================================================================
; CMPR
; Compare AESTK(SP), the top of the stack, with AESTK(SP-2)
; as per the relations indicated by AESTK(SP-1).
; Delete all from stack.
; If the condition specified did not match, then perform NXT action.
;
; Return:
; AL = -1 error
; AL = 0 false
; AL = 1 true
;==============================================================================
ILM_CMPR:
		xor		ax,ax					;clear AX
        xor     si,si                   ;clear SI

        add     si,[AESTACK_POINTER]    ;get stack pointer

		cmp     si,03h					;not enough elements
        jb     	.stack_err

        dec     si						;get top stack
		shl		si,1					;mult by 2
		add		si,AESTACK_BASE			;add stack base address

		mov		dx,[si]					;get second operand

		dec		si						;decrease address by 2
		dec		si

		mov		cx,[si]					;get operator index

		dec		si						;decrease address by 2
		dec		si

		mov		bx,[si]					;get first operand

		sub		[AESTACK_POINTER],byte 03h   ;remove 3 elements

	.switch:
		cmp		cx,00h
		je		.e
		cmp		cx,01h
		je		.ne
		cmp		cx,02h
		je		.le
		cmp		cx,03h
		je		.ge
		cmp		cx,04h
		je		.l
		cmp		cx,05h
		je		.g

	.e:
		cmp		bx,dx
		je		.done_true
		ret

	.ne:
		cmp		bx,dx
		jne		.done_true
		ret

	.le:
		cmp		bx,dx
		jle		.done_true
		ret

	.ge:
		cmp		bx,dx
		jge		.done_true
		ret

	.l:
		cmp		bx,dx
		jl		.done_true
		ret

	.g:
		cmp		bx,dx
		jg		.done_true
		ret

	.done_true:
		mov		al,1					;exit true
		ret

    .stack_err:
		mov		[ERROR_CODE],word ERROR_AESTACK_UNDERFLOW
		call	ILM_ERR
		mov		al,-1					;return -1 on fail
		ret

;==============================================================================
; Include: src/ILM/ILM_DIV.ASM
;==============================================================================
;==============================================================================
; DIV
; Replace top two elements of AESTK by their quotient.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_DIV:
        xor     bx,bx                   ;clear BX

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,02h					;not enough elements
        jb     	.stack_err

        dec     bl						;get top stack
		shl		bl,1					;mult by 2
		add		bx,AESTACK_BASE			;add stack base address

		mov		cx,[bx]					;get second element in CX

		cmp		cx,0					;divide by 0 error
		je		.div_zero_err

		dec		bx						;decrease address by 2
		dec		bx

		mov		ax,[bx]					;get first element in AX
		cwd								;NOTE: extends sign bit of AX in DX

		idiv	cx						;divide by cx

		mov		[bx],ax					;store result

		dec		byte [AESTACK_POINTER]	;decrease stack pointer

		mov		al,01h					;exit success

		ret

    .stack_err:
		mov		[ERROR_CODE],word ERROR_AESTACK_UNDERFLOW
		jmp		.err

	.div_zero_err:
		mov		[ERROR_CODE],word ERROR_DIVIDE_ZERO

	.err:
		call	ILM_ERR
		xor		al,al
		ret


;==============================================================================
; Include: src/ILM/ILM_DONE.ASM
;==============================================================================
;==============================================================================
; DONE
; Report a syntax error if after deletion leading blanks the cursor is not
; positioned to road a carriage return.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_DONE:

		mov		si,[CURSOR]

	.skip_blanks:

		cmp		[si],byte 00h				;is EOL ?
		je		.done						;ok done

		cmp		[si],byte 20h				;is a blank ?
		ja		.err						;no, error

		inc		si							;increase cursor
		jmp		.skip_blanks				;check next char

	.err:
		mov		[ERROR_CODE],word ERROR_SYNTAX
		call	ILM_ERR
		xor		al,al
		ret

	.done:
		mov		al,01h
		ret

;==============================================================================
; Include: src/ILM/ILM_ERR.ASM
;==============================================================================
;==============================================================================
; ERR
; Report syntax error am return to line collect routine.
;
; Expect:
; [ERROR_CODE] == the error line to print
;
; NOTE : insert JMP CO after calling this function
;==============================================================================
ILM_ERR:

		call	ILM_NLINE				;new line

	.mode:
		cmp		[MODE],byte 00h			;direct mode ?
		je		.err_direct				;skip line number

	.err_at_line:
		mov		dx,ERROR_STR_AT_LINE	;
		call	PRINT_STR

	.line:
		mov		ax,[PGP]				;convert line address to line number
		sub		ax,PGM
		mov		bl,COLS
		div		bl

	.num:								;print line number
		mov		dx,ax
		call	PRINT_NUMBER

		jmp		.err_code

	.err_direct:
		mov		dx,ERROR_STR
		call	PRINT_STR

	.err_code:
		mov		dx,[ERROR_CODE]			;print code error
		call	PRINT_STR

		call	ILM_NLINE

		ret

;==============================================================================
; Include: src/ILM/ILM_GETLINE.ASM
;==============================================================================
;==============================================================================
; GETLINE
; Input a line to LBUF.
;
; Expect :
; AL = the ascii symbol for the prompt
;==============================================================================
ILM_GETLINE:

	.prompt:
		mov     ah,0Eh                  ;teletype print interupt
        mov     bh,00h                  ;page
        int     10h

	.init:
		mov     al,00h            		;the value to initialize the buffer
        mov		di,LBUF       			;clear LBUF
        mov     cx,COLS		          	;size of bufffer to copy
		rep		stosb                   ;repeat

		mov		si,00h					;reset SI (index)

	.cycle:
		xor     ax,ax                   ;keyboard read function
        int     16h						;ah scancode, al ascii code

		cmp		al,0Dh					;is enter pressed ?
		je		.done					;ok finished

		cmp		al,08h 					;is backspace ?
		je		.backspace

		cmp		si,COLS-2               ;do we have any space left ?
		jge		.cycle                  ;if not skip insertion

		cmp		al,20h					;is printable ?
		jb		.cycle
		cmp		al,7Eh
		ja		.cycle

		mov		bx,LBUF
		mov		[bx+si],al				;store character
		inc		si

		mov     ah,0Eh                  ;teletype print interupt
        mov     bh,00h                  ;page
        int     10h

		jmp		.cycle

	.backspace:

		cmp		si,0					;we are at beginning of LBUF
		jle		.cycle					;skip backspace

		dec		si						;dec DI and store a blank in LBUF
		mov		bx,LBUF
		mov		[bx+si],byte 00h

		mov		bh,00h      			;set page number for all operations

		mov		ah,03h					;get cursor position in DH,DL (row/col)
		int		10h

		dec		dl						;dec the col
		mov		ah,02h					;set cur pos
		int		10h

		mov     ah,0Ah                  ;write character at current cursor pos
		mov		al,20h					;we use empty space
        int     10h

		jmp		.cycle

	.done:
		ret

;==============================================================================
; Include: src/ILM/ILM_IND.ASM
;==============================================================================
;==============================================================================
; IND
; Replace top of AEstack by variable value it indexes.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_IND:
        xor     bx,bx                  	;clear bx

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,00h					;if zero stack empty
        jbe     .stack_err

        dec     bl						;go to first element

		shl		bl,1					;mult by 2

		add		bx,AESTACK_BASE			;add stack base

		mov 	si,[bx]					;copy the var index from [BX] to SI
		shl		si,1					;mult by2
		add 	si,VARIABLES			;add VARIABLES BASE

		mov		ax,[si] 				;copy the value in ax

		mov		[bx],ax					;store it at top of stack

		mov		al,01h

		ret

    .stack_err:
		mov		[ERROR_CODE],word ERROR_AESTACK_UNDERFLOW
		call	ILM_ERR
		xor		al,al
		ret

;==============================================================================
; Include: src/ILM/ILM_INIT.ASM
;==============================================================================
;==============================================================================
; INIT
; Perform global initilization.
; Clears program area, empties GOSUB stack, etc.
;==============================================================================
ILM_INIT:
		mov		[MODE],byte 00h			;mode 0 = direct

		mov     al,00h            		;the byte to initialize the buffer
        mov		di,PGM       			;clear PGM
        mov     cx,256*COLS		        ;size of bufffer
		rep		stosb                   ;repeat

		mov     ax,0000h            	;the word to initialize the buffer
        mov		di,VARIABLES   			;clear VARIABLES
        mov     cx,26		        	;size of bufffer
		rep		stosw                   ;repeat

		mov		[PGP],word PGM			;clear the PGP

		mov		[CURSOR],word PGM		;clear the CURSOR

		mov		[AESTACK_POINTER], byte 00h 	;clear AESTACK pointer
		mov		[SBRSTACK_POINTER], byte 00h 	;clear AESTACK pointer

		ret

;==============================================================================
; Include: src/ILM/ILM_INNUM.ASM
;==============================================================================
;==============================================================================
; INNUM
; Read a number from the terminal and push its value onto the AESTK.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;
; NOTE : we use LBUF to read the number
;==============================================================================
ILM_INNUM:

		mov		al,23h					;set prompt	'#'
		call	ILM_GETLINE				;read a line in LBUF

	.init:
		mov		si,LBUF					;set SI at LBUF
		xor		ax,ax					;AX will store the result
		mov		bx,10					;BX will be multiplier by 10
		xor		di,di					;set DL for positive sign
		xor		ch,ch					;clear high part of CX

	.skip_blanks:
		cmp		[si],byte 00h			;is EOL ?
		je		.empty_line				;possible error

		cmp		[si],byte 20h			;is a blank ?
		jg		.check_sign				;no, check if sign present

		inc		si						;increase position

		jmp		.skip_blanks			;check next char

	.check_sign:
		cmp		[si],byte 2Bh			;check '+'
		je		.skip_sign

		cmp		[si],byte 2Dh			;check '-'
		jne		.get_number

		mov		di,1					;set DL for sign change

	.skip_sign:
		inc		si

	.get_number:

		mov		cl,[si]					;get in cl the current char

		cmp		cl,00h					;ok done, go to fix sign if needed
		je		.fix_sign

		cmp 	cl,30h					;is less than 0 ?
		jl		.not_number

		cmp 	cl,39h					;is greater than 9 ?
		jg		.not_number

		sub 	cl,30h					;convert CL ascii to a number 0..9

		mul 	bx						;multiply the content of AL for 10
		jo		.big_number				;if overflow error

		add		ax,cx					;add the the CL value
		jo		.big_number				;if overflow error

		inc 	si						;next char
		jmp		.get_number 			;repeat

	.fix_sign:
		cmp		di,00h					;was negative ?
		je		.done					;nope
		neg		ax						;yes, negate it

	.done:
		mov		dx,ax
		call	ILM_LIT
		cmp		al,00h
		jne		.done_ok
		ret								;AL already set to 0 from ILM_LIT

	.done_ok:
		call	ILM_NLINE
		mov		al,01h					;exit success
		ret

	.empty_line:
		mov		[ERROR_CODE],word ERROR_EMPTY_LINE
		jmp		.err

	.not_number:
		mov		[ERROR_CODE],word ERROR_NOT_NUMBER
		jmp		.err

	.big_number:
		mov		[ERROR_CODE],word ERROR_NUMBER_OVERFLOW

	.err:
		call	ILM_ERR
		xor		al,al
		ret

;==============================================================================
; Include: src/ILM/ILM_INSERT.ASM
;==============================================================================
;==============================================================================
; INSRT
; Insert line after deleting any line with same line number.
;
; Expect:
; AL == line number
; SI == first element after line number
;
; Return :
; AL == line number inserted
;==============================================================================
ILM_INSERT:
		mov		dl,al					;bkup the line number

		mov		cx,COLS					;how many to copy
		sub		cx,si

		add		si,LBUF					;prepare source data index

		mov		bl,COLS					;prepare dest data index (PGM+LINE_NUM*COLS)
		mul		bl
		mov		di,ax
		add		di,PGM

        rep     movsb           		;copy

		mov		al,dl					;restore line number inserted

		ret

;==============================================================================
; Include: src/ILM/ILM_LIT.ASM
;==============================================================================
;==============================================================================
; LIT num
; Push the number num onto the AESTK (Originally omitted)
;
; Expect:
; DX == the number to push on the Aestack
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_LIT:
		xor		bx,bx					;clear bx

        mov		bl,[AESTACK_POINTER] 	;get current stack pointer
		cmp		bl,MAX_STACK			;greatest of max elements ?
		jae		.stack_err				;if yes error

		shl		bl,1					;multiply pointer by 2

		add		bx,AESTACK_BASE			;add the base of stack

		mov		[bx],dx					;store the number

		inc		byte [AESTACK_POINTER]	;store the new pointer value

		mov		al,01h

		ret

	.stack_err:
		mov		[ERROR_CODE],word ERROR_AESTACK_OVERFLOW
		call	ILM_ERR
		xor		al,al
		ret


;==============================================================================
; Include: src/ILM/ILM_LST.ASM
;==============================================================================
;==============================================================================
; LST
; List the contents of the program area.
;==============================================================================
LINE_COUNTER	db 00h					;line counter
PAGE_BREAK		db 00h					;page break
;------------------------------------------------------------------------------
ILM_LST:
		mov		[PAGE_BREAK],byte 00h	;keep track of how many lines printed
		mov		[LINE_COUNTER],byte 01h	;reset counter variable
		mov		di,PGM+COLS				;init DI at the line number 1

	.cycle:
		cmp		di,PGM+256*80			;is this the last line ?
		jge		.done					;if yes exit

		cmp		[di],byte 00h			;is an empty line ?
		je		.next					;skip it

		xor		dx,dx					;clear dx
		mov		dl,[LINE_COUNTER]		;get the line counter
		call	PRINT_NUMBER			;print the line number

		mov		dx,di					;copy the start of the line
		call	PRINT_STR				;call print line
		call	ILM_NLINE				;add a new line

		inc		byte [PAGE_BREAK]		;increase line printed
		cmp		byte [PAGE_BREAK],ROWS-1;less than screen row ? (-1 cause CRLF)
		jb		.next					;yep, continue

		call	WAIT_KEY				;wait for key press
		mov		byte [PAGE_BREAK],00h	;reset counter

	.next:

		add		di,COLS					;move to the next line
		inc		byte [LINE_COUNTER]		;increase line counter
		jmp		.cycle					;repeat

	.done:
		ret

;==============================================================================
; Include: src/ILM/ILM_MUL.ASM
;==============================================================================
;==============================================================================
; MUL
; Replace top two elements of AESTK by their product.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_MUL:
        xor     bx,bx                   ;clear bx

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,02h					;not enough elements
        jb     	.stack_err

        dec     bl						;get top stack
		shl		bl,1					;mult by 2
		add		bx,AESTACK_BASE			;add stack base address

		mov		ax,[bx]					;get second element in AX

		dec		bx						;decrease address by 2
		dec		bx

		imul	word [bx]				;multiply
		jo		.number_err

		mov		[bx],ax					;store result

		dec		byte [AESTACK_POINTER]	;decrease stack pointer

		mov		al,01h

		ret

    .stack_err:
		mov		[ERROR_CODE],word ERROR_AESTACK_UNDERFLOW
		jmp		.err

	.number_err:
		mov		[ERROR_CODE],word ERROR_NUMBER_OVERFLOW

	.err:
		call 	ILM_ERR
		xor		al,al
		ret

;==============================================================================
; Include: src/ILM/ILM_NEG.ASM
;==============================================================================
;==============================================================================
; NEG
; Replace top of AESTK with its negative.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_NEG:

        xor     bx,bx                   ;clear bx

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,00h					;if zero stack empty
        jbe     .stack_err

        dec     bl						;go to first element

		shl		bl,1					;mult by 2

		add		bx,AESTACK_BASE			;add stack base

		neg		word [bx]				;negate it

		mov		al,01h

		ret

    .stack_err:
		mov		[ERROR_CODE],word ERROR_AESTACK_UNDERFLOW
		call	ILM_ERR
		xor		al,al
		ret


;==============================================================================
; Include: src/ILM/ILM_NLINE.ASM
;==============================================================================
;==============================================================================
; NLINE
; Output CRLF to Printer.
;==============================================================================


ILM_NLINE:
  mov ah,0x05     ; PRos: print newline (CR+LF)
  int 0x21
  ret

;==============================================================================
; Include: src/ILM/ILM_NXT.ASM
;==============================================================================
;==============================================================================
; NXT
; If the present mode is direct (line number zero), return to line collection.
; Otherwise, select the next line and begin interpretation.
;
; Return:
; AL == 0 must jump to CO, 1 must jump to XEC
;==============================================================================
ILM_NXT:

        cmp		[MODE],byte 00h			;is direct ?
		je		.collection				;return to collect

		mov		bx,[PGP]				;get the PGP

	.cycle:
		add		bx,COLS

		cmp		bx,PGM+(256*80)			;is this the last line ?
		jge		.err					;err, we are outside of program

		cmp		[bx],byte 00h			;is empty line ?
		je		.cycle

	.done:
		mov		[PGP],bx				;next line
		mov		[CURSOR],bx				;set cursor to beginning of the line
		mov		al,01h					;set return to STMT
		ret

	.err:
		sub		bx,COLS					;get last valid line
		mov		[PGP],bx				;copy it in PGP

		mov		[ERROR_CODE],word ERROR_PGP
		call	ILM_ERR

	.collection:
		xor		al,al					;set for return to collection
		ret

;==============================================================================
; Include: src/ILM/ILM_PRN.ASM
;==============================================================================
;==============================================================================
; PRN
; Print number obtained by popping the top of the expression stack.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_PRN:
        xor     bx,bx                   ;clear bx

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,01h					;at least one element
        jl     	.stack_err

        dec     bl						;get top stack
		shl		bl,1					;mult by 2
		add		bx,AESTACK_BASE			;add stack base address

		mov		dx,[bx]					;top of stack

		call	PRINT_NUMBER

		dec		byte [AESTACK_POINTER]	;decrease stack pointer

		mov		al,1					;exit success

		ret

    .stack_err:
		mov		[ERROR_CODE],word ERROR_AESTACK_UNDERFLOW
		call	ILM_ERR
		xor		al,al
		ret

;==============================================================================
; Include: src/ILM/ILM_PRS.ASM
;==============================================================================
;==============================================================================
; PRS
; Print characters from the BASIC text up to but not including the
; closing quote mark.
; If a cr is found in the program text, report an error.
; Move the cursor to the point following the closing quote.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_PRS:
        mov		si,[CURSOR]

	.cycle:
		cmp		[si],byte 00h			;EOL ?
		je		.err					;error

		cmp		[si],byte 22h			;double quotes found ?
		je		.done					;done

		mov		al,[si]
		mov     ah,0Eh                  ;interrupt 10h code (teletype print)
        mov     bh,00h                  ;interrupt 10h page 0
		int		10h

		inc 	si						;advance to next char

		jmp		.cycle

	.err:
		mov		[ERROR_CODE],word ERROR_QUOTES
		call	ILM_ERR
		xor		al,al
		ret

	.done:
		inc		si						;move one pos after double quotes
		mov		[CURSOR],si				;save cursor
		mov		al,01h
        ret

;==============================================================================
; Include: src/ILM/ILM_RSTR.ASM
;==============================================================================
;==============================================================================
; RSTR
; Replace current line number with value on SBRSTK.
; If stack is empty, report error.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;
;NOTE : we push the address of line
;==============================================================================
ILM_RSTR:
        xor     bx,bx                  	;clear bx

        mov     bl,[SBRSTACK_POINTER]   ;get stack pointer

		cmp     bl,00h					;if zero stack empty
        jbe     .stack_err

        dec     bl						;go to first element

		add		bx,SBRSTACK_BASE		;add stack base

		xor		ax,ax					;clear DX

		mov 	al,[bx]					;copy line number in DL

		mov		cl,COLS					;set CL as line multiplier

		mul		cl						;multiply by cols

		add		ax,PGM					;add PGM base

		mov		[PGP],ax				;store it in PGP

		dec		byte [SBRSTACK_POINTER]	;store the new pointer value

		mov		al,01h

		ret

    .stack_err:
		mov		[ERROR_CODE],word ERROR_SBRSTACK_UNDERFLOW
		call	ILM_ERR
		xor		al,al
		ret

;==============================================================================
; Include: src/ILM/ILM_SAV.ASM
;==============================================================================
;==============================================================================
; SAV
; Push present line number on SBRSTK. Report overflow as error.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_SAV:

		xor		bx,bx					;clear bx

        mov		bl,[SBRSTACK_POINTER] 	;get current stack pointer
		cmp		bl,MAX_STACK			;greatest of max elements ?
		jae		.stack_err				;if yes error

		add		bx,SBRSTACK_BASE		;add the base of stack

		mov		ax,[PGP]				;get the current line address

		sub		ax,PGM					;subtract the base stack address

		mov		cl,COLS					;we use CL as divider

		div		cl						;divide AX by CL

		xor		ah,ah					;clear remainder

		mov		[bx],ax					;store the line address

		inc		byte [SBRSTACK_POINTER]	;store the new pointer value

		mov		al,01h

		ret

	.stack_err:
		mov		[ERROR_CODE],word ERROR_SBRSTACK_OVERFLOW
		call	ILM_ERR
		xor		al,al
		ret

;==============================================================================
; Include: src/ILM/ILM_SPC.ASM
;==============================================================================
;==============================================================================
; SPC
; Insert spaces, to move the print head to next zone.
;==============================================================================
ILM_SPC:
        mov		al,20h					;space
		mov     ah,0Eh                  ;interrupt 10h code (teletype print)
        mov     bh,00h                  ;interrupt 10h page 0
		int		10h

        ret

;==============================================================================
; Include: src/ILM/ILM_STORE.ASM
;==============================================================================
;==============================================================================
; STORE
; Place the value at the top of the AESTK
; into the variable designated by the index specified by the value immediately
; below it. Delete both from the stack.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_STORE:

        xor     bx,bx                   ;clear bx

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,02h					;not enough elements
        jb     	.stack_err

        dec     bl						;get top stack
		shl		bl,1					;mult by 2
		add		bx,AESTACK_BASE			;add stack base address

		mov		ax,[bx]					;get the value in AX

		dec		bx						;decrease address by 2
		dec		bx

		mov		di,[bx]					;get in DI the variable index

		shl		di,1					;mult by 2

		add		di,VARIABLES			;add base address for variables

		mov		[di],ax					;store the value

		dec		byte [AESTACK_POINTER]	;decrease stack pointer
		dec		byte [AESTACK_POINTER]

		mov		al,1					;exit success

		ret

    .stack_err:
		mov		[ERROR_CODE],word ERROR_AESTACK_UNDERFLOW
		call	ILM_ERR					;return 0 on fail
		xor		al,al
		ret

;==============================================================================
; Include: src/ILM/ILM_SUB.ASM
;==============================================================================
;==============================================================================
; SUB
; Replace top two elements of AESTK by their difference.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_SUB:
        xor     bx,bx                   ;clear bx

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,02h					;not enough elements
        jb     	.stack_err

        dec     bl						;get top stack
		shl		bl,1					;mult by 2
		add		bx,AESTACK_BASE			;add stack base address

		mov		ax,[bx]					;get second element in DX

		dec		bx						;decrease address by 2
		dec		bx

		sub		[bx],ax					;store result of sub

		dec		byte [AESTACK_POINTER]	;decrease stack pointer

		mov		al,01h
		ret

    .stack_err:
		mov		[ERROR_CODE],word ERROR_AESTACK_UNDERFLOW
		call	ILM_ERR
		xor		al,al
		ret

;==============================================================================
; Include: src/ILM/ILM_TST.ASM
;==============================================================================
;==============================================================================
; TST lbl,'string'
; Delete leading blanks
; If string matches the BASIC line, advance cursor over the
; matched string and execute the next IL instruction.
; If a match fails, execute the IL instruction at the labled lbl.
;
; Expect :
; DX == the string to compare
;
; Return :
; AL == 0 no match, 1 match success
;
; NOTE: if match, [CURSOR] point to first element after matched string
;==============================================================================
ILM_TST:
		mov		ax,[CURSOR]				;use AX as cursor bkup
		mov		si,ax					;we use SI as byte pointer of string

	.skip_blanks:
		cmp		[si],byte 00h			;is EOL ?
		je		.nomatch				;possible error

		cmp		[si],byte 20h			;is a blank ?
		ja		.compare				;no, check the string

		inc		si						;increase position

		jmp		.skip_blanks			;check next char

	.compare:
		xor		cx,cx					;clear CX (counter of strlen)
		mov		bx,dx					;copy in BX the start of the string

	.strlen:							;calculate the len of the string
		cmp		[bx],byte 00h
		je		.strcmp
		inc 	bx
		inc		cx
		jmp		.strlen

	.strcmp:
		mov     di,dx     				;DX is the start of the str to compare
        repe    cmpsb           		;equals ?
        jne     .nomatch        		;nope

	.match: 							;if here strings are equals
		mov		[CURSOR],si				;update the cursor position
		mov		al,01h
		ret

	.nomatch:
		mov		[CURSOR],ax				;restore cursor position
		xor		al,al
		ret

;==============================================================================
; Include: src/ILM/ILM_TSTL.ASM
;==============================================================================
;==============================================================================
; TSTL lbl
; After editing leading blanks, look for a line number.
; Report error if invalid.
; Transfer to lbl if not present.
;
; Return :
; AL == line number, -1 on error
; SI == index of first element after the line number
;==============================================================================
ILM_TSTL:
		xor		ax,ax					;clear AX
		mov		ch,10					;set CH as multiplier

		mov		bx,LBUF					;get the base address of buffer
		mov		si,00h					;we use SI as index

	.skip_blanks:						;skip leading blanks
		mov		cl,[bx+si]				;get in CL the current char
		cmp		cl,00h					;is EOL ?
		je		.done

		cmp 	cl,byte 20h				;is a BLANK ?
		jg		.get_number				;no go to check if number is present
		inc		si						;next char
		jmp		.skip_blanks			;repeat skip blanks loop

	.get_number:						;check if we have line number

		mov		cl,[bx+si]				;get in cl the current char

		cmp 	cl,30h					;is less than 0 ?
		jl		.done

		cmp 	cl,39h					;is greater than 9 ?
		jg		.done

		sub 	cl,30h					;convert CL ascii to a number 0..9

		mul 	ch						;multiply the content of AL for 10
		jc		.err					;if carry error

		add		al,cl					;add the the CL value
		jc		.err					;if carry error

		inc 	si						;next char
		jmp		.get_number 			;repeat

	.done:
		cmp		ax,00h					;do we have a line number ?
		jne		.blank					;if yes verify we are on blank
		ret

	.blank:
		cmp		[bx+si],byte 20h		;we should have a blank after line num
		jg		.err					;if not error
		ret

	.err:
		mov		[ERROR_CODE],word ERROR_LINE_NUMBER
		call	ILM_ERR
		mov		al,-1
		ret

;==============================================================================
; Include: src/ILM/ILM_TSTN.ASM
;==============================================================================
;==============================================================================
; TSTN lbl
; Test for number.
; If present, place its value onto the AESTK and continue execution
; at next suggested location. Otherwise continue at lbl.
;
; Return:
; AL == -1 on error ( should return to CO )
; AL == 0 if no match
; AL == 1 on success
;
; NOTE: if match, [CURSOR] point to first element after the number
;==============================================================================
ILM_TSTN:
		xor		ch,ch					;clear high part of CX
		xor		ax,ax					;clear AX
		mov		bx,10					;set BX as multiplyer
		mov		di,0					;set DI for positive sign

		mov		si,[CURSOR]				;init SI with current cursor position

    .skip_blanks:						;skip leading blanks
		cmp		[si],byte 00h			;is EOL ?
		je		.not_found

		cmp 	[si],byte 20h			;is a BLANK ?
		ja		.check_sign				;no go to check if is a sign

		inc		si						;next char
		jmp		.skip_blanks			;repeat skip blanks loop

	.check_sign:
		cmp		[si],byte 2Bh			;check '+'
		je		.skip_sign

		cmp		[si],byte 2Dh			;check '-'
		jne		.get_number

		mov		di,1					;set DI for sign change

	.skip_sign:
		inc		si

	.check_number:						;if not number exit
		cmp 	[si],byte 30h
		jl		.not_found
		cmp 	[si],byte 39h
		jg		.not_found

	.get_number:

		mov		cl,[si]					;get in CL the current char

		cmp 	cl,30h					;is less than 0 ?
		jl		.fix_sign

		cmp 	cl,39h					;is greater than 9 ?
		jg		.fix_sign

		sub 	cl,30h					;convert CL ascii to a number 0..9

		mul 	bx						;multiply the content of AX for 10
		jo		.number_err				;if overflow error

		add		ax,cx					;add the the CX value
		jo		.number_err				;if overflow error

		inc 	si						;next char

		jmp		.get_number 			;repeat

	.fix_sign:
		cmp		di,00h					;was negative ?
		je		.done					;nope
		neg		ax						;yes, negate it

	.done:
		mov		dx,ax
		call	ILM_LIT
		cmp		al,00h
		jne		.done_ok
		mov		al,-1					;err
		ret

	.done_ok:
		mov		[CURSOR],si				;update cursor
		mov		al,01h					;exit success
		ret

	.number_err:
		mov		[ERROR_CODE],word ERROR_NUMBER_OVERFLOW
		call	ILM_ERR
		mov		al,-1
		ret

	.not_found:
		xor		al,al
		ret

;==============================================================================
; Include: src/ILM/ILM_TSTV.ASM
;==============================================================================
;==============================================================================
; TSTV lbl
; Test for variable (i.e letter) if present.
; Place its index value onto the AESTK and continue execution at next suggested
; location.
; Otherwise continue at lbl.
;
; Return:
; AL == -1 on error ( should return to CO )
; AL == 0 if no match
; AL == 1 on success
;
; NOTE: if match, [CURSOR] point to first element after matched string
;==============================================================================
ILM_TSTV:
        mov     si,[CURSOR]

    .skip_blanks:
		cmp		[si],byte 00h			;is EOL ?
		je		.nomatch				;possible error

		cmp		[si],byte 20h			;is a blank ?
		ja		.check					;no, check for var

		inc		si						;increase position

		jmp		.skip_blanks			;check next char

	.check:
		cmp		[si],byte 41h			;less than 'A' ?
		jb		.nomatch

		cmp		[si],byte 5Ah			;greater than 'Z' ?
		ja		.nomatch

		xor		dh,dh
		mov		dl,byte [si]			;convert ascii char to index
		sub		dl,41h

	.done:
		call	ILM_LIT					;dx already contains tha val
		cmp		al,00h
		jne		.done_ok
		mov		al,-1					;err
		ret

	.done_ok:
		inc 	si						;advance SI to element after letter
		mov		[CURSOR],si				;update CURSOR

		mov		al,1					;exit success
		ret

	.nomatch:							;match fail
		xor		al,al
		ret

;==============================================================================
; Include: src/ILM/ILM_XPER.ASM
;==============================================================================
;==============================================================================
; XPER
; Test value at the top of the AE stack to be within range.
; If not,report an error.
; If in range, attempt to position cursor at that line.
; If it exists, begin interpretation there.
; If not report an error.
;
; Return:
; AL = 0 on error should jump back to CO
; AL = 1 on success should jump to XEC
;==============================================================================
ILM_XPER:

		mov		dl,COLS					;set DL as line multiplier

        xor     bx,bx                   ;clear BX

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,00h					;if zero stack empty
        jbe     .stack_err

        dec     bl						;go to first element

		shl		bl,1					;mult by 2

		add		bx,AESTACK_BASE			;add stack base

		mov		ax,[bx]					;in AX line number index

		cmp		ax,00h					;less than 1?
		jle		.pgp_err

		cmp		ax,0FFh					;greater than 255 ?
		jg		.pgp_err

		xor		ah,ah					;clear high part of ax
		mul		dl

		add		ax,PGM					;add PGM base

		mov		si,ax					;check for empty line
		cmp		[si],byte 00h
        je      .empty_err

		mov		[PGP],si				;set line
		mov		[CURSOR],si				;reset cursor

		mov		al,01h

		ret

	.stack_err:
		mov		[ERROR_CODE],word ERROR_AESTACK_UNDERFLOW
		jmp		.err

	.pgp_err:
		mov		[ERROR_CODE],word ERROR_PGP
		jmp		.err

	.empty_err:
		mov		[ERROR_CODE],word ERROR_EMPTY_LINE

	.err:
		call	ILM_ERR
		xor		al,al
		ret

;==============================================================================
; Include: src/ILM/ILM_XINIT.ASM
;==============================================================================
;==============================================================================
; XINIT
; Perform initialization for each stated execution.
; Empties AEXP stack.
;==============================================================================
ILM_XINIT:
		mov		[AESTACK_POINTER],byte 00h
		ret


;==============================================================================
; Vars section
;==============================================================================
;welcome string
STR_WELCOME		db "TINY BASIC 8086",0Ah,0Dh,"Vers.2023 by Honny",10,13
              db "Conversion for x16PRos by Aleksey Shilo in 2026",00h

;list of language keywords
STR_EXIT    db "EXIT",00h
STR_REM			db "REM",00h
STR_LET			db "LET",00h
STR_GOTO		db "GOTO",00h
STR_GOSUB		db "GOSUB",00h
STR_END			db "END",00h
STR_PRINT		db "PRINT",00h
STR_LIST		db "LIST",00h
STR_RUN			db "RUN",00h
STR_RESET		db "RESET",00h
STR_RETURN		db "RETURN",00h
STR_INPUT		db "INPUT",00h
STR_IF			db "IF",00h
STR_THEN		db "THEN",00h

STR_COMMA		db ',',00h
STR_QUOTES		db '"',00h
STR_ASSIGN		db '=',00h
STR_MINUS		db '-',00h
STR_PLUS		db '+',00h
STR_MUL			db '*',00h
STR_DIV			db '/',00h
STR_LPAREN		db '(',00h
STR_RPAREN		db ')',00h

;list of logic operators
STR_OP_E		db "==",00h
STR_OP_NE		db "!=",00h
STR_OP_LE		db "<=",00h
STR_OP_GE		db ">=",00h
STR_OP_L		db "<",00h
STR_OP_G		db ">",00h

;error flag and list of available errors
ERROR_CODE					dw 0000h

ERROR_STR					db "ERROR",00h
ERROR_STR_AT_LINE			db "ERROR at line ",00h
ERROR_SYNTAX				db ":Syntax error",00h
ERROR_LINE_NUMBER			db ":Invalid line number",00h
ERROR_EMPTY_LINE			db ":Empty line",00h
ERROR_PGP 					db ":PGP out of range",00h
ERROR_QUOTES				db ":Missing quotes",00h
ERROR_INVALID_NUMBER		db ":Number invalid",00h
ERROR_NOT_NUMBER			db ":Not a number",00h
ERROR_NUMBER_OVERFLOW		db ":Number out of range",00h
ERROR_AESTACK_OVERFLOW		db ":Arithmetic stack overflow",00h
ERROR_AESTACK_UNDERFLOW		db ":Arithmetic stack underflow",00h
ERROR_SBRSTACK_OVERFLOW		db ":Subroutines stack overflow",00h
ERROR_SBRSTACK_UNDERFLOW	db ":Subroutines stack underflow",00h
ERROR_DIVIDE_ZERO			db ":Divide by zero",00h
ERROR_OPERATOR				db ":Invalid operator",00h
ERROR_MODE					db ":Unavailable for current mode",00h

;ILM variables
MODE			db 00h						;0==direct, 1==run

VARIABLES		times 26 dw 0000h			;Variables A,B,C...Z

AESTACK_BASE	times MAX_STACK dw 0000h	;Arithmetic Expression stack
AESTACK_POINTER db 00h

SBRSTACK_BASE	times MAX_STACK db 00h		;Subroutines stack
SBRSTACK_POINTER db 00h

LBUF 			times COLS db 00h			;the reading buffer
CURSOR			dw	0000h					;Cursor (byte pointer)
PGP				dw	0000h					;PGP (line pointer)
PGM				dw	0000h
;PGM				times 256 * COLS db 00h		;the PGM area (256 lines * 80 byte)
