.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "BSS"
.code

;=================================================
;=================================================
; 
;   Headers
;
;-------------------------------------------------

.include "debug.inc"
.include "graphics.inc"
.include "kernal.inc"
.include "system.inc"
.include "vera.inc"

;=================================================
; Macros
;
;-------------------------------------------------

DEFAULT_SCREEN_ADDR = (0)
DEFAULT_SCREEN_SIZE = ((128*64)*2)
VROM_PETSCII = ($1F<<11)

NUM_MATRIX_PALETTE_ENTRIES = ((Matrix_palette_end - Matrix_palette) >> 1)

;=================================================
; MOD
;   Module the accumulator by a value.
;-------------------------------------------------
; INPUTS:   .v  Divisor of the modulo
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro MOD v
:   sec
    sbc #v
    bcs :-
    adc #v
.endmacro

;=================================================
;=================================================
; 
;   main code
;
;-------------------------------------------------
start:
    sei

    SYS_INIT_IRQ
    SYS_RAND_SEED $34, $56, $fe

    jsr graphics_init
    jsr graphics_fade_out

    jsr init_stuff
    jsr fill_text_buffer_with_random_chars
    jsr offset_palette_of_each_column
    jsr fill_palette_of_remaining_chars

    lda #32
    sta Fade_in_steps

    SYS_SET_IRQ irq_handler
    cli

    jmp *

.proc init_stuff
    VERA_SET_CTRL 0
    VERA_CONFIGURE_TILE_LAYER 0, 0, 1, 0, 0, 2, 1, (::DEFAULT_SCREEN_ADDR), (::VROM_PETSCII)

    VERA_DISABLE_LAYER 1
    VERA_ENABLE_LAYER 0

    rts
.endproc

.proc fill_text_buffer_with_random_chars
    VERA_SET_ADDR (DEFAULT_SCREEN_ADDR), 2

    ldx #128
    ldy #64

yloop:
    phy
xloop:
    phx

    jsr sys_rand
    and #$7F
    tay

    lda Petscii_table,Y
    sta VERA_data

    plx
    dex
    bne xloop

    ply
    dey
    bne yloop

    rts
.endproc

.proc offset_palette_of_each_column
    VERA_SET_CTRL 0
    VERA_SET_ADDR (DEFAULT_SCREEN_ADDR+1), 2

    ldy #128

loop:
    jsr sys_rand
    ; If we're about to assign palette index 0 (background), increment to 1
    ; I don't think we can depend on the carry bit in this case, so we're
    ; doing this the hard and slow way.
    cmp #0
    bne :+
    clc
    adc #1
:   sta VERA_data

    dey
    bne loop

    rts
.endproc

.proc fill_palette_of_remaining_chars
    VERA_SET_CTRL 0
    VERA_SET_ADDR (DEFAULT_SCREEN_ADDR+1), 2
    VERA_SET_CTRL 1
    VERA_SET_ADDR (DEFAULT_SCREEN_ADDR+257), 2

    ldx #127
    ldy #64

yloop:
    phy
xloop:
    phx

    lda VERA_data
    clc
    adc #1
    ; If we're about to assign palette index 0 (background), increment to 1
    ; Fortunately, the carry bit will be set, so let's just adc #0. Faster
    ; than branching, anyways.
    adc #0

    sta VERA_data2

    plx
    dex
    bne xloop

    ply
    dey
    bne yloop

    rts
.endproc

;=================================================
;=================================================
; 
;   IRQ Handlers
;
;-------------------------------------------------

