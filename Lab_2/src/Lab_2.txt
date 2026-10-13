.section .text
.align 2
.globl _start

// -------------------------------------------------------------------------------------
// Name:        Lab_2.S
// Purpose:     This code will convert a string of ASCII chracters into Morse code
//              and flash a single LED (Led Bar LED_7) in Morse code with a time base
//		of approximately 500ms.
// Author:      Julius Olajos
// -------------------------------------------------------------------------------------


_start:

// -------------------------------------------------------------------------------------
// GPIO Control Registers Memory Mapping

    .equ GPIO_BASE_CTRL_ADDR, 0x10012000    // Base address for the GPIO control registers
    .equ GPIO_OUTPUT_EN,      0x08          // address offset for enabling GPIO outputs
    .equ GPIO_OUTPUT_VAL,     0x0C          // Address offset for writing to GPIO outputs
    .equ GPIO_OUTPUT_XOR,     0x40          // Address offset for GPIO Outputs XOR

// -------------------------------------------------------------------------------------
// 8 LEDS, 7 Segment LED Display Pins Register Address Mapping

    .equ GPIO_7SEGLED_PINS, 0x0000023F      // Seven Segment LED Display Pins (7)
    .equ GPIO_LEDBAR_PINS,  0x00FC0C00      // LED Bar Pins (8)
    .equ GPIO_ALL_LED_PINS, 0x00FC0E3F      // All LED Pins (15)
    .equ GPIO_LEDBAR_LED_7, 0x00800000      // LEDBAR LED7
// -------------------------------------------------------------------------------------
// Initialize the GPIO control registers
// -------------------------------------------------------------------------------------

    li t0, GPIO_BASE_CTRL_ADDR          // Load Base Address for GPIO Control Registers
    li t1, GPIO_ALL_LED_PINS            // Load GPIO Register to set GPIO_OUTPUT_EN and GPIO_OUTPUT_XOR registers for all GPIO LED Pins
    sw t1, GPIO_OUTPUT_EN(t0)           // Enable outputs on all GPIO LED Pins
    li t2, 0xFF03F1C0
    sw t2, GPIO_OUTPUT_VAL(t0)          // Set all LED pins to zero to turn off all LEDS.


// Reset s1 to the starting address of the input string

ResetLUT:
    la s1, InputLUT           // assign s1 to the address at label LUT

// Start processing each character byte by byte

NextChar:
    lbu     a0, 0(s1)            // Read a character to convert to Morse
    addi    s1, s1, 1            // point to next value for number of delays, jump by 1 byte
    snez    a1, a0               // If we hit 0 (null at end of the string) then reset to the start of lookup table
    bnez    a1, ProcessChar      // If we have a character process it

    jal ra, DELAY_2000MS
    j   ResetLUT

// Display the converted character to the LED BAR LED_7

ProcessChar:
    jal ra, CHAR2MORSE        // convert ASCII to Morse pattern in a1

    DISPLAY:
        li      t1, 0x8000      // Load 0b1000 0000 0000 0000 to check MSB, 16 bit aligned
        and     t0, a1, t1      // Check if MSB is set
        slli    a1, a1, 1       // Shift a1 register left by one to continue pattern
        li      t1, 0xffff      // Load value where only bits[15:0] are set
        and     a1, a1, t1      // Make the length 16 bits by zeroing bits[31:16]

        beqz    t0, CALL_LED_OFF   // If MSB unset, turn LED off
        jal     ra, LED_ON         // Else turn LED on
        j       DISPLAY_DELAY      // Delay

    CALL_LED_OFF:
        jal ra, LED_OFF

    DISPLAY_DELAY:
        li  a0, 1       // One delay cycle
        jal ra, DELAY   // Call delay

        bnez a1, DISPLAY    // While a1 is not zero, loop the Morse Code display

    jal ra, LED_OFF     // After char displayed, call LED_OFF
    li  a0, 3           // Load three delay cycles
    jal ra, DELAY       // Call delay

    j NextChar          // Go to the NextChar



// Turn the LED On
LED_ON:
    addi sp, sp, -16
    sw ra, 12(sp)

    li t0, GPIO_BASE_CTRL_ADDR  // Load Base Address for GPIO Control Registers
    lw t1, GPIO_OUTPUT_VAL(t0)  // Read GPIO output values into t1
    li t2, GPIO_LEDBAR_LED_7    // Load LED_1 Address into t2 (Bit 11)
    or t1, t2, t1		        // OR the GPIO_LEDBAR_LED_7 to turn LED ON
    sw t1, GPIO_OUTPUT_VAL(t0)	// Store this new value in GPIO output

    lw ra, 12(sp)
    addi sp, sp, 16
    ret

