    .data
in_buf:
    .space 64, 0x0
in_pos:
    .quad 0
out_buf:
    .space 64, 0x0
out_pos:
    .quad 0

    .global inImage, getInt, getText, getChar, getInPos, setInPos, outImage, putInt, putText, putChar, getOutPos, setOutPos
    .text
# Inmatning

# Läs in ny textrad i in_buf, flytta pekare till början av in_buf
inImage:
    pushq %rdi
    pushq %rsi
    pushq %rdx  
    movq $in_buf, %rdi # read into in_buf
    movq $64, %rsi # read max 63 characters
    movq stdin, %rdx # read from standard input
    call fgets
    leaq in_pos, %rdi
    movq $0, (%rdi) # set in_pos to 0
    popq %rdx
    popq %rsi
    popq %rdi
    ret

# Läs tecken från in_buf, tolka som heltal om siffror
# Retur (%rax): heltalet som lästs från in_buf
getInt:
    movq $0, %rax # put total in rax
    movq $0, %rdx
    movq $0, %rcx
    movq in_pos, %rsi
    leaq in_buf, %rdi
    cmpq $63, %rsi
    je getInt_new # pointer at end of buffer
    jmp getInt_space
getInt_new:
    call inImage
    movq in_pos, %rsi
getInt_space:
    cmpb $32, (%rdi, %rsi) # 32 = ' ' ascii
    jne getInt_sign
    cmpq $63, %rsi
    je getInt_end # pointer at end of buffer
    incq %rsi
    jmp getInt_space
getInt_sign:
    cmpb $45, (%rdi, %rsi) # 45 = '-' ascii
    je getInt_neg
    cmpb $43, (%rdi, %rsi) # 43 = '+' ascii
    je getInt_pos
    jmp getInt_num # no sign
getInt_neg:
    movq $1, %rdx # flag negative
    cmpq $63, %rsi # pointer at end of buffer
    je getInt_end
    incq %rsi
    jmp getInt_num
getInt_pos:
    cmpq $63, %rsi
    je getInt_end # pointer at end of buffer
    incq %rsi
getInt_num:
    movb (%rdi, %rsi), %cl
    cmpb $48, %cl
    jl getInt_end # less than '0' ascii
    cmpb $57, %cl
    jg getInt_end # greater than '9' ascii
    subq $48, %rcx # ascii number -> int , '0' = 48 ascii
    imulq $10, %rax
    addq %rcx, %rax # add the number to the total
    cmpq $63, %rsi
    je getInt_end # pointer at end of buffer
    incq %rsi
    jmp getInt_num
getInt_end:
    cmpq $1, %rdx
    jne getInt_ret
    negq %rax
getInt_ret:
    movq %rsi, in_pos
    ret

# Kopiera max %rsi tecken från in_buf till adress %rdi
# Parameter 1 (%rdi): adress att kopiera till
# Parameter 2 (%rsi): maximalt antal tecken att läsa
# Retur (%rax): antal lästa tecken
getText:
    movq $0, %rax # number of characters read
    movq $0, %r8 # current character
    movq in_pos, %rdx
    leaq in_buf, %rcx
    cmpq $63, %rdx
    je getText_new # pointer at end of buffer
    jmp getText_text
getText_new:
    call inImage
    movq in_pos, %rdx
getText_text:
    cmpq %rsi, %rax
    je getText_end # max characters read
    movb (%rcx, %rdx), %r8b
    cmpb $0, %r8b
    je getText_end # found null
    movb %r8b, (%rdi, %rax)
    incq %rax
    cmpq $63, %rdx
    je getText_end # at end of buffer
    incq %rdx
    jmp getText_text
getText_end:
    movb $0, 1(%rdi, %rax) # put null at end of string
    movq %rdx, in_pos
    ret

# Läs ett tecken från in_buf
# Retur (%rax): inläst tecken
getChar:
    xorq %rax, %rax # zero rax
    movq in_pos, %rsi
    leaq in_buf, %rdi
    cmpq $63, %rsi
    je getChar_new # pointer at end of buffer
    jmp getChar_char
getChar_new:
    call inImage
    movq in_pos, %rsi
getChar_char:
    movb (%rdi, %rsi), %al
    incq %rsi
getChar_end:
    movq %rsi, in_pos
    ret

# Läs aktuell position i in_buf
# Retur (%rax): index i in_buf (värde på in_pos)
getInPos:
    movq in_pos, %rax
    ret

# Ändra position i in_buf
# Parameter (%rdi): nytt index i in_buf (nytt värde på in_pos)
setInPos:
    cmpq $0, %rdi
    jle setInPos_zero
    cmpq $63, %rdi
    jge setInPos_max
    movq %rdi, %rax
    jmp setInPos_end
