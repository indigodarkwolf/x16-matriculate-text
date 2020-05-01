
.ifndef VERA_INC
VERA_INC=1

.include "system.inc"

;=================================================
;=================================================
;
;   Memory-mapped registers
;
;-------------------------------------------------

.ifdef MACHINE_C64
	VERA_base = $df00
.else
	VERA_base = $9f20
.endif

VERA_addr_low   = VERA_base+0
VERA_addr_high  = VERA_base+1
VERA_addr_bank  = VERA_base+2
VERA_data       = VERA_base+3
VERA_data2      = VERA_base+4
VERA_ctrl       = VERA_base+5
VERA_ien   		= VERA_base+6
VERA_isr        = VERA_base+7
VERA_irqline_l	= VERA_base+8

VERA_dc_video	= VERA_base+9
VERA_dc_hscale	= VERA_base+10
VERA_dc_vscale	= VERA_base+11
VERA_dc_border 	= VERA_base+12
VERA_dc_hstart	= VERA_base+9
VERA_dc_hstop 	= VERA_base+10
VERA_dc_vstart	= VERA_base+11
VERA_dc_vstop	= VERA_base+12

VERA_l0_config	= VERA_base+13
VERA_l0_mapbase = VERA_base+14
VERA_l0_tilebase = VERA_base+15
VERA_l0_hscroll_l = VERA_base+16
VERA_l0_hscroll_h = VERA_base+17
VERA_l0_vscroll_l = VERA_base+18
VERA_l0_vscroll_h = VERA_base+19

VERA_l1_config	= VERA_base+20
VERA_l1_mapbase = VERA_base+21
VERA_l1_tilebase = VERA_base+22
VERA_l1_hscroll_l = VERA_base+23
VERA_l1_hscroll_h = VERA_base+24
VERA_l1_vscroll_l = VERA_base+25
VERA_l1_vscroll_h = VERA_base+26

VERA_audio_ctrl = VERA_base+27
VERA_audio_rate = VERA_base+28
VERA_audio_data = VERA_base+29

VERA_spi_data	= VERA_base+30
VERA_spi_ctrl	= VERA_base+31

VERA_l0_base = VERA_l0_config
VERA_l1_base = VERA_l1_config

VERA_layer_config = 0
VERA_layer_mapbase = 1
VERA_layer_tilebase = 2
VERA_layer_hscroll_l = 3
VERA_layer_hscroll_h = 4
VERA_layer_vscroll_l = 5
VERA_layer_vscroll_h = 6


VRAM_psg		= $1F9C0
VRAM_palette   	= $1FA00
VRAM_spr_attrib	= $1FC00

VRAM_palette0  = VRAM_palette + (2*16)*0
VRAM_palette1  = VRAM_palette + (2*16)*1
VRAM_palette2  = VRAM_palette + (2*16)*2
VRAM_palette3  = VRAM_palette + (2*16)*3
VRAM_palette4  = VRAM_palette + (2*16)*4
VRAM_palette5  = VRAM_palette + (2*16)*5
VRAM_palette6  = VRAM_palette + (2*16)*6
VRAM_palette7  = VRAM_palette + (2*16)*7
VRAM_palette8  = VRAM_palette + (2*16)*8
VRAM_palette9  = VRAM_palette + (2*16)*9
VRAM_palette10 = VRAM_palette + (2*16)*10
VRAM_palette11 = VRAM_palette + (2*16)*11
VRAM_palette12 = VRAM_palette + (2*16)*12
VRAM_palette13 = VRAM_palette + (2*16)*13
VRAM_palette14 = VRAM_palette + (2*16)*14
VRAM_palette15 = VRAM_palette + (2*16)*15

TILE_HFLIP=(1 << 10)
TILE_VFLIP=(1 << 11)

;=================================================
;=================================================
;
;   Macros
;
;-------------------------------------------------

;=================================================
; VERA_SET_CTRL
;   Select which address channel to configure (VERA_data vs. VERA_data2)
;-------------------------------------------------
; INPUTS:   addr	0 for VERA_data
;					1 for VERA_data2
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_SET_CTRL addr
	lda VERA_ctrl
	.if addr = 0
		and #$FE
	.else
		ora #$01
	.endif
	sta VERA_ctrl
