/* Public Domain Release: CC0 1.0 Universal.

   For more information, please see
   <http://creativecommons.org/publicdomain/zero/1.0/>
*/

#include <avr/io.h>
#include <avr/wdt.h>
#include <avr/interrupt.h>
#include <avr/sleep.h>

/********************************************************************/
// Simplified Arduino.h definitions.
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
const int  PRAM_SIZE = 20;
const int group1Base = 0x00;
const int group2Base = 0x10;
#else
// Mac Plus used the xPRAM chip with 256 bytes
const int  PRAM_SIZE = 256;
const int group1Base = 0x10;
const int group2Base = 0x08;
#endif

volatile boolean lastSerClock = 0;
volatile byte serialBitNum = 0;
volatile byte address = 0;
volatile byte xaddr = 0; // xPRAM extended address byte
volatile byte serialData = 0;

enum SerialStateType { SERIAL_DISABLED, RECEIVING_COMMAND,
                       SENDING_DATA, RECEIVING_DATA,
                       RECEIVING_XCMD_ADDR, RECEIVING_XCMD_DATA };
volatile SerialStateType serialState = SERIAL_DISABLED;

// Number of seconds since midnight, January 1, 1904.  Clock is
// initialized to January 1st, 1984?  Or is this done by the ROM when
// the validity status is invalid?
volatile unsigned long seconds = 60 * 60 * 24 * (365 * 4 + 1) * 20;
volatile byte pram[PRAM_SIZE] = {}; // PRAM initialized as zeroed data

#define shiftReadPB(output, bitNum, portBit) \
  bitWrite(output,bitNum, (PINB&_BV(portBit)) ? 1 : 0)

void setup() {
  cli(); // Disable interrupts while we set things up

  // OUTPUT: The 1Hz square wave (used for interrupts elsewhere in the system)
  DDRB |= ONE_SEC_PIN;
  // INPUT_PULLUP: The processor pulls this pin low when it wants access
  DDRB &= ~RTC_ENABLE_PIN;
  PORTB |= RTC_ENABLE_PIN;
  // INPUT_PULLUP: The serial clock is driven by the processor
  DDRB &= ~SERIAL_CLOCK_PIN;
  PORTB |= SERIAL_CLOCK_PIN;
  // INPUT_PULLUP: We'll need to switch this to output when sending data
  DDRB &= ~SERIAL_DATA_PIN;
  PORTB |= SERIAL_DATA_PIN;

  wdt_disable();      // Disable watchdog
  bitSet(ACSR,ACD);   // Disable Analog Comparator, don't need it, saves power
  bitSet(PRR,PRTIM1); // Disable Timer 1, only using Timer 0, Timer 1 uses around ten times as much current
  bitSet(PRR,PRUSI);  // Disable Universal Serial Interface, using Apple's RTC serial interface on pins 6 and 7
  bitSet(PRR,PRADC);  // Disable Analog/Digital Converter

  bitSet(GIMSK,PCIE);   // Pin Change Interrupt Enable
  bitSet(PCMSK,PCINT0); // turn on RTC enable interrupt

  //set up timer
  bitSet(GTCCR,TSM);    // Turns off timers while we set it up
  bitSet(TIMSK,TOIE0);  // Set Timer/Counter0 Overflow Interrupt Enable
  TCCR0B = 0b111;       // Set prescaler, 32,768Hz/64 = 512Hz, fills up the 8-bit counter (256) once every half second
  TCNT0 = 0;            // Clear the counter
  bitClear(GTCCR,TSM);  // Turns timers back on

  sei(); //We're done setting up, enable those interrupts again
}

void clearState() {
  // Return the pin to input mode, set pullup resistor
  cli();
  DDRB &= ~SERIAL_DATA_PIN;
  PORTB |= SERIAL_DATA_PIN;
  sei();
  serialState = SERIAL_DISABLED;
  lastSerClock = 0;
  serialBitNum = 0;
  address = 0;
  serialData = 0;
}

/*
 * An interrupt to both increment the seconds counter and generate the
 * square wave
 */
void halfSecondInterrupt() {
  PINB = 1<<ONE_SEC_PIN;  // Flip the one-second pin
  if(!(PINB&(1<<ONE_SEC_PIN))) { // If the one-second pin is low
    seconds++;
  }
}

/*
 * The actual serial communication can be done in the main loop, this
 * way the clock still gets incremented
 */
void handleRTCEnableInterrupt() {
  if(!(PINB&(1<<RTC_ENABLE_PIN))){ // Simulates a falling interrupt
    serialState = RECEIVING_COMMAND;
    // enableRTC = true;
  }
}

void loop() {
  if((PINB&(1<<RTC_ENABLE_PIN))) {
    clearState();
    set_sleep_mode(0); // Sleep mode 0 == default, timers still running.
    sleep_mode();
  } else {
    // Compute rising and falling edge trigger flags for the serial
    // clock.
    boolean curSerClock = PINB&(1<<SERIAL_CLOCK_PIN);
    boolean serClockRising = !lastSerClock && curSerClock;
    boolean serClockFalling = lastSerClock && !curSerClock;
    lastSerClock = curSerClock;

    // TODO FIXME: We need to implement an artificial delay between
    // the clock's rising edge and the update of the data line output
    // because of a bug in the ROM.  Is 10 microseconds a good wait
    // time?  Or, here's what we can do.  We keep the old value for as
    // long as the clock is high, and we only load the new value
    // immediately once the clock goes low, i.e. that's how we handle
    // the trailing edge event.

    if(serClockRising) {
      switch(serialState) {


      case RECEIVING_COMMAND:
        shiftReadPB(address,7-serialBitNum,SERIAL_DATA_PIN);
        serialBitNum++;
        if(serialBitNum > 7) {
          boolean writeRequest = address&(1<<7);  // the MSB determines if it's a write request or not
          address &= ~(1<<7); // Discard the first bit, it's not part of the address
          serialBitNum = 0;
          if(writeRequest) {
            serialState = RECEIVING_DATA;
            serialBitNum = 0;
          } else {
            if (address < 4) {
              serialData = (seconds>>(8*address))&0xff;
            } if(!(address&0b0110000)) { // Apparently this address range is off-limits for reading
              serialData = pram[address];
            }
            serialState = SENDING_DATA;
            serialBitNum = 0;
            // Set the pin to output mode
            cli();
            DDRB |= SERIAL_DATA_PIN;
            sei();
          }
        }
        break;

      case RECEIVING_DATA:
        shiftReadPB(serialData,7-serialBitNum,SERIAL_DATA_PIN);
        serialBitNum++;
        if(serialBitNum > 7) {
          if(address < 4) {
            cli(); // Don't update the seconds counter while we're updating it, bad stuff could happen
            seconds = (seconds & ~(((long)0xff)<<address)) | (((long)serialData)<<address);
            sei();
          } else {
            pram[address] = serialData;
          }
          clearState();
        }
        break;

      case SENDING_DATA:
        {
          uint8_t bit = _BV(SERIAL_DATA_PIN);
          uint8_t val = bitRead(serialData,7-serialBitNum);
          cli();
          if (val == 0)
            PORTB &= ~bit;
          else
            PORTB |= bit;
          sei();
        }
        serialBitNum++;
        if(serialBitNum > 7) {
          clearState();
        }
        break;

      case RECEIVING_XCMD_ADDR:
        break;

      case RECEIVING_XCMD_DATA:
        break;
      }
    }
  }
}

/*
 * Actually attach the interrupt functions
 */
ISR(PCINT0_vect) {
  handleRTCEnableInterrupt();
}

ISR(TIMER0_OVF) {
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