.code
;=================================================
; irq_handler
;   This is essentially my "do_frame". Several others have been doing this as well.
;   Since the IRQ is triggered at the beginning of the VGA/NTSA front porch, we don't
;   get the benefit of the entire VBLANK, but it's still useful as a "do this code
;   once per frame" function.
;-------------------------------------------------
; INPUTS: (none)
;
;-------------------------------------------------
; MODIFIES: A, X, Y, VRAM_palette
; 
irq_handler: DEBUG_LABEL irq_handler
    VERA_SET_CTRL 0

    ; Increment which palette index we're starting at
    lda Palette_cycle_index
    clc
    adc #1
    ; I don't want to clobber palette index 0. Fortunately, the highest palette index is
    ; also the maximum of an unsigned 8-bit integer, as with our registers on the 6502. There
    ; is a "carry" bit in the processor which indicates overflows, and is intended to aid with
    ; multi-byte additions. We can sneakily use it to skip zero, however, by attempting to add
    ; "0" to our incremented value. If the carry bit was set, we'll actually add "1", which
    ; causes us to skip 0.
    adc #0
    sta Palette_cycle_index

    ;
    ; Palette cycle for the letters glowing and stuff
    ;
    ; Set the starting address of the VRAM palette we're going to cycle
    asl ; Palette_cycle_index * 2 == Address offset into palette memory
    ; adc #<(VRAM_palette) ; We happen to know that #<(VRAM_palette) is 0. Being able to skip this also preserves Carry in case it was set
    sta VERA_addr_low
    lda #<(VRAM_palette >> 8)
    adc #0  ; Add carry bit for indices 128-255
    sta VERA_addr_high
    lda #<(VRAM_palette >> 16) | ($10)
    sta VERA_addr_bank

    ; Okay, this is tricksy: 
    ; First, I'm generating 16 palettes which range from "full brightness" to "no brightness".
    ; Then, I'm generating two tables using the start addresses of each palette. One with the high byte of these
    ; addresses, one with the low byte.
    ; Fade_in_steps is nominally the number of frames left in the fade-in process. I happen to be choosing
    ; a value that is 2x as many palettes as I have to choose from, so I'm decrementing the value and then
    ; right-shifting to get the "palette index" I want. I then use this index to grab the high byte and low byte
    ; of the address of the appropriate palette, from the pair of tables I generated with their addresses.
    ; That high byte and low byte make the final address of the palette I apply.
    ldx Fade_in_steps
    cpx #0
    beq :+
    dex
    stx Fade_in_steps

:   txa
    lsr
    tax

    lda Matrix_palette_table_low, X
    sta $FB
    lda Matrix_palette_table_high, X
    sta $FC

    ldx Palette_cycle_index
    ldy #0

