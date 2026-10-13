.section .text
.globl _start
.align  2

// -------------------------------------------------------------------------------------
// Name:        Lab_1.S
// Purpose:     This code will flash a single LED at an approximate 1 Hz frequency
// Author:      Julius Olajos
// -------------------------------------------------------------------------------------
//
// -------------------------------------------------------------------------------------

_start:

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
.equ GPIO_LEDBAR_LED_1, 0x00000800      // LEDBAR LED1 (Bit 11)
// -------------------------------------------------------------------------------------
// Initialize the GPIO control registers and run the delay loop code
// -------------------------------------------------------------------------------------


    li t0, GPIO_BASE_CTRL_ADDR          // Load Base Address for GPIO Control Registers
    li t1, GPIO_ALL_LED_PINS            // Load GPIO Register to set GPIO_OUTPUT_EN and GPIO_OUTPUT_XOR registers for all GPIO LED Pins
    sw t1, GPIO_OUTPUT_EN(t0)           // Enable outputs on all GPIO LED Pins
    li t2, 0xFF03F1C0
    sw t2, GPIO_OUTPUT_VAL(t0)          // Set all LED pins to zero to turn off all LEDS.

    li t5, GPIO_LEDBAR_LED_1     // Load LED_1 Address into t5 (Bit 11)
    lw t3, GPIO_OUTPUT_VAL(t0)   // Read GPIO output values into t3
    xor t3, t5, t3               // XOR the GPIO output value (all zeroes to the LEDs)
    sw t3, GPIO_OUTPUT_VAL(t0)   // Store this new value in GPIO output register

loop:
                        // 16Mhz clock cycle
                        // 1/16*10^6 s
                        // Time per cycle is 1/16*10e6 = 6.25e-8
                        // To get the 500ms delay, 500e-3 / 6.25e-8 = 8,000,000
                        // We need 8,000,000 instructions to make the 500ms delay
                        // Adding takes 1 clock cycle and branching takes 1 clock cycle so the loop takes 2 clock cycles per branch
						// Divide by 2 for the clock cycles per loop to get counter value, 8,000,000 / 2 = 4,000,000
    li t4, 0x003D0900   // Load immediate 0x003D0900 or 4,000,000 base 10 into t4 (counter value)

    xor t3, t5, t3		// XOR the GPIO output value to toggle LED
    sw t3, GPIO_OUTPUT_VAL(t0)	// Store this new value in GPIO output register

loop1:
    addi    t4, t4, -1		// Addi instruction takes 1 clock cycle
    bnez    t4, loop1		// Jump back to loop1 and while t4 not zero
							// Branch instruction also takes one clock cycle
    j       loop			// Jump back to the main loop once the counter value reaches 0

// ADDI t4, t3, 0x100
// 000100000000 11100 000 11101 0010011