.endmacro

;=================================================
; VERA_SET_ADDR (multiple)
;   Set the current address channel's address
;-------------------------------------------------
; INPUTS:   addr			VRAM address to set to
;			[stride = 1]	Address stride/auto-increment
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_SET_ADDR addr, stride
	lda #(<addr)
	sta VERA_addr_low
	lda #(>addr)
	sta VERA_addr_high
	
	.ifnblank stride
		.if stride < 0
			lda #((^addr) | (stride << 4)) | $08
		.else
			lda #((^addr) | (stride << 4))
		.endif
	.else
		lda #(^addr) | $10
	.endif

	sta VERA_addr_bank
.endmacro

;=================================================
; VERA_WRITE (multiple)
;   Write values to VERA_data.
;	If more than 8 values are needed, consider 
;	the SYS_STREAM_* family.
;-------------------------------------------------
; INPUTS:   v0 - v7	Values to write
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_WRITE v0, v1, v2, v3, v4, v5, v6, v7
	.ifblank v0
		.exitmacro
	.else
		lda #v0
		sta VERA_data
	.endif

	.if .paramcount > 1
		VERA_WRITE v1, v2, v3, v4, v5, v6, v7
	.endif
.endmacro

;=================================================
; VPEEK
;   It's... VPEEK(), but in assembly.
;-------------------------------------------------
; INPUTS:   addr	VRAM address to read from.
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VPEEK addr
	VERA_SET_ADDR addr
	lda VERA_data
.endmacro

;=================================================
; VERA_ENABLE_LAYER
;   Enable the specified layer
;-------------------------------------------------
; INPUTS:   layer	Which layer to enable
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_ENABLE_LAYER layer
	lda VERA_dc_video
	.if layer = 0
		ora #$10
	.else
		ora #$20
	.endif
	sta VERA_dc_video
.endmacro

;=================================================
; VERA_DISABLE_LAYER
;   Disable the specified layer
;-------------------------------------------------
; INPUTS:   layer	Which layer to enable
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_DISABLE_LAYER layer
	lda VERA_dc_video
	.if layer = 0
		and #($ff - $10)
	.else
		and #($ff - $20)
	.endif
	sta VERA_dc_video
.endmacro

;=================================================
; VERA_CONFIGURE_TILE_LAYER
;   Apply the given params to a layer.
;-------------------------------------------------
; INPUTS:   layer			Layer (0|1)
;			bpp				0: glyphs
;							1: tile 2bpp
;							2: tile 4bpp
;							3: tile 8bpp
;			t256c			0: 16-color glyphs, fg+bg
;							1: 256-color glyphs, fg only
;			w16_tiles		(0|1) enable 16-width tiles?
;			h16_tiles		(0|1) enable 16-height tiles?
;			mapw, maph		0: 32 tiles/chars
;							1: 64 tiles/chars
;							2: 128 tiles/chars
;							3: 256 tiles/chars
;			map_base		Start address of map indices (512-byte align)
;			tile_base		Start address of tile indices (2048-byte align)
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_CONFIGURE_TILE_LAYER layer, bpp, t256c, w16_tiles, h16_tiles, mapw, maph, map_base, tile_base
	.local layer_base

	.if layer = 0
		layer_base = VERA_l0_base
	.else
		layer_base = VERA_l1_base
	.endif

	.if (map_base & $FFE00) <> map_base
		.error "Map data does not obey alignment rules (512-byte alignment)"
	.endif

	.if (tile_base & $FF800) <> tile_base
		.error "Tile data does not obey alignment rules (2048-byte alignment)"
	.endif

	; Color mode and Map size
	lda #((maph << 6) | (mapw << 4) | (t256c << 3) | (bpp))
	sta layer_base + VERA_layer_config

	; Map base
	lda #(map_base >> 9)
	sta layer_base + VERA_layer_mapbase

	; Tile size and tile base
	lda #(((tile_base >> 11) << 2) | (h16_tiles << 1) | (w16_tiles))
	sta layer_base + VERA_layer_tilebase
.endmacro

