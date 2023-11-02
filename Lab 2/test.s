.data
Nums:
    .byte 0b00111111 // 0
    .byte 0b00000110 // 1
    .byte 0b01011011 // 2
    .byte 0b01001111 // 3
    .byte 0b01100110 // 4
    .byte 0b01101101 // 5
    .byte 0b01111101 // 6
    .byte 0b00000111 // 7
    .byte 0b01111111 // 8
    .byte 0b01101111 // 9
    .byte 0b01110111 // A
    .byte 0b01111100 // b
    .byte 0b00111001 // C
    .byte 0b01011110 // d
    .byte 0b01111001 // E
    .byte 0b01110001 // F


.global _start
.text
/*_start:
    MOV r0, #0b0011
    ANDS r1, r0, #0b0000
    BEQ not_equal
equal:
    B equal

not_equal:
    B not_equal
    */

_start:
    LDR r0, =Nums
    MOV r1, #0
    LDRB r2, [r0, #3]
CMP_Loop:
    LDRB r3, [r0]
    CMP r2, r3
    BEQ _Continue
    ADD r1, r1, #1
    ADD r0, r0, #1
    B CMP_Loop
_Continue:
    B _Continue
