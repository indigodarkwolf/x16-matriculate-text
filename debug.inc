.ifndef DEBUG_INC
DEBUG_INC=1

; This is only good for .code segment stuff.
; If this provides warnings or errors, it's because you used it outside of .code
;
.macro DEBUG_LABEL name
    .out .sprintf("%s: $%04x", .string(name), $080d + (* - ::start))
.endmacro

.endif ; DEBUG_INC
