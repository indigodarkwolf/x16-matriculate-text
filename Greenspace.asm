!src "vera.inc"
!src "system.inc"

DEFAULT_SCREEN_ADDR = 0
DEFAULT_SCREEN_SIZE = (128*64)*2

MATRIX_TILEMAP_ADDR = DEFAULT_SCREEN_ADDR + DEFAULT_SCREEN_SIZE
MATRIX_TILEMAP_SIZE = (64*32)*2

MATRIX_TILEDAT_ADDR = MATRIX_TILEMAP_ADDR + MATRIX_TILEMAP_SIZE
MATRIX_TILEDAT_SIZE = (8*16*64)

HIGHEST_VRAM = MATRIX_TILEDAT_ADDR + MATRIX_TILEDAT_SIZE

!if HIGHEST_VRAM > $20000 {
    !warn "VRAM allocations extend into VROM, expect corruption."
}

*=$0801
    +SYS_HEADER

    ; +VERA_RESET
START:
    +VERA_SET_ADDR VRAM_LAYER1
    +VERA_WRITE ($03 << 5) | $01            ; Mode 3 (4bpp tiles), enabled
    +VERA_WRITE $31                         ; 16x16 tiles, 64x32 map
    +VERA_WRITE <(MATRIX_TILEMAP_ADDR >> 2) ; Map indices at VRAM address 0
    +VERA_WRITE >(MATRIX_TILEMAP_ADDR >> 2) ; 
    +VERA_WRITE <(MATRIX_TILEDAT_ADDR >> 2) ; Tile data immediately after map indices
    +VERA_WRITE >(MATRIX_TILEDAT_ADDR >> 2) ; Tile data immediately after map indices
    +VERA_WRITE 0, 0, 0, 0                  ; Hscroll and VScroll to 0
    
    +VERA_SET_ADDR MATRIX_TILEMAP_ADDR
    +SYS_STREAM_OUT MATRIX_TEST_TILEMAP, VERA_DATA, MATRIX_TILEMAP_SIZE

    +VERA_SET_ADDR MATRIX_TILEDAT_ADDR
    +SYS_STREAM_OUT MATRIX_SET, VERA_DATA, MATRIX_TILEDAT_SIZE

    +VERA_SET_PALETTE 0
    +SYS_STREAM_OUT MATRIX_PALETTE, VERA_DATA, 16*8

    +SYS_SET_IRQ IRQ
    cli

.loop:
    jmp .loop

    ; +VERA_RESET
IRQ:
    +SYS_END_IRQ

!src "matrix-set.inc"

MATRIX_PALETTE:
MATRIX_PALETTE_0_1:
    !byte $00, $00, $20, $00, $41, $00, $61, $00, $82, $00, $a2, $00, $c3, $00, $f3, $00
    !byte $00, $00, $00, $00, $20, $00, $41, $00, $61, $00, $82, $00, $a2, $00, $c3, $00
    !byte $00, $00, $00, $00, $00, $00, $20, $00, $41, $00, $61, $00, $82, $00, $a2, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $20, $00, $41, $00, $61, $00, $82, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $20, $00, $41, $00, $61, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $20, $00, $41, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $20, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

MATRIX_TEST_TILEMAP:
    !for i, 0, (64*32) {
        !byte (i & $3f), 0
    }

!if * > $9EFF {
    !warn "Program size exceeds Fixed RAM space."
}