setInPos_zero:
    movq $0, %rax
    jmp setInPos_end
setInPos_max:
    movq $63, %rax
    jmp setInPos_end
setInPos_end:
    movq %rax, in_pos
    ret

# Utmatning

# Skriv ut inehhållet i out_buf med puts, flytta out_pos till början av out_buf
# Kallas om utmatningsfunktion når slutet av out_buf
outImage:
    pushq %rdi
    pushq %rsi
    pushq $0
    leaq out_buf, %rdi
    call puts
    movq $0, %rdi
    movq %rdi, out_pos
    popq %rsi
    popq %rsi
    popq %rdi
    ret

# Lägg tal i out_buf
# Parameter (%rdi): tal som ska läggas i out_buf
putInt:
    pushq %rbp
    leaq out_buf, %r8
    movq out_pos, %r9
    movq $10, %rsi # integer base, divide by 10
    xorq %rdx, %rdx
    movq $0, %rcx # count numbers
    movq $0, %rbp
    cmpq $0, %rdi
    jl putInt_neg
    movq %rdi, %rax # [%rdx]:[%rax] = 0...0:[%rdi]
    jmp putInt_div
putInt_neg:
    negq %rdi
    movq %rdi, %rax
    movq $1, %rbp # flag negative
putInt_div: # idivq -> täljare %rdx:%rax, rest i %rdx, kvot i %rax
    idivq %rsi # -> %rdx = last digit
    pushq %rdx # push on stack to get digits in right order
    incq %rcx
    cmpq $0, %rax
    je putInt_sign
    xorq %rdx, %rdx
    jmp putInt_div
putInt_sign:
    movq %rcx, %rdi
    cmpq $1, %rbp
    jne putInt_len
    addq %r9, %rdi
    addq $1, %rdi
    cmpq $62, %rdi
    jg putInt_new
    jmp putInt_min
putInt_new:
    call outImage
    movq out_pos, %r9
    cmpq $1, %rbp
    je putInt_min
    jmp putInt_str
putInt_len:
    movq %rcx, %rdi
    addq %r9, %rdi
    cmpq $62, %rdi
    jg putInt_new # number does not fit in out_buf
    jmp putInt_str
putInt_min:
    movq $45, (%r8, %r9) # put '-' in out_buf
    incq %r9
putInt_str:
    cmpq $0, %rcx
    je putInt_end
    popq %rdx
    addq $48, %rdx
    movb %dl, (%r8, %r9)
    decq %rcx
    incq %r9
    jmp putInt_str
putInt_end:
    movb $0, (%r8, %r9) # null-termination
    #incq %r9
    movq %r9, out_pos
    popq %rbp
    ret

# Lägg textsräng från en buffert i out_buf
# Parameter (%rdi): adress till buffert att läsa från
putText:
    movq out_pos, %rsi
    leaq out_buf, %rdx
    movq $0, %rcx # characters read
    xorq %r8, %r8
    movq $0, %r9 # string length
putText_len:
    movb (%rdi, %r9), %r8b
    incq %r9
    cmpb $0, %r8b
    je putText_check_len
    jmp putText_len
putText_check_len:
    addq %rsi, %r9
    cmpq $63, %r9
    jg putText_new
    jmp putText_text
putText_new:
    call outImage
    movq out_pos, %rsi
putText_text:
    movb (%rdi, %rcx), %r8b
    movb %r8b, (%rdx, %rsi)
    cmpb $0, %r8b
    je putText_end # found null
    incq %rsi
    incq %rcx
    jmp putText_text
putText_end:
    movq %rsi, out_pos
    ret

# Lägg ett tecken i out_buf
# Parameter (%rdi): tecken att lägga i out_buf
putChar:
    movq out_pos, %rsi
    leaq out_buf, %rdx
    cmpq $63, %rsi
    je putChar_new
    jmp putChar_char
putChar_new:
    call outImage
    movq out_pos, %rsi
putChar_char:
    movb %dil, (%rdx, %rsi)
    incq %rsi
putChar_end:
    movq %rsi, out_pos
    ret

# Läs aktuell position i out_buf
# Retur (%rax): position i out_buf (out_pos)
getOutPos:
    movq out_pos, %rax
    ret

# Ändra position i out_buf
# Parameter (%rdi): nytt index i out_buf (nytt värde på out_pos)
setOutPos:
    cmpq $0, %rdi
    jle setOutPos_zero
    cmpq $63, %rdi
    jge setOutPos_max
    movq %rdi, %rax
    jmp setOutPos_end
setOutPos_zero:
    movq $0, %rax
    jmp setOutPos_end
setOutPos_max:
    movq $63, %rax
    jmp setOutPos_end
setOutPos_end:
    movq %rax, out_pos
    ret
