.section .text
.align 2
.globl _start


// -------------------------------------------------------------------------------------
// Name:        Lab_3.S
// Purpose:     This code has 2 parts: the first part is to create a simple counter
//              subroutine that increments from 0x00 to 0xFF, wraps to 0 and continues
//              counting.  There is a 100ms delay between the display of the count. 
//		The second part is a reflex meter that will measure how fast
//              a user responds to an event accurate to a 10th of a millisecond.
//              Initially, all LED's are off and after a random amount of time
//              (between 2 and 10 seconds), one LED turns on (LED_6) and then the user
//		presses pushbutton S1.  The press of the button will be monitored by
//		using "polling".
//
// Author:      Julius Olajos
// -------------------------------------------------------------------------------------


_start:

// -------------------------------------------------------------------------------------
// GPIO Control Registers Memory Mapping

    .equ GPIO_BASE_CTRL_ADDR, 0x10012000    // Base address for the GPIO control registers
    .equ GPIO_OUTPUT_EN,      0x08          // address offset for enabling GPIO outputs
    .equ GPIO_OUTPUT_VAL,     0x0C          // Address offset for writing to GPIO outputs
    .equ GPIO_OUTPUT_XOR,     0x40          // Address offset for GPIO Outputs XOR
    .equ GPIO_INPUT_VAL,      0x00          // Address offset for reading GPIO inputs
    .equ GPIO_INPUT_EN,       0x04          // address offset for enabling GPIO inputs
    .equ GPIO_PUE,            0x10          // address offset for internal GPIO pull-up resistor

// -------------------------------------------------------------------------------------
// 8 LEDS, 7 Segment LED Display Pins Register Address Mapping

    .equ GPIO_7SEGLED_PINS,   0x0000023F      // Seven Segment LED Display Pins (7)
    .equ GPIO_LEDBAR_PINS,    0x00FC0C00      // LED Bar Pins (8)
    .equ GPIO_ALL_LED_PINS,   0x00FC0E3F      // All LED Pins (15)
    .equ GPIO_LEDBAR_LED_6,   0x00400000      // LEDBAR LED6

// -------------------------------------------------------------------------------------
// Pushbuttons SW(x) Register Address Mapping

    .equ GPIO_SW_1,           0x00001000      // SW1 pushbutton (bit 12)
    .equ GPIO_SW_2,           0x00002000      // SW2 Pushbutton (bit 13)
    .equ GPIO_ALL_PBS,        0x00003000      // All Pushbutton Pins (bits 12, 13)

// Initialize the GPIO control registers
// -------------------------------------------------------------------------------------

    li t0, GPIO_BASE_CTRL_ADDR          // Load Base Address for GPIO Control Registers
    li t1, GPIO_ALL_LED_PINS            // Load GPIO Register to set GPIO_OUTPUT_EN and GPIO_OUTPUT_XOR registers for all GPIO LED Pins
    sw t1, GPIO_OUTPUT_EN(t0)           // Enable outputs on all GPIO LED Pins
    li t2, 0xFF03F1C0
    sw t2, GPIO_OUTPUT_VAL(t0)          // Set all LED pins to zero to turn off all LEDS.
    li t1, GPIO_SW_1                    // Load GPIO Register to set GPIO_INPUT_EN for input pins
    sw t1, GPIO_INPUT_EN(t0)            // Enable inputs on all Pushbutton pins

// -------------------------------------------------------------------------------------


INITIAL:

// Initialize random number generator
 	li a7, 0xABCD                   // Initializes register a7 to a 16-bit non-zero value and NOTHING else can write to a7 !!!!

COUNTER:
  mv s2, x0     // Use register s2 for counter
  li s1, 0x100  // Value of 0xFF + 1 which means reset

  INC:
    jal   ra, RandomNum
    mv    a0, s2            // Number to display
    jal   ra, DISPLAY_NUM   // Jump to DISPLAY_NUM
  
    li    a2, 1             // Enable POLL exit
    li    a3, 1000          // 1000*0.1ms to get 100ms delay
    jal   ra, POLL
    bne   a3, a1, loop      // Jump to main loop if user pressed button early
  
    addi  s2, s2, 1         // Increment s2
    bne   s2, s1, INC       // Branch if s2 has not reached s1

  j COUNTER