;=================================================
; VERA_CONFIGURE_BMP_LAYER
;   Apply the given params to a layer.
;-------------------------------------------------
; INPUTS:   layer			Layer (0|1)
;			bpp				0: bitmap 1bpp
;							1: bitmap 2bpp
;							2: bitmap 4bpp
;							3: bitmap 8bpp
;			w640			(0|1) enable 640p width?
;			palette_offset	Which 16-color palette should it use?
;			image_base		Start address of bitmap data
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_CONFIGURE_BMP_LAYER layer, bpp, w640, palette_offset
	.local layer_base

	.if layer = 0
		layer_base = VERA_l0_base
	.else
		layer_base = VERA_l1_base
	.endif

	.if (tile_base & $FFFF80) <> tile_base
		.error "Tile data does not obey alignment rules"
	.endif

	; Color mode and Map size
	lda #((1 << 2) | (bpp))
	sta layer_base + VERA_layer_config

	; Tile size and tile base
	lda #(((tile_base >> 11) << 2) | (w640))
	sta layer_base + VERA_layer_tilebase

	; Palette offset
	lda #palette_offset
	sta layer_base + VERA_layer_hscroll_h
.endmacro

;=================================================
; VERA_SET_LAYER_SCROLL_X
;   Apply the given X scroll parameter at a memory address to the layer
;-------------------------------------------------
; INPUTS:   layer	Layer (0|1)
;			src		memory address containing WORD of scroll
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_SET_LAYER_SCROLL_X layer, src
	.local layer_base

	.if layer = 0
		layer_base = VERA_l0_base
	.else
		layer_base = VERA_l1_base
	.endif

    lda src
    sta layer_base + VERA_layer_hscroll_l
    lda src+1
    and #$0F
    sta layer_base + VERA_layer_hscroll_h
.endmacro


;=================================================
; VERA_SET_LAYER_SCROLL_Y
;   Apply the given Y scroll parameter at a memory address to the layer
;-------------------------------------------------
; INPUTS:   layer	Layer (0|1)
;			src		memory address containing WORD of scroll
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_SET_LAYER_SCROLL_Y layer, src
	.local layer_base

	.if layer = 0
		layer_base = VERA_l0_base
	.else
		layer_base = VERA_l1_base
	.endif

    lda src
    sta layer_base + VERA_layer_vscroll_l
    lda src+1
    and #$0F
    sta layer_base + VERA_layer_vscroll_h
.endmacro


;=================================================
; VERA_ENABLE_SPRITES
;   Enables sprites layer
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_ENABLE_SPRITES
    lda VERA_dc_video
	ora #$40
    sta VERA_dc_video
.endmacro

;=================================================
; VERA_DISABLE_SPRITES
;   Disables sprites layer
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_DISABLE_SPRITES
    lda VERA_dc_video
	and #($ff - $40)
    sta VERA_dc_video
.endmacro

;=================================================
; VERA_SET_SPRITE
;   Set the current address channel to target
;	an indexed sprite_data entry in VRAM_spr_attrib
;-------------------------------------------------
; INPUTS:   sprite_index	Sprite index to target
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_SET_SPRITE sprite_index
	VERA_SET_ADDR (VRAM_spr_attrib + (sprite_index << 3))
.endmacro

;=================================================
; VERA_CONFIGURE_SPRITE
;   Configure sprite data at the current sprite
;-------------------------------------------------
; INPUTS:   data_addr	Location in VRAM where sprite data exists
;			colors			0: 4bpp
;							1: 8bpp
;			xpos			X-position
;			ypos			Y-position
;			hflip			toggle horizontal flip
;			vflip			toggle verticle flip
;			zdepth			Z-depth of sprite
;			palette_index	16-color-palette index selection
;			width, height	0: 8px
;							1: 16px
;							2: 32px
;							3: 64px
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_CONFIGURE_SPRITE data_addr, colors, xpos, ypos, hflip, vflip, zdepth, palette_index, width, height
.if ((data_addr & $FFFE0) <> data_addr)
	.error "Sprite data does not obey alignment rules"
.endif

