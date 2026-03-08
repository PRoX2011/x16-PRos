; ==================================================================
; Sierpinski Triangles (fractal) implemented in assembly 8086
;
; Made by Leo-ono
; ===============================================================

[BITS 16]
[ORG 0x100]

start:
		; start VGA graphic mode
		mov ax, 13h
		int 10h

		; set ES to access video memory
		mov ax, 0a000h
		mov es, ax

		mov cx, 4000h
	.next_pixel:

		; random = (3 * random) % 65536
		mov ax, [random]
		add ax, [random]
		add ax, [random]
		mov [random], ax

		; index = random % 3;
		mov dx, 0
		mov bx, 3
		div bx ; dx = index

		mov si, dx
		shl si, 2 ; si = index * 4

		; point_x = point_x + (triangle_points[si] - point_x) / 2
		mov ax, [triangle_points + si]
		sub ax, [point_x]
		sar ax, 1
		add [point_x], ax

		; point_y = point_y + (triangle_points[si + 2] - point_y) / 2
		mov ax, [triangle_points + si + 2]
		sub ax, [point_y]
		sar ax, 1
		add [point_y], ax

		; plot current pixel
		mov ax, [point_x]
		mov bx, [point_y]
		call set_pixel

		loop .next_pixel

        ; Wait for key press
        mov ah, 0
        int 16h

        mov ax, 12h
		int 10h

		; return to DOS
		mov ax, 4c00h
		int 21h

; set white pixel
; ax = x
; bx = y
set_pixel:
		mov dx, bx
		shl dx, 8
		shl bx, 6
		add bx, dx
		add bx, ax
		mov byte [es:bx], 15 ; 15 = white
		ret

triangle_points dw 10, 190, 160, 10, 310, 190
point_x dw 10
point_y dw 190
random dw 1