// -------------------------------------------------------------------------------------

loop:
//  Generate random number
    mv    a0, x0            // Clear display
    jal   ra, DISPLAY_NUM
    jal   ra, RandomNum

//  Once your number has been generated, it will be stored in register a7. Do not overwrite this!
//  You will now need to set up delays, timer, subroutines to turn the LED ON and OFF, and for polling whether the Pushbutton S1 has been pressed.
//  Keep in mind that you will get a 32-bit number back from the timer that measures the time between the LED turning ON and the press of the pushbutton.
//  You will need to display this 8 bits at a time, starting with the lowest 8 bits.


  /*
    * To scale the RandomNum between 2s-10s
    * Take the RandomNum and the desired range between max and min counter values (80,000)
    * Multiply the ratio of the RandomNum and max RandomNum (0xffff) with the range of counter values
    * Add back the min counter value (20,000)
    *
    * Since the register is 32 bits, the will be overflow from 80,000 multiplied by the RandomNum if the num is large
    * This would lose 1.4 seconds if the num was 0xffff which doesn't fit in the +-5% requirement.
    * To account for this, RandomNum is first multiplied by 40,000 then divided by max value, 0xffff and then multiplied by 2 again
    * to get the original 80,000
    * This method loses a little precision ~0.001% or ~0.078ms (negligible since 0.1ms steps)
    * between numbers due to early division but ensures no overflow
    */
  scale:
    mv    a0, a7          // Use a0 register for counter value to pass to DELAY as a parameter
    
    li    t0, 0xffff      // Get bottom 16 bits for random number
    and  a0, a0, t0       
    
    li    t0, 40000       // Load 40,000 into t0 for (10s-2s)/0.1ms with overflow consideration
    mul   a0, a0, t0      // Multiply a0 by t0 to get counter value
    li    t0, 0xffff      // Load max value of RandomNum
    div   a0, a0, t0      // Ratio of RandomNum
    slli  a0, a0, 1       // Multiply counter by 2 to get the 80,000
    li    t0, 20000       // Load 20,000 into t0
    add   a0, a0, t0      // Add 20,000 to t0 to get 2s offset

  jal ra, DELAY

  li  t0, GPIO_BASE_CTRL_ADDR         // Load Base Address for GPIO Control Registers
  li  t2, 0xff43f1c0                  // Load every LED off except LED_6
  sw  t2, GPIO_OUTPUT_VAL(t0)         // Turn on LED_6 by storing to GPIO

  li  a2, 0                           // No early exit timer
  jal ra, POLL                        // Poll for SW_1 press
  mv  s2, a1                          // Store POLL value persistently

loop_display:
  mv  a0, s2                          // Move value from poll to a0
  jal ra, DISPLAY                     // Display reaction time

  j   loop_display                    // Continue looping display

// @param a2, Enable exit by DELAY
// @param a3, DELAY counter by 0.1ms increments
// @ret a1,   counter return
// @ret a3,   DELAY counter parameter
POLL:
  addi  sp, sp, -12                      // Store ra on stack
  sw    ra, 0(sp)
  sw    s0, 4(sp)
  sw    s1, 8(sp)

  li    a0, 1                           // Use 0.1ms Delay
  mv    a1, x0                          // Reset a1 to use for counter
  addi  a2, a2, -1                      // Inverse a2 for easy bitwise operations
  mv    t3, a3                          // Make a3 non destructive for easy comparisons

  li    s0, GPIO_BASE_CTRL_ADDR         // Load offsets
  li    s1, GPIO_SW_1

  poll_loop: // TODO: Could simplify this
    lw    t0, GPIO_INPUT_VAL(s0)        // Get INPUT value
    and   t1, t0, s1                    // Get GPIO_SW_1 value
  
    beqz  t1, end_poll                  // Check if SW_1 is pressed, end_poll if it is, SW_1 is 1 when not pressed
    jal   ra, DELAY                     // Call 0.1ms delay
    addi  a1, a1, 1                     // Increment counter

    addi  t3, t3, -1                    // Decrement DELAY counter parameter
    or    t1, a2, t3                    // Bitwise check that DELAY counter is 0 and counter is on
    bnez  t1, poll_loop                 // IF NOT ZERO: DELAY counter is not 0 or counter is not on, continue

  end_poll:
    lw    ra, 0(sp)
    lw    s0, 4(sp)
    lw    s1, 8(sp)
    addi  sp, sp, 12
    ret

