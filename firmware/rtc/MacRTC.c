/* Macintosh RTC chip drop-in replacement.

   Written in 2020 by Andrew Makousky

   Public Domain Dedication:

   To the extent possible under law, the author(s) have dedicated all
   copyright and related and neighboring rights to this software to
   the public domain worldwide. This software is distributed without
   any warranty.

   You should have received a copy of the CC0 Public Domain Dedication
   along with this software. If not, see
   <http://creativecommons.org/publicdomain/zero/1.0/>.

   ----------

   Developed with reference to a Reddit posting and Mini vMac source.

   * 2020-08-05: <https://www.reddit.com/r/VintageApple/comments/91e5cf/couldnt_find_a_replacement_for_the_rtcpram_chip/e2xqq60/>

   * 2020-09-04: <https://www.gryphel.com/d/minivmac/minivmac-36.04/minivmac-36.04.src.tgz>
*/

#include <avr/io.h>
#include <avr/wdt.h>
#include <avr/interrupt.h>
#include <avr/sleep.h>

#ifdef DO_SIMAVR
#include "avr_mcu_section.h"
AVR_MCU(32768, "attiny85");
AVR_MCU_SIMAVR_COMMAND (& GPIOR0 );
const struct avr_mmcu_vcd_trace_t _mytrace[] _MMCU_ =
  {
   { AVR_MCU_VCD_SYMBOL("PORTB5"), .what = (void*)&PORTB, .mask = _BV(5) },
  };
#endif

/********************************************************************/
// Simplified Arduino.h definitions.
typedef enum { false, true } bool; // Compatibility with C++.
typedef bool boolean;
typedef uint8_t byte;

#define bitRead(value, bit) (((value) >> (bit)) & 0x01)
#define bitSet(value, bit) ((value) |= (1UL << (bit)))
#define bitClear(value, bit) ((value) &= ~(1UL << (bit)))
#define bitWrite(value, bit, bitvalue) ((bitvalue) ? bitSet(value, bit) : bitClear(value, bit))
// END simplified Arduino.h definitions.
/********************************************************************/

/****************************************
 *                                      *
 * A drop-in replacement for the custom *
 * RTC chip in early Apple Macintosh    *
 * computers, using an ATtiny85.        *
 * Uses an external 32.768kHz crystal   *
 * on pins 2 and 3 as a clock source.   *
 *            __  __                    *
 *     1SEC -|1 \/ 8|- VCC              *
 *    XTAL2 -|2    7|- RTC.CLK          *
 *    XTAL1 -|3    6|- RTC.DATA         *
 *      GND -|4____5|- !RTC             *
 *                                      *
 ****************************************/

/*********************************************
 * ATMEL ATTINY85                            *
 *                                           *
 *                  +-\/-+                   *
 * Ain0 (D 5) PB5  1|    |8  Vcc             *
 * Ain3 (D 3) PB3  2|    |7  PB2 (D 2)  Ain1 *
 * Ain2 (D 4) PB4  3|    |6  PB1 (D 1) pwm1  *
 *            GND  4|    |5  PB0 (D 0) pwm0  *
 *                  +----+                   *
 *********************************************/

const int      ONE_SEC_PIN = 5;   // A 1Hz square wave on PB5
const int  RTC_ENABLE_PIN  = 0;   // Active low chip enable on PB0
const int  SERIAL_DATA_PIN = 1;   // Bi-directional serial data line on PB1
const int SERIAL_CLOCK_PIN = 2;   // Serial clock input on PB2

#if NoXPRAM
// Models earlier than the Plus had 20 bytes of PRAM
#define PRAM_SIZE 20
const int group1Base = 0x00;
const int group2Base = 0x10;
#else
// Mac Plus used the xPRAM chip with 256 bytes
#define PRAM_SIZE 256
const int group1Base = 0x10;
const int group2Base = 0x08;
#endif

enum SerialStateType { SERIAL_DISABLED, RECEIVING_COMMAND,
                       SENDING_DATA, RECEIVING_DATA,
                       RECEIVING_XCMD_ADDR, RECEIVING_XCMD_DATA };

enum PramAddrResult { INVALID_CMD, SECONDS_CMD,
                      WRTEST_CMD, WRPROT_CMD, SUCCESS_ADDR };

