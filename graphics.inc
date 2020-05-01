.ifndef GRAPHICS_INC
GRAPHICS_INC=1

;=================================================
; GRAPHICS_FADE_OUT
;   Fade out graphics to black
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A, X, Y, $FB-$FF
; 
.macro GRAPHICS_FADE_OUT
    jsr graphics_fade_out
.endmacro

;=================================================
; GRAPHICS_FADE_IN
;   Fade in graphics to a set of palette colors
;-------------------------------------------------
; INPUTS:   .palette_data   Final desired color data
;           .num_colors     Number of colors in the above
;
;-------------------------------------------------
; MODIFIES: A, X, Y, $FB-$FF
; 
.macro GRAPHICS_FADE_IN palette_data, num_colors
    lda #<palette_data
    sta $FB
    lda #>palette_data
    sta $FC
    lda #num_colors
    sta $FD

    jsr graphics_fade_in
.endmacro

.endif ; GRAPHICS_INC