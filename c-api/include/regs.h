#ifndef REGS_H
#define REGS_H

union REGS
{
    struct { unsigned int ax, bx, cx, dx, si, di, ds, es; } x;
    struct { unsigned char al, ah, bl, bh, cl, ch, dl, dh; } h;
};

#endif /* REGS_H */