volatile boolean lastRTCEnable = 0;
volatile boolean lastSerClock = 0;
volatile boolean serClockRising = false;
volatile boolean serClockFalling = false;

volatile enum SerialStateType serialState = SERIAL_DISABLED;
volatile byte serialBitNum = 0;
volatile byte address = 0;
volatile byte serialData = 0;

// Number of seconds since midnight, January 1, 1904.  The serial
// register interface exposes this data as little endian.  TODO
// VERIFY: Clock is initialized to January 1st, 1984?  Or is this done
// by the ROM when the validity status is invalid?
volatile unsigned long seconds = 60UL * 60 * 24 * (365 * 4 + 1) * 20;
volatile byte pram[PRAM_SIZE] = {}; // PRAM initialized as zeroed data
volatile byte writeProtect = 0;

#define shiftReadPB(output, bitNum, portBit) \
  bitWrite(output, bitNum, ((PINB&_BV(portBit))) ? 1 : 0)

// Configure a pin to be an open-drain output, currently does nothing
// as using digitalWriteOD() does all required setup and leaving the
// pin as an input in the meantime is fine.
#define configOutputOD(pin)

// Digital write in an open-drain fashion: set as output-low for zero,
// set as input-no-pullup for one.
void digitalWriteOD(uint8_t pin, uint8_t val) {
  uint8_t bit = _BV(pin);
  // cli();
  if (val == 0) {
    DDRB |= bit;
    // PORTB &= ~bit;
  } else {
    DDRB &= ~bit;
    // PORTB &= ~bit;
  }
  // sei();
}

void setup(void) {
  cli(); // Disable interrupts while we set things up

  // OUTPUT: The 1Hz square wave (used for interrupts elsewhere in the system)
  DDRB |= ONE_SEC_PIN;
  // INPUT: The processor pulls this pin low when it wants access
  DDRB &= ~RTC_ENABLE_PIN;
  PORTB &= ~RTC_ENABLE_PIN;
  lastRTCEnable = PINB&(1<<RTC_ENABLE_PIN); // Initialize last value
  // INPUT: The serial clock is driven by the processor
  DDRB &= ~SERIAL_CLOCK_PIN;
  PORTB &= ~SERIAL_CLOCK_PIN;
  lastSerClock = PINB&(1<<SERIAL_CLOCK_PIN); // Initialize last value
  // INPUT: We'll need to switch this to output when sending data
  DDRB &= ~SERIAL_DATA_PIN;
  PORTB &= ~SERIAL_DATA_PIN;

  wdt_disable();       // Disable watchdog
  bitSet(ACSR, ACD);   // Disable Analog Comparator, don't need it, saves power
  bitSet(PRR, PRTIM1); // Disable Timer 1, only using Timer 0, Timer 1 uses around ten times as much current
  bitSet(PRR, PRUSI);  // Disable Universal Serial Interface, using Apple's RTC serial interface on pins 6 and 7
  bitSet(PRR, PRADC);  // Disable Analog/Digital Converter

  bitSet(GIMSK, PCIE);   // Pin Change Interrupt Enable
  bitSet(PCMSK, PCINT0); // turn on RTC enable interrupt
  bitSet(PCMSK, PCINT2); // turn on serial clock interrupt

  //set up timer
  bitSet(GTCCR, TSM);    // Turns off timers while we set it up
  bitSet(TIMSK, TOIE0);  // Set Timer/Counter0 Overflow Interrupt Enable
  // NOTE: 0b111 external clock, 0b011, uses 1/64 prescaler on I/O clock.
  TCCR0B = 0b011;        // Set prescaler, 32,768Hz/64 = 512Hz, fills up the 8-bit counter (256) once every half second
  TCNT0 = 0;             // Clear the counter
  bitClear(GTCCR, TSM);  // Turns timers back on

#ifdef DO_SIMAVR
  GPIOR0 = SIMAVR_CMD_VCD_START_TRACE;
#endif

  sei(); //We're done setting up, enable those interrupts again

}

void clearState(void) {
  // Return the pin to input mode
  // cli();
  DDRB &= ~SERIAL_DATA_PIN;
  // PORTB &= ~SERIAL_DATA_PIN;
  // sei();
  serialState = SERIAL_DISABLED;
  serialBitNum = 0;
  address = 0;
  serialData = 0;
}

