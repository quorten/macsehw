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

// 8 MHz clock is recommended for a physical device.  For real-time
// simulation, a slower 400 kHz clock is needed.
#ifndef F_CPU
#define F_CPU 8000000UL
//#define F_CPU 400000UL // DEBUG
#endif

#include <avr/io.h>
#include <avr/wdt.h>
#include <avr/interrupt.h>
#include <avr/sleep.h>

/* Fuse bit programming.  */
#if defined(__AVR_ATtiny25__) || defined(__AVR_ATtiny45__) || \
  defined(__AVR_ATtiny85__)
FUSES = {
  // Use 8 MHz internal clock, not default 1 MHz internal clock.
  .low = (LFUSE_DEFAULT | ~FUSE_CKDIV8),
  // Disable the external RESET pin since it is used for the 1-second
  // interrupt output.
  .high = (HFUSE_DEFAULT & FUSE_RSTDISBL),
  .extended = EFUSE_DEFAULT,
};
#endif

/********************************************************************/
// Simplified Arduino.h definitions.
typedef enum { false, true } bool; // Compatibility with C++.
typedef bool boolean;
typedef uint8_t bool8_t;
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
 * on pins 2 and 3 as a clock source.*  *
 * SEE ELECTRICAL SPECIFICATIONS.       *
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

const int       SOFT_XTAL1 = 4;   // (software) inverting amplifier input on PB4
const int       SOFT_XTAL2 = 3;   // (software) inverting amplifier output on PB3
const int      ONE_SEC_PIN = 5;   // A 1Hz square wave on PB5
const int  RTC_ENABLE_PIN  = 0;   // Active low chip enable on PB0
const int  SERIAL_DATA_PIN = 1;   // Bi-directional serial data line on PB1
const int SERIAL_CLOCK_PIN = 2;   // Serial clock input on PB2

/* ELECTRICAL SPECIFICATIONS:

   * When the Macintosh is powered off, the RTC is powered by the
     clock battery.  The battery supply voltage is anywhere from 3.6V
     to 3V, though depleted batteries can sink below 3V.

   * When the Macintosh is powered on, a diode supplies power to the
     RTC from the main logic board's power rails.  This means the RTC
     runs off of 5V power during power-on operation.  If necessary, we
     can take advantage of this to run the AVR core clock at 16 MHz.

   * All dedicated input lines already have a pull-up resistor, so
     there is no need to enable the AVR's internal pull-up resistors.

   * The bi-directional serial data line is also wired to a pull-up
     resistor.  This means we can use open-drain signaling to avoid
     the risk of the output drivers getting burned out if both sides
     inadvertently configure themseslves as outputs at the same time.

   * What about the one-second interrupt pin?  Since this is wired to
     a dedicated input line, it's okay to leave this as a "totem-pole"
     buffered output.

   * The serial data clock needs to be able to operate at a frequency
     of at least 1 kHz, maybe up to 20 kHz.

   * Because of the requirement on the serial clock speed, the AVR
     core clock speed should be around 8 MHz, given that it can take
     about 100 cycles to process one edge of the serial data clock.

   * Because the AVR core clock speed needs to operate faster than the
     32.768 kHz crystal oscillator clock frequency, the external clock
     would ideally be used as the crystal oscillator input to an
     asynchronous timer.  Unfortunately, the ATTiny85 does not have
     the necessary circuitry or ASSR control register.

     If you are willing to forgo the cosmetics of a pin-compatible DIP
     package, you can instead use the ATTiny87 which has an AS0
     asynchronous timer.  Though it has extra pins, it comes in a
     smaller form factor, so you can just mount it on a custom adapter
     circuit board that breaks out the desired pins to through-hole
     and ignores/grounds the unnecessary pins.

   * Because the ATTiny85 cannot use the 32.768 kHz crystal
     oscillator, we configure the respective pins to some sane default
     values, namely both sides as pull-up inputs.  This should put the
     voltage on both sides of the crystal to equal, so the crystal
     effectively not used or stressed.  However, if you're feeling
     like an evil mad scientist, you can change one of the pins to be
     an output and then proceed to programming a software-defined
     inverting amplifier, possibly with the assistance of a few other
     external passives.

   * TODO: Determine the target standby power consumption.
*/

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

