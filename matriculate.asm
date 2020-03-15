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

.include "vera.inc"
.include "system.inc"

;=================================================
; Macros
;
;-------------------------------------------------

DEFAULT_SCREEN_ADDR = (0)
DEFAULT_SCREEN_SIZE = ((128*64)*2)

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
    SYS_RAND_SEED $34, $56, $fe

decrement_palette:
    ; This is an optimistic flag: have we cleared the entire palette? 
    ; We'll falsify if not.
    lda #1
    sta All_palettes_cleared

    ; Let's assume the system is starting in Mode 0 with the default palette.
    ; And fade out the screen because we can.
    VERA_SELECT_ADDR 0
    VERA_SET_PALETTE 0
    VERA_SELECT_ADDR 1
    VERA_SET_PALETTE 0

    ldy #0 ; 256 colors in the palette

decrement_palette_entry:
    lda VERA_data
    ; Don't need to decrement if already #0 (black)
    cmp #0
    beq :+

    ; The first byte is %0000rrrr, which means we could get away just a
    ; decrement. But the second is %ggggbbbb, so we need to decrement 
    ; each half if not 0. Instead of complex assembly to do that, I'm just 
    ; going to precompute to a table and do a lookup of the next value.
    ; And since I did it that way for the second byte, do it the same
    ; way for the first as well since that answer is good for both.
    tax

    lda #0
    sta All_palettes_cleared

    lda Palette_decrement_table, X
:   sta VERA_data2

    lda VERA_data

    ; Still don't need to decrement 0.
    cmp #0
    beq :+

    tax

    lda #0
    sta All_palettes_cleared

    lda Palette_decrement_table, X
:   sta VERA_data2

    dey
    bne decrement_palette_entry

    SYS_SET_IRQ inc_new_frame
    cli
    ; Tight loop until next frame
:   lda New_frame
    cmp #$01
    bne :-

    sei

    lda #0
    sta New_frame

    lda All_palettes_cleared
    cmp #0
    beq decrement_palette

    ;
    ; Palette memory should now be all 0s, or a black screen.
    ; If only the composer gave us a brightness setting, I could
    ; have used that. Mei banfa.
    ;

    VERA_SELECT_ADDR 0

    VERA_SET_ADDR VRAM_layer1
    VERA_WRITE ($01 << 5) | $01            ; Mode 1 (256-color text), enabled
    VERA_WRITE %00000110                   ; 8x8 tiles, 128x64 map
    VERA_WRITE <(DEFAULT_SCREEN_ADDR >> 2) ; Map indices at VRAM address 0
    VERA_WRITE >(DEFAULT_SCREEN_ADDR >> 2) ; 
    VERA_WRITE <(VROM_petscii >> 2)        ; Tile data immediately after map indices
    VERA_WRITE >(VROM_petscii >> 2)        ; Tile data immediately after map indices
    VERA_WRITE 0, 0, 0, 0                  ; Hscroll and VScroll to 0

    VERA_SET_ADDR VRAM_layer2
    VERA_WRITE ($01 << 5) | $00            ; Mode 1 (256-color text), disabled

.proc fill_text_buffer_with_random_chars
    VERA_SET_ADDR DEFAULT_SCREEN_ADDR, 2

    ldx #128
    ldy #64

yloop:
    tya
    pha
xloop:
    txa

    jsr sys_rand
    and #$7F
    tay

    lda Petscii_table,Y
    sta VERA_data

    tax
    dex
    bne xloop

    pla
    tay
    dey
    bne yloop
.endproc

.proc offset_palette_of_each_column
    VERA_SET_ADDR DEFAULT_SCREEN_ADDR+1, 2

    lda #128

xloop:
    pha

    jsr sys_rand
    ; If we're about to assign palette index 0 (background), increment to 1
    cmp #0
    beq :+
    clc
    adc #1
:   sta VERA_data

    pla
    sec
    sbc #1
    bne xloop
.endproc

.proc fill_palette_of_remaining_chars
    VERA_SET_ADDR DEFAULT_SCREEN_ADDR+1, 2
    VERA_SELECT_ADDR 1
    VERA_SET_ADDR DEFAULT_SCREEN_ADDR+257, 2
    VERA_SELECT_ADDR 0

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
    cmp #0
    bne store_index
    clc
    adc #1
store_index:
    sta VERA_data2

    plx
    dex
    bne xloop

    ply
    dey
    bne yloop
.endproc

    lda #32
    sta Fade_in_steps

    SYS_SET_IRQ irq_handler
    cli

    jmp *

;=================================================
;=================================================
; 
;   IRQ Handlers
;
;-------------------------------------------------

Line_number: .byte 0, 0
Offset: .byte 0, 0, 0

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
irq_handler:
    lda VERA_irq
    and #$02
    beq vsync_irq

    lda #1
    adc Line_number
    sta Line_number
    lda #0
    adc Line_number+1
    sta Line_number+1

    lda #128
    adc Offset
    sta Offset
    lda #0
    adc Offset+1
    sta Offset+1
    lda #0
    adc Offset+2
    sta Offset+2

    VERA_SET_ADDR $0F2006, 1
    lda Offset+1
    sta VERA_data
    lda Offset+2
    sta VERA_data

    VERA_SET_ADDR $0F0009, 1
    lda Line_number
    sta VERA_data
    lda Line_number+1
    sta VERA_data

    lda #$2
    sta VERA_irq
    SYS_END_IRQ

vsync_irq:
    stz Line_number
    stz Line_number+1
    stz Offset
    stz Offset+1
    stz Offset+2
    VERA_SET_ADDR $0F2006, 1
    stz VERA_data
    stz VERA_data

    VERA_SET_ADDR $0F0009, 1
    stz VERA_data
    stz VERA_data

    lda #$03
    sta VERA_irq_ctrl

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
    lda #<(VRAM_palette >> 16) | (1 << 4)
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

    VERA_END_IRQ
    SYS_END_IRQ

;=================================================
; inc_new_frame
;   This is essentially my "do_frame". Several others have been doing this as well.
;   Since the IRQ is triggered at the beginning of the VGA/NTSA front porch, we don't
;   get the benefit of the entire VBLANK, but it's still useful as a "do this code
;   once per frame" function.
;-------------------------------------------------
; INPUTS:   Sys_rand_mem
;
;-------------------------------------------------
; MODIFIES: A, X, Sys_rand_mem
; 
inc_new_frame:
    inc New_frame
    VERA_END_IRQ
    SYS_END_IRQ

;=================================================
;=================================================
; 
;   Libs
;
;-------------------------------------------------
.include "system.asm"

;=================================================
;=================================================
; 
;   Data
;
;-------------------------------------------------
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

;=================================================
;=================================================
;
;   Variables
;
;-------------------------------------------------
.include "matriculate_vars.asm"
.include "system_vars.asm"