/*
 * An interrupt to both increment the seconds counter and generate the
 * square wave
 */
void halfSecondInterrupt(void) {
  PINB = 1<<ONE_SEC_PIN;  // Flip the one-second pin
  if (!(PINB&(1<<ONE_SEC_PIN))) { // If the one-second pin is low
    seconds++;
    // Make up for lost time, something around 6.4 cycles.
    TCNT0 += 6;
  }
  else
    TCNT0 += 7;
}

/*
 * The actual serial communication can be done in the main loop, this
 * way the clock still gets incremented.
 */
void handleRTCEnableInterrupt(void) {
  boolean curRTCEnable = PINB&(1<<RTC_ENABLE_PIN);
  if (lastRTCEnable && !curRTCEnable){ // Simulates a falling interrupt
    serialState = RECEIVING_COMMAND;
  }
  /* Else if a rising edge to disable the RTC interrupts a serial
     communication in progress, we still wake up to clear the serial
     state then go back to sleep.  */
  lastRTCEnable = curRTCEnable;
}

/*
 * Same deal over here, the actual serial communication can be done in
 * the main loop, this way the clock still gets incremented.
 */
void handleSerClockInterrupt(void) {
  boolean curSerClock = PINB&(1<<SERIAL_CLOCK_PIN);
  if (!lastSerClock && curSerClock) {
    serClockRising = true;
    serClockFalling = false;
  } else if (lastSerClock && !curSerClock) {
    serClockRising = false;
    serClockFalling = true;
  }
  /* Else leave it up to the main loop code to clear the edge trigger
     flags.  */
  lastSerClock = curSerClock;
}

/*
 * For 20-byte PRAM equivalent commands, compute the actual PRAM
 * address by modifying the `address` variable in-place.  A status
 * code is returned for commands that need special processing:
 *
 * INVALID_CMD: Invalid command byte.
 * SECONDS_CMD: Special command: read seconds.
 * WRTEST_CMD: Special command: test write register.
 * WRPROT_CMD: Special command: write-protect register.
 * SUCCESS_ADDR: Successful address computation.
 */
uint8_t decodePramCmd(boolean writeRequest) {
  // Discard the first bit and the last two bits, it's not pertinent
  // to address interpretation.
  address = (address&~(1<<7))>>2;
  if (address < 8) {
    // Little endian clock data byte
    return SECONDS_CMD;
  } else if (address < 12) {
    // Group 2 register
    address = (address&0x03) + group2Base;
  } else if (address < 16) {
    if (writeRequest) {
      if (address == 12) // test write
        return WRTEST_CMD;
      if (address == 13) // write-protect
      return WRPROT_CMD;
    }
    return INVALID_CMD;
  } else {
    // Group 1 register
    address = (address&0x0f) + group1Base;
  }

  return SUCCESS_ADDR;
}