// Timer constants
#if F_CPU == 8000000UL
#define PRESCALER_MASK 0b101 /* 1/1024 */
#define LIM_OFLOWS 15
#define LIM_REMAIN 66
#define NUMER_FRAC_REMAIN 1
// `fracRemain` denominator is assumed to be a power-of-two, this
// makes calculations more efficient.
#define DENOM_FRAC_REMAIN 4
#define MASK_FRAC_REMAIN (DENOM_FRAC_REMAIN-1)

#elif F_CPU == 400000UL
#define PRESCALER_MASK 0b100 /* 1/256 */
#define LIM_OFLOWS 3
#define LIM_REMAIN 13
#define NUMER_FRAC_REMAIN 1
// `fracRemain` denominator is assumed to be a power-of-two, this
// makes calculations more efficient.
#define DENOM_FRAC_REMAIN 4
#define MASK_FRAC_REMAIN (DENOM_FRAC_REMAIN-1)

#else
#error "Invalid clock frequency selection"
#endif

/* Explanation of the 1-second timer calculations.

   First divide the AVR core clock frequency by two since we count
   half-second cycles.

   8000000 / 2 = 4000000

   Find quotient and remainder of timer frequency divider.

   4000000 / 1024 = 3906 + 256/1024 = 3906 + 1/4

   Now, divide by 256 to find out how many 8-bit timer overflows we
   need to process.

   3906 / 256 = 15 + 66/256

   The remainder is the fractional overflow to process.  We achieve
   this by setting the counter register to 256 - remainder after 15
   overflows.  On the 16th overflow, we then just let the register
   wrap to zero.

   But we're not finished yet, we still have the other remainder to
   adjust for.  Here's how we do it.

   1/4 / 256 = (1/4)/256

   Okay, so what does that mean?  That means we have 1/4 of a counter
   tick to accumulate every half-second cycle in `fracRemain`.  After 4
   half-second cycles, the error is one full counter tick to add to
   the fractional overflow.  So, every 4 half-second cycles, we use 67
   as the remainder rather than 66.
*/

enum SerialStateType { SERIAL_DISABLED, RECEIVING_COMMAND,
                       SENDING_DATA, RECEIVING_DATA,
                       RECEIVING_XCMD_ADDR, RECEIVING_XCMD_DATA };

volatile bool8_t lastRTCEnable = 0;
volatile bool8_t lastSerClock = 0;
volatile bool8_t serClockRising = false;
volatile bool8_t serClockFalling = false;

volatile byte serialState = SERIAL_DISABLED;
volatile byte serialBitNum = 0;
volatile byte address = 0;
volatile byte serialData = 0;

/* Number of seconds since midnight, January 1, 1904.  The serial
   register interface exposes this data as little endian.

   TODO VERIFY: Clock is initialized to January 1st, 1984?  Or is this
   done by the ROM when the validity status is invalid?

   TODO INVESTIGATE: Does `simavr` not initialize non-zero variables?
   Or is this a quirk with `avr-gcc`?  */
volatile unsigned long seconds = 60UL * 60 * 24 * (365 * 4 + 1) * 20;
volatile byte writeProtect = 0;
volatile byte pram[PRAM_SIZE] = {}; // PRAM initialized as zeroed data

// Extra timer precision book-keeping.
volatile byte numOflows = 0;
volatile byte fracRemain = 0;

#define shiftReadPB(output, bitNum, portBit) \
  bitWrite(output, bitNum, ((PINB&_BV(portBit))) ? 1 : 0)

// Configure a pin to be an open-drain output, currently does nothing
// as using digitalWriteOD() does all required setup and leaving the
// pin as an input in the meantime is fine.
#define configOutputOD(pin)

