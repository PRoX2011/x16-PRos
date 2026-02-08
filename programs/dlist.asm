; ==================================================================
; x16-PRos -- DLIST. Drive listing utility for x16-PRos
; Copyright (C) 2025 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

start:
    mov ah, 0x11
    int 0x22
    ret