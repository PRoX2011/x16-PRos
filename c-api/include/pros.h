/*
 * x16-PRos operating system C interface.
 */

#ifndef PROS_H
#define PROS_H

enum VGA_COLOR
{
    VGA_COLOR_DARK_BLACK,
    VGA_COLOR_DARK_BLUE,
    VGA_COLOR_DARK_GREEN,
    VGA_COLOR_DARK_CYAN,
    VGA_COLOR_DARK_RED,
    VGA_COLOR_DARK_PINK,
    VGA_COLOR_DARK_YELLOW,
    VGA_COLOR_DARK_WHITE,
    VGA_COLOR_LIGHT_BLACK,
    VGA_COLOR_LIGHT_BLUE,
    VGA_COLOR_LIGHT_GREEN,
    VGA_COLOR_LIGHT_CYAN,
    VGA_COLOR_LIGHT_RED,
    VGA_COLOR_LIGHT_PINK,
    VGA_COLOR_LIGHT_YELLOW,
    VGA_COLOR_LIGHT_WHITE
};

/* Prints null-terminated string */
void print(const char __far *str);

/* Prints null-terminated string in color set by set_color() */
void print_colored(const char __far *str);

/* Sets color of text to be printed by print_colored() */
void set_color(enum VGA_COLOR);

/* Clears screen */
void clear();

#endif /* PROS_H */
