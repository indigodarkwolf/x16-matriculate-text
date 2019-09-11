; !ifdef SYSTEM_ASM !eof
; SYSTEM_ASM=1

;=================================================
; sys_rand
;   Generate an 8-bit random number.
;-------------------------------------------------
; INPUTS:   Sys_rand_mem
;
;-------------------------------------------------
; MODIFIES: A, X, Sys_rand_mem
; 

sys_rand:
    ldx #8
    lda Sys_rand_mem
-   asl
    rol Sys_rand_mem+1
    rol Sys_rand_mem+2
    bcc +
    eor #$1B
+   dex
    bne -
    sta Sys_rand_mem
    cmp #0
    rts
