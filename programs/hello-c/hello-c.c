/*
 * Program for testing x16-PRos C interface.
 */

#include <pros.h>

void start(void)
{
    clear();
    print("");

    set_color(VGA_COLOR_LIGHT_CYAN);
    print_colored("Hello from C!!!");

    set_color(VGA_COLOR_LIGHT_YELLOW);
    print_colored("----------------------------------------");

    print ("This program is created to test C API.");
    print("");

    print("This is a string literal.");

    char str[37] = "And this string is located in stack.";
    print(str);
    print("");

    print("If you see 2 strings above, everything");
    print("seems to be working!");

    print_colored("-----------------------------------------");
    print("");
}