stream_out_color:
    lda ($FB),Y
    sta VERA_data
    iny
    lda ($FB),Y
    sta VERA_data
    iny
    inx
    bne check_for_end   
    ; If incrementing X here put us at zero (e.g. we'll clobber palette index 0 next), reset the VERA data address to point at palette index 1 instead. 
    ; We know we can't cycle through index 0 twice, so no additional fix-up is needed.
    VERA_SET_PALETTE 0, 1
check_for_end:
    cpy #(Matrix_palette_end - Matrix_palette)
    bne stream_out_color
 
    ;
    ; Palette cycle (redux) for double-density! See if you can still follow what's going on, with fewer comments.
    ;
    lda Palette_cycle_index
    clc
    adc #127
    adc #0

    ; Set the starting address of the VRAM palette we're going to cycle
    asl ; Palette_cycle_index * 2 == Address offset into palette memory
    sta VERA_addr_low
    lda #<(VRAM_palette >> 8)
    adc #0  ; Add carry bit for indices 128-255
    sta VERA_addr_high
    lda #<(VRAM_palette >> 16) | (1 << 4)
    sta VERA_addr_bank

    lda Fade_in_steps
    lsr
    tax
    lda Matrix_palette_table_low, X
    sta $FB
    lda Matrix_palette_table_high, X
    sta $FC

    lda Palette_cycle_index
    adc #127
    adc #0
    tax
    ldy #0

stream_out_color2:
    lda ($FB),Y
    sta VERA_data
    iny
    lda ($FB),Y
    sta VERA_data
    iny
    inx
    bne check_for_end2
    VERA_SET_PALETTE 0, 1
check_for_end2:
    cpy #(Matrix_palette_end - Matrix_palette)
    bne stream_out_color2

    VERA_END_VBLANK_IRQ
    SYS_END_IRQ

;=================================================
;=================================================
; 
;   Libs
;
;-------------------------------------------------
.include "system.asm"
.include "graphics.asm"

;=================================================
;=================================================
; 
;   Data
;
;-------------------------------------------------
.data
Fade_in_steps:
All_palettes_cleared: .byte $00
Palette_cycle_index: .byte $00

Petscii_table:
    .repeat $60, i
        .byte i
    .endrep

    .repeat $20, i
        .byte i+$A0
    .endrep

Matrix_palette:
    .word $0000, $0000, $0020, $0020, $0030, $0030, $0040, $0040
    .word $0050, $0050, $0060, $0060, $0070, $0070, $0080, $0080
    .word $0090, $0090, $00A0, $00A0, $00B0, $00B0, $00C0, $00C0
    .word $00D0, $00D0, $00E0, $00E0, $00F0, $00F0, $08FC
Matrix_palette_end:

.macro LE16_MIN v0, v1
    .if v0 < v1
        .word v0
    .else
        .word v1
    .endif
.endmacro

.macro LE16_MAX v0, v1
    .if v0 > v1
        .word v0
    .else
        .word v1
    .endif
.endmacro

.macro COLOR_DEC color, amt
    .word 0 ; I'll figure this out later, for now I'm cheating and the "leading character" will
            ; just be black during the fade-in.
.endmacro

.repeat 16, i
    .word $0000, $0000
    LE16_MAX ($0020 - i*$10), 0
    LE16_MAX ($0020 - i*$10), 0
    LE16_MAX ($0030 - i*$10), 0
    LE16_MAX ($0030 - i*$10), 0
    LE16_MAX ($0040 - i*$10), 0
    LE16_MAX ($0040 - i*$10), 0
    LE16_MAX ($0050 - i*$10), 0
    LE16_MAX ($0050 - i*$10), 0
    LE16_MAX ($0060 - i*$10), 0
    LE16_MAX ($0060 - i*$10), 0
    LE16_MAX ($0070 - i*$10), 0
    LE16_MAX ($0070 - i*$10), 0
    LE16_MAX ($0080 - i*$10), 0
    LE16_MAX ($0080 - i*$10), 0
    LE16_MAX ($0090 - i*$10), 0
    LE16_MAX ($0090 - i*$10), 0
    LE16_MAX ($00A0 - i*$10), 0
    LE16_MAX ($00A0 - i*$10), 0
    LE16_MAX ($00B0 - i*$10), 0
    LE16_MAX ($00B0 - i*$10), 0
    LE16_MAX ($00C0 - i*$10), 0
    LE16_MAX ($00C0 - i*$10), 0
    LE16_MAX ($00D0 - i*$10), 0
    LE16_MAX ($00D0 - i*$10), 0
    LE16_MAX ($00E0 - i*$10), 0
    LE16_MAX ($00E0 - i*$10), 0
    LE16_MAX ($00F0 - i*$10), 0
    LE16_MAX ($00F0 - i*$10), 0
    COLOR_DEC ($08FC), i
.endrep

Matrix_palette_table_high:
    .repeat 16, i
        .byte >(Matrix_palette + ((Matrix_palette_end - Matrix_palette) * i))
    .endrep
Matrix_palette_table_low:
    .repeat 16, i
        .byte <(Matrix_palette + ((Matrix_palette_end - Matrix_palette) * i))
    .endrep

Palette_decrement_table:
    ;     $X0, $X1, $X2, $X3, $X4, $X5, $X6, $X7, $X8, $X9, $XA, $XB, $XC, $XD, $XE, $XF
    .byte $00, $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E    ; $0X
    .byte $00, $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E    ; $1X
    .byte $10, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1A, $1B, $1C, $1D, $1E    ; $2X
    .byte $20, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $2A, $2B, $2C, $2D, $2E    ; $3X
    .byte $30, $30, $31, $32, $33, $34, $35, $36, $37, $38, $39, $3A, $3B, $3C, $3D, $3E    ; $4X
    .byte $40, $40, $41, $42, $43, $44, $45, $46, $47, $48, $49, $4A, $4B, $4C, $4D, $4E    ; $5X
    .byte $50, $50, $51, $52, $53, $54, $55, $56, $57, $58, $59, $5A, $5B, $5C, $5D, $5E    ; $6X
    .byte $60, $60, $61, $62, $63, $64, $65, $66, $67, $68, $69, $6A, $6B, $6C, $6D, $6E    ; $7X
    .byte $70, $70, $71, $72, $73, $74, $75, $76, $77, $78, $79, $7A, $7B, $7C, $7D, $7E    ; $8X
    .byte $80, $80, $81, $82, $83, $84, $85, $86, $87, $88, $89, $8A, $8B, $8C, $8D, $8E    ; $9X
    .byte $90, $90, $91, $92, $93, $94, $95, $96, $97, $98, $99, $9A, $9B, $9C, $9D, $9E    ; $AX
    .byte $A0, $A0, $A1, $A2, $A3, $A4, $A5, $A6, $A7, $A8, $A9, $AA, $AB, $AC, $AD, $AE    ; $BX
    .byte $B0, $B0, $B1, $B2, $B3, $B4, $B5, $B6, $B7, $B8, $B9, $BA, $BB, $BC, $BD, $BE    ; $CX
    .byte $C0, $C0, $C1, $C2, $C3, $C4, $C5, $C6, $C7, $C8, $C9, $CA, $CB, $CC, $CD, $CE    ; $DX
    .byte $D0, $D0, $D1, $D2, $D3, $D4, $D5, $D6, $D7, $D8, $D9, $DA, $DB, $DC, $DD, $DE    ; $EX
    .byte $E0, $E0, $E1, $E2, $E3, $E4, $E5, $E6, $E7, $E8, $E9, $EA, $EB, $EC, $ED, $EE    ; $FX