.local DATA_ADDR
DATA_ADDR=data_addr>>5

	VERA_WRITE (DATA_ADDR & $FF), ((DATA_ADDR >> 8) | (colors << 7))
	VERA_WRITE (xpos & $0FF), ((xpos & $300) >> 8), (ypos & $0FF), ((ypos & $300) >> 8)
	VERA_WRITE ((hflip) | (vflip << 1) | (zdepth << 2))
	VERA_WRITE ((palette_index & $0F) | (width << 4) | (height << 6))
.endmacro


;=================================================
; VERA_SET_SPRITE_POS_X
;   Set the X coordinate of the sprite from some location in memory
;-------------------------------------------------
; INPUTS:   sprite		Sprite index
;			src			Memory location with X coordinate
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_SET_SPRITE_POS_X sprite, src
    VERA_SET_ADDR (VRAM_spr_attrib + (8 * sprite) + 2), 1
    lda src
    sta VERA_data
    lda src+1
    and #$03
    sta VERA_data
.endmacro

;=================================================
; VERA_SET_SPRITE_POS_Y
;   Set the Y coordinate of the sprite from some location in memory
;-------------------------------------------------
; INPUTS:   sprite		Sprite index
;			src			Memory location with Y coordinate
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_SET_SPRITE_POS_Y sprite, src
    VERA_SET_ADDR (VRAM_spr_attrib + (8 * sprite) + 4), 1
    lda src
    sta VERA_data
    lda src+1
    and #$03
    sta VERA_data
.endmacro


;=================================================
; VERA_SET_PALETTE
;   Set the current address channel to target
;	an indexed palette  entry in VRAM_palette
;-------------------------------------------------
; INPUTS:   palette_index		Palette index to target
;			[.color_offset = 0]	Which color within the palette to target
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_SET_PALETTE palette_index, color_offset
	.ifblank color_offset
		VERA_SET_ADDR (VRAM_palette + (palette_index << 5))
	.else
		VERA_SET_ADDR (VRAM_palette + (palette_index << 5) + (color_offset << 1))
	.endif
.endmacro

;=================================================
; VERA_STREAM_OUT
;   Stream out a block of data to a location in VRAM
;-------------------------------------------------
; INPUTS:   src	Source data
;			dst	Destination start location
;			size	Numbers of bytes to stream out (max 64KiB)
;
;-------------------------------------------------
; MODIFIES: A, X, Y, $FB, $FC
; 
.macro VERA_STREAM_OUT_DATA src, dst, size
.ifndef USING_VERA_STREAM_OUT_DATA
	USING_VERA_STREAM_OUT_DATA=1
.endif
    VERA_SET_ADDR dst
    ldy #<(size)
    ldx #>(size)
    lda #<src
    sta $FB
    lda #>src
    sta $FC
    jsr vera_stream_out_data
.endmacro

;=================================================
; VERA_STREAM_OUT_RLE
;   Stream out a block of rle-deflated data to a location in VRAM
;-------------------------------------------------
; INPUTS:   src	Source data
;			dst	Destination start location
;			size	Numbers of bytes to stream out (max 64KiB)
;
;-------------------------------------------------
; MODIFIES: A, X, Y, $FB, $FC
;
.macro VERA_STREAM_OUT_RLE src, dst, size
.ifndef USING_VERA_STREAM_OUT_RLE
	USING_VERA_STREAM_OUT_RLE=1
.endif
    VERA_SET_ADDR dst
    ldy #<(size)
    ldx #>(size)
    lda #<src
    sta $FB
    lda #>src
    sta $FC
    jsr vera_stream_out_rle
.endmacro

;=================================================
; VERA_ENABLE_ALL
;   Enables all layers and global sprites
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_ENABLE_ALL
	lda VERA_dc_video
	ora #$70
	sta VERA_dc_video
.endmacro

;=================================================
; VERA_DISABLE_ALL
;   Enables all layers and global sprites
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_DISABLE_ALL
	lda VERA_dc_video
	and #($ff - $70)
	sta VERA_dc_video
.endmacro

;=================================================
; VERA_RESET
;   Reset the Vera to its default settings.
;	See official documentation for specifics.
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_RESET
	lda #$80
	sta VERA_ctrl
.endmacro


