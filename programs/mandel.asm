; =================================================================            
; x16-PRos Mandelbrot Set Visualizer
; Author: Gemini
; 
; Mode: VGA 13h (320x200, 256 colors)
; =================================================================

[BITS 16]
[ORG 0x100]

start:
    ; Set 0x13 (320x280; 256 colors videomode)
    mov ax, 0x13
    int 0x10

    ; --- Setting up clolor palete ---
    mov dx, 0x03C8      
    xor al, al          
    out dx, al
    mov dx, 0x03C9
    out dx, al          ; R=0
    out dx, al          ; G=0
    out dx, al          ; B=0

    mov cx, 1           
palette_loop:
    mov dx, 0x03C8
    mov al, cl
    out dx, al
    mov dx, 0x03C9

    ; --- Blue component ---
    mov ax, cx
    shr ax, 2       
    add al, 15
    cmp al, 63
    jbe b_ok
    mov al, 63
b_ok:
    push ax       

    ; --- Red and blue ---
    mov al, cl
    cmp al, 20
    jb no_white
    sub al, 20          
    
    shr al, 1           

    cmp cl, 110
    jb white_ok
    add al, 10       
    
white_ok:
    cmp al, 63
    jbe rgb_out
    mov al, 63
rgb_out:
    out dx, al          ; Red
    out dx, al          ; Green
    pop ax
    out dx, al          ; Blue
    jmp next_color

no_white:
    xor al, al
    out dx, al          ; Red = 0
    out dx, al          ; Green = 0
    pop ax
    out dx, al          ; Blue
    
next_color:
    inc cl
    jnz palette_loop

    ; --- Main cycle ---
    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov word [py], 0

y_loop:
    mov word [px], 0

x_loop:
    ; Cx = (px - 220) * scale (4.12 fixed point)
    mov ax, [px]
    sub ax, 220
    shl ax, 5
    mov [cx_val], ax

    ; Cy = (py - 100) * scale
    mov ax, [py]
    sub ax, 100
    shl ax, 6
    mov [cy_val], ax

    xor si, si          ; Zx
    xor bx, bx          ; Zy
    mov cx, 0   

iterate:
    ; Zx^2
    mov ax, si
    imul si
    shrd ax, dx, 12
    mov [zx_sq], ax

    ; Zy^2
    mov ax, bx
    imul bx
    shrd ax, dx, 12
    mov [zy_sq], ax

    ; Условие выхода: Zx^2 + Zy^2 > 4.0
    mov dx, [zx_sq]
    add dx, [zy_sq]
    cmp dx, 16384
    jg done_iter

    ; new Zy = 2*Zx*Zy + Cy
    mov ax, si
    imul bx
    shrd ax, dx, 11
    add ax, [cy_val]
    mov [new_zy], ax

    ; new Zx = Zx^2 - Zy^2 + Cx
    mov ax, [zx_sq]
    sub ax, [zy_sq]
    add ax, [cx_val]
    
    mov si, ax
    mov bx, [new_zy]

    inc cx
    cmp cx, 150       
    jl iterate

done_iter:
    cmp cx, 150
    je set_black
    
    mov al, cl          
    test al, al         
    jnz draw_pixel
    mov al, 1
    jmp draw_pixel

set_black:
    xor al, al    

draw_pixel:
    mov [es:di], al
    inc di
    inc word [px]
    cmp word [px], 320
    jl x_loop

    inc word [py]
    cmp word [py], 200
    jl y_loop

wait_key:
    xor ax, ax
    int 0x16
    mov ax, 0x12
    int 0x10
    ret

; --- Date section ---
px dw 0
py dw 0
cx_val dw 0
cy_val dw 0
zx_sq  dw 0
zy_sq  dw 0
new_zy dw 0