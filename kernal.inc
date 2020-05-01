.ifndef KERNAL_INC
KERNAL_INC=1

;=================================================
;=================================================
; 
;   Kernal calls
;
;-------------------------------------------------
;
; $FF90: SETMSG – set verbosity 
; $FFB7: READST – return status byte 
; $FFBA: SETLFS – set LA, FA and SA 
; $FFBD: SETNAM – set filename 
; $FFC0: OPEN – open a channel 
; $FFC3: CLOSE – close a channel 
; $FFC6: CHKIN – set channel for character input 
; $FFC9: CHKOUT – set channel for character output 
; $FFCC: CLRCHN – restore character I/O to screen/keyboard 
; $FFCF: BASIN – get character 
; $FFD2: BSOUT – write character 
; $FFD5: LOAD – load a file into memory 
; $FFD8: SAVE – save a file from memory 
; $FFE7: CLALL – close all channels

;=================================================
; KERNAL_SETMSG
;   Set system error display switch at memory address $009D.
;-------------------------------------------------
; INPUTS:   value    Switch value.
;
;-------------------------------------------------
; OUTPUTS:  (none)
;-------------------------------------------------
; MODIFIES: A
; 
.macro KERNAL_SETMSG value
    lda #value
    jsr $FF90
.endmacro

;=================================================
; KERNAL_READST
;   Fetch status of current input/output device, value of ST variable. (For RS232, status is cleared.)
;-------------------------------------------------
; INPUTS:   (none)
;-------------------------------------------------
; OUTPUTS:  value    Device status.
;
;-------------------------------------------------
; MODIFIES: A
; 
.macro KERNAL_READST value
    jsr $FFB7
.endmacro

;=================================================
; KERNAL_SETLFS
;   Set file parameters
;-------------------------------------------------
; INPUTS:   logical_num         Logical number
;           device_num          Device number
;           secondary_address   Secondary address
;
;-------------------------------------------------
; OUTPUTS:  (none)
;-------------------------------------------------
; MODIFIES: A, X, Y
; 
.macro KERNAL_SETLFS logical_num, device_num, secondary_address
    lda #logical_num
    ldx #device_num
    ldy #secondary_address
    jsr $FFBA
.endmacro

;=================================================
; KERNAL_SETNAM
;   Set file name parameters
;-------------------------------------------------
; INPUTS:   name_len    Length of filename
;           name_addr   Address of filename in memory
;
;-------------------------------------------------
; OUTPUTS:  (none)
;-------------------------------------------------
; MODIFIES: A, X, Y
; 
.macro KERNAL_SETNAM name_len, name_addr
    lda #name_len
    ldx #<name_addr
    ldy #>name_addr
    jsr $FFBD
.endmacro

;=================================================
; KERNAL_OPEN
;   Open file. (Must call SETLFS and SETNAM beforehands.)
;-------------------------------------------------
; INPUTS:   (none)
;-------------------------------------------------
; OUTPUTS:  (none)
;-------------------------------------------------
; MODIFIES: A, X, Y
; 
.macro KERNAL_OPEN
    jsr $FFC0
.endmacro

;=================================================
; KERNAL_CLOSE
;   Close file.
;-------------------------------------------------
; INPUTS:   logical_num     Logical number
;
;-------------------------------------------------
; OUTPUTS:  (none)
;-------------------------------------------------
; MODIFIES: A, X, Y
; 
.macro KERNAL_CLOSE logical_num
    lda #logical_num
    jsr $FFC3
.endmacro

;=================================================
; KERNAL_CHKIN
;   Define file as default input. (Must call OPEN beforehands.)
;-------------------------------------------------
; INPUTS:   logical_num     Logical number
;
;-------------------------------------------------
; OUTPUTS:  (none)
;-------------------------------------------------
; MODIFIES: A, X
; 
.macro KERNAL_CHKIN logical_num
    ldx #logical_num
    jsr $FFC6
.endmacro

;=================================================
; KERNAL_CHKOUT
;   Define file as default input. (Must call OPEN beforehands.)
;-------------------------------------------------
; INPUTS:   logical_num     Logical number
;
;-------------------------------------------------
; OUTPUTS:  (none)
;-------------------------------------------------
; MODIFIES: A, X
; 
.macro KERNAL_CHKOUT logical_num
    ldx #logical_num
    jsr $FFC9
.endmacro

;=================================================
; KERNAL_CLRCHN
;   Close default input/output files (for serial bus, send UNTALK and/or UNLISTEN); restore default input/output to keyboard/screen.
;-------------------------------------------------
; INPUTS:   (none)
;-------------------------------------------------
; OUTPUTS:  (none)
;-------------------------------------------------
; MODIFIES: A, X
; 
.macro KERNAL_CLRCHN
    jsr $FFCC
.endmacro

;=================================================
; KERNAL_BASIN
;   ???
;-------------------------------------------------
; INPUTS:   (none)
;-------------------------------------------------
; OUTPUTS:  (none)
;-------------------------------------------------
; MODIFIES: (none)
; 
.macro KERNAL_BASIN
    .error "KERNAL_BASIN in not implemented"
    brk
.endmacro

;=================================================
; KERNAL_BSOUT
;   ???
;-------------------------------------------------
; INPUTS:   (none)
;-------------------------------------------------
; OUTPUTS:  (none)
;-------------------------------------------------
; MODIFIES: (none)
; 
.macro KERNAL_BSOUT
    .error "KERNAL_BSOUT in not implemented"
    brk
.endmacro

;=================================================
; KERNAL_LOAD
;   Load or verify file. (Must call SETLFS and SETNAM beforehands.)
;-------------------------------------------------
; INPUTS:   verify  Do verify
;           addr    Load address (if secondary address = 0)
;-------------------------------------------------
; OUTPUTS:  Carry   0 = No errors, 1 = Error; A = KERNAL error code (if Carry = 1); 
;           X/Y     Address of last byte loaded/verified (if Carry = 0).
;-------------------------------------------------
; MODIFIES: A, X, Y
; 
.macro KERNAL_LOAD  verify, addr
    lda #verify
    ldx #<addr
    ldy #>addr
    jsr $FFD5
.endmacro

;=================================================
; KERNAL_SAVE
;   Save file. (Must call SETLFS and SETNAM beforehands.)
;-------------------------------------------------
; INPUTS:   zp_ptr          Address of zero page register holding start address of memory area to save
;           end_address     End address of memory area.
;-------------------------------------------------
; OUTPUTS:  Carry:  0 = No errors, 1 = Error; 
;           A:      KERNAL error code (if Carry = 1).
;-------------------------------------------------
; MODIFIES: A, X, Y
; 
.macro KERNAL_SAVE zp_ptr, end_address
    lda #zp_ptr
    ldx #<(end_address+1)
    ldy #>(end_address+1)
    jsr $FFD8
.endmacro

;=================================================
; KERNAL_CLALL
;   Clear file table; call CLRCHN.
;-------------------------------------------------
; INPUTS:   (none)
;-------------------------------------------------
; OUTPUTS:  (none)
;-------------------------------------------------
; MODIFIES: A, X; 
.macro KERNAL_CLALL
    jsr $FFE7
.endmacro

.endif ; KERNAL_INC