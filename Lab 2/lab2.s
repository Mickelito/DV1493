/******************************************************************************
    Define symbols
******************************************************************************/
// Proposed interrupt vector base address
.equ INTERRUPT_VECTOR_BASE, 0x00000000

// Proposed stack base addresses
.equ SVC_MODE_STACK_BASE, 0x3FFFFFFF - 3 // set SVC stack to top of DDR3 memory
.equ IRQ_MODE_STACK_BASE, 0xFFFFFFFF - 3 // set IRQ stack to A9 onchip memory

// GIC Base addresses
.equ GIC_CPU_INTERFACE_BASE, 0xFFFEC100
.equ GIC_DISTRIBUTOR_BASE, 0xFFFED000

// Other I/O device base addresses

.equ PUSH_BUTTONS_BASE, 0xff200050
.equ DISPLAYS_BASE, 0xff200020

/* Data section, for global data/variables if needed. */
.data

// Bytes needed to display all hexadecimal numbers
Display_Nums:
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

/* Code section */
.text

/*****************************************************************************
    Interrupt Vector
*****************************************************************************/
.org INTERRUPT_VECTOR_BASE  // Address of interrupt vector
// Write your Interrupt Vector here

_int_vector:
    B _start
    B Undef_Handl
    B Softw_Handl
    B Pre_Abort_Handl
    B Data_Abort_Handl
    .word 0
    B IRQ_Handl
    B FIQ_Handl

.global _start
/*****************************************************************************************************
    System startup.
    ---------------

On system startup some basic configuration is needed, in this case:
    1. Setup stack pointers for each used processor mode
    2. Configure the Generic Interrupt Controller (GIC). Use the given help function CONFIG_GIC!
    3. Configure the used I/O devices and enable them for interrupt
    4. Change to the processor mode for the main program loop (for example supervisor mode)
    5. Enable the processor interrupts (IRQ in our case)
    6. Start running the main program loop

 Your program will use two different processor modes when running:
 -Supervisor mode (SVC) when running the main program loop. Also default mode on reset.
 -IRQ mode when handling IRQ interrupts

 Changing processor mode and/or enabling/disabling interrupts control bits
 is done by updating the program status register (CPSR) control bits [7:0]
 
 The CPSR register holds the processor mode control bits [4:0]:
   10011 - Supervisor mode (SVC)
   10010 - IRQ mode
 The CPSR register also holds the following interrupt control bits:
   bit [7] IRQ enable/disable. 0 means IRQ enabled, 1 means IRQ disabled
   bit [6] FIQ enable/disable. 0 means FIQ enabled, 1 means FIQ disabled
 Bit [5] of the CPSR register should always be 0 in this case!

 The instruction "MSR CPSR_c, #0b___" can be used to modify the CPSR control bits.
 Example: "MSR CPSR_c #0b11011111" diables both interrupts and sets processor mode to "system mode".

 The instruction "MRS CPSR_c, R__" can be used to read the CPSR control bits into a register.
 Example: "MRS CPSR_c R0" reads CPSR control bits for interrupts and processor mode into register R0.
*****************************************************************************************************/
// Write your system startup code here. Follow the steps in the description above!

_start:
    LDR sp, =SVC_MODE_STACK_BASE
    MOV r0, #0b11010010
    MSR CPSR_c, r0 // IRQ mode, IRQ/FIQ disabled
    LDR sp, =IRQ_MODE_STACK_BASE
    MOV r0, #0b11010011
    MSR CPSR_c, r0 // SVC mode, IRQ/FIQ disabled
    MOV r0, #73
    BL CONFIG_GIC
    BL CONFIG_PUSH_BUTTONS
    MOV r0, #0b01010011
    MSR CPSR_c, r0 // SVC mode, IRQ enabled, FIQ disabled

    B main_loop

