// -------------------------------------------------------------------------------------
// Name:        Lab_4.S
// Purpose:     This code has 2 parts: the first part is to flash all 8 LED's on and off
//              at a rate between 1 - 10Hz while the random number generator is called
//              continuosly. The random number generated will generate a number that
//              gives a time delay of 5.0 to 25.0 seconds. with a resolution of 0.1s.
//              Pressing pushbutton S1 will create an interrupt in the microprocessor, 
//              forcing the interrupt service routine (ISR) to run.
//              The ISR program displays this random number (without a decimal) on 
//              the 8 LED's.  The program delays for 1 second (count of 10) and the
//              new count (time left) is diplayed. This continues until the count is
//              equal to or less than 0.  The program then exits the ISR and returns to
//              the main program and flashes all 8 LED's again as before.  
//              The program then waits for another press of pushbutton S1 and everything
//              repeats.

// Author:      Julius Olajos
// -------------------------------------------------------------------------------------

.section .text
.align 2
.globl _start

// Constants
GPIO_BASE                   = 0x10012000      // GPIO base address
GPIO_OUTPUT                 = 0x0C            // GPIO output register offset
GPIO_OUTPUT_ENABLE           = 0x08            // GPIO output enablr register offset
GPIO_INPUT                  = 0x00            // GPIO input register offset
GPIO_INPUT_ENABLE           = 0x04            // GPIO input enable register offset
GPIO_7SEGLED_PINS           = 0x0000023F      // Seven Segment LED Display Pins (7)
GPIO_LEDBAR_PINS            = 0x00FC0C00      // LED Bar Pins (8)
GPIO_ALL_LED_PINS           = 0x00FC0E3F      // All LED Pins (15)
GPIO_FALL_INTERRUPT_ENABLE  = 0x20            // Falling edge interrupt enable register offset
GPIO_FALL_INTERRUPT_PENDING = 0x24            // Falling Edge interrupt pending register offset
GPIO_IO_FUNCTION_ENABLE     = 0x028           // I/O function enable register offset
GPIO_IO_FUNCTION_SELECT     = 0x02C           // I/O function select register offset
PLIC_BASE                   = 0x0C000000      // PLIC base address
PLIC_ENABLE                 = 0x2000          // PLIC interrupt enable register offset
PLIC_PRIORITY               = 0x0004          // PLIC priority register offset
PLIC_THRESHOLD              = 0x200000        // PLIC threshold register offset
PLIC_CLAIM                  = 0x200004        // PLIC claim/complete register offset
PLIC_INT_PEND               = 0x1000          // PLIC Interrupt pending register 1 offset
S1_GPIO_PIN                 = 12              // S1 pushbutton pin number (active low)
S1_IRQ                      = 12              // IRQ number for GPIO pin 12
S1_PLIC_ID                  = 20              // PLIC Interrupt source ID for GPIO pin 12
S1_PRIORITY                 = 7               // Interrupt priority for S1

// --------------------------------------------------------------------------------------------------------------
// This is the setup for the interrupt functionality of the RISC-V processor
//
// --------------------------------------------------------------------------------------------------------------

_start:
    // Set up mtvec with the address of the interrupt vector (S1_interrupt)
    la t0, S1_interrupt
    csrw mtvec, t0

    // Enable external machine interrupts in the mie register
    li t0, (1 << 11)                      // Enable machine external interrupts (MEIE)
    csrs mie, t0

    // Enable global interrupts in the mstatus register
    csrr t0, mstatus
    li t1, (1 << 3)                       // Set MIE (Machine Interrupt Enable) bit mask in mstatus
    or t0, t0, t1
    csrw mstatus, t0

// You need to set up the pushbutton S1 in the GPIO pins as an input. Refer to your Lab 3 code.

// --------------------------------------------------------------------------------------------------------------

//                   ;This is where you put your code for setting up the S1 pushbutton input

    li s0, GPIO_BASE              // Load Base Address for GPIO Control Registers
    li t1, (1 << S1_GPIO_PIN)     // Load GPIO Register to set GPIO_INPUT_ENABLE for input pins
    sw t1, GPIO_INPUT_ENABLE(s0)  // Enable inputs on all Pushbutton pins

// --------------------------------------------------------------------------------------------------------------

// You need to set up the LED's in the GPIO pins as outputs. Refer to your Lab 3 code.

// --------------------------------------------------------------------------------------------------------------

