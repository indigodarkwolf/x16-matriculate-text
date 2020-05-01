.ifndef VERA_ASM
VERA_ASM=1

.code
.ifdef USING_VERA_STREAM_OUT_RLE
;==============================================
; vera_stream_out_data
; Stream out a block of memory to VERA_data
;----------------------------------------------
; INPUT: X   - number of pages to stream
;        Y   - number of bytes to stream
;        $FB - low byte of starting address
;        $FC - high byte of starting address
;----------------------------------------------
; Modifies: A, X, Y, $FC
;
vera_stream_out_data:
    tya
    pha
    ; If no pages to copy, skip to bytes
    txa
    cmp #0
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
.endif ; USING_VERA_STREAM_OUT_DATA

.ifdef USING_VERA_STREAM_OUT_RLE
;==============================================
; vera_stream_out_rle
; Stream out a block of rle-compressed memory to VERA_data
;----------------------------------------------
; INPUT: X   - number of rle pages to stream
;        Y   - number of rle bytes to stream
;        $FB - low byte of starting address
;        $FC - high byte of starting address
;----------------------------------------------
; Modifies: A, X, Y, $FC
;
vera_stream_out_rle:
    tya
    pha
    ; If no pages to copy, skip to bytes
    txa
    cmp #0
    beq @no_pages

    ; Copy X pages to VERA_data
    ldy #0
@page_loop:
    pha

@tuple_loop:
    ; First byte is the number of repetitions
    lda ($FB),Y
    tax

    iny

    ; Second byte is the value to stream
    lda ($FB),Y
    iny

@byte_loop:
    sta VERA_data
    dex
    bne @byte_loop

    cpy #0
    bne @tuple_loop

    inc $FC
    pla
    clc
    adc #$FF
    bne @page_loop

@no_pages:
    ; Copy X bytes to VERA_data
    ldy #0

@loop2:
    ; First byte is the number of repetitions
    lda ($FB),Y
    tax
    iny

    ; Second byte is the value to stream
    lda ($FB),Y
    iny
@byte_loop2:
    sta VERA_data
    dex
    bne @byte_loop2

    pla
    clc 
    adc #$FE
    pha
    bne @loop2
    pla
    
    rts

.endif ; USING_VERA_STREAM_OUT_RLE

.endif ; VERA_ASM