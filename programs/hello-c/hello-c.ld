OUTPUT_FORMAT("binary")

/* Entry point */
ENTRY(start)

SECTIONS
{
    . = 0x8000;     /* Offset */
    . : { * }       /* Everything in a single section */
}
