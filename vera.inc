!ifdef VERA_INC !eof
VERA_INC=1

!addr {
	!if MACHINE_C64 = 1 {
		VERA_base = $df00
	} else {
		VERA_base = $9f20
	}
	VERA_addr_bank  = VERA_base+0
	VERA_addr_high  = VERA_base+1
	VERA_addr_low   = VERA_base+2
	VERA_data       = VERA_base+3
	VERA_data2      = VERA_base+4
	VERA_ctrl       = VERA_base+5
	VERA_irq_ctrl   = VERA_base+6
	VERA_irq        = VERA_base+7

	VRAM_layer1   = $40000
	VRAM_layer2   = $40010
	VRAM_sprinfo  = $40020
	VRAM_composer = $40040
	VRAM_palette  = $40200
	VRAM_sprdata  = $40800

	VROM_petscii = $20000
}

!macro VERA_SELECT_ADDR .addr {
	lda #.addr
	sta VERA_ctrl
}

!macro VERA_SET_ADDR .addr, .stride {
	lda #<(.addr >> 16) | (.stride << 4)
	sta VERA_addr_bank
	lda #<(.addr >> 8)
	sta VERA_addr_high
	lda #<(.addr)
	sta VERA_addr_low
}

!macro VERA_SET_ADDR .addr {
	lda #<(.addr >> 16) | $10
	sta VERA_addr_bank
	lda #<(.addr >> 8)
	sta VERA_addr_high
	lda #<(.addr)
	sta VERA_addr_low
}

!macro VERA_WRITE .v0 {
	lda #.v0
	sta VERA_data
}

!macro VERA_WRITE .v0, .v1 {
	+VERA_WRITE .v0
	+VERA_WRITE .v1
}

!macro VERA_WRITE .v0, .v1, .v2, .v3 {
	+VERA_WRITE .v0, .v1
	+VERA_WRITE .v2, .v3
}

!macro VERA_WRITE .v0, .v1, .v2, .v3, .v4, .v5, .v6, .v7 {
	+VERA_WRITE .v0, .v1, .v2, .v3
	+VERA_WRITE .v4, .v5, .v6, .v7
}

!macro VERA_WRITE .v0, .v1, .v2, .v3, .v4, .v5, .v6, .v7, .v8, .v9, .v10, .v11, .v12, .v13, .v14, .v15 {
	+VERA_WRITE .v0, .v1, .v2, .v3, .v4, .v5, .v6, .v7
	+VERA_WRITE .v8, .v9, .v10, .v11, .v12, .v13, .v14, .v15
}

!macro VERA_COPY .dst, .src, .bytes {
	+VERA_SET_ADDR .dst, 0
	ldx #<.bytes	; Pages
	ldy #>.bytes	; Bytes
@loop:

	txa
	cpy
	tax
	bne @loop
@end:
}

!macro VPEEK .addr {
	+VERA_SET_ADDR .addr
	lda VERA_data
}

!macro VERA_SET_SPRITE .sprite_index {
	+VERA_SET_ADDR (VRAM_sprdata + (.sprite_index << 3))
}

!macro VERA_SET_PALETTE .palette_index {
	+VERA_SET_ADDR (VRAM_palette + (.palette_index << 5))
}

!macro VERA_SET_PALETTE .palette_index, .color_offset {
	+VERA_SET_ADDR (VRAM_palette + (.palette_index << 5) + (.color_offset << 1))
}

!macro VERA_RESET {
	lda #$80
	sta VERA_ctrl
}

!macro video_init {
	lda #0
	sta VERA_ctrl ; set ADDR1 active
	sta VERA_addr_high
	lda #$14    ; $40040 - Composer output mode and chroma toggle
	sta VERA_addr_bank
	lda #$40
	sta VERA_addr_low
	lda #1
	sta VERA_data ; VGA output
}
