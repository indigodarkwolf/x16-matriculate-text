; File header of encoded BASIC commands to start execution
!macro SYS_HEADER { 
    !byte $0b,$08,$01,$00,$9e,$32,$30,$36,$31,$00,$00,$00
}

!macro SYS_SET_IRQ .address {
    lda #<.address
    sta $0314
    lda #>.address
    sta $0315
}

!macro SYS_END_IRQ {
    PLA
    TAY
    PLA
    TAX
    PLA
    rti
}

; Generic "copy a block of data from A to B" macro
!macro SYS_COPY .src, .dst, .size {
    lda #<.src ;.src to $FC $FB 
    sta $FB
    lda #>.src
    sta $FC
    lda #<.dst ;.dst to $FE $FD
    sta $FD
    lda #>.dst
    sta $FE
    !if .size > $FF {
                    ; If we have at least 1 full page to copy, then include the 
                    ; page copy portion which needs a 5th byte to track the number
                    ; of pages to copy.

        lda #>.size ; number of pages to copy
        sta $FF

        ldy #$00 ; reset y for our loop
@loop:
        lda ($FB),Y ; indirect index source memory address
        sta ($FD),Y ; indirect index dest memory address
        iny
        bne @loop   ; loop until our dest goes over 255

        inc $FC     ; increment high order source memory address
        inc $FE     ; increment high order dest memory address

        dec $FF     ; decrement number of pages remaining
        bne @loop   ; If we still have at least 1 page to copy, go back and copy it
    }
    !if <.size > 0 {
                    ; If we're not copying exactly some number of pages, include
                    ; the "copy the rest of it" section
        ldy #0
        ldx #.size
@loop2:
        lda ($FB),Y
        sta ($FD),Y
        iny
        dex
        bne @loop2
    }
}

; Copy a block of data starting at a source address, 
; to exactly one destination address. because it's memory-mapped IO
; that will auto-increment its own destination.
!macro SYS_STREAM_OUT .src, .dst, .size {
    lda #<.src ;.src to $FC $FB 
    sta $FB
    lda #>.src
    sta $FC

    !if .size > $FF {
                    ; If we have at least 1 full page to copy, then include the 
                    ; page copy portion which needs a 5th byte to track the number
                    ; of pages to copy.

        lda #>.size ; number of pages to copy
        sta $FF

        ldy #$00 ; reset y for our loop
@loop:
        lda ($FB),Y ; indirect index source memory address
        sta .dst
        iny
        bne @loop   ; loop until our dest goes over 255

        inc $FC     ; increment high order source memory address

        dec $FF     ; decrement number of pages remaining
        bne @loop   ; If we still have at least 1 page to copy, go back and copy it
    }
    !if <.size > 0  {
                    ; If we're not copying exactly some number of pages, include
                    ; the "copy the rest of it" section
        ldy #0
        ldx #<.size
@loop2:
        lda ($FB),Y
        sta .dst
        iny
        dex
        bne @loop2
    }
}

; Copy a block of data from exactly one source address, 
; because it's memory-mapped IO that will auto-increment 
; its own source, to a destination starting at some address.
!macro SYS_STREAM_IN .src, .dst, .size {
    lda #<.dst ;.dst to $FE $FD
    sta $FD
    lda #>.dst
    sta $FE

    !if .size > $FF {
                    ; If we have at least 1 full page to copy, then include the 
                    ; page copy portion which needs a 5th byte to track the number
                    ; of pages to copy.

        lda #>.size ; number of pages to copy
        sta $FF

        ldy #$00 ; reset y for our loop
@loop:
        lda .src
        sta ($FD),Y ; indirect index dest memory address
        iny
        bne @loop   ; loop until our dest goes over 255

        inc $FE     ; increment high order dest memory address

        dec $FF     ; decrement number of pages remaining
        bne @loop   ; If we still have at least 1 page to copy, go back and copy it
    }
    !if <.size > 0 {
                    ; If we're not copying exactly some number of pages, include
                    ; the "copy the rest of it" section
        ldy #0
        ldx #.size
@loop2:
        lda .src
        sta ($FD),Y
        iny
        dex
        bne @loop2
    }
}

; Copy a block of data from exactly one source address, 
; because it's memory-mapped IO that will auto-increment 
; its own source, to exactly one destination address,
; because it too is memory-mapped IO.
!macro SYS_STREAM .src, .dst, .size {
    !if .size > $FF {
                    ; If we have at least 1 full page to copy, then include the 
                    ; page copy portion which needs a 5th byte to track the number
                    ; of pages to copy.

        lda #>.size ; number of pages to copy
        sta $FF

        ldy #0 ; reset y for our loop
@loop:
        lda .src
        sta .dst
        iny
        bne @loop   ; loop until our dest goes over 255

        dec $FF     ; decrement number of pages remaining
        bne @loop   ; If we still have at least 1 page to copy, go back and copy it
    }
    !if <.size > 0  {
                    ; If we're not copying exactly some number of pages, include
                    ; the "copy the rest of it" section
        ldy #0
        ldx #<.size
@loop2:
        lda .src
        sta .dst
        iny
        dex
        bne @loop2
    }
}