void loop(void) {
  if ((PINB&(1<<RTC_ENABLE_PIN))) {
    clearState();
    set_sleep_mode(0); // Sleep mode 0 == default, timers still running.
    sleep_mode();
  } else {
    /* Normally we only perform an action on the rising edge of the
       serial clock.  The main exception is cleanup at the last cycle
       of serial output, there we wait one full cycle and then until
       the falling edge before switching the direction of the data pin
       back to an input.  */
    if (serClockFalling &&
        serialState == SENDING_DATA &&
        serialBitNum >= 9) {
      clearState();
    } else if (serClockRising) {
      boolean writeRequest;
      switch(serialState) {
      case RECEIVING_COMMAND:
        shiftReadPB(address, 7 - serialBitNum, SERIAL_DATA_PIN);
        serialBitNum++;
        if (serialBitNum <= 7)
          break;

        // The MSB determines if it's a write request or not.
        writeRequest = !(address&(1<<7));
        if ((address&0x78) == 0x38) {
#if NoXPRAM
          // Invalid command.
          clearState();
          break;
#else
          // This is an extended command, read the second address
          // byte.
          serialState = RECEIVING_XCMD_ADDR;
          serialBitNum = 0;
          break;
#endif
        } else if (writeRequest) {
          // Read the data byte before continuing.
          serialState = RECEIVING_DATA;
          serialBitNum = 0;
          break;
        } else {
          boolean finished = false;
          // Decode the command/address.
          switch (decodePramCmd(false)) {
          case SECONDS_CMD:
            // Read little endian clock data byte.
            cli(); // Ensure that reads are atomic.
            address = (address&0x03)<<3;
            serialData = (seconds>>address)&0xff;
            sei();
            break;
          case SUCCESS_ADDR:
            serialData = pram[address];
            break;
          case INVALID_CMD:
          default:
            finished = true;
            break;
          }
          if (finished) {
            clearState();
            break;
          }
        }

        // If we didn't break out early, send the output byte.
        serialState = SENDING_DATA;
        serialBitNum = 0;
        // Set the pin to output mode
        configOutputOD(SERIAL_DATA_PIN);
        break;

      case RECEIVING_DATA:
        shiftReadPB(serialData, 7 - serialBitNum, SERIAL_DATA_PIN);
        serialBitNum++;
        if (serialBitNum <= 7)
          break;

        // Decode the command/address.
        switch (decodePramCmd(true)) {
        case SECONDS_CMD:
          if (!writeProtect) {
            // Write little endian clock data byte.
            cli(); // Ensure that writes are atomic.
            address = (address&0x03)<<3;
            seconds &= ~(0xff<<address);
            seconds |= serialData<<address;
            sei();
          }
          break;
        case WRPROT_CMD:
          // Update the write-protect register.
          writeProtect = ((serialData & 0x80)) ? 1 : 0;
          break;
        case SUCCESS_ADDR:
          if (!writeProtect)
            pram[address] = serialData;
          break;
        case WRTEST_CMD: // test write, do nothing
        case INVALID_CMD:
        default:
          break;
        }

        // Finished with the write command.
        clearState();
        break;

      case SENDING_DATA:
        if (serialBitNum <= 7)
          digitalWriteOD(SERIAL_DATA_PIN,
                         bitRead(serialData, 7 - serialBitNum));
        serialBitNum++;
        /* if (serialBitNum <= 7)
          break; */

        /* NOTE: The last output cycle is treated specially, hold the
           data line as an output for at least one full next cycle,
           then until the falling edge of the serial clock, then
           switch back to an input and reset the serial communication
           state.  It's for bug compatibility with the ROM, but with a
           little bit of sanity too.  */
        break;

#if !defined(NoXPRAM) || !NoXPRAM
      case RECEIVING_XCMD_ADDR:
        shiftReadPB(serialData, 7 - serialBitNum, SERIAL_DATA_PIN);
        serialBitNum++;
        if (serialBitNum <= 7)
          break;

        // The MSB determines if it's a write request or not.
        writeRequest = !(address&(1<<7));
        // Assemble the extended address.
        address = ((address&0x07)<<5) | ((serialData&0x7c)>>2);

        if (writeRequest) {
          // Read the data byte before continuing.
          serialState = RECEIVING_XCMD_DATA;
          serialBitNum = 0;
          break;
        }

        // Read and send the PRAM register.
        serialData = pram[address];
        serialState = SENDING_DATA;
        serialBitNum = 0;
        // Set the pin to output mode
        configOutputOD(SERIAL_DATA_PIN);
        break;

      case RECEIVING_XCMD_DATA:
        shiftReadPB(serialData, 7 - serialBitNum, SERIAL_DATA_PIN);
        serialBitNum++;
        if (serialBitNum <= 7)
          break;

        // Write the PRAM register.
        pram[address] = serialData;
        // Finished with the write command.
        clearState();
        break;
#endif

      default:
        // Invalid command.
        clearState();
        break;
      }
    }

    // Clear the edge trigger flags now that the events have been
    // processed.
    serClockRising = false;
    serClockFalling = false;

    // Go to sleep until the next serial clock rising or falling edge.
    set_sleep_mode(0); // Sleep mode 0 == default, timers still running.
    sleep_mode();
  }
}

/*
 * Actually attach the interrupt functions
 */
ISR(PCINT0_vect) {
  handleRTCEnableInterrupt();
  handleSerClockInterrupt();
}

ISR(TIMER0_OVF_vect) {
  halfSecondInterrupt();
}

// Arduino main function.
int main(void) {
  setup();

  for (;;) {
    loop();
  }

  return 0;
}
