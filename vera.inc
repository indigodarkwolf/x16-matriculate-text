!if MACHINE_C64 = 1 {
	VERA_BASE =$df00
} else {
	VERA_BASE =$9f20
}
VERA_ADDR_BANK  = VERA_BASE+0
VERA_ADDR_HIGH  = VERA_BASE+1
VERA_ADDR_LOW   = VERA_BASE+2
VERA_DATA       = VERA_BASE+3
VERA_DATA2      = VERA_BASE+4
VERA_CTRL       = VERA_BASE+5
VERA_IRQ_CTRL   = VERA_BASE+6
VERA_IRQ        = VERA_BASE+7

VRAM_LAYER1   = $40000
VRAM_LAYER2   = $40010
VRAM_SPRINFO  = $40020
VRAM_COMPOSER = $40040
VRAM_PALETTE  = $40200
VRAM_SPRDATA  = $40800

!macro VERA_SELECT_ADDR .addr {
	lda #.addr
	sta VERA_CTRL
}

!macro VERA_SET_ADDR .addr, .stride {
	lda #<(.addr >> 16) | (.stride << 4)
	sta VERA_ADDR_BANK
	lda #<(.addr >> 8)
	sta VERA_ADDR_HIGH
	lda #<(.addr)
	sta VERA_ADDR_LOW
}

!macro VERA_SET_ADDR .addr {
	lda #<(.addr >> 16) | $10
	sta VERA_ADDR_BANK
	lda #<(.addr >> 8)
	sta VERA_ADDR_HIGH
	lda #<(.addr)
	sta VERA_ADDR_LOW
}

!macro VERA_WRITE .v0 {
	lda #.v0
	sta VERA_DATA
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
	lda VERA_DATA
}

!macro VERA_SET_SPRITE .sprite_index {
	+VERA_SET_ADDR (VRAM_SPRDATA + (.sprite_index << 3))
}

!macro VERA_SET_PALETTE .palette_index {
	+VERA_SET_ADDR (VRAM_PALETTE + (.palette_index << 5))
}

!macro VERA_RESET {
	lda #$80
	sta VERA_CTRL
}

!macro video_init {
	lda #0
	sta VERA_CTRL ; set ADDR1 active
	sta VERA_ADDR_HIGH
	lda #$14    ; $40040 - Composer output mode and chroma toggle
	sta VERA_ADDR_BANK
	lda #$40
	sta VERA_ADDR_LOW
	lda #1
	sta VERA_DATA ; VGA output
}