//                   ;This is where you put your code for setting up the LED outputs

    li  s1, GPIO_LEDBAR_PINS        // Load GPIO Register to set GPIO_OUTPUT_ENABLE and GPIO_OUTPUT_XOR registers for all GPIO LED Pins
    sw  s1, GPIO_OUTPUT_ENABLE(s0)  // Enable outputs on all GPIO LED Pins
    not s1, s1                      // Invert LEDBAR_PINS
    sw  s1, GPIO_OUTPUT(s0)         // Set all LED pins to zero to turn off all LEDS.

// --------------------------------------------------------------------------------------------------------------

// You need to configure the GPIO interrupt to trigger when S1 (GPIO pin 12) is on a falling edge.


//                   ;This is where you put your code for setting up the S1 pushbutton input interrupt
//                   ;trigger on a falling edge.

    sw  t1, GPIO_FALL_INTERRUPT_ENABLE(s0)


// --------------------------------------------------------------------------------------------------------------

    // Enable PLIC for S1 interrupt
    li t1, PLIC_BASE + PLIC_ENABLE         // Calculate address of PLIC interrupt enable register
    li t2, (1 << 20)                       // Set bit 20 for PLIC Interrupt Source ID = 20 (GPIO pin 12)
    sw t2, 0(t1)

    // Set PLIC priority for S1 interrupt  // Set PLIC priority
    li t1, PLIC_BASE
    li t2, 4*(S1_PLIC_ID)                  // Calculate address of Interrupt Priority Regoster
    add t2, t2, t1
    li t3, S1_PRIORITY                     // Set interrup priority = 7
    sw t3, 0(t2)

    // Set PLIC threshold to 6 (allow all interrupts)
    li t1, PLIC_BASE + PLIC_THRESHOLD      // Calculate address of PLIC threshold register
    li t2, 6                               // Set threshold to 6.  Masks all interrups of priority 6 or less
    sw t2, 0(t1)

// --------------------------------------------------------------------------------------------------------------

// Main Program: Keep looping, let the interrupt handle events

// Initialize random number generator
 	li a7, 0xABCD

main_program:



//                   ;This is where you put your code for flashing LED's
    li  a0, 1                           // 10 Hz delay parameter

    flash_loop:
      not s1, s1
      sw  s1, GPIO_OUTPUT(s0)           // Set GPIO values

      jal RandomNum                     //  Generate random number
      mv  a4, a7                        // Move a7 into a4

      jal DELAY                         // DELAY 10 Hz

      j flash_loop                      // Jump to flash_loop

    j main_program


/*
 * @param a0, Number to 100ms delay increments
 *
 * 16Mhz clock cycle
 * t=1/f = 1/(16e6 Hz)
 * Time per cycle is 1/(16e6 Hz) = 6.25e-8s
 * To get the 100ms delay, 100e-3 / 6.25e-8 = 1,600,000
 * We need 1,600,000 cycles to make the 100ms delay
 * Adding takes 1 clock cycle and branching takes 1 clock cycle so the loop takes 2 clock cycles per branch
 * Divide by 2 for the clock cycles per loop to get counter value, 1,600,000 / 2 = 800,000
 */

DELAY:
  li  t1, 800000      // Load immediate 800,000 into t1 (counter value for 100ms)
  mul t1, t1, a0      // Multiply the 100ms delay with the number of times to delay, stored in a0

  loop1:
    addi    t1, t1, -1	// Addi instruction takes 1 clock cycle
    bnez    t1, loop1		// Jump back to loop1 and while t1 not zero
                        // Branch instruction also takes 1 clock cycle
  ret


// @param a1, Number to display
DISPLAY_NUM:
// Remember, the 8 LEDS are mapped to the GPIO as bits MSB to LSB: bits 23, 22, 21, 20, 19, 18, 11, 10
    li  t2, GPIO_LEDBAR_PINS   // All LEDS initially 0
    not t2, t2

    // Set bits 10 & 11 if needed
    andi  t3, a1, 0x3   // Check LSB of a1, store in t3
    slli  t3, t3, 10    // Shift left t3 by 10 to set LED bits 10 & 11
    or    t2, t2, t3    // Set LED bit if needed

    // Set bits 18-23 if needed
    andi  a1, a1, -4    // Unset already set bits
    slli  a1, a1, 16    // Shift left t3 by 16 to set LED bits 18-23
    or    t2, t2, a1    // Set LED bit if needed

    li t0, GPIO_BASE        // Load Base Address for GPIO Control Registers
    sw t2, GPIO_OUTPUT(t0)  // Set GPIO values

    ret


