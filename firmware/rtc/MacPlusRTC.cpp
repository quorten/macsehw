#include <avr/wdt.h>
#include <avr/interrupt.h>
#include <EEPROM.h>

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

const int      ONE_SEC_PIN = 1;   // A 1Hz square wave on PB5
const int  RTC_ENABLE_PIN =  5;   // Active low chip enable on PB0
const int  SERIAL_DATA_PIN = 6;   // Bi-directional serial data line on PB1
const int SERIAL_CLOCK_PIN = 7;   // Serial clock input on PB2

const int PRAM_SIZE = 256;        // Mac Plus used the xPRAM chip with 256 bytes, time is a separate 4 additional bytes
//const int PRAM_SIZE = 20;         // Models earlier than the Plus had 20 bytes of PRAM

volatile byte serialBitNum = 0;
volatile byte address = 0;
volatile byte serialData = 0;


enum SerialStateType { SERIAL_DISABLED, RECEIVING_COMMAND, SENDING_DATA, RECEIVING_DATA };
volatile SerialStateType serialState = SERIAL_DISABLED;

volatile unsigned long seconds = 0;
volatile byte pram[PRAM_SIZE] = {}; // 256 Bytes of PRAM, the first four of which count the number of seconds since 1/1/1904

/*
 * The following is potential locations of various bits of PRAM data, none of this is in any way certain:
 *    Sound volume is in pram[0x08]
 *    Alert sound is in param[0x7c - 0x7d]
 *    Machine location and timezone is in pram[0xE4 - 0xEF]
 */


/*
 * An interrupt to both increment the seconds counter and generate the square wave
 */
void halfSecondInterrupt() {
  PINB = 1<<PINB0;  // Flip the one-second pin
  if(!(PINB & (1<<PINB0))) { // If the one-second pin is low
    seconds++;
  }
}

/*
 * The actual serial communication can be done in the main loop, this way the clock still gets incremented
 */
void handleRTCEnableInterrupt() {
  serialBitNum = 0;
  address = 0;
  serialData = 0;
  if(!(PINB&(1<<RTC_ENABLE_PIN))){ // Simulates a falling interrupt
    serialState = RECEIVING_COMMAND;
//    enableRTC = true;
  } else {                         // Simulates a rising interrupt
    clearState();
  }
}

void clearState() {
    DDRB &= ~(1<<DDB1);   // Return the pin to input mode
    PORTB |= (1<<PORTB1); // Set pullup resistor
    serialState = SERIAL_DISABLED;
    serialBitNum = 0;
    address = 0;
    serialData = 0;
}

/*
 * The ATtiny has EEPROM, lets use it to store the contents of PRAM in case of power failure, 
 * this is an improvement over the original, still a good idea to keep the chip powered by a 
 * battery or supercapacitor so that the clock continues to advance.
 * 
 */
void savePRAM() {
  noInterrupts(); // Don't update the seconds counter while we're saving it to ROM, probably unnecessary
  for(int i = 0; i < 4; i++) {
    EEPROM.update(i,(seconds>>(8*i))&0xff);
  }
  interrupts(); // Go ahead and interrupt us while we save the rest
  for(int i = 0; i < PRAM_SIZE; i++) {
    EEPROM.update(i+4,pram[i]);
  }
}


void goToSleep() {
  bitClear(MCUCR,SM0);  // The two SM bits must be set to 00 to enter idle mode
  bitClear(MCUCR,SM1);  // Sleeping in other modes will disable the timer
  bitSet(MCUCR,SE);
  __asm__("sleep" "\n\t");
  bitClear(MCUCR,SE);
}

void setup() {
  noInterrupts(); // Disable interrupts while we set things up
  
  pinMode(ONE_SEC_PIN, OUTPUT);             // The 1Hz square wave (used, I think, for interrupts elsewhere in the system)
  pinMode(RTC_ENABLE_PIN, INPUT_PULLUP);    // The processor pulls this pin low when it wants access
  pinMode(SERIAL_CLOCK_PIN, INPUT_PULLUP);  // The serial clock is driven by the processor
  pinMode(SERIAL_DATA_PIN, INPUT_PULLUP);   // We'll need to switch this to output when sending data
  
  wdt_disable();      // Disable watchdog
  bitSet(ACSR,ACD);   // Disable Analog Comparator, don't need it, saves power
  bitSet(PRR,PRTIM1); // Disable Timer 1, only using Timer 0, Timer 1 uses around ten times as much current
  bitSet(PRR,PRUSI);  // Disable Universal Serial Interface, using Apple's RTC serial interface on pins 6 and 7
  bitSet(PRR,PRADC);  // Disable Analog/Digital Converter

  bitSet(GIMSK,PCIE);   // Pin Change Interrupt Enable
  bitSet(PCMSK,PCINT0); // turn on RTC enable interrupt

//  for(int i = 0; i < 4; i++) {
//    seconds += ((unsigned long)EEPROM.read(i))<<(8*i);
//  }
//  for(int i = 0; i < PRAM_SIZE; i--) { // Preload PRAM with saved values
//    pram[i] = EEPROM.read(i+4);
//  }
  
  //set up timer
  bitSet(GTCCR,TSM);    // Turns off timers while we set it up
  bitSet(TIMSK,TOIE0);  // Set Timer/Counter0 Overflow Interrupt Enable
  TCCR0B = 0b111;       // Set prescaler, 32,768Hz/64 = 512Hz, fills up the 8-bit counter (256) once every half second
  TCNT0 = 0;            // Clear the counter
  bitClear(GTCCR,TSM);  // Turns timers back on
  
  interrupts(); //We're done setting up, enable those interrupts again
}

void loop() {
  if(digitalRead(RTC_ENABLE_PIN)) {
    clearState();
    goToSleep(); 
  } else if(digitalRead(SERIAL_CLOCK_PIN)) {
    switch(serialState) {
      
      case RECEIVING_COMMAND:
        bitWrite(address,7-serialBitNum,digitalRead(SERIAL_DATA_PIN));
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
            pinMode(SERIAL_DATA_PIN, OUTPUT); // Set the pin to output mode
          }
        }
        break;
        
      case RECEIVING_DATA:
        bitWrite(serialData,7-serialBitNum,digitalRead(SERIAL_DATA_PIN));
        serialBitNum++;
        if(serialBitNum > 7) {
          if(address < 4) {
            noInterrupts(); // Don't update the seconds counter while we're updating it, bad stuff could happen
            seconds = (seconds & ~(((long)0xff)<<address)) | (((long)serialData)<<address);
            interrupts();
          } else {
            pram[address] = serialData;
          }
//          savePRAM();
          clearState();
        }
        break;
        
      case SENDING_DATA:
        digitalWrite(SERIAL_DATA_PIN,bitRead(serialData,7-serialBitNum));
        serialBitNum++;
        if(serialBitNum > 7) {
          clearState();
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