;=================================================
;=================================================
;
;   IRQs
;
;-------------------------------------------------

;=================================================
; VERA_ENABLE_LINE_IRQ
;   Enable the Vera Line IRQ flag so that it generates interrupts.
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_ENABLE_LINE_IRQ
	lda VERA_ien
	ora #$02
	sta VERA_ien
.endmacro

;=================================================
; VERA_DISABLE_LINE_IRQ
;   Enable the Vera Line IRQ flag so that it generates interrupts.
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_DISABLE_LINE_IRQ
	lda VERA_ien
	and #($ff - $02)
	sta VERA_ien
.endmacro

; ;=================================================
; ; VERA_CONFIGURE_LINE_IRQ
; ;   Configure the line irq settings
; ;-------------------------------------------------
; ; INPUTS:   line	line number to generate the next interrupt
; ;
; ;-------------------------------------------------
; ; MODIFIES: A
; ; 
; .macro VERA_CONFIGURE_LINE_IRQ line
; 	lda #<line
; 	sta VERA_irqline_l
; 	lda VERA_ien
; 	.if line > $ff
; 		ora #$80
; 	.else
; 		and #($ff - $80)
; 	.endif
; 	sta VERA_ien
; .endmacro

;=================================================
; VERA_CONFIGURE_LINE_IRQ
;   Configure the line irq settings
;-------------------------------------------------
; INPUTS:   source		address containing the line number
;
;-------------------------------------------------
; MODIFIES: A, X
; 
.macro VERA_CONFIGURE_LINE_IRQ source
	lda source
	sta VERA_irqline_l

	; My lame method:

	; lda VERA_ien
	; and #($ff - $80)
	; sta VERA_ien
	; lda source+1
	; ror
	; ror
	; and #$80
	; ora VERA_ien
	; sta VERA_ien

	; Matt Heffernan's better method (saves 3 cycles):

	; lda VERA_ien
	; asl
	; pha
	; lda source+1
	; lsr
	; pla
	; ror
	; sta VERA_ien

	; Jesper Balman Gravgaard offered this improvement (saves 2 cycles):

	lda VERA_ien
	asl
	tax
	lda source+1
	lsr
	txa
	ror
	sta VERA_ien
.endmacro

;=================================================
; VERA_END_LINE_IRQ
;   Reset the Vera line IRQ flag so that it generates interrupts.
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_END_LINE_IRQ
	lda #$2
	sta VERA_isr
.endmacro

;=================================================
; VERA_ENABLE_VBLANK_IRQ
;   Enable the Vera Line IRQ flag so that it generates interrupts.
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_ENABLE_VBLANK_IRQ
	lda VERA_ien
	ora #$02
	sta VERA_ien
.endmacro

;=================================================
; VERA_DISABLE_VBLANK_IRQ
;   Enable the Vera Line IRQ flag so that it generates interrupts.
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_DISABLE_VBLANK_IRQ
	lda VERA_ien
	and #($ff - $02)
	sta VERA_ien
.endmacro

;=================================================
; VERA_END_VBLANK_IRQ
;   Reset the Vera IRQ flag so that it generates interrupts.
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro VERA_END_VBLANK_IRQ
	lda #$1
	sta VERA_isr
.endmacro


;=================================================
;=================================================
;
;   Alignment
;
;-------------------------------------------------

;=================================================
; VERA_MAP_DATA_ALIGN
;   Align an address to a map data offset
;-------------------------------------------------
.define VERA_MAP_DATA_ALIGN(ADDR)	((ADDR + ($FFFFF - $FFE00)) & $FFE00)

;=================================================
; VERA_TILE_DATA_ALIGN
;   Align an address to a tile data offset
;-------------------------------------------------
.define VERA_TILE_DATA_ALIGN(ADDR)	((ADDR + ($FFFFF - $FF800)) & $FF800)

;=================================================
; VERA_SPRITE_DATA_ALIGN
;   Align an address to a sprite data offset
;-------------------------------------------------
.define VERA_SPRITE_DATA_ALIGN(ADDR)	((ADDR + ($FFFFF - $FFFE0)) & $FFFE0)

.endif ; VERA_INC