CONFIG_PUSH_BUTTONS:
    PUSH {r4, lr}
    LDR r0, =PUSH_BUTTONS_BASE
    MOV r4, #0xF // 0b1111, set push buttons interrupt mask bits to allow interrupts
    STR r4, [r0, #8] // 0xFF200058, address of mask bits
    POP {r4, pc}



/*******************************************************************
 Main program
*******************************************************************/
// Write code for your main program here

main_loop:
    B main_loop


/*******************************************************************
    IRQ Interrupt Service Routine (ISR)
    -----------------------------------

The ISR  should:
    1. Read and acknowledge the interrupt at the GIC.The GIC returns the interrupt ID.
    2. Check which device raised the interrupt
    3. Handle the specific device interrupt
    4. Acknowledge the specific device interrupt
    5. Inform the GIC that the interrupt is handled
    6. Return from interrupt

The following GIC CPU interface registers should be used (both v2/v1 alternative names showed below):
    -Interrupt Acknowledge Register (GICC_IAR/ICCIAR)
        Reading this register returns the interrupt ID corresponding to the I/O device.
        This read acts as an acknowledge for the interrupt.
    -End of Interrupt Register (GICC_EOIR/ICCEOIR)
        Writing the corresponding interrupt ID to this register informs the GIC that
        the interrupt is handled and clears the interrupt from the GIC CPU interface.

How to handle a specific interrupt depends on the I/O device generating the interrupt.
Read the documentation for your I/O device carefully!
Every I/O device has a base address. Usually the I/O device has several registers
(32 bit words on a 32 bit architecture) starting from the base address. Each register, and 
often every bit in these registers, have a certain function and meaning. Look out for 
how to read and/write to your device and also how to enable/disable interrupts from the device.

Returning from an interrupt is done by using a special system level instruction:
    SUBS PC, LR, #CONSTANT
    where the CONSTANT depends on the specific interrupt (4 for IRQ).

Finally, don't forget to push/pop registers used by this interrupt routine!

*******************************************************************/
// Write code for your IRQ interrupt service routine here

IRQ_Handl:
    PUSH {r0-r4, lr}
    LDR r2, =GIC_CPU_INTERFACE_BASE
    LDR r1, [r2, #0xC] // get interrupt ID from ICCIAR register of gic cpu interface

    CMP r1, #73 // check for push button interrupt
    BNE FINISH_INT

    BL Push_Button_Handl

FINISH_INT:
    ADD r3, r2, #0x10
    STR r1, [r3] // write interrupt ID to ICCEOIR
    POP {r0-r4, lr}
    SUBS PC, LR, #4


/*************
Handle the result of a button being pushed
    Button 1: '+', increase number on display
    Button 0: '-', decrease number on display
*********** */
Push_Button_Handl:
    PUSH {r0-r4, lr}
    LDR r0, =DISPLAYS_BASE
    LDRB r2, [r0] // read bits of currently displayed number
    MOV r1, #0 // index/number
    LDR r0, =Display_Nums

// loop through Display_Nums array to find current number
// exit loop with currently displayed number in r1
    CMP r2, #0 // nothing displayed, put up a 0
    MOVEQ r1, #15
    BEQ Num_Found
Find_Num_Loop:
    LDRB r3, [r0] // byte in index/number
    CMP r2, r3 // is Display_Nums[i] = currently displayed number
    BEQ Num_Found
    ADD r1, r1, #1 // increase index/number
    ADD r0, r0, #1 // check next byte
    B Find_Num_Loop

Num_Found:
    LDR r0, =PUSH_BUTTONS_BASE
    LDR r2, [r0, #0xC] // push buttons edgecapture bits
    MOV r3, #0b1111
    STR r3, [r0, #0xC] // clear interrupt
    LDR r0, =DISPLAYS_BASE
    LDR r4, =Display_Nums

Check_Button_0:
    ANDS r3, r2, #0b0001
    BEQ Check_Button_1
    // decrease number
    CMP r1, #0
    MOVEQ  r1, #16
    SUB r1, r1, #1
    LDRB r2, [r4, r1]
    STR r2, [r0]
    B Push_Button_Handl_Done

Check_Button_1:
    ANDS r3, r2, #0b0010
    BEQ Other_Button
    // increase number
    CMP r1, #15
    SUBEQ r1, r1, #16
    ADD r1, r1, #1
    LDRB r2, [r4, r1]
    STR r2, [r0]
    B Push_Button_Handl_Done

Other_Button:
    B Push_Button_Handl_Done

Push_Button_Handl_Done:
    POP {r0-r4, pc}

/****************************************************************************
    Other Interrupt Service Routines (except for IRQ)
    -------------------------------------------------
    
Other interrupts are unused in this program, but should at least be defined.
These interrupt routines can just "idle" if ever called...

****************************************************************************/
// Write code for your other interrupt service routines here

// all infinite loops
Undef_Handl:
    B Undef_Handl

Softw_Handl:
    B Softw_Handl

Pre_Abort_Handl:
    B Pre_Abort_Handl

Data_Abort_Handl:
    B Data_Abort_Handl

FIQ_Handl:
    B FIQ_Handl

/*******************************************************************
    HELP FUNCTION!
    --------------

Configures the Generic Interrupt Controller (GIC)
    Arguments:  R0: Interrupt ID

*******************************************************************/
CONFIG_GIC:
    PUSH {LR}
    /* To configure a specific interrupt ID:
    * 1. set the target to cpu0 in the ICDIPTRn register
    * 2. enable the interrupt in the ICDISERn register */
    /* CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1)); */
    MOV R1, #1 // this field is a bit-mask; bit 0 targets cpu0
    BL CONFIG_INTERRUPT
    /* configure the GIC CPU Interface */
    LDR R0, =GIC_CPU_INTERFACE_BASE // base address of CPU Interface, 0xFFFEC100
    /* Set Interrupt Priority Mask Register (ICCPMR) */
    LDR R1, =0xFFFF // enable interrupts of all priorities levels
    STR R1, [R0, #0x04]
    /* Set the enable bit in the CPU Interface Control Register (ICCICR).
    * This allows interrupts to be forwarded to the CPU(s) */
    MOV R1, #1
    STR R1, [R0]
    /* Set the enable bit in the Distributor Control Register (ICDDCR).
    * This enables forwarding of interrupts to the CPU Interface(s) */
    LDR R0, =GIC_DISTRIBUTOR_BASE   // 0xFFFED000
    STR R1, [R0]
    POP {PC}


/*********************************************************************
    HELP FUNCTION!
    --------------

Configure registers in the GIC for an individual Interrupt ID.

We configure only the Interrupt Set Enable Registers (ICDISERn) and
Interrupt Processor Target Registers (ICDIPTRn). The default (reset)
values are used for other registers in the GIC.

Arguments:  R0 = Interrupt ID, N
            R1 = CPU target

*********************************************************************/
CONFIG_INTERRUPT:
PUSH {R4-R5, LR}
/* Configure Interrupt Set-Enable Registers (ICDISERn).
* reg_offset = (integer_div(N / 32) * 4
* value = 1 << (N mod 32) */
LSR R4, R0, #3 // calculate reg_offset
BIC R4, R4, #3 // R4 = reg_offset
LDR R2, =0xFFFED100 // Base address of ICDISERn
ADD R4, R2, R4 // R4 = address of ICDISER
AND R2, R0, #0x1F // N mod 32
MOV R5, #1 // enable
LSL R2, R5, R2 // R2 = value
/* Using the register address in R4 and the value in R2 set the
* correct bit in the GIC register */
LDR R3, [R4] // read current register value
ORR R3, R3, R2 // set the enable bit
STR R3, [R4] // store the new register value
/* Configure Interrupt Processor Targets Register (ICDIPTRn)
* reg_offset = integer_div(N / 4) * 4
* index = N mod 4 */
BIC R4, R0, #3 // R4 = reg_offset
LDR R2, =0xFFFED800 // Base address of ICDIPTRn
ADD R4, R2, R4 // R4 = word address of ICDIPTR
AND R2, R0, #0x3 // N mod 4
ADD R4, R2, R4 // R4 = byte address in ICDIPTR
/* Using register address in R4 and the value in R2 write to
* (only) the appropriate byte */
STRB R1, [R4]
POP {R4-R5, PC}


.end
