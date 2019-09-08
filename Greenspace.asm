!symbollist "greenspace.sym"

!src "vera.inc"
!src "system.inc"

DEFAULT_SCREEN_ADDR = 0
DEFAULT_SCREEN_SIZE = (128*64)*2

SYS_rand_mem=$A000    ; 3 bytes

!macro SYS_RAND_SEED .v0, .v1, .v2 {
    lda #.v0
    sta SYS_rand_mem
    lda #.v1
    sta SYS_rand_mem+1
    lda #.v2
    sta SYS_rand_mem+2
}

!macro MOD .v {
; !if .v < $80 {
-   sec
    sbc #.v
    bcs -
    adc #.v
; } else {
;     sec
;     sbc #.v
;     bcs @skip
;     adc #.v
; @skip:
; }
}

*=$0801
    +SYS_HEADER

    ; +VERA_RESET
Start:
    +SYS_STREAM_OUT MATRIX_PALETTE, $A100, 16*16

    +SYS_RAND_SEED $34, $56, $78

    +VERA_SET_ADDR VRAM_layer1
    +VERA_WRITE ($01 << 5) | $01            ; Mode 1 (256-color text), enabled
    +VERA_WRITE $0A                         ; 8x8 tiles, 64x32 map
    +VERA_WRITE <(DEFAULT_SCREEN_ADDR >> 2) ; Map indices at VRAM address 0
    +VERA_WRITE >(DEFAULT_SCREEN_ADDR >> 2) ; 
    +VERA_WRITE <(VROM_petscii >> 2)        ; Tile data immediately after map indices
    +VERA_WRITE >(VROM_petscii >> 2)        ; Tile data immediately after map indices
    +VERA_WRITE 0, 0, 0, 0                  ; Hscroll and VScroll to 0
    
!zn Fill_text_buffer_with_random_chars {
    +VERA_SET_ADDR DEFAULT_SCREEN_ADDR, 2

    ldx #128
    ldy #64

.yloop:
    tya
    pha
.xloop:
    txa

    jsr Sys_rand
    +MOD $7F
    tay

    lda PETSCII_TABLE,Y    
    sta VERA_data

    tax
    dex
    bne .xloop

    pla
    tay
    dey
    bne .yloop
}

!zn Offset_palette_of_each_column {
    +VERA_SET_ADDR DEFAULT_SCREEN_ADDR+1, 2

    ldx #128

.xloop:
    txa
    pha

    jsr Sys_rand
    ; If we're about to assign palette index 0 (background), increment to 1
    cmp #0
    beq +
    clc
    adc #1
+   sta VERA_data

    pla
    tax
    dex
    bne .xloop
}

!zn Fill_palette_of_remaining_chars {
Fill_palette_of_remaining_chars:
    +VERA_SET_ADDR DEFAULT_SCREEN_ADDR+1, 2
    +VERA_SELECT_ADDR 1
    +VERA_SET_ADDR DEFAULT_SCREEN_ADDR+257, 2

    ldx #127
    ldy #64

.yloop:
    tya
    pha
.xloop:
    txa
    pha

    lda VERA_data
    clc
    adc #1
    ; If we're about to assign palette index 0 (background), increment to 1
    cmp #0
    beq +
    clc
    adc #1
+   sta VERA_data2

    pla
    tax
    dex
    bne .xloop

    pla
    tay
    dey
    bne .yloop
}

    +VERA_SELECT_ADDR 0
    +VERA_SET_PALETTE 0
    +SYS_STREAM_OUT MATRIX_PALETTE_REV, VERA_data, 16*2
    +SYS_STREAM MATRIX_PALETTE_REV, VERA_data, 16*30

    +SYS_SET_IRQ Irq_handler
    cli

    jmp *

    ; +VERA_RESET

; This is essentially my "do_frame". Several others have been doing this as well.
; Since the IRQ is triggered at the beginning of the VGA/NTSA front porch, we don't
; get the benefit of the entire VBLANK, but it's still useful as a "do this code
; once per frame" function.
Irq_handler:
    ; Increment which palette index we're starting at
    lda Palette_cycle_index
    clc
    adc #1
    ; Skip index zero, that's the background, we want to leave it black.
    bcc +
    adc #0
+   sta Palette_cycle_index
    clc
    ; Set the starting address of the VRAM palette we're going to cycle
    asl ; Palette_cycle_index * 2 == Address offset into palette memory
    ; adc #<(VRAM_palette) ; We happen to know that #<(VRAM_palette) is 0. Being able to skip this also preserves Carry in case it was set
    sta VERA_addr_low
    lda #<(VRAM_palette >> 8)
    adc #0  ; Add carry bit for indices 128-255
    sta VERA_addr_high
    lda #<(VRAM_palette >> 16) | (1 << 4)
    sta VERA_addr_bank

    ; lda #$F0
    ; sta VERA_data
    ; lda #00
    ; sta VERA_data 
    ; jmp .irq_end   

    lda #<MATRIX_PALETTE
    sta $FB
    lda #>MATRIX_PALETTE
    sta $FC

    ; The palette has room for 256 colors, let's make sure we don't
    ; try to exceed that. (Technically the memory immediately following)
    ; the palette is unassigned, but it may still be undefined behavior
    ; in final hardware.)

    ; Find the number of palette indices we have room for
    lda #0
    sec
    sbc Palette_cycle_index

