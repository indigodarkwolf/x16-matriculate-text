.ifndef SYSTEM_INC
SYSTEM_INC=1

;=================================================
;=================================================
; 
;   IRQ Handling
;
;-------------------------------------------------

;=================================================
; SYS_SET_IRQ
;   Set where the kernal should jump to after
;   its own interrupt handling.
;-------------------------------------------------
; INPUTS:   address    Label or address of IRQ handler
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro SYS_SET_IRQ address
    lda #<address
    sta $0314
    lda #>address
    sta $0315
.endmacro

;=================================================
; SYS_END_IRQ
;   Restore registers and return control to 
;   interrupted process.
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A, X, Y
; 
.macro SYS_END_IRQ
    ply
    plx
    pla
    rti
.endmacro

;=================================================
;=================================================
; 
;   Random number generation
;
;-------------------------------------------------

;=================================================
; SYS_RAND_SEED
;   Seed the PRNG implementation with the selected
;   values.
;-------------------------------------------------
; INPUTS:   (none)
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro SYS_RAND_SEED v0, v1, v2
    lda #v0
    sta Sys_rand_mem
    lda #v1
    sta Sys_rand_mem+1
    lda #v2
    sta Sys_rand_mem+2
.endmacro

;=================================================
;=================================================
; 
;   Copy macros
;
;-------------------------------------------------

;=================================================
; SYS_COPY
;   Generic "copy a block of data from A to B" macro
;-------------------------------------------------
; INPUTS:   src    Source address
;           dst    Destination address
;           size   Number of bytes to copy
;
;-------------------------------------------------
; MODIFIES: A, X, Y, $FB-$FF
; 
.macro SYS_COPY src, dst, size
    lda #<src ;src to $FC $FB 
    sta $FB
    lda #>src
    sta $FC
    lda #<dst ;dst to $FE $FD
    sta $FD
    lda #>dst
    sta $FE
    .if size > $FF
                    ; If we have at least 1 full page to copy, then include the 
                    ; page copy portion which needs a 5th byte to track the number
                    ; of pages to copy.

        lda #>size ; number of pages to copy
        sta $FF

        ldy #$00 ; reset y for our loop

:       lda ($FB),Y ; indirect index source memory address
        sta ($FD),Y ; indirect index dest memory address
        iny
        bne :-      ; loop until our dest goes over 255

        inc $FC     ; increment high order source memory address
        inc $FE     ; increment high order dest memory address

        dec $FF     ; decrement number of pages remaining
        bne :-      ; If we still have at least 1 page to copy, go back and copy it
    .endif
    .if <size > 0
                    ; If we're not copying exactly some number of pages, include
                    ; the "copy the rest of it" section
        ldy #0
        ldx #<size

:       lda ($FB),Y
        sta ($FD),Y
        iny
        dex
        bne :-
    .endif
.endmacro

;=================================================
; SYS_STREAM_OUT
;   Copy a block of data starting at a source address, 
;   to exactly one destination address, because it's 
;   memory-mapped IO that will auto-increment its own 
;   destination.
;-------------------------------------------------
; INPUTS:   src    Source address
;           dst    Destination address
;           size   Number of bytes to copy
;
;-------------------------------------------------
; MODIFIES: A, X, Y, $FB-$FC, $FF
; 
.macro SYS_STREAM_OUT src, dst, size
    lda #<src ;src to $FC $FB 
    sta $FB
    lda #>src
    sta $FC

    .if size > $FF
                    ; If we have at least 1 full page to copy, then include the 
                    ; page copy portion which needs a 5th byte to track the number
                    ; of pages to copy.

        lda #>size ; number of pages to copy
        sta $FF

        ldy #$00 ; reset y for our loop

:       lda ($FB),Y ; indirect index source memory address
        sta dst
        iny
        bne :-      ; loop until our dest goes over 255

        inc $FC     ; increment high order source memory address

        dec $FF     ; decrement number of pages remaining
        bne :-      ; If we still have at least 1 page to copy, go back and copy it
    .endif
    .if <size > 0
                    ; If we're not copying exactly some number of pages, include
                    ; the "copy the rest of it" section
        ldy #0
        ldx #<size

:       lda ($FB),Y
        sta dst
        iny
        dex
        bne :-
    .endif
.endmacro

;=================================================
; SYS_STREAM_IN
;   Copy a block of data from exactly one source address, 
;   because it's memory-mapped IO that will auto-increment 
;   its own source, to a destination starting at some address.
;-------------------------------------------------
; INPUTS:   src    Source address
;           dst    Destination address
;           size   Number of bytes to copy
;
;-------------------------------------------------
; MODIFIES: A, X, Y, $FD-$FF
; 
.macro SYS_STREAM_IN src, dst, size
    lda #<dst ;dst to $FE $FD
    sta $FD
    lda #>dst
    sta $FE

    .if size > $FF
                    ; If we have at least 1 full page to copy, then include the 
                    ; page copy portion which needs a 5th byte to track the number
                    ; of pages to copy.

        lda #>size ; number of pages to copy
        sta $FF

        ldy #$00 ; reset y for our loop

:       lda src
        sta ($FD),Y ; indirect index dest memory address
        iny
        bne :-      ; loop until our dest goes over 255

        inc $FE     ; increment high order dest memory address

        dec $FF     ; decrement number of pages remaining
        bne :-      ; If we still have at least 1 page to copy, go back and copy it
    .endif
    .if <size > 0
                    ; If we're not copying exactly some number of pages, include
                    ; the "copy the rest of it" section
        ldy #0
        ldx #<size

:       lda src
        sta ($FD),Y
        iny
        dex
        bne :-
    .endif
.endmacro

;=================================================
; SYS_STREAM
;   Copy a block of data from exactly one source address, 
;   because it's memory-mapped IO that will auto-increment 
;   its own source, to exactly one destination address,
;   because it too is memory-mapped IO.
;-------------------------------------------------
; INPUTS:   src    Source address
;           dst    Destination address
;           size   Number of bytes to copy
;
;-------------------------------------------------
; MODIFIES: A, X, Y, $FF
; 
.macro SYS_STREAM src, dst, size
    .if size > $FF
                    ; If we have at least 1 full page to copy, then include the 
                    ; page copy portion which needs a 5th byte to track the number
                    ; of pages to copy.

        lda #>size ; number of pages to copy
        sta $FF

        ldy #0 ; reset y for our loop

-       lda src
        sta dst
        iny
        bne -       ; loop until our dest goes over 255

        dec $FF     ; decrement number of pages remaining
        bne -       ; If we still have at least 1 page to copy, go back and copy it
    .endif
    .if <size > 0
                    ; If we're not copying exactly some number of pages, include
                    ; the "copy the rest of it" section
        ldy #0
        ldx #<size

-       lda src
        sta dst
        iny
        dex
        bne -
    .endif
.endmacro

.endif