// @param a0, Number to display
// @ret   a1, value from polling
DISPLAY:

// Display the 32-bit number on the 8-LED Bar

// Register s2 holds the value of the number to be displayed
// Map each bit of the number to the corresponding LED Bar bit
// MSB to LSB: bits 23, 22, 21, 20, 19, 18, 11, 10
//
  addi  sp, sp, -16         // Store s2, ra, s1 onto stack
  sw    ra, 0(sp)
  sw    s1, 4(sp)
  sw    s2, 8(sp)
  sw    a0, 12(sp)

  li    s1, 4               // Loop 4 times for 4 bytes to display
  mv    s2, a0              // Move a1 into s2 for persistence
  display_loop:
    mv    t1, s2            // Move current s2 value into t1
    andi  a0, t1, 0xff      // Get lower 8 bits and store in a0
    jal   ra, DISPLAY_NUM   // Call DISPLAY_NUM for lower 8 bits with a0 storing value
    li    a0, 20000         // 2s Delay from 2s/(0.1ms)
    jal   ra, DELAY         // Call Delay with 2s delay
    srli  s2, s2, 8         // Shift s2 right 8 bits to get next 8 bits
    addi  s1, s1, -1        // Subtract one from loop
    bnez  s1, display_loop  // Loop while s1 is non-zero
  
  lw  t0, 12(sp)      // Load displayed number from stack
  li  t1, 0xffff0000  // Get upper 8 bits of display number
  and t0, t1, t0

  li    a0, 50000         // 5s Delay from 5s/(0.1ms)
  jal   ra, DELAY


  lw    ra, 0(sp)
  lw    s1, 4(sp)
  lw    s2, 8(sp)           // Load s2 from stack
  addi  sp, sp, 16
  j DISPLAY

  bne a3, a1, loop          // Restore stack and check if counter is not equal to originally passed counter, button was pressed and go to main program

  ret

// @param a0, Number to display
DISPLAY_NUM:
// Remember, the 8 LEDS are mapped to the GPIO as bits MSB to LSB: bits 23, 22, 21, 20, 19, 18, 11, 10
    li t2, 0xFF03F1C0   // All LEDS initially 0

    // Set bits 10 & 11 if needed
    andi  t3, a0, 0x3   // Check LSB of a0, store in t3
    slli  t3, t3, 10    // Shift left t3 by 10 to set LED bits 10 & 11
    or    t2, t2, t3    // Set LED bit if needed

    // Set bits 18-23 if needed
    andi  a0, a0, -4    // Unset already set bits
    slli  a0, a0, 16    // Shift left t3 by 16 to set LED bits 18-23
    or    t2, t2, a0    // Set LED bit if needed
  
    li t0, GPIO_BASE_CTRL_ADDR  // Load Base Address for GPIO Control Registers
    sw t2, GPIO_OUTPUT_VAL(t0)  // Set GPIO values

    ret

// Random Number generator
// Register a7 holds the random number.
// You can read this value anywhere in the code, but this register can only be written to by this subroutine
// Or Else!

