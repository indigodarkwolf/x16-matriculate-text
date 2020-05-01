.ifndef GRAPHICS_ASM
GRAPHICS_ASM=1

.include "debug.inc"
.include "vera.inc"

GRAPHICS_TABLES_BANK = $01
Gfx_palette_decrement_table = $A000
Gfx_palette                 = $A100
Gfx_palette_gb              = $A100
Gfx_palette_gb_0            = $A100
Gfx_palette_gb_1            = $A110
Gfx_palette_gb_2            = $A120
Gfx_palette_gb_3            = $A130
Gfx_palette_gb_4            = $A140
Gfx_palette_gb_5            = $A150
Gfx_palette_gb_6            = $A160
Gfx_palette_gb_7            = $A170
Gfx_palette_gb_8            = $A180
Gfx_palette_gb_9            = $A190
Gfx_palette_gb_10           = $A1A0
Gfx_palette_gb_11           = $A1B0
Gfx_palette_gb_12           = $A1C0
Gfx_palette_gb_13           = $A1D0
Gfx_palette_gb_14           = $A1E0
Gfx_palette_gb_15           = $A1F0
Gfx_palette_r              = $A200
Gfx_palette_r_0            = $A200
Gfx_palette_r_1            = $A210
Gfx_palette_r_2            = $A220
Gfx_palette_r_3            = $A230
Gfx_palette_r_4            = $A240
Gfx_palette_r_5            = $A250
Gfx_palette_r_6            = $A260
Gfx_palette_r_7            = $A270
Gfx_palette_r_8            = $A280
Gfx_palette_r_9            = $A290
Gfx_palette_r_10           = $A2A0
Gfx_palette_r_11           = $A2B0
Gfx_palette_r_12           = $A2C0
Gfx_palette_r_13           = $A2D0
Gfx_palette_r_14           = $A2E0
Gfx_palette_r_15           = $A2F0

.data
Gfx_all_palettes_at_full:
Gfx_all_palettes_cleared: .byte $00

.define GRAPHICS_TABLES_NAME "GRAPHICS_TABLES.SEQ"
GRAPHICS_TABLES_STR: .asciiz GRAPHICS_TABLES_NAME

;=================================================
;=================================================
;
;   General-purpose graphics routines
;
;-------------------------------------------------

.code
;=================================================
; graphics_init
;   Initialize the graphics subsystem, loading tables
;   and initializing values.
;
;-------------------------------------------------
; INPUTS:   A   Lhs
;           Y   Rhs
;
;-------------------------------------------------
; OUTPUTS:  X   Low-byte
;           A   High-byte
;
;-------------------------------------------------
; MODIFIES: A, X, Y
.proc graphics_init
    ; Load tables into himem
    SYS_SET_BANK GRAPHICS_TABLES_BANK
    KERNAL_SETLFS 1, 8, 0
    KERNAL_SETNAM .strlen(GRAPHICS_TABLES_NAME), GRAPHICS_TABLES_STR
    KERNAL_LOAD 0, $A000
    rts
.endproc

;=================================================
; graphics_decrement_palette
;   Fade the palette one step towards black
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A, X, Y, Gfx_all_palettes_cleared
;
.proc graphics_decrement_palette
    ; This is an optimistic flag: have we cleared the entire palette? 
    ; We'll falsify if not.
    lda #1
    sta Gfx_all_palettes_cleared

    ; The first thing I'm doing is trying to spin through the palette until there's work to be done.
    ; If we can quickly determine the whole palette is done, then bonus, we didn't have to do a lot
    ; of work.
    ; 
    ; But also, there's a that optimistic flag, and it's senseless to clear it more than once, so we'll
    ; scan through data until we find work, then clear the flag, then do work and not worry about the flag
    ; again.
    ;
    ; So if you imagine one loop that does everything, what I've done is cloned it, deleted all the actual work
    ; from one, and the optimstic flag from the other, and I use the section under "has_work" to bridge from
    ; one clone to the other.
    ;
    ; Finally, I've broken the entire palette into two sets of 256 bytes. Not the first 128 colors followed
    ; by the second 128, but all 256 colors' low byte (the gb portion), followed by all 256 colors' high byte
    ; (the r portion). This allows me to duplicate a minimal amount of code and avoid needless loops and stack
    ; variables. 256 is a magic number in the 8-bit world, it's always helpful to not exceed it.

check_for_work:
    lda Gfx_palette_gb,y
    ; Don't need to decrement if already #0 (black)
    cmp #0
    bne has_work_gb

    lda Gfx_palette_r,y
    ; Don't need to decrement if already #0 (black)
    cmp #0
    bne has_work_r

    iny
    bne check_for_work

    ; If we get here, we had no work to do. Huzzah! So much time saved.
    rts

has_work_gb:
    tax
    lda #0
    sta Gfx_all_palettes_cleared
    bra continue_with_work_gb

has_work_r:
    tax
    lda #0
    sta Gfx_all_palettes_cleared
    bra continue_with_work_r

decrement_entry:
    lda Gfx_palette_gb,y
    cmp #0
    beq next_byte

    ; The first byte is %ggggbbbb, so we need to decrement 
    ; each half if not 0. Instead of complex assembly to do that, I'm just 
    ; going to precompute to a table and do a lookup of the next value.
    ;
    ; The second byte is %0000rrrr, but since I did a table for the first
    ; byte, and the table results are good for this too, I do the same
    ; thing for the second.

    tax
continue_with_work_gb:
    lda Gfx_palette_decrement_table,x
    sta Gfx_palette_gb,y