NUM_MATRIX_PALETTE_ENTRIES = ((MATRIX_PALETTE_END - MATRIX_PALETTE) >> 1)

    ; If we have more room than needed, skip to copying
    ; everything.
    cmp #<(NUM_MATRIX_PALETTE_ENTRIES)
    bcs .skip_first_block

    clc
    asl     ; 2 bytes per color for total bytes we want to copy
    sta $FF

    ; copy what we have room for at the end
    tax
+   ldy #0
-   lda ($FB),Y
    sta VERA_data
    iny
    dex
    bne -

Setup_for_remainder:
    ; Palette start addr += (What we had room for)
    lda $FB
    adc $FF
    sta $FB
    bcc +
    inc $FC

    ; Palette entries remaining = Total - (What we had room for)
    ; e.g. Remaining = -(What we had room for) + Total
+   lda #(MATRIX_PALETTE_END - MATRIX_PALETTE)
    sec
    sbc $FF
    sec
    sbc $FF
    sta $FF

    ; Remaining palette writes start from the beginning of the palette buffer
    +VERA_SET_PALETTE 0, 1

    jmp .copy_remainder

.skip_first_block:
    lda #<NUM_MATRIX_PALETTE_ENTRIES
    asl
    sta $FF

.copy_remainder:
;     bcc +   ; Whoops, do we have more than 255 bytes to copy? Copy a page.
;     ldy #0
; -   lda ($FB),Y
;     sta VERA_data
;     iny
;     bne -
;     inc $FC

+   ldy #0
-   lda ($FB),Y
    sta VERA_data
    iny
    cpy $FF
    bmi -

    jmp .irq_end
.irq_end:
    +SYS_END_IRQ

Sys_rand:
    ldx #8
    lda SYS_rand_mem
-   asl
    rol SYS_rand_mem+1
    rol SYS_rand_mem+2
    bcc +
    eor #$1B
+   dex
    bne -
    sta SYS_rand_mem
    cmp #0
    rts

;==============================================
; VERA_stream_out_data
; Stream out a block of memory to VERA_data
;----------------------------------------------
; INPUT: X   - number of pages to stream
;        Y   - number of bytes to stream
;        $FB - low byte of starting address
;        $FC - high byte of starting address
;----------------------------------------------
; Modifies: A, X, Y, $FC
;
VERA_stream_out_data:
    tya
    pha
    ; If no pages to copy, skip to bytes
    txa
    cmp #0
    tax
    beq @no_blocks

    ; Copy X pages to VERA_data
    ldy #0
@loop:
    lda ($FB),Y
    sta VERA_data
    iny
    bne @loop

    inc $FC
    dex
    bne @loop

@no_blocks:
    ; Copy X bytes to VERA_data
    pla
    tax
    ldy #0
@loop2:
    lda ($FB),Y
    sta VERA_data
    iny
    dex
    bne @loop2
    rts

PETSCII_TABLE:
    !for i,1,$60 {
        !byte i
    }
    !for i,0,$20 {
        !byte i+$A0
    }

MATRIX_PALETTE:
    !le16 $0000, $0000, $0000, $0000, $0020, $0020, $0030, $0030 
    !le16 $0040, $0040, $0050, $0050, $0060, $0060, $0070, $0070 
    !le16 $0080, $0080, $0090, $0090, $00A0, $00A0, $00B0, $00B0
    !le16 $00C0, $00C0, $00D0, $00D0, $00E0, $00E0, $00F0, $00F0
    !le16 $08FC, $04F4, $0000, $0000
MATRIX_PALETTE_END:
MATRIX_PALETTE_REV:
    !le16 $0000, $0000, $04F4, $08FC, $00F0, $00F0, $00E0, $00E0
    !le16 $00D0, $00D0, $00C0, $00C0, $00B0, $00B0, $00A0, $00A0
    !le16 $0090, $0090, $0080, $0080, $0070, $0070, $0060, $0060
    !le16 $0050, $0050, $0040, $0040, $0030, $0030, $0020, $0020
    !le16 $0010, $0010, $0000, $0000
MATRIX_PALETTE_REV_END:

Palette_cycle_index: !byte $00

!if * > $9EFF {
    !warn "Program size exceeds Fixed RAM space."
}
