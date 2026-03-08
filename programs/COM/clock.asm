; analogic clock 8086/87 (using 13h graphic mode)
; written by Leonardo Ono (ono.leo@gmail.com)
; 26/09/2017
; target os: DOS (.COM file extension)

		bits 16
		org 100h

start:
		call start_graphic_mode
		finit
		call draw_background
	.main_loop:
		call update_time
		call update_angles

		mov cx, 15
		call draw_pointers

		mov ah, 1
		int 16h ; if key pressed, exit
		jnz exit_process

		call sleep_half_s ; wait 0.5 seconds

		mov cx, 0
		call draw_pointers ; clear previous pointers

		jmp .main_loop

sleep_half_s:
		mov cx, 07h
		mov dx, 0a120h
		mov ah, 86h
		int 15h
		ret

; in:
;	di = angle
;	si = size
update_pointer:
		fld qword [di]
		fcos
		fld qword [si]
		fmul st1
		fistp word [data.x]
		ffree st0

		fld qword [di]
		fsin
		fld qword [si]
		fmul st1
		fistp word [data.y]
		ffree st0

		ret

update_angles:
		mov bx, data.v720
		mov si, data.hours
		mov di, data.angle_h
		call update_angle

		mov bx, data.v60
		mov si, data.minutes
		mov di, data.angle_m
		call update_angle

		mov bx, data.v60
		mov si, data.seconds
		mov di, data.angle_s
		call update_angle

		ret;

; in:
;	bx = v720 or v60
;	si = hours, minutes or seconds
;	di = angle_h, angle_m or angle_s
update_angle:
		fld qword [data.v90deg]
		fld qword [data.pi2]
		fld qword [bx]
		fild word [si]
		fdiv st1
		fmul st2
		fsub st3
		fstp qword [di]
		ffree st0
		ffree st1
		ffree st2
		ret

update_time:
		; http://vitaly_filatov.tripod.com/ng/asm/asm_029.3.html
		mov ah, 02h
		int 1ah
		; ch = hours (bcd)
		; cl = minutes (bcd)
		; dh = seconds (bcd)

		mov al, dh
		call convert_byte_bcd_to_bin
		mov ah, 0
		mov word [data.seconds], ax

		mov al, cl
		call convert_byte_bcd_to_bin
		mov ah, 0
		mov word [data.minutes], ax

		mov al, ch
		call convert_byte_bcd_to_bin
		mov ah, 0
		mov bx, 60
		xor dx, dx
		mul bx
		add ax, [data.minutes]
		mov word [data.hours], ax ; in number of minutes

		ret

; in:
;	cx = color index
draw_pointers:
		mov di, data.angle_h
		mov si, data.size50
		call update_pointer
		mov di, cx
		call draw_pointer

		mov di, data.angle_m
		mov si, data.size80
		call update_pointer
		mov di, cx
		call draw_pointer

		mov di, data.angle_s
		mov si, data.size80
		call update_pointer
		mov di, cx
		call draw_pointer

		ret

; in:
;	di = color index
draw_pointer:
		pusha
		mov ax, 160
		mov bx, 100
		mov cx, 160
		mov dx, 100
		add cx, word [data.x]
		add dx, word [data.y]
		call draw_line
		popa
		ret

; in:
;	cx = number of steps
;	bx = angle incrementation
;   di = angle variable
;   si = radius
draw_circle:
	.next:
		fld qword [bx]
		fld qword [di]
		fadd st1
		fstp qword [di]
		ffree st0

		mov di, data.angle_s
		;mov si, data.size90
		call update_pointer

		pusha
		mov al, 15
		mov cx, 160
		add cx, [data.x]
		mov bx, 100
		add bx, [data.y]
		call pset
		popa

		loop .next
		ret