// Turn the LED Off
LED_OFF:
    addi sp, sp, -16
    sw ra, 12(sp)

    li  t0, GPIO_BASE_CTRL_ADDR // Load Base Address for GPIO Control Registers
    lw  t1, GPIO_OUTPUT_VAL(t0) // Read GPIO output values into t1
    li  t2, GPIO_LEDBAR_LED_7   // Load LED_1 Address into t2 (Bit 11)
    not t2, t2                  // Bitwise NOT the GPIO_LEDBAR_LED_7 to retain state of all LEDS except Bit 11
    and t1, t2, t1		        // Bitwise AND the bitwise NOT GPIO_LEDBAR_LED_7 to turn LED OFF
    sw  t1, GPIO_OUTPUT_VAL(t0)	// Store this new value in GPIO output

    lw ra, 12(sp)
    addi sp, sp, 16
    ret

//  Delay Routines

// 16Mhz clock cycle
// 1/16*10^6 s
// Time per cycle is 1/16*10e6 = 6.25e-8
// To get the 500ms delay, 500e-3 / 6.25e-8 = 8,000,000
// We need 8,000,000 instructions to make the 500ms delay
// Adding takes 1 clock cycle and branching takes 1 clock cycle so the loop takes 2 clock cycles per branch
// Divide by 2 for the clock cycles per loop to get counter value, 8,000,000 / 2 = 4,000,000
DELAY_2000MS:
    li a0, 0x4  // Load 4 delay cycles

    DELAY:
        li t1, 0x003D0900   // Load immediate 0x003D0900 or 4,000,000 base 10 into t1 (counter value)
        mul t1, t1, a0      // Multiply the 500ms delay with the number of times to delay, stored in a0

        loop1:
            addi    t1, t1, -1		// Addi instruction takes 1 clock cycle
            bnez    t1, loop1		// Jump back to loop1 and while t1 not zero
                                    // Branch instruction also takes 1 clock cycle

        ret // Return to the calling function once the counter value reaches 0


// Subroutines
// Convert ASCII character to Morse pattern
// Pass ASCII character in a0, output in a1
// Index into MorseLUT must be by steps of 2 bytes

// Convert the ASCII character to Morse Code

CHAR2MORSE:
    addi sp, sp, -16		// Set-up the stack
    sw ra, 12(sp)

    la      t1, MorseLUT    // load address of lookup table into
                            // register t1
    li      t0, 0xFFFFFFBF  // 0xFFBF is -0x41 representing -'A'
    add     t0, a0, t0      // -'A' to the data to get the offset of the character from 'A' in the ascii table
    slli    t0, t0, 1       // Multiply by 2 because index is in halfwords
    add     t1, t1, t0      // add index of character to MorseLUT
                            // address into register t1

    lhu     t0, 0(t1)       // load data stored at address of MorseLUT
                            // plus index into register a1

    ALIGN_LEFT:
        li      t1, 0x8000  // 16 bit align
        and     t1, t0, t1  // Check if MSB is set
        bnez    t1, BREAK   // Break out of loop if MSB is set
        slli    t0, t0, 1   // Shift t0 left if MSB is zero
        j       ALIGN_LEFT  // Loop
    
    BREAK:
        mv a1, t0
        lw ra, 12(sp)		// read stack
        addi sp, sp, 16
        ret

// Data used in the program

.align 2

// Character input string

InputLUT:
    .asciz "PGJQW"


// Morse Code Look Up Table

.align 2
MorseLUT:
    .half 0x17,     0x1D5,  0x75D,  0x75    // A, B, C, D
    .half 0x1,      0x15D,  0x1DD,  0x55    // E, F, G, H
    .half 0x5,      0x1777, 0x1D7,  0x175   // I, J, K, L
    .half 0x77,     0x1D,   0x777,  0x5DD   // M, N, O, P
    .half 0x1DD7,   0x5D,   0x15,   0x7     // Q, R, S, T
    .half 0x57,     0x157,  0x177,  0x757   // U, V, W, X
    .half 0x1D77,   0x775                   // Y, Z

End:
  .end