// Digital write in an open-drain fashion: set as output-low for zero,
// set as input-no-pullup for one.
void digitalWriteOD(uint8_t pin, uint8_t val)
{
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

void setup(void)
{
  cli(); // Disable interrupts while we set things up

  // TODO FIXME: Because `simavr` does not initialize non-zero global
  // variables, we must repeat the initialization here.
  seconds = 60UL * 60 * 24 * (365 * 4 + 1) * 20;

  // INPUT_PULLUP: Set the crystal oscillator pins as such to sanely
  // disable it.
  DDRB &= ~(1<<SOFT_XTAL1);
  PORTB |= 1<<SOFT_XTAL1;
  DDRB &= ~(1<<SOFT_XTAL2);
  PORTB |= 1<<SOFT_XTAL2;  
  // OUTPUT open-drain: The 1Hz square wave (used for interrupts
  // elsewhere in the system)
  DDRB &= ~(1<<ONE_SEC_PIN);
  PORTB &= ~(1<<ONE_SEC_PIN);
  digitalWriteOD(ONE_SEC_PIN, 0);
  // INPUT: The processor pulls this pin low when it wants access
  DDRB &= ~(1<<RTC_ENABLE_PIN);
  PORTB &= ~(1<<RTC_ENABLE_PIN);
  lastRTCEnable = PINB&(1<<RTC_ENABLE_PIN); // Initialize last value
  // INPUT: The serial clock is driven by the processor
  DDRB &= ~(1<<SERIAL_CLOCK_PIN);
  PORTB &= ~(1<<SERIAL_CLOCK_PIN);
  lastSerClock = PINB&(1<<SERIAL_CLOCK_PIN); // Initialize last value
  // INPUT: We'll need to switch this to output when sending data
  DDRB &= ~(1<<SERIAL_DATA_PIN);
  PORTB &= ~(1<<SERIAL_DATA_PIN);

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
  TCCR0B = PRESCALER_MASK; // Set prescaler
  TCNT0 = 0;             // Clear the counter
  bitClear(GTCCR, TSM);  // Turns timers back on

  sei(); //We're done setting up, enable those interrupts again

}

void clearState(void)
{
  // Return the pin to input mode
  // cli();
  DDRB &= ~(1<<SERIAL_DATA_PIN);
  // PORTB &= ~(1<<SERIAL_DATA_PIN);
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
void oflowInterrupt(void)
{
  numOflows++;
  if (numOflows == LIM_OFLOWS) {
    /* Configure a timer interrupt to handle the final remainder cycle
       wait.  We simply subtract the value from 256, which is the same
       as going negative two's complement and using 8-bit wrap-around.
       Also, since the timer may have ticked a few cycles since
       wrap-around, accumulate via `+=`.  */
    fracRemain += NUMER_FRAC_REMAIN;
    TCNT0 += (fracRemain >= DENOM_FRAC_REMAIN) ?
      -(LIM_REMAIN + 1) : -LIM_REMAIN;
    fracRemain &= MASK_FRAC_REMAIN;
  } else if (numOflows == LIM_OFLOWS + 1) {
    // Reset the timer-related flags now that we've reached a
    // half-second.
    numOflows = 0;
    DDRB ^= 1<<ONE_SEC_PIN; // Flip the one-second pin
    if ((DDRB&(1<<ONE_SEC_PIN))) { // If the one-second pin is low
      seconds++;
    }
  }
}

/*
 * The actual serial communication can be done in the main loop, this
 * way the clock still gets incremented.
 */
void handleRTCEnableInterrupt(void)
{
  bool8_t curRTCEnable = PINB&(1<<RTC_ENABLE_PIN);
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
void handleSerClockInterrupt(void)
{
  bool8_t curSerClock = PINB&(1<<SERIAL_CLOCK_PIN);
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

/* For 20-byte PRAM equivalent commands, execute the PRAM command.
   Return `false` on invalid commands.  */
bool8_t execTradPramCmd(bool8_t writeRequest)
{
  // Discard the first bit and the last two address bits, it's not
  // pertinent to address interpretation.  Also, use a local,
  // non-volatile variable to save code size.
  byte lAddress = (address&~(1<<7))>>2;
  if (writeRequest && writeProtect &&
      lAddress != 13) // 13 == update write-protect register
    return true; // nothing to be done
  if (lAddress < 8) {
    // Little endian clock data byte
    cli(); // Ensure that reads/writes are atomic.
    if (writeRequest) {
      lAddress = (lAddress&0x03)<<3;
      seconds &= ~((unsigned long)0xff<<lAddress);
      seconds |= (unsigned long)serialData<<lAddress;
    } else {
      lAddress = (lAddress&0x03)<<3;
      serialData = (seconds>>lAddress)&0xff;
      // Fall through to send data to host.
    }
    sei();
  } else if (lAddress < 12) {
    // Group 2 register
    lAddress = (lAddress&0x03) + group2Base;
    if (writeRequest)
      pram[lAddress] = serialData;
    else {
      serialData = pram[lAddress];
      // Fall through to send data to host.
    }
  } else if (lAddress < 16) {
    if (writeRequest) {
      if (lAddress == 12) // test write, do nothing
        ;
      else if (lAddress == 13) {
        // Update the write-protect register.
        writeProtect = ((serialData & 0x80)) ? 1 : 0;
      }
      else {
        // Addresses 14 and 15 are used for the encoding of the first
        // byte of an extended command.  Therefore, interpretation as
        // a traditional PRAM command is invalid.
      }
    } else
      return false; // invalid command
  } else {
    // Group 1 register
    lAddress = (lAddress&0x0f) + group1Base;
    if (writeRequest)
      pram[lAddress] = serialData;
    else {
      serialData = pram[lAddress];
      // Fall through to send data to host.
    }
  }

  return true;
}

void loop(void)
{
  if ((PINB&(1<<RTC_ENABLE_PIN))) {
    clearState();
  } else {
    /* Normally we only perform an action on the falling edge of the
       serial clock.

       If we instead program to use the rising edge for almost all
       actions, we have an exception: Cleanup at the last cycle of
       serial output, there we wait one full cycle and then until the
       falling edge before switching the direction of the data pin
       back to an input.  */
    /* if (serClockFalling &&
        serialState == SENDING_DATA &&
        serialBitNum >= 9) {
      clearState();
    } else */ if (serClockFalling) {
      bool8_t writeRequest;
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
          // Execute the command.
          if (!execTradPramCmd(false)) {
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

        // Execute the command.
        execTradPramCmd(true);
        // Finished with the write command.
        clearState();
        break;

      case SENDING_DATA:
        if (serialBitNum <= 7)
          digitalWriteOD(SERIAL_DATA_PIN,
                         bitRead(serialData, 7 - serialBitNum));
        serialBitNum++;
        if (serialBitNum >= 9)
          clearState();

        /* NOTE: The last output cycle is treated specially if we act
           on the rising edge of the clock, hold the data line as an
           output for at least one full next cycle, then until the
           falling edge of the serial clock, then switch back to an
           input and reset the serial communication state.  It's for
           bug compatibility with the ROM, but with a little bit of
           sanity too.

           However, for the time being, I've changed the code so all
           actuions are preformed on the falling edge of the clock.
           This seems to make things more consistent/robust given the
           documented errors in the Macintosh ROM.  */
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
          serialData = 0;
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
        if (!writeProtect)
          pram[address] = serialData;
        // Finished with the write command.
        clearState();
        break;
#endif

      default:
        // Invalid state.
        clearState();
        break;
      }
    }

    // Clear the edge trigger flags now that the events have been
    // processed.
    serClockRising = false;
    serClockFalling = false;
  }

  // Go to sleep until the next RTC enable or serial clock
  // rising/falling edge.
  set_sleep_mode(0); // Sleep mode 0 == default, timers still running.
  sleep_mode();
}

/*
 * Actually attach the interrupt functions
 */
ISR(PCINT0_vect)
{
  handleRTCEnableInterrupt();
  handleSerClockInterrupt();
}

ISR(TIMER0_OVF_vect)
{
  oflowInterrupt();
}

// Arduino main function.
int main(void)
{
  setup();

  for (;;) {
    loop();
  }

  return 0;
}
