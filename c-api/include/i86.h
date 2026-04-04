#ifndef I86_H
#define I86_H

#include <regs.h>

/* x86-16 interrupt. Returns CFLAG. */
int int86(unsigned char int_no,
          union REGS __far *in_regs,
          union REGS __far *out_regs);

#endif /* I86_H */