draw_hours_indications:
		mov cx, 12
	.next:
		push cx

		fld qword [data.v30deg]
		fld qword [data.angle_h]
		fadd st1
		fstp qword [data.angle_h]
		ffree st0

		mov di, data.angle_h
		mov si, data.size85
		call update_pointer

	.draw_square:
		mov ax, 159
		mov dx, 99
	.next_dot:
		call .draw_square_dot
		inc ax
		cmp ax, 162
		jb .next_dot
	.dot_next_y:
		mov ax, 159
		inc dx
		cmp dx, 102
		jb .next_dot

		pop cx
		loop .next

		ret
	; ax = x
	; dx = y
	.draw_square_dot:
		pusha
		mov cx, ax
		add cx, [data.x]
		mov bx, dx
		add bx, [data.y]
		mov al, 15
		call pset
		popa
		ret

draw_background:
		; draw external circle
		mov cx, 720
		mov bx, data.vhalf_deg
		mov si, data.size90
		mov di, data.angle_s
		call draw_circle

		; draw minutes indications
		mov cx, 60
		mov bx, data.v6deg
		mov si, data.size85
		mov di, data.angle_m
		call draw_circle

		call draw_hours_indications
		ret

exit_process:
		mov ah, 4ch
		int 21h

; in:
;	example:
;	al = 11h (bcd)
; out:
;	al = 0bh
convert_byte_bcd_to_bin:
		push bx
		push cx
		push dx
		mov bh, 0
		mov bl, al
		and bl, 0fh
		mov ch, 0
		mov cl, al
		shr cx, 4
		xor dx, dx
		mov ax, 10
		mul cx
		add ax, bx
		pop dx
		pop cx
		pop bx
		ret

; bresenham's line algorithm
; written by Leonardo Ono (ono.leo@gmail.com)
; 26/09/2017
; target os: DOS (.COM file extension)

start_graphic_mode:
	mov ax, 0a000h
	mov es, ax
	mov ah, 0
	mov al, 13h
	int 10h
	ret

; ax = x1
; bx = y1
; cx = x2
; dx = y2
; di = color index
draw_line:
		mov word [.x1], ax
		mov word [.y1], bx
		mov word [.x2], cx
		mov word [.y2], dx
		sub cx, ax ; CX -> dx = x2 - x1
		sub dx, bx ; DX -> dy = y2 - y1
		mov word [.dx], cx
		mov word [.dy], dx
		cmp cx, 0
		jl .dx_less

	.dx_greater:
		cmp dx, 0
		jge .dx_greater_dy_greater
		jl .dx_greater_dy_less
	.dx_less:
		cmp dx, 0
		jge .dx_less_dy_greater
		jl .dx_less_dy_less

	.dx_greater_dy_greater:
		mov ax, [.dx]
		mov bx, [.dy]
		mov [draw_line_quadrant.dx], ax
		mov [draw_line_quadrant.dy], bx
		mov ax, [.x1]
		mov bx, [.y1]
		mov cx, [.x2]
		mov dx, [.y2]
		mov si, 0 ; quadrant 0
		jmp .continue
	.dx_greater_dy_less:
		mov ax, [.dy]
		neg ax
		mov bx, [.dx]
		mov [draw_line_quadrant.dx], ax
		mov [draw_line_quadrant.dy], bx
		mov ax, [.y1]
		neg ax
		mov bx, [.x1]
		mov cx, [.y2]
		neg cx
		mov dx, [.x2]
		mov si, 3 ; quadrant 3
		jmp .continue
	.dx_less_dy_greater:
		mov ax, [.dy]
		mov bx, [.dx]
		neg bx
		mov [draw_line_quadrant.dx], ax
		mov [draw_line_quadrant.dy], bx
		mov ax, [.y1]
		mov bx, [.x1]
		neg bx
		mov cx, [.y2]
		mov dx, [.x2]
		neg dx
		mov si, 1 ; quadrant 1
		jmp .continue
	.dx_less_dy_less:
		mov ax, [.dx]
		neg ax
		mov bx, [.dy]
		neg bx
		mov [draw_line_quadrant.dx], ax
		mov [draw_line_quadrant.dy], bx
		mov ax, [.x1]
		neg ax
		mov bx, [.y1]
		neg bx
		mov cx, [.x2]
		neg cx
		mov dx, [.y2]
		neg dx
		mov si, 2 ; quadrant 2

	.continue:
		call draw_line_quadrant
		ret
		.x1 dw 0
		.y1 dw 0
		.x2 dw 0
		.y2 dw 0
		.dx dw 0
		.dy dw 0