// Random Number generator Subroutine
// Register a7 holds the random number.
// You can read this value anywhere in the code, but this register can only be written to by this subroutine
// Or Else!

RandomNum:
     addi sp, sp, -16
     sw ra, 12(sp)

     li s4, 0x8000		     // Load upper 20 bits
     and t1, a7, s4  		     // Mask to lower 16 bits
     li s4, 0x2000  		     // Load upper 20 bits
     and t3, a7, s4  		     // Mask to lower 16 bits

     slli t3, t3, 2
     xor t3, t1, t3
     li s4, 0x1000  		     // Load upper 20 bits
     and t1, a7, s4		     // Mask to lower 16 bits

     slli t1, t1, 3
     xor t3, t3, t1
     andi t1, a7, 0x0400
     slli t1, t1, 5
     xor t3, t3, t1
     srli t3, t3, 15
     slli a7, a7, 1
     or a7, a7, t3		     // Register a7 holds the random number

     lw ra, 12(sp)
     addi sp, sp, 16
     ret


// --------------------------------------------------------------------------------------------------------------
// Interrupt Service Routine (ISR) for S1 interrupt
S1_interrupt:
      addi  sp, sp, -36   // Put all used registers onto stack
      sw    t0, 0(sp)
      sw    t1, 4(sp)
      sw    t2, 8(sp)
      sw    t3, 12(sp)
      sw    s1, 16(sp)
      sw    s2, 20(sp)
      sw    a0, 24(sp)
      sw    a1, 28(sp)
      sw    ra, 32(sp)

      // Acknowledge the interrupt in the PLIC (write the IRQ number to PLIC claim/complete register)
      li s1, PLIC_BASE + PLIC_CLAIM          // Calculate address of PLIC claim/complete register
      lw s2, 0(s1)                           // Read the PLIC Interrupt ID


//                   ;This is where you put your code:
//                   ;Calculate the time from the randomly generated number in register a7. You will have to scale the random number. Perhaps a7 mod 200 + 50 would work?
//                   ;Display this number on the 8 LED's
//                   ;Subtract 10 (Hex A) and display the number again until it is less than or equal to 0
//                   ;Reset counter to 0 before exiting the subroutine so it's ready to be used again

      li    t1, 0xffff      // LOAD set 16 bits
      and   a4, a4, t1      // Get lower 16 bits of num
      li    t0, 200         // Load max value of RandomNum ( 200 )
      mul   a4, a4, t0      // Multiply 200 by RandomNum to scale num between 0 and 200
      div   a4, a4, t1      // Divide by max value of 16 bits set to scale
      addi  a4, a4, 50      // Add 50 to make range between 50-250

      li    a0, 10          // Delay cycles to be 1s

      display_loop:         // Decrease by 10 each time and Display num
        mv    a1, a4        // Move num to a1 as parameter to DISPLAY_NUM
        jal   DISPLAY_NUM
        jal   DELAY         // 1s Delay
        addi  a4, a4, -10   // Decrease counter by 10
        bgt   a4, x0, display_loop // Loop while a4 is not less than or equal to 0

      mv    a4, x0                  // Store 0 in a4
      jal   DISPLAY_NUM             // Display 0




// You need to clear the interrupt pending flag for S1 (GPIO pin 12). Refer to Appendix I in the lab manual

// --------------------------------------------------------------------------------------------------------------

//                   ;This is where you put your code for clearing the interrupt pending flag for S1

        lw    t1, GPIO_FALL_INTERRUPT_PENDING(s0)   // Get memory at FALL_INTERRUPT_PENDING
        li    t0, (1 << S1_GPIO_PIN)                // Get bitshifted of value of S1
        or    t1, t1, t0                            // Set the bit of S1 to 1
        sw    t1, GPIO_FALL_INTERRUPT_PENDING(s0)   // Write back to FALL_INTERRUPT_PENDING

// You need to acknowledge the interrupt is complete in the PLIC Refer to Appendix I in the lab manual

// --------------------------------------------------------------------------------------------------------------

//                   ;This is where you put your code for acknowledging the interrupt in the PLIC

        sw s2, 0(s1)                    // Store the PLIC Interrupt ID


end_interrupt:
      lw    t0, 0(sp)     // Restore all registers from stack
      lw    t1, 4(sp)
      lw    t2, 8(sp)
      lw    t3, 12(sp)
      lw    s1, 16(sp)
      lw    s2, 20(sp)
      lw    a0, 24(sp)
      lw    a1, 28(sp)
      lw    ra, 32(sp)
      addi  sp, sp, 36


      mret                                   // Return from interrupt



