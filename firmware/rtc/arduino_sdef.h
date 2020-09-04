#ifndef ARDUINO_SDEF_H
#define ARDUINO_SDEF_H

/********************************************************************/
// Simplified Arduino.h definitions.
typedef bool boolean;
typedef uint8_t byte;

#define HIGH 0x1
#define LOW  0x0

#define INPUT 0x0
#define OUTPUT 0x1
#define INPUT_PULLUP 0x2

#define interrupts() sei()
#define noInterrupts() cli()

#define bitRead(value, bit) (((value) >> (bit)) & 0x01)
#define bitSet(value, bit) ((value) |= (1UL << (bit)))
#define bitClear(value, bit) ((value) &= ~(1UL << (bit)))
#define bitWrite(value, bit, bitvalue) ((bitvalue) ? bitSet(value, bit) : bitClear(value, bit))
// END simplified Arduino.h definitions.

/********************************************************************/
// Simplified wiring_digital.c definitions.
// Only suitable for single source code file projects.

void pinModePB(uint8_t portbit, uint8_t mode)
{
	uint8_t bit = _BV(portbit);

	if (mode == INPUT) {
		uint8_t oldSREG = SREG;
                cli();
		DDRB &= ~bit;
		PORTB &= ~bit;
		SREG = oldSREG;
	} else if (mode == INPUT_PULLUP) {
		uint8_t oldSREG = SREG;
                cli();
		DDRB &= ~bit;
		PORTB |= bit;
		SREG = oldSREG;
	} else {
		uint8_t oldSREG = SREG;
                cli();
		DDRB |= bit;
		SREG = oldSREG;
	}
}

void digitalWritePB(uint8_t portbit, uint8_t val)
{
	uint8_t bit = _BV(portbit);

	uint8_t oldSREG = SREG;
	cli();

	if (val == LOW) {
		PORTB &= ~bit;
	} else {
		PORTB |= bit;
	}

	SREG = oldSREG;
}

int digitalReadPB(uint8_t portbit)
{
	uint8_t bit = _BV(portbit);

	if (PINB & bit) return HIGH;
	return LOW;
}
// END simplified wiring_digital.c definitions.

#endif /* not ARDUINO_SDEF_H */
