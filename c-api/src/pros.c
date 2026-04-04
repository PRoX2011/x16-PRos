/* x16-PRos C interface implementation.
 *
 * Copyright (c) 2026 Alexander Zubov
 *
 * The x16-PRos project is licensed under the MIT License.
 */

/* Macros to extract segment/offset from far pointers */
#define FP_SEG(p) ((unsigned short)(((unsigned long)(p) >> 16) & 0xFFFF))
#define FP_OFF(p) ((unsigned short)((unsigned long)(p) & 0xFFFF))

#include <pros.h>
#include <regs.h>
#include <i86.h>

/* Prints null-terminated string */
void print(const char __far *str)
{
    union REGS r;

    /* Print string */
    r.h.ah = 0x01;
    r.x.ds = FP_SEG(str);
    r.x.si = FP_OFF(str);
    int86(0x21, &r, &r);

    /* New line */
    r.h.ah = 0x05;
    int86(0x21, &r, &r);
}

/* Prints null-terminated string in color set by set_color() */
void print_colored(const char __far *str)
{
    union REGS r;

    /* Print string */
    r.h.ah = 0x08;
    r.x.ds = FP_SEG(str);
    r.x.si = FP_OFF(str);
    int86(0x21, &r, &r);

    /* New line */
    r.h.ah = 0x05;
    int86(0x21, &r, &r);
}

/* Sets color of text to be printed by print_colored() */
void set_color(enum VGA_COLOR color)
{
    union REGS r;

    /* Set BL to color code */
    switch (color)
    {
        case VGA_COLOR_DARK_BLACK:   r.h.bl = 0x00; break;
        case VGA_COLOR_DARK_BLUE:    r.h.bl = 0x01; break;
        case VGA_COLOR_DARK_GREEN:   r.h.bl = 0x02; break;
        case VGA_COLOR_DARK_CYAN:    r.h.bl = 0x03; break;
        case VGA_COLOR_DARK_RED:     r.h.bl = 0x04; break;
        case VGA_COLOR_DARK_PINK:    r.h.bl = 0x05; break;
        case VGA_COLOR_DARK_YELLOW:  r.h.bl = 0x06; break;
        case VGA_COLOR_DARK_WHITE:   r.h.bl = 0x07; break;
        case VGA_COLOR_LIGHT_BLACK:  r.h.bl = 0x08; break;
        case VGA_COLOR_LIGHT_BLUE:   r.h.bl = 0x09; break;
        case VGA_COLOR_LIGHT_GREEN:  r.h.bl = 0x0A; break;
        case VGA_COLOR_LIGHT_CYAN:   r.h.bl = 0x0B; break;
        case VGA_COLOR_LIGHT_RED:    r.h.bl = 0x0C; break;
        case VGA_COLOR_LIGHT_PINK:   r.h.bl = 0x0D; break;
        case VGA_COLOR_LIGHT_YELLOW: r.h.bl = 0x0E; break;
        case VGA_COLOR_LIGHT_WHITE:  r.h.bl = 0x0F; break;
    }

    r.h.ah = 0x07;
    int86(0x21, &r, &r);
}

/* Clears screen */
void clear()
{
    union REGS r;
    r.h.ah = 0x06;
    int86(0x21, &r, &r);
}