RandomNum:
    addi sp, sp, -16
    sw ra, 12(sp)


    li s4, 0x8000		        // Load upper 20 bits
    and t1, a7, s4  		      // Mask to lower 16 bits
    li s4, 0x2000  		      // Load upper 20 bits
    and t3, a7, s4  		      // Mask to lower 16 bits


    slli t3, t3, 2
    xor t3, t1, t3
    li s4, 0x1000  		      // Load upper 20 bits
    and t1, a7, s4		        // Mask to lower 16 bits

    slli t1, t1, 3
    xor t3, t3, t1
    andi t1, a7, 0x0400
    slli t1, t1, 5
    xor t3, t3, t1
    srli t3, t3, 15
    slli a7, a7, 1
    or a7, a7, t3		        // Register a7 holds the random number

    lw ra, 12(sp)
    addi sp, sp, 16
    ret

/*
 * @param a0, Number to 0.1ms delay increments
 *
 * 16Mhz clock cycle
 * t=1/f = 1/(16e6 Hz)
 * Time per cycle is 1/(16e6 Hz) = 6.25e-8s
 * To get the 0.1ms delay, 0.1e-3 / 6.25e-8 = 1,600
 * We need 1,600 cycles to make the 0.1ms delay
 * Adding takes 1 clock cycle and branching takes 1 clock cycle so the loop takes 2 clock cycles per branch
 * Divide by 2 for the clock cycles per loop to get counter value, 1,600 / 2 = 800
 */

DELAY:
  li  t1, 800         // Load immediate 800 into t1 (counter value for 0.1ms)
  mul t1, t1, a0      // Multiply the 0.1ms delay with the number of times to delay, stored in a0

  loop1:
    addi    t1, t1, -1	// Addi instruction takes 1 clock cycle
    bnez    t1, loop1		// Jump back to loop1 and while t1 not zero
                        // Branch instruction also takes 1 clock cycle
  ret

/*
 * 1- If a 32-bit register is counting user reaction time in 0.1 milliseconds increments, what is the maximum amount of time which can be stored in 8 bits, 16-bits, 24-bits and 32-bits?
 * 8 bits   - 25ms
 * 16 bits  - 6553ms
 * 24 bits  - 1677721ms
 * 32 bits  - 429496729ms

 * 2- Considering typical human reaction time, which size would be the best for this task (8, 16, 24, or 32 bits)?
 *  16 bits should be used since the average human reaction time is 250ms and 16 bits stores up to 6553ms in 0.1ms increments

 * 3- Prove time delay meets 2 to 10 sec +/- 5% spec.
 *  Time delay meets 2 to 10 seconds because I scaled the RandomNum to fit between an 8 second range and added 2 seconds to it
    * To scale the RandomNum between 2s-10s
    * Take the RandomNum and the desired range between max and min counter values (80,000)
    * Multiply the ratio of the RandomNum and max RandomNum (0xffff) with the range of counter values
    * Add back the min counter value (20,000)
    *
    * Since the register is 32 bits, the will be overflow from 80,000 multiplied by the RandomNum if the num is large
    * This would lose 1.4 seconds which doesn't fit in the +-5% requirement.
    * To account for this, RandomNum is first multiplied by 40,000 then divided by max value, 0xffff and then multiplied by 2 again
    * to get the original 80,000
    * This method loses a little precision ~0.001% or ~0.078ms (negligible since 0.1ms steps)
    * between numbers due to early division but ensures no overflow
    Using the formula (floor((RandomNum*40000)/2^16)*2+20000)*0.1e-3s
    You'll see that if you substitute 0 of 0xffff for RandomNum, the values are between 2 and 10
    Where the floor considers the precision loss from integer division and there is no overflow
    Thus, the value fits between 2-10 seconds
    The delay function is adjusted from previous Labs.
	* 16Mhz clock cycle
 	* t=1/f = 1/(16e6 Hz)
 	* Time per cycle is 1/(16e6 Hz) = 6.25e-8s
 	* To get the 0.1ms delay, 0.1e-3 / 6.25e-8 = 1,600
 	* We need 1,600 cycles to make the 0.1ms delay
 	* Adding takes 1 clock cycle and branching takes 1 clock cycle so the loop takes 2 clock cycles per branch
 	* Divide by 2 for the clock cycles per loop to get counter value, 1,600 / 2 = 800
 */