; ax = x1
; bx = y1
; cx = x2
; dx = y2
; di = color index
; si = quadrant
draw_line_quadrant:
		add si, si
		push cx
		push dx
		mov cx, word [.dx] ; CX = dx
		mov dx, word [.dy] ; DX = dy
		cmp cx, dx
		jge .not_swap
	.swap:
		pop dx
		pop cx
		xchg ax, bx
		xchg cx, dx
		inc si
		jmp .continue
	.not_swap:
		pop dx
		pop cx
	.continue:
		call draw_line_octant
		ret
	.dx dw 0
	.dy dw 0

; ax = x1
; bx = y1
; cx = x2
; dx = y2
; di = color index
; si = octant
draw_line_octant:
		mov word [.x2], cx
		sub cx, ax
		sub dx, bx
		add dx, dx
		mov word [.2dy], dx
		sub dx, cx ; dx = d = 2 * dy - dx
		add cx, cx
		mov word [.2dx], cx
		; bx = y = y1
		mov cx, ax ; cx = x
		mov ax, di
	.next_point:
		call pset_octant
		cmp dx, 0
		jle .d_less_or_equal
	.d_greater:
		add dx, word [.2dy]
		sub dx, word [.2dx]
		inc bx
		jmp .continue
	.d_less_or_equal:
		add dx, word [.2dy]
	.continue:
		inc cx
		cmp cx, word [.x2]
		jbe .next_point
		ret
		.x2 dw 0
		.2dx dw 0
		.2dy dw 0

; al = color index
; bx = row
; cx = col
; si = octant
pset_octant:
		push bx
		push cx
		cmp si, 0
		jz .octant_0
		cmp si, 1
		jz .octant_1
		cmp si, 2
		jz .octant_2
		cmp si, 3
		jz .octant_3
		cmp si, 4
		jz .octant_4
		cmp si, 5
		jz .octant_5
		cmp si, 6
		jz .octant_6
		cmp si, 7
		jz .octant_7
	.octant_0:
		; do nothing
		jmp .continue
	.octant_1:
		xchg bx, cx
		jmp .continue
	.octant_2:
		neg bx
		xchg bx, cx
		jmp .continue
	.octant_3:
		neg cx
		jmp .continue
	.octant_4:
		neg cx
		neg bx
		jmp .continue
	.octant_5:
		neg cx
		neg bx
		xchg bx, cx
		jmp .continue
	.octant_6:
		neg cx
		xchg bx, cx
		jmp .continue
	.octant_7:
		neg bx
	.continue:
		call pset
		pop cx
		pop bx
		ret

; al = color index
; bx = row
; cx = col
pset:
	pusha
	xor dx, dx
	push ax
	mov ax, 320
	mul bx
	add ax, cx
	mov bx, ax
	pop ax
	mov byte [es:bx], al
	popa
	ret



data:
		.angle_s	dq 0
		.angle_m	dq 0
		.angle_h	dq 0

		.hours		dw 0 ; in number of minutes
		.minutes	dw 0
		.seconds	dw 0

		.size90		dq 90.0
		.size85		dq 85.0
		.size80		dq 80.0
		.size50		dq 50.0

		.pi2		dq 6.28318

		.vhalf_deg	dq 0.00872665
		.v6deg		dq 0.10472
		.v90deg		dq 1.5708
		.v30deg		dq 0.523599

		.v60		dq 60.0
		.v720		dq 720.0

		.x 			dw 0
		.y 			dw 0

		.tmp		dw 0