next_byte:
    lda Gfx_palette_r,y
    cmp #0
    beq next_entry

    tax
continue_with_work_r:
    lda Gfx_palette_decrement_table,x
    sta Gfx_palette_r,y

next_entry:
    iny
    bne decrement_entry

    rts
.endproc

;=================================================
; graphics_increment_palette
;   Fade the palette one step towards a set of desired values
;-------------------------------------------------
; INPUTS:   $FA-$FB Address of intended palette
;           $FC     First color in palette
;           $FD     Last color of palette
;
;-------------------------------------------------
; MODIFIES: A, X, Y, $FE-$FF, Gfx_all_palettes_at_full
; 
.proc graphics_increment_palette
    lda $FA
    sta $FE
    lda $FB
    sta $FF
    inc $FD
    ; This is an optimistic flag: have we cleared the entire palette? 
    ; We'll falsify if not.
    lda #1
    sta Gfx_all_palettes_at_full

    ldy $FC ; 256 colors in palette
check_palette_entry:
    lda Gfx_palette_gb,y
    ; Don't need to increment if already at target value
    cmp ($FE),y
    bne has_work_gb

    inc $FE
    bne :+
    inc $FF
:

    lda Gfx_palette_r,y
    ; Don't need to increment if already at target value
    cmp ($FE),y
    bne has_work_r

    iny
    cpy $FD
    bne check_palette_entry

    dec $FD
    rts


has_work_gb:
    tax
    lda #0
    sta Gfx_all_palettes_at_full
    bra continue_gb

has_work_r:
    tax
    lda #0
    sta Gfx_all_palettes_at_full
    txa
    bra continue_r


    ; The first byte is %ggggbbbb, which means we have to increment these separately.
    ; We're going to xor with the intended color. This gives us some bits like %aaaabbbb
    ; where any 'b' bits set mean we increment the bottom half, then any 'a' bits set mean we
    ; increment the top half.
    ;   --- I'm a little proud of realizing how much branching an XOR saves me, because I'm
    ;       a hack and I was literally staring at C++ code that did this:
    ;       
    ;       unsigned short increment(unsigned short color, unsigned short target) {
    ;           color = ((color & 0xF0) < (target & 0xF0)) ? color + 0x10 : color;
    ;           color = ((color & 0x0F) < (target & 0x0F)) ? color + 0x01 : color;
    ;           return color;
    ;       }
    ;
    ;       Yeah. What a waste of electricity compared to:
    ;
    ;       unsigned short increment(unsigned short color, unsigned short target) {
    ;           unsigned short bit_diff = color ^ target
    ;           if(bit_diff >= 0x10) color += 0x10;
    ;           if(bit_diff & 0x0F) color += 0x01;
    ;       }

increment_palette_entry:
    lda Gfx_palette_gb,y
    ; Don't need to increment if already at target value
    cmp ($FE),y
    beq next_byte

    tax
continue_gb:
    eor ($FE),y
    cmp #$10
    bcc low_nibble

    txa
    clc
    adc #$10
    tax
low_nibble:
    eor ($FE),y
    and #$0F
    beq :+
    inx
:
    txa

    sta Gfx_palette_gb,y

next_byte:
    ; Y holds the number of colors we've copied, so increment our starting address here instead.
    ; we'll still increment Y at the bottom.
    inc $FE
    bne :+
    inc $FF
:   

    lda Gfx_palette_r,y
    ; Don't need to increment if already at target value
    cmp ($FE),y
    beq next_palette_entry

continue_r:
    ; The second byte is %0000rrrr, which means we can get away with just an increment
    clc
    adc #1
    and #$0F
    sta Gfx_palette_r,y

next_palette_entry:
    iny
    cpy $FD
    bne increment_palette_entry

    dec $FD
    rts
.endproc

;=================================================
; graphics_apply_palette
;   Apply the current palette to the VERA
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A, X, Y
; 
.proc graphics_apply_palette
    VERA_SET_CTRL 0
    VERA_SET_PALETTE 0

    ldy #0
stream_byte:
    lda Gfx_palette_gb,y
    sta VERA_data
    lda Gfx_palette_r,y
    sta VERA_data
    iny
    lda Gfx_palette_gb,y
    sta VERA_data
    lda Gfx_palette_r,y
    sta VERA_data
    iny
    bne stream_byte

    rts
.endproc

;=================================================
; graphics_fade_out
;   Use palette decrementing to fade out the screen to black.
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A, X, Y
; 
.proc graphics_fade_out
    DEBUG_LABEL graphics_fade_out
    SYS_SET_BANK GRAPHICS_TABLES_BANK
    jsr graphics_decrement_palette
    jsr graphics_apply_palette
    jsr sys_wait_one_frame

    lda Gfx_all_palettes_cleared
    cmp #0
    beq graphics_fade_out

    rts
.endproc

;=================================================
; graphics_fade_in
;   Use palette incmenting to fade in the screen from black.
;-------------------------------------------------
; INPUTS:   $FA-$FB Address of intended palette
;           $FC     First color in the palette
;           $FD     Last color in the palette
;
;-------------------------------------------------
; MODIFIES: A, X, Y, $FE-$FF
; 
.proc graphics_fade_in
    DEBUG_LABEL graphics_fade_in
    SYS_SET_BANK GRAPHICS_TABLES_BANK
    jsr graphics_increment_palette
    jsr graphics_apply_palette
    jsr sys_wait_one_frame

    lda Gfx_all_palettes_at_full
    cmp #0
    beq graphics_fade_in

    rts
.endproc

.code
.endif ; GRAPHICS_ASM