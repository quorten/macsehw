/* A very simple RTC test interface program.  */

/* First of all, we expose a similar software interface that the
   original Macintosh had through the VIA hardware registers.

   * VIA base address = vBase = VIA

   * Data register B, offset from VIA base = vBufB:

     Bit 2: rtcEnb
     Bit 1: rtcClk
     Bit 0: rtcData

   * Direction register B, offset = vDirB: Same layout as data
     register B.

   Finally, the one-second interrupt enable and one-second interrupt
   signal.  Let's just go really basic on that, yeah there's registers
   for that, they are separate and they have the name peripheral in
   them.

   Then, for the sake of software test, we plug in our own software
   program that exposes a text user interface through a serial
   terminal.  Yes, keep it simple but reasonably user-friendly.  We
   provide a set of command-line commands to encode/decode data,
   send/receive serial communications, and to top it off, a high-level
   Apple II monitor interface.  And, by virtue of being a
   command-line, it allows the easy scripting of test suites.

   By default, the command-line command runs the non-interactive test
   script.  Use the `-i` command-line option to run in interactive
   mode.  The Apple II monitor interface is disabled by default, it
   must be enabled and the "address space" set to either traditional
   PRAM or XPRAM.

   We also expose a Macintosh-style PRAM interface where the PRAM
   registers arae pre-copied into host memory.

   Finally, not only is this good for testing a design on a test
   bench, but through the use of different driver back-ends, you can
   make an integrated Raspberry Pi system that can be used to dump out
   the contents of an existing PRAM chip using an IC clip, remove
   power, then restore the contents, like you might do during a
   battery replacement.  Okay... so now that I mentioned it, there's
   an easier way.  Of course.  Put an IC clip on the RTC while you are
   changing the battery.  You provide diode power through the IC clip,
   so you can change the battery without loosing a beat.

*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
// Define for strptime():
#define __USE_XOPEN
#include <time.h>
#include <signal.h>
#include <pthread.h>
#include <sys/mman.h>
#include <sys/epoll.h>

#include "sim_avr.h"
#include "avr_ioport.h"
#include "avr_timer.h"
#include "sim_elf.h"
#include "sim_gdb.h"
#include "sim_vcd_file.h"

/********************************************************************/
/* Simplified Arduino definitions support module header */

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned uint32_t;
typedef enum { false, true } bool;

typedef uint8_t byte;
typedef bool boolean;
typedef uint8_t bool8_t;

#define bitRead(value, bit) (((value) >> (bit)) & 0x01)
#define bitSet(value, bit) ((value) |= (1UL << (bit)))
#define bitClear(value, bit) ((value) &= ~(1UL << (bit)))
#define bitWrite(value, bit, bitvalue) ((bitvalue) ? bitSet(value, bit) : bitClear(value, bit))

/********************************************************************/
/* Miniature Apple II monitor module header */

/* Apple II monitor mode: 0 = disable, 1 = traditional PRAM, 2 =
   XPRAM.  XPRAM monitor mode is only valid when the host PRAM is
   configured likewise, of course.  */
uint8_t monMode = 0;

/********************************************************************/
/* `simavr` support module header */

/* Note that the test bench's input is the RTC's output.  Input and
   output here are specified from the perspective of the RTC.  */
enum BenchIrqs { IRQ_SEC1, IRQ_CE, IRQ_CLK, IRQ_DATA_IN, IRQ_DATA_OUT };

extern avr_t *avr;
extern avr_irq_t *bench_irqs;

/********************************************************************/
/* Raspberry Pi GPIO module */

/*
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>
*/

unsigned int *gpio_mem;

/* From BCM2835 data-sheet, p.91 */
const unsigned GPREGS_BASE     = 0x7e200000;
/* N.B. To avoid memory alignment issues, we change these to 32-bit
   integer offsets.  */
const unsigned GPFSEL_OFFSET   = 0x00 >> 2;
const unsigned GPSET_OFFSET    = 0x1c >> 2;
const unsigned GPCLR_OFFSET    = 0x28 >> 2;
const unsigned GPLEV_OFFSET    = 0x34 >> 2;
const unsigned GPEDS_OFFSET    = 0x40 >> 2;
const unsigned GPREN_OFFSET    = 0x4c >> 2;
const unsigned GPFEN_OFFSET    = 0x58 >> 2;
const unsigned GPHEN_OFFSET    = 0x64 >> 2;
const unsigned GPLEN_OFFSET    = 0x70 >> 2;
const unsigned GPAREN_OFFSET   = 0x7c >> 2;
const unsigned GPAFEN_OFFSET   = 0x88 >> 2;
const unsigned GPPUD_OFFSET    = 0x94 >> 2;
const unsigned GPPUDCLK_OFFSET = 0x98 >> 2;
const unsigned char N = 4;

enum {
  GPFN_INPUT,
  GPFN_OUTPUT,
  GPFN_ALT5,
  GPFN_ALT4,
  GPFN_ALT0,
  GPFN_ALT1,
  GPFN_ALT2,
  GPFN_ALT3,
};

enum {
  GPUL_OFF,
  GPUL_DOWN,
  GPUL_UP,
};

int
rpi_gpio_init (void)
{
  int result;
  int fd = open ("/dev/gpiomem", O_RDWR | O_SYNC);
  if (fd == -1)
    return 0;
  gpio_mem = mmap (NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  if (gpio_mem == (unsigned int*)-1)
    return 0;
  return 1;
}

void
rpi_gpio_set_fn (unsigned char idx, unsigned char fn)
{
  unsigned word_idx = idx / 10;
  unsigned int wordbuf = gpio_mem[GPFSEL_OFFSET+word_idx];
  wordbuf &= ~(0x07 << ((idx % 10) * 3));
  wordbuf |= (fn & 0x07) << ((idx % 10) * 3);
  gpio_mem[GPFSEL_OFFSET+word_idx] = wordbuf;
}

void
rpi_gpio_set_pull (unsigned char idx, unsigned char pull)
{
  unsigned int wordbuf;
  unsigned i;
  gpio_mem[GPPUD_OFFSET] = (unsigned int)pull & 0x03;
  /* Wait at least 150 cycles.  */
  for (i = 150; i > 0; i--);
  wordbuf = 1 << idx;
  gpio_mem[GPPUDCLK_OFFSET] = wordbuf;
  /* Wait at least 150 cycles.  */
  for (i = 150; i > 0; i--);
  gpio_mem[GPPUD_OFFSET] = (unsigned int)GPUL_OFF;
  gpio_mem[GPPUDCLK_OFFSET] = 0;
}

void
rpi_gpio_set_pin (unsigned char idx, unsigned char val)
{
  /* N.B. Do not read the current value and use that to set the new
     value else you get problems with random junk.  Only set/clear the
     value you want to change.  */
  if (val) { /* set the pin to 1 */
    unsigned int wordbuf = gpio_mem[GPSET_OFFSET];
    /* wordbuf |= 1 << idx; */
    wordbuf = 1 << idx;
    gpio_mem[GPSET_OFFSET] = wordbuf;
  } else { /* clear the pin to zero */
    unsigned int wordbuf = gpio_mem[GPCLR_OFFSET];
    /* wordbuf |= 1 << idx; */
    wordbuf = 1 << idx;
    gpio_mem[GPCLR_OFFSET] = wordbuf;
  }
}

unsigned char
rpi_gpio_get_pin (unsigned char idx)
{
  unsigned int wordbuf = gpio_mem[GPLEV_OFFSET];
  /* N.B. Interpret the values as follows.  The value of the pin is
     the current flowing through the pull-up/down termination.  For
     example:

     * If you have pull-up termination, the value is one when the
       switch is open, zero when the switch is closed.

     * If you have pull-down termination, the value is zero when the
       switch is open, one when the switch is closed.  */
  return (wordbuf >> idx) & 1;
}

unsigned char
rpi_gpio_get_pin_event (unsigned char idx)
{
  unsigned int wordbuf = gpio_mem[GPEDS_OFFSET];
  return (wordbuf >> idx) & 1;
}

void
rpi_gpio_clear_pin_event (unsigned char idx)
{
  gpio_mem[GPEDS_OFFSET] = 1 << idx;
}

/* Watch for rising edge.  */
void
rpi_gpio_watch_re (unsigned char idx)
{
  gpio_mem[GPREN_OFFSET] |= 1 << idx;
}

void
rpi_gpio_unwatch_re (unsigned char idx)
{
  gpio_mem[GPREN_OFFSET] &= ~(1 << idx);
}

/* Watch for falling edge.  */
void
rpi_gpio_watch_fe (unsigned char idx)
{
  gpio_mem[GPFEN_OFFSET] |= 1 << idx;
}

void
rpi_gpio_unwatch_fe (unsigned char idx)
{
  gpio_mem[GPFEN_OFFSET] &= ~(1 << idx);
}

/* Watch for asynchronous rising edge.  */
void
rpi_gpio_watch_async_re (unsigned char idx)
{
  gpio_mem[GPAREN_OFFSET] |= 1 << idx;
}

void
rpi_gpio_unwatch_async_re (unsigned char idx)
{
  gpio_mem[GPAREN_OFFSET] &= ~(1 << idx);
}

/* Watch for asynchronous falling edge.  */
void
rpi_gpio_watch_async_fe (unsigned char idx)
{
  gpio_mem[GPAFEN_OFFSET] |= 1 << idx;
}

void
rpi_gpio_unwatch_async_fe (unsigned char idx)
{
  gpio_mem[GPAFEN_OFFSET] &= ~(1 << idx);
}

/********************************************************************/
/* Linux GPIO interrupts support module */

/* Linux `epoll` is an ugly way to get GPIO interrupts into
   user-space, but it works and it is relativelly old/stable.  Matter
   of fact, Raspbian was first released without any Linux kernel
   support for GPIO interrupts in user-space, despite the hardware
   having the capability.  As soon as the software capability was
   added in `epoll` and `gpio-keys`, those were the first of their
   kind on that platform.  So, that's the word.

   Only bothers with the Linux `sysfs` filesystem manipulation as much
   as it is required to get interrupts into user-space.  Use
   memory-mapped BCM2835 registers in your own code to configure the
   rest for Raspberry Pi.

   Only a single GPIO pin is supported for interrupt wait-and-notify.
   To support more than one thread, though, we simply use a single
   epfd_thread descriptor (likewise only a single wait-notify thread)
   and then open and add one file descriptor per GPIO pin.  Adding
   watches on all read pins can be particularly useful for producing
   VCD files for poor man's oscilloscope analysis of Apple's custom
   silicon RTC.
*/

/*
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <pthread.h>
#include <sys/epoll.h>

#include "arduino_sdef.h"
*/

int g_gpio_num;
pthread_t g_epoll_thread;
bool8_t g_thread_running = false;
bool8_t g_thread_initial = true;
int g_gpio_fd = -1;
int epfd_thread = -1;

void sec1Isr(void);

void *lingpirq_poll_thread(void *thread_arg)
{
  struct epoll_event events;
  char buf;

  g_thread_running = true;
  while (g_thread_running) {
    int result = epoll_wait(epfd_thread, &events, 1, -1);
    if (result > 0) {
      lseek(events.data.fd, 0, SEEK_SET);
      if (read(events.data.fd, &buf, 1) != 1) {
        g_thread_running = false;
        pthread_exit((void*)0);
      }
      if (g_thread_initial) // ignore first epoll trigger
        g_thread_initial = false;
      else
        sec1Isr();
    } else if (result == -1) {
      if (errno == EINTR)
        continue;
      g_thread_running = false;
      pthread_exit((void*)0);
    }
  }

  pthread_exit((void*)0);
}

bool8_t lingpirq_setup(int gpio_num)
{
  struct epoll_event ev;

  char cmd[64];
  char filename[64];
  g_gpio_num = gpio_num;
  epfd_thread = -1;
  snprintf(cmd, sizeof(cmd), "echo %d >/sys/class/gpio/export", g_gpio_num);
  if (system(cmd) != 0)
    return false; /* error */
  snprintf(filename, sizeof(filename), "/sys/class/gpio/gpio%d", g_gpio_num);

  g_gpio_fd = open(filename, O_RDONLY | O_NONBLOCK);
  if (g_gpio_fd < 0)
    goto cleanup_fail; /* error */

  // Create and configure an `epoll` for the GPIO file descriptor.
  epfd_thread = epoll_create(1);
  if (epfd_thread == -1)
    goto cleanup_fail; /* error */
  ev.events = EPOLLIN | EPOLLET | EPOLLPRI;
  ev.data.fd = g_gpio_fd;
  if (epoll_ctl(epfd_thread, EPOLL_CTL_ADD, g_gpio_fd, &ev) == -1)
    goto cleanup_fail; /* error */

  // Create the wait-and-notify thread.
  if (pthread_create(&g_epoll_thread, NULL,
                     lingpirq_poll_thread, (void*)0) != 0)
    goto cleanup_fail; /* error */

  return true; /* success */
 cleanup_fail:
  close(epfd_thread);
  close(g_gpio_fd);
  snprintf(cmd, sizeof(cmd), "echo %d >/sys/class/gpio/unexport", g_gpio_num);
  system(cmd);
  return false;
}

void lingpirq_cleanup(void)
{
  struct epoll_event ev;
  char cmd[64];
  ev.events = EPOLLIN | EPOLLET | EPOLLPRI;
  ev.data.fd = g_gpio_fd;
  close(g_gpio_fd);
  epoll_ctl(epfd_thread, EPOLL_CTL_DEL, g_gpio_fd, &ev);
  close(epfd_thread);

  close(g_gpio_fd);
  snprintf(cmd, sizeof(cmd), "echo %d >/sys/class/gpio/unexport", g_gpio_num);
  system(cmd);
}

/********************************************************************/
/* VIA emulation module */

/* TODO: Program support for two "drivers" as follows:

   * Raspberry Pi GPIO pin communications driver

   * simavr IRQ pin communications driver

 */

/*
#include <stdlib.h>
#include <time.h>

#include "arduino_sdef.h"
#include "simavr-support.h"
*/

bool8_t simAvrStep(void);
avr_cycle_count_t notify_timeup(avr_t *avr, avr_cycle_count_t when,
                                void *param);

#define rtcEnb 2
#define rtcClk 1
#define rtcData 0

// VIA direction: 0 for input, 1 for output.
const uint8_t DIR_IN = 0;
const uint8_t DIR_OUT = 1;

const uint8_t vBufB = 0;
const uint8_t vDirB = 1;
const uint8_t irqEnb = 2; // Enable a particular interrupt
const uint8_t irqFlags = 3; // Indicates which interrupt triggered

// VIA registers in memory
uint8_t vBase[4];
uint8_t const *VIA = vBase;

bool g_waitTimeUp = true;
uint8_t g_timePoll = 0;

#define viaBitRead(ptr, bit) (bitRead(*(ptr), (bit)))

void viaBitWrite(uint8_t *ptr, uint8_t bit, uint8_t bitvalue)
{
  // Only handle the vBufB and vDirB registers for now.
  if (ptr == vBase + vBufB) {
    // Ensure the direction is correctly configured before sending an
    // output, otherwise do nothing.
    if (bitRead(vBase[vDirB], bit) != DIR_OUT)
      return;
    // Send the signal to the actual hardware.
    switch (bit) {
    case rtcEnb:
      avr_raise_irq(bench_irqs + IRQ_CE, bitvalue & 1);
      break;
    case rtcClk:
      avr_raise_irq(bench_irqs + IRQ_CLK, bitvalue & 1);
      break;
    case rtcData:
      avr_raise_irq(bench_irqs + IRQ_DATA_IN, bitvalue & 1);
      break;
    default:
      break; // unrecognized signals do nothing
    }
  } else if (ptr == vBase + vDirB) {
    // TODO FIXME:

    // The main special handling we do here is to set to the
    // corresponding buffer bit to the input value as soon as we
    // change to an input type.  With the `simavr` setup, we simply
    // set to default logic value 1 and we will get an IRQ if we
    // should do otherwise.
    if (bitvalue == DIR_IN)
      bitWrite(vBase[vBufB], bit, 1);
  } else
    return;
  // Update our register value.
  bitWrite(*ptr, bit, bitvalue);
}

/* Time our wait periods based off of a maximum 500 Hz (minimum 2 ms
   period) clock signal.  That means we need to wait at least 0.5 ms
   (500 us = 500000 ns) for a quarter-cycle wait time.

   PLEASE NOTE: This cautious maximum serial clock speed results in
   considerably slow memory access compared to modern standards.  From
   testing at 32.768 kHz core clock, the speed limit is a 50 Hz serial
   clock, so it takes 128 seconds to write all 256 bytes of XPRAM.
   This should be compared with the speed limits of Apple custom
   silicon RTC.  */
void waitQuarterCycle(void)
{
#ifdef RPI_DRIVER
  struct timespec tv = { 0, 500000 };
  struct timespec tvNext;
  do {
    if (clock_nanosleep(CLOCK_MONOTONIC, 0, &tv, &tvNext) == 0)
      break;
    tv.tv_nsec = tvNext.tv_nsec;
  } while (tv.tv_nsec > 0);
#else
  // Unfortunately, if the AVR runs at 32.768 kHz, I've found from
  // simulation that serial communications are only reliable at an
  // abysmal 50 Hz serial clock speed.  Therefore, running at a higher
  // core speed and using a phase-locked loop on the crystal clock
  // frequency a must.
  struct timespec tv, tvTarget;
  // N.B. Over here we are using cycle timers mainly to prevent
  // simulation waits stretching unbearably long.
  g_timePoll = 16;
  avr_cycle_timer_register(avr, g_timePoll, notify_timeup, NULL);
  clock_gettime(CLOCK_MONOTONIC, &tv);
  tvTarget.tv_nsec = tv.tv_nsec + 500000;
  tvTarget.tv_sec = tv.tv_sec;
  if (tvTarget.tv_nsec >= 1000000000) {
    tvTarget.tv_nsec -= 1000000000;
    tvTarget.tv_sec++;
  }
  while (tv.tv_sec < tvTarget.tv_sec ||
         (tv.tv_sec == tvTarget.tv_sec &&
          tv.tv_nsec < tvTarget.tv_nsec)) {
    if (!simAvrStep())
      break;
    clock_gettime(CLOCK_MONOTONIC, &tv);
  }
  g_timePoll = 0;
#endif
}

void waitHalfCycle(void)
{
  waitQuarterCycle();
  waitQuarterCycle();
}

void waitCycle(void)
{
  waitHalfCycle();
  waitHalfCycle();
}

void waitOneSec(void)
{
#ifdef RPI_DRIVER
  sleep(1);
#else
  struct timespec tv, tvTarget;
  // N.B. Over here we are using cycle timers mainly to prevent
  // simulation waits stretching unbearably long.
  g_timePoll = 16;
  avr_cycle_timer_register(avr, g_timePoll, notify_timeup, NULL);
  clock_gettime(CLOCK_MONOTONIC, &tv);
  tvTarget.tv_nsec = tv.tv_nsec;
  tvTarget.tv_sec = tv.tv_sec + 1;
  while (tv.tv_sec < tvTarget.tv_sec ||
         (tv.tv_sec == tvTarget.tv_sec &&
          tv.tv_nsec < tvTarget.tv_nsec)) {
    if (!simAvrStep())
      break;
    clock_gettime(CLOCK_MONOTONIC, &tv);
  }
  g_timePoll = 0;
#endif
}

/********************************************************************/
/* PRAM C library module */

/*
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
// Define for strptime():
#define __USE_XOPEN
#include <time.h>
#include <pthread.h>

#include "arduino_sdef.h"
#include "via-emu.h"
#include "simavr-support.h"
*/

// PRAM configuration, set to XPRAM by default
int pramSize = 256;
int group1Base = 0x10;
int group2Base = 0x08;

// Host copy of RTC chip memory.  Note that the write-protect register
// cannot be read.
volatile uint32_t timeSecs = 0;
pthread_mutex_t timeSecsMutex;
byte writeProtect = 0;
byte pram[256];

// Delta between Macintosh time epoch and Unix time epoch.  Number of
// seconds between 1904 and 1970 = 16 4-year cycles plus 1 regular
// year plus one leap year.  Does not cross 100-year or 400-year
// boundaries.
const uint32_t macUnixDelta = 60UL * 60 * 24 *
  ((365 * 4 + 1) * 16 + (365 * 2 + 1));

// Initialize the `timeSecs` mutex.
void pramInit(void)
{
  pthread_mutex_init(&timeSecsMutex, NULL);
}

// Destroy the `timeSecs` mutex.
void pramDestroy(void)
{
  pthread_mutex_destroy(&timeSecsMutex);
}

// Configure whether the PRAM should be traditional 20-byte PRAM
// (false) or XPRAM (true).
void setPramType(bool8_t isXPram)
{
  if (isXPram) {
    pramSize = 256;
    group1Base = 0x10;
    group2Base = 0x08;
  } else {
    pramSize = 20;
    group1Base = 0x00;
    group2Base = 0x10;
  }
}

// Return true if the PRAM type is set to XPRAM, false otherwise.
bool8_t getPramType(void)
{
  if (pramSize == 256)
    return true;
  return false;
}

void serialBegin(void)
{
  viaBitWrite(vBase + vDirB, rtcEnb, DIR_OUT);
  viaBitWrite(vBase + vDirB, rtcData, DIR_OUT);
  viaBitWrite(vBase + vDirB, rtcClk, DIR_OUT);
  viaBitWrite(vBase + vBufB, rtcClk, 0);
  viaBitWrite(vBase + vBufB, rtcEnb, 0);
  waitQuarterCycle();
}

void serialEnd(void)
{
  viaBitWrite(vBase + vBufB, rtcEnb, 1);
  waitQuarterCycle();
}

void sendByte(byte data)
{
  uint8_t bitNum = 0;
  viaBitWrite(vBase + vDirB, rtcData, DIR_OUT);
  while (bitNum <= 7) {
    uint8_t bit = (data >> (7 - bitNum)) & 1;
    bitNum++;
    viaBitWrite(vBase + vBufB, rtcData, bit);
    waitQuarterCycle();
    viaBitWrite(vBase + vBufB, rtcClk, 1);
    waitHalfCycle();
    viaBitWrite(vBase + vBufB, rtcClk, 0);
    waitQuarterCycle();
  }
}

byte recvByte(void)
{
  byte serialData = 0;
  uint8_t bitNum = 0;
  viaBitWrite(vBase + vDirB, rtcData, DIR_IN);
  while (bitNum <= 7) {
    uint8_t bit;
    waitQuarterCycle();
    viaBitWrite(vBase + vBufB, rtcClk, 1);
    waitHalfCycle();
    viaBitWrite(vBase + vBufB, rtcClk, 0);
    waitQuarterCycle();
    bit = viaBitRead(vBase + vBufB, rtcData);
    serialData |= bit << (7 - bitNum);
    bitNum++;
  }
  return serialData;
}

byte sendReadCmd(byte cmd)
{
  byte serialData;
  serialBegin();
  sendByte(cmd);
  serialData = recvByte();
  serialEnd();
  return serialData;
}

void sendWriteCmd(byte cmd, byte data)
{
  serialBegin();
  sendByte(cmd);
  sendByte(data);
  serialEnd();
}

byte sendReadXCmd(byte cmd1, byte cmd2)
{
  byte serialData;
  serialBegin();
  sendByte(cmd1);
  sendByte(cmd2);
  serialData = recvByte();
  serialEnd();
  return serialData;
}

void sendWriteXCmd(byte cmd1, byte cmd2, byte data)
{
  serialBegin();
  sendByte(cmd1);
  sendByte(cmd2);
  sendByte(data);
  serialEnd();
}

// Perform a test write, does nothing since there is no indication if
// it succeeds.
void testWrite(void)
{
  sendWriteCmd(0x30, 0x80);
}

// Set the write-protect register on the RTC.
void setWriteProtect(void)
{
  sendWriteCmd(0x34, 0x80);
  writeProtect = 1;
}

// Clear the write-protect register on the RTC.
void clearWriteProtect(void)
{
  sendWriteCmd(0x34, 0x00);
  writeProtect = 0;
}

/* Copy the time from RTC to host.  The time is read twice and
   compared for equality to verify a consistent read.  If the read is
   inconsistent, this function will retry up to a maximum of 4 times
   before returning failure.  */
bool8_t dumpTime(void)
{
  uint8_t retry = 0;
  uint32_t newTime1, newTime2;

  while (retry < 4) {
    newTime1 = 0; newTime2 = 0;

    newTime1 |= sendReadCmd(0x80);
    newTime1 |= sendReadCmd(0x84) << 8;
    newTime1 |= sendReadCmd(0x88) << 16;
    newTime1 |= sendReadCmd(0x8c) << 24;

    newTime2 |= sendReadCmd(0x90);
    newTime2 |= sendReadCmd(0x94) << 8;
    newTime2 |= sendReadCmd(0x98) << 16;
    newTime2 |= sendReadCmd(0x9c) << 24;

    if (newTime1 == newTime2) {
      pthread_mutex_lock(&timeSecsMutex);
      timeSecs = newTime1;
      pthread_mutex_unlock(&timeSecsMutex);
      return true;
    }

    retry++;
  }

  return false;
}

// Clear write-protect and copy the time from host to RTC.
void loadTime(void)
{
  byte serialData = 0;
  clearWriteProtect();
  serialData = timeSecs & 0xff;
  sendWriteCmd(0x00, serialData);
  serialData = (timeSecs >> 8) & 0xff;
  sendWriteCmd(0x04, serialData);
  serialData = (timeSecs >> 16) & 0xff;
  sendWriteCmd(0x08, serialData);
  serialData = (timeSecs >> 24) & 0xff;
  sendWriteCmd(0x0c, serialData);
}

// Set the host time to the given new time and propagate it to the
// RTC.  Also clears write-protect.
void setTime(uint32_t newTimeSecs)
{
  pthread_mutex_lock(&timeSecsMutex);
  timeSecs = newTimeSecs;
  pthread_mutex_unlock(&timeSecsMutex);
  loadTime();
}

// Accessor function to return the current host time copy.
uint32_t getTime(void)
{
  return timeSecs;
}

// 1-second interrupt service routine, increment the current time.
void sec1Isr(void)
{
  pthread_mutex_lock(&timeSecsMutex);
  timeSecs++;
  pthread_mutex_unlock(&timeSecsMutex);
}

// Convert Macintosh numeric time into ISO 8601 format (YYYY-MM-DD
// HH:MM:SS) string time.
void macToStrTime(char *outBuf, size_t outBufLen, uint32_t macTime)
{
  time_t unixTime = macTime - macUnixDelta;
  struct tm calTime;
  gmtime_r(&unixTime, &calTime);
  strftime(outBuf, outBufLen, "%Y-%m-%d %H:%M:%S", &calTime);
}

// Convert ISO 8601 format (YYYY-MM-DD HH:MM:SS) string time into
// Macintosh numeric time.  On error, returns zero.
uint32_t strToMacTime(const char *strBuf)
{
  struct tm calTime;
  char *envOldTz;
  char oldTz[16];
  time_t unixTime;
  if (strptime(strBuf, "%Y-%m-%d %H:%M:%S", &calTime) == NULL)
    return 0;
  // Ensure there is no timezone correction.
  envOldTz = getenv("TZ");
  if (envOldTz != NULL)
    strncpy(oldTz, envOldTz, 16);
  oldTz[15] = '\0';
  setenv("TZ", "UTC", 1);
  unixTime = mktime(&calTime);
  if (envOldTz == NULL)
    unsetenv("TZ");
  else
    setenv("TZ", oldTz, 1);
  return unixTime + macUnixDelta;
}

// Set the host time to the new time given as a string and propagate
// it to the RTC.  Also clears write-protect.  If the time string is
// invalid, no changes are made.
void setStrTime(const char *strBuf)
{
  uint32_t newTimeSecs = strToMacTime(strBuf);
  if (newTimeSecs == 0)
    return; // error
  setTime(newTimeSecs);
}

// Accessor function to return the current host time copy, formatted
// as a string.
void getStrTime(char *outBuf, size_t outBufLen)
{
  macToStrTime(outBuf, outBufLen, getTime());
}

// Set the RTC to the current Unix time.  Also clears write-protect.
void setCurTime(void)
{
  time_t unixTime = time(NULL);
  struct tm calTime;
  char *envOldTz;
  char oldTz[16];
  // Ensure we apply the proper timezone offset to get local epoch
  // time.
  localtime_r(&unixTime, &calTime);
  envOldTz = getenv("TZ");
  if (envOldTz != NULL)
    strncpy(oldTz, envOldTz, 16);
  oldTz[15] = '\0';
  setenv("TZ", "UTC", 1);
  unixTime = mktime(&calTime);
  if (envOldTz == NULL)
    unsetenv("TZ");
  else
    setenv("TZ", oldTz, 1);
  setTime(unixTime + macUnixDelta);
}

// Convenience function to generate a traditional PRAM command from
// logical command address and write-request flag.  `addr` must not
// exceed 0x1f.
byte genCmd(byte addr, bool8_t writeRequest)
{
  return ((!writeRequest) << 7) | (addr << 2);
}

byte genSendReadCmd(byte addr)
{
  return sendReadCmd(genCmd(addr, false));
}

void genSendWriteCmd(byte addr, byte data)
{
  sendWriteCmd(genCmd(addr, true), data);
}

// Copy all traditional 20-byte PRAM memory from RTC to host.
void dumpAllTradMem(void)
{
  uint8_t i;
  // Copy group 2 registers.
  for (i = 0; i < 4; i++) {
    pram[group2Base+i] = genSendReadCmd(8 + i);
  }
  // Copy group 1 registers.
  for (i = 0; i < 16; i++) {
    pram[group1Base+i] = genSendReadCmd(16 + i);
  }
}

// Clear write-protect and copy all traditional 20-byte PRAM memory
// from host to RTC.
void loadAllTradMem(void)
{
  uint8_t i;
  clearWriteProtect();
  // Copy group 2 registers.
  for (i = 0; i < 4; i++) {
    genSendWriteCmd(8 + i, pram[group2Base+i]);
  }
  // Copy group 1 registers.
  for (i = 0; i < 16; i++) {
    genSendWriteCmd(16 + i, pram[group1Base+i]);
  }
}

// Generate an extended command from a byte address.  The first byte
// to send is the most significant byte in the returned 16-bit
// integer.
uint16_t genXCmd(byte addr, bool8_t writeRequest)
{
  uint16_t xcmd = 0x3800 | ((addr & 0xe0) << 3) | ((addr & 0x1f) << 2);
  if (!writeRequest)
    xcmd |= 0x8000;
  return xcmd;
}

// Generate and send and extended read command from a byte address.
byte genSendReadXCmd(byte addr)
{
  uint16_t xcmd = genXCmd(addr, false);
  return sendReadXCmd((xcmd >> 8) & 0xff, xcmd & 0xff);
}

// Generate and send and extended write command from a byte address.
void genSendWriteXCmd(byte addr, byte data)
{
  uint16_t xcmd = genXCmd(addr, true);
  return sendWriteXCmd((xcmd >> 8) & 0xff, xcmd & 0xff, data);
}

// Copy all XPRAM memory from RTC to host.
void dumpAllXMem(void)
{
  uint8_t i = 0;
  do {
    pram[i] = genSendReadXCmd(i);
    i++;
  } while (i != 0);
  // N.B. We rely on overflow here to copy all 256 bytes.
}

// Clear write-protect and copy all XPRAM memory from host to RTC.
void loadAllXMem(void)
{
  uint8_t i = 0;
  clearWriteProtect();
  do {
    genSendWriteXCmd(i, pram[i]);
    i++;
  } while (i != 0);
  // N.B. We rely on overflow here to copy all 256 bytes.
}

/* For 20-byte equivalent PRAM commands, read or write the
   corresponding host memory.  Writes are also propagated to the RTC.
   For reads, `data` is ignored.  Invalid reads return zero.
   Successful writes return 1, unsuccessful writes return zero.

   Copied almost exactly from the corresponding subroutine in the
   firmware.  */
byte hostTradPramCmd(byte cmd, byte data)
{
  bool8_t writeRequest = !(cmd&(1<<7));
  // Discard the first bit and the last two bits, it's not pertinent
  // to address interpretation.
  byte address = (cmd&~(1<<7))>>2;
  if (writeRequest && writeProtect)
    return 0; // invalid command
  if (address < 8) {
    // Little endian clock data byte
    if (writeRequest) {
      address = (address&0x03)<<3;
      timeSecs &= ~(0xff<<address);
      timeSecs |= data<<address;
      // Fall through to send command to RTC.
    } else {
      address = (address&0x03)<<3;
      return (timeSecs>>address)&0xff;
    }
  } else if (address < 12) {
    // Group 2 register
    address = (address&0x03) + group2Base;
    if (writeRequest) {
      pram[address] = data;
      // Fall through to send command to RTC.
    } else
      return pram[address];
  } else if (address < 16) {
    if (writeRequest) {
      if (address == 12) // test write, do nothing
        ; // Fall through to send command to RTC.
      else if (address == 13) {
        // Update the write-protect register.
        writeProtect = ((data & 0x80)) ? 1 : 0;
        // Fall through to send command to RTC.
      }
      else {
        // Addresses 14 and 15 are used for the encoding of the first
        // byte of an extended command.  Therefore, interpretation as
        // a traditional PRAM command is invalid.
        return 0;
      }
    } else
      return 0; // invalid command
  } else {
    // Group 1 register
    address = (address&0x0f) + group1Base;
    if (writeRequest) {
      pram[address] = data;
      // Fall through to send command to RTC.
    } else
      return pram[address];
  }

  // We only reach this point for valid write commands.
  sendWriteCmd(cmd, data);
  return 1;
}

// Write to host XPRAM memory and also propagate the changes to the
// RTC.  Always succeeds and returns 1.
byte hostWriteXMem(byte address, byte data)
{
  genSendWriteXCmd(address, data);
  pram[address] = data;
  return 1;
}

// Accessor function to read host XPRAM memory.
byte hostReadXMem(byte address)
{
  return pram[address];
}

// Load the host copy of the traditional PRAM from a file and update
// the RTC device memory.  Also clears write-protect.  Returns true on
// success, false on failure.
bool8_t fileLoadAllTradMem(const char *filename)
{
  FILE *fp = fopen(filename, "rb");
  int ch;
  uint8_t i;
  if (fp == NULL)
    return false;
  clearWriteProtect();
  // Copy group 1 registers.
  for (i = 0; i < 16; i++) {
    byte data;
    ch = getc(fp);
    if (ch == EOF)
      goto cleanup_fail;
    data = ch;
    pram[group1Base+i] = data;
    genSendWriteCmd(16 + i, data);
  }
  // Copy group 2 registers.
  for (i = 0; i < 4; i++) {
    byte data;
    ch = getc(fp);
    if (ch == EOF)
      goto cleanup_fail;
    data = ch;
    pram[group2Base+i] = data;
    genSendWriteCmd(8 + i, data);
  }
  if (fclose(fp) == EOF)
    return false;
  return true;
 cleanup_fail:
  fclose(fp);
  return false;
}

// Save the host copy of the traditional PRAM to a file.  Returns true
// on success, false on failure.
bool8_t fileDumpAllTradMem(const char *filename)
{
  FILE *fp = fopen(filename, "wb");
  uint8_t i;
  if (fp == NULL)
    return false;
  // Copy group 1 registers.
  for (i = 0; i < 16; i++) {
    byte data = pram[group1Base+i];
    if (putc(data, fp) == EOF)
      goto cleanup_fail;
  }
  // Copy group 2 registers.
  for (i = 0; i < 4; i++) {
    byte data = pram[group2Base+i];
    if (putc(data, fp) == EOF)
      goto cleanup_fail;
  }
  if (fclose(fp) == EOF)
    return false;
  return true;
 cleanup_fail:
  fclose(fp);
  return false;
}

// Load the host copy of the XPRAM from a file and update the RTC
// device memory.  Also clears write-protect.  Returns true on
// success, false on failure.
bool8_t fileLoadAllXMem(const char *filename)
{
  FILE *fp = fopen(filename, "rb");
  if (fp == NULL)
    return false;
  if (fread(pram, 1, 256, fp) != 256) {
    fclose(fp);
    return false;
  }
  if (fclose(fp) == EOF)
    return false;
  loadAllXMem();
  return true;
}

// Save the host copy of the XPRAM to a file.  Returns true on
// success, false on failure.
bool8_t fileDumpAllXMem(const char *filename)
{
  FILE *fp = fopen(filename, "wb");
  if (fp == NULL)
    return false;
  if (fwrite(pram, 1, 256, fp) != 256) {
    fclose(fp);
    return false;
  }
  if (fclose(fp) == EOF)
    return false;
  return true;
}

/********************************************************************/
/* PRAM interactive command line module */

/*
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>

#include "arduino_sdef.h"
#include "pram-lib.h"
#include "a2mon-pram.h"
#include "simavr-support.h"
#include "auto-test-suite.h"
*/

void simRec(void);
void simNoRec(void);
void setMonMode(uint8_t newMonMode);
uint8_t getMonMode(void);
byte monMemAccess(uint16_t address, bool8_t writeRequest, byte data);
bool8_t execMonLine(char *lineBuf);
bool8_t autoTestSuite(bool8_t verbose, bool8_t simRealTime,
                      bool8_t testXPram);

/* Since every subroutine for command-line commands only has zero to
   three arguments, all being numeric except for the file commands
   that take a single string argument, I can use a very simple
   command-line parser, space separation for arguments only, no
   quoting semantics.  */

// Parse the desired number of 8-bit numbers expressed in hexidecimal
// on a command line and store them in the designated output array.
// Returns the actual number of 8-bit numbers parsed.  On format
// error or extra arguments, 0xff is returned.
uint8_t parse8Bits(byte *output, uint8_t limit, char *parsePtr)
{
  uint8_t numParsed = 0;
  char *token;
  char *firstPtr = parsePtr;
  char *savePtr;
  while (numParsed < limit &&
         (token = strtok_r(firstPtr, " \t", &savePtr)) != NULL) {
    long num = strtol(token, NULL, 16);
    firstPtr = NULL;
    if (num < 0 || num > 255)
      return 0xff;
    output[numParsed++] = (byte)num;
  }
  // Ensure that we do not have extra arguments.
  if ((token = strtok_r(firstPtr, " \t", &savePtr)) != NULL)
    return 0xff;
  return numParsed;
}

#define SKIP_WHITESPACE(str) \
  while (*(str) != '\0' && (*(str) == ' ' || *(str) == '\t')) \
    (str)++;

#define PARSE_8BIT_HEAD(numParams) \
  uint8_t params[(numParams)+1]; \
  if (parse8Bits(params, (numParams), parsePtr) != (numParams)) { \
    fputs("Error: Argument syntax error\n", stderr); \
    return 0; \
  }

// Parse and execute a command line.  Return value contains bit flags:
// Bit flag 1|0: Command succeeded/failed
// Bit flag 2|0: Quit command encountered vs. continue
uint8_t execCmdLine(char *lineBuf)
{
  bool8_t splitCmd = false;
  char *cmdName;
  char *parsePtr = lineBuf;
  SKIP_WHITESPACE(parsePtr);
  cmdName = parsePtr;
  while (*parsePtr != '\0' && *parsePtr != ' ' && *parsePtr != '\t')
    parsePtr++;
  if (*parsePtr != '\0') {
    splitCmd = true;
    *parsePtr++ = '\0';
  }
  SKIP_WHITESPACE(parsePtr);
  if (strcmp(cmdName, "?") == 0 ||
      strcmp(cmdName, "help") == 0) {
    fputs(
"Summary of command-line commands:\n"
"    ?, help -- show this help page\n"
"    set-pram-type isXPram -- 0 for 20-byte PRAM, 1 for XPRAM (default)\n"
"    get-pram-type\n"
"    send-read-cmd cmd\n"
"    send-write-cmd cmd data\n"
"    send-read-xcmd cmd1 cmd2\n"
"    send-write-xcmd cmd1 cmd2 data\n"
"    test-write\n"
"    set-write-protect\n"
"    clear-write-protect\n"
"    dump-time -- copy time from RTC to host\n"
"    load-time -- clear write-protect, copy time from host to RTC\n"
"    set-time b1 b2 b3 b4 -- also clears write-protect\n"
"    get-time\n"
"    mac-to-str-time b1 b2 b3 b4\n"
"    str-to-mac-time timeStr\n"
"    set-str-time timeStr  -- also clears write-protect\n"
"    get-str-time\n"
"    set-cur-time  -- also clears write-protect\n"
"    gen-cmd address writeRequest\n"
"    gen-send-read-cmd address\n"
"    gen-send-write-cmd address data\n"
"    dump-all-trad-mem -- copy all traditional 20-byte PRAM memory from\n"
"                         RTC to host\n"
"    load-all-trad-mem -- clear write-protect, copy from host to RTC\n"
"    gen-xcmd address writeRequest\n"
"    gen-send-read-xcmd address\n"
"    gen-send-write-xcmd address data\n"
"    dump-all-xmem\n"
"    load-all-xmem -- also clears write-protect\n"
"    host-trad-pram-cmd cmd data\n"
"    host-write-xmem address data\n"
"    host-read-xmem address\n"
"    set-mon-mode newMode -- 0 = disable, 1 = traditional PRAM,\n"
"                            2 = XPRAM\n"
"    get-mon-mode\n"
"    mon-mem-access address writeRequest data\n"
"    file-load-all-trad-mem filename -- also clears write-protect\n"
"    file-dump-all-trad-mem filename\n"
"    file-load-all-xmem filename -- also clears write-protect\n"
"    file-dump-all-xmem filename\n"
"    sim-rec -- start recording RTC pin signal waveforms\n"
"    sim-no-rec -- stop recording RTC pin signal waveforms\n"
"    auto-test-suite verbose simRealTime testXPram\n"
"    q, quit -- exit the program\n"
"\n"
"Most commands are named after the corresponding library subroutines,\n"
"see the source code comments for more information.  All arguments\n"
"are 8-bit hexidecimal integers, except for file names and string\n"
"time.\n"
"\n"
"If one of the \"monitor modes\" are enabled, a subset of the most\n"
"basic Apple II monitor commands can be used and it will operate in the\n"
"configured address space.  Namely, dumping memory and writing memory\n"
"contents.\n"
"\n"
"For example, to write memory:\n"
"\n"
"You type> 0000: 01 02 1a 2c\n"
"\n"
"To dump memory:\n"
"\n"
"You type> 00C0\n"
"You get> 00C0- 53 52 68 2E 0A 00 00 68\n"
"\n"
"Other noteworthy tricks:\n"
"\n"
"* Type a memory address and ENTER to dump one line of memory.\n"
"\n"
"* Press ENTER repeatedly to dump the next line of memory.\n"
"\n"
"* Type \".\" (dot) ADDR and ENTER to dump memory from the last address\n"
"  up to the given address.\n"
"\n"
"* Type \"G\" to execute at the last address.  NOT RECOMMENDED.\n"
"\n"
"* You can omit the address and type \":\" when writing memory to\n"
"  continue from the last address.\n"
"\n"
"* \"-\" (hyphen) is also supported on entry for convenience.\n"
"\n",
          stdout);
    // If XOR checksum mode is enabled, add it to the example:
"* The XOR checksum at the end (example X3114) is optional when writing\n"
"  memory.\n"
"\n";
    return 1;
  } else if (strcmp(cmdName,  "set-pram-type") == 0) {
    PARSE_8BIT_HEAD(1);
    setPramType(params[0]);
    return 1;
  } else if (strcmp(cmdName,  "get-pram-type") == 0) {
    byte result;
    PARSE_8BIT_HEAD(0);
    result = getPramType();
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "send-read-cmd") == 0) {
    byte result;
    PARSE_8BIT_HEAD(1);
    result = sendReadCmd(params[0]);
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "send-write-cmd") == 0) {
    PARSE_8BIT_HEAD(2);
    sendWriteCmd(params[0], params[1]);
    return 1;
  } else if (strcmp(cmdName, "send-read-xcmd") == 0) {
    byte result;
    PARSE_8BIT_HEAD(2);
    result = sendReadXCmd(params[0], params[1]);
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "send-write-xcmd") == 0) {
    PARSE_8BIT_HEAD(3);
    sendWriteXCmd(params[0], params[1], params[2]);
    return 1;
  } else if (strcmp(cmdName, "test-write") == 0) {
    PARSE_8BIT_HEAD(0);
    testWrite();
    return 1;
  } else if (strcmp(cmdName, "set-write-protect") == 0) {
    PARSE_8BIT_HEAD(0);
    setWriteProtect();
    return 1;
  } else if (strcmp(cmdName, "clear-write-protect") == 0) {
    PARSE_8BIT_HEAD(0);
    clearWriteProtect();
    return 1;
  } else if (strcmp(cmdName, "dump-time") == 0) {
    byte result;
    PARSE_8BIT_HEAD(0);
    result = dumpTime();
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "load-time") == 0) {
    PARSE_8BIT_HEAD(0);
    loadTime();
    return 1;
  } else if (strcmp(cmdName, "set-time") == 0) {
    uint32_t newTimeSecs;
    PARSE_8BIT_HEAD(4);
    newTimeSecs = params[0] | (params[1] << 8) |
      (params[2] << 16) | (params[3] << 24);
    setTime(newTimeSecs);
    return 1;
  } else if (strcmp(cmdName, "get-time") == 0) {
    uint32_t result;
    PARSE_8BIT_HEAD(0);
    result = getTime();
    printf("%02x %02x %02x %02x\n",
           result & 0xff, (result >> 8) & 0xff,
           (result >> 16) & 0xff, (result >> 24) & 0xff);
    return 1;
  } else if (strcmp(cmdName, "mac-to-str-time") == 0) {
    uint32_t readTimeSecs;
    char outBuf[64];
    PARSE_8BIT_HEAD(4);
    readTimeSecs = params[0] | (params[1] << 8) |
      (params[2] << 16) | (params[3] << 24);
    macToStrTime(outBuf, 64, readTimeSecs);
    printf("%s\n", outBuf);
    return 1;
  } else if (strcmp(cmdName, "str-to-mac-time") == 0) {
    uint32_t result = strToMacTime(parsePtr);
    printf("%02x %02x %02x %02x\n",
           result & 0xff, (result >> 8) & 0xff,
           (result >> 16) & 0xff, (result >> 24) & 0xff);
    return 1;
  } else if (strcmp(cmdName, "set-str-time") == 0) {
    setStrTime(parsePtr);
    return 1;
  } else if (strcmp(cmdName, "get-str-time") == 0) {
    char outBuf[64];
    PARSE_8BIT_HEAD(0);
    getStrTime(outBuf, 64);
    printf("%s\n", outBuf);
    return 1;
  } else if (strcmp(cmdName, "set-cur-time") == 0) {
    PARSE_8BIT_HEAD(0);
    setCurTime();
    return 1;
  } else if (strcmp(cmdName, "gen-cmd") == 0) {
    byte result;
    PARSE_8BIT_HEAD(2);
    result = genCmd(params[0], params[1]);
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "gen-send-read-cmd") == 0) {
    byte result;
    PARSE_8BIT_HEAD(1);
    result = genSendReadCmd(params[0]);
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "gen-send-write-cmd") == 0) {
    PARSE_8BIT_HEAD(2);
    genSendWriteCmd(params[0], params[1]);
    return 1;
  } else if (strcmp(cmdName, "dump-all-trad-mem") == 0) {
    PARSE_8BIT_HEAD(0);
    dumpAllTradMem();
    return 1;
  } else if (strcmp(cmdName, "load-all-trad-mem") == 0) {
    PARSE_8BIT_HEAD(0);
    loadAllTradMem();
    return 1;
  } else if (strcmp(cmdName, "gen-xcmd") == 0) {
    uint16_t result;
    PARSE_8BIT_HEAD(2);
    result = genXCmd(params[0], params[1]);
    printf("%02x %02x\n", (result >> 8) & 0xff, result & 0xff);
    return 1;
  } else if (strcmp(cmdName, "gen-send-read-xcmd") == 0) {
    byte result;
    PARSE_8BIT_HEAD(1);
    result = genSendReadXCmd(params[0]);
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "gen-send-write-xcmd") == 0) {
    PARSE_8BIT_HEAD(2);
    genSendWriteXCmd(params[0], params[1]);
    return 1;
  } else if (strcmp(cmdName, "dump-all-xmem") == 0) {
    PARSE_8BIT_HEAD(0);
    dumpAllXMem();
    return 1;
  } else if (strcmp(cmdName, "load-all-xmem") == 0) {
    PARSE_8BIT_HEAD(0);
    loadAllXMem();
    return 1;
  } else if (strcmp(cmdName, "host-trad-pram-cmd") == 0) {
    byte result;
    PARSE_8BIT_HEAD(2);
    result = hostTradPramCmd(params[0], params[1]);
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "host-write-xmem") == 0) {
    PARSE_8BIT_HEAD(2);
    hostWriteXMem(params[0], params[1]);
    return 1;
  } else if (strcmp(cmdName, "host-read-xmem") == 0) {
    byte result;
    PARSE_8BIT_HEAD(1);
    result = hostReadXMem(params[0]);
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "set-mon-mode") == 0) {
    PARSE_8BIT_HEAD(1);
    setMonMode(params[0]);
    return 1;
  } else if (strcmp(cmdName, "get-mon-mode") == 0) {
    byte result;
    PARSE_8BIT_HEAD(0);
    result = getMonMode();
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "mon-mem-access") == 0) {
    byte result;
    PARSE_8BIT_HEAD(3);
    result = monMemAccess(params[0], params[1], params[2]);
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "file-load-all-trad-mem") == 0) {
    byte result = fileLoadAllTradMem(parsePtr);
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "file-dump-all-trad-mem") == 0) {
    byte result = fileDumpAllTradMem(parsePtr);
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "file-load-all-xmem") == 0) {
    byte result = fileLoadAllXMem(parsePtr);
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "file-dump-all-xmem") == 0) {
    byte result = fileDumpAllXMem(parsePtr);
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "sim-rec") == 0) {
    PARSE_8BIT_HEAD(0);
    simRec();
    return 1;
  } else if (strcmp(cmdName, "sim-no-rec") == 0) {
    PARSE_8BIT_HEAD(0);
    simNoRec();
    return 1;
  } else if (strcmp(cmdName, "auto-test-suite") == 0) {
    byte result;
    PARSE_8BIT_HEAD(3);
    result = autoTestSuite(params[0], params[1], params[2]);
    printf("0x%02x\n", result);
    return 1;
  } else if (strcmp(cmdName, "q") == 0 ||
             strcmp(cmdName, "quit") == 0) {
    return 3; // Time to quit.
  } else if (*cmdName == '\0') {
    // Empty command line, handle specially if in Apple II monitor
    // mode.
    if (monMode != 0) {
      if (splitCmd)
        *(--parsePtr) = ' '; // unsplit
      // Unchomp the newline character.
      lineBuf[strlen(lineBuf)] = '\n';
      return execMonLine(lineBuf);
    }
    return 1;
  } else {
    /* Default action.  If monitor mode is enabled, jump to the
       monitor command parser.  Otherwise indicate a syntax error
       right away.  */
    if (monMode == 0) {
      fputs("Error: Unknown command\n", stderr);
    } else {
      if (splitCmd)
        *(--parsePtr) = ' '; // unsplit
      // Unchomp the newline character.
      lineBuf[strlen(lineBuf)] = '\n';
      return execMonLine(lineBuf);
    }
  }

  // NOT REACHED
  return 0;
}

// Return false on exit with error, true on graceful exit.
bool8_t cmdLoop(void)
{
  uint8_t retVal = true;
  char lineBuf[512];
  char *parsePtr;

  // Print the prompt character.
  putchar('*');

  while (1) {

    if (fgets(lineBuf, 512, stdin) == NULL) {
      if (feof(stdin))
        break; // End of file
      else if (errno == EWOULDBLOCK) {
        // Run one simulation step.
        if (!simAvrStep()) {
          fputs("Simulation terminated.\n", stdout);
          return true;
        }
        continue;
      } else
        break; // Other I/O error.
    }

    parsePtr = lineBuf + strlen(lineBuf) - 1;
    if (*parsePtr != '\n') {
      fputs("Error: Command line too long.\n", stderr);
      return false;
    }
    *parsePtr = '\0'; // Chomp off the newline character.

    // Dispatch on the command name.
    retVal = execCmdLine(lineBuf);
    if ((retVal & 2) == 2)
      return retVal & 1;

    // Print the prompt character.
    putchar('*');
  }

  return retVal;
}

/********************************************************************/
/* Miniature Apple II monitor module */
/* Tailored for PRAM interface */

/*
#include <stdio.h>

#include "arduino_sdef.h"
#include "pram-lib.h"
*/

// Set the Apple II monitor mode.
void setMonMode(uint8_t newMonMode)
{
  monMode = newMonMode;
}

// Get the Apple II monitor mode.
uint8_t getMonMode(void)
{
  return monMode;
}

/* Read/write to either traditional PRAM or XPRAM depending on the
   Apple II monitor mode.  Addresses out of range return zero on read
   and do nothing on write.  For reads, `data` is ignored.  Returns
   data on successful reads, zero on unsuccessful reads, one on
   successful writes, zero on unsuccessful writes.  */
byte monMemAccess(uint16_t address, bool8_t writeRequest, byte data)
{
  if (monMode == 1) {
    // Traditional PRAM
    if (address > 0x1f)
      return 0; // invalid address
    return hostTradPramCmd(genCmd(address, writeRequest), data);
  } else if (monMode == 2) {
    // XPRAM
    if (address > 0xff)
      return 0; // invalid address
    if (writeRequest)
      return hostWriteXMem(address, data);
    else
      return hostReadXMem(address);
  }
  // else Monitor mode disabled, always return zero.
  return 0;
}

/* NOTE: We're copying in some hexidecimal helper subroutines in here
   just because they are a little more convenient to use than the
   standard C library routines, even though it's a duplication of
   effort.  Plus I already wrote up and tested an Apple II style
   monitor, so I was copying and pasting the code into here with minor
   modifications.  */

#define ishex(ch) (((ch >= '0') && (ch <= '9')) || \
                                   ((ch >= 'A') && (ch <= 'F')) || \
                                   ((ch >= 'a') && (ch <= 'f')))

/* #define USE_XOR_CK */
/* #define XOR_CK_LEN 2 */

unsigned short last_addr;
#ifdef USE_XOR_CK
unsigned short error_count = 0;
#endif
char *g_monLineBuf;

void puthex(unsigned char len, unsigned short data);
unsigned short parsehex(unsigned char len, char *data);
unsigned short gethex(unsigned char maxlen, char *rch);
void dumphex(unsigned short addr, unsigned short end_addr,
             unsigned char one_line);
void writehex(char *rch);

bool8_t execMonLine(char *lineBuf)
{
  char ch;
  g_monLineBuf = lineBuf;
  ch = *g_monLineBuf++;
  while (ch != '\0') {
    if (ch == '\n') {
      /* Display one line of hex dump.  */
      unsigned short addr = last_addr;
      unsigned short end_addr = addr + 8;
      dumphex(addr, end_addr, 1);
    } else if (ishex(ch)) {
      /* Read an address.  */
      last_addr = gethex(4, &ch);
      /* Skip standard actions at end of loop, we may have additional
         commands to read.  */
      continue;
    } else if (ch == '.') {
      /* Read memory range.  */
      unsigned short end_addr;
      ch = *g_monLineBuf++;
      if (ch == '\0')
        break;
      end_addr = gethex(4, &ch);
      dumphex(last_addr, end_addr, 0);
    } else if (ch == '-' || ch == ':') {
      /* Write bytes to address.  */
      writehex(&ch);
      if (ch == '\0')
        break;
    } else if (ch == 'G' || ch == 'g') {
      /* Ignore characters until end of newline.  */
      while ((ch = *g_monLineBuf++) != '\0' && ch != '\n');

      /* Execute!  */
      /* PLEASE NOTE: This will always crash unless you've changed the
         section headers to make the XPRAM section executable, which
         it isn't by default.  Also,this only works in a linear
         address space, of course, i.e. XPRAM.  */
      if (monMode != 2 || last_addr > 0xff) {
        fputs("\aINVALID EXECUTE MODE\n", stderr);
        return false;
      }
      ((void (*)(void))&pram[last_addr])();
    } else if (ch == ' ') {
      /* Horizontal whitespace, ignore.  */
      ch = *g_monLineBuf++;
      continue;
    } else {
      fputs("\a?SYNTAX ERROR\n", stderr);
      return false;
    }
    // return true; // putprompt();
    ch = *g_monLineBuf++;
  }
  return true;
}

/* `len' is length in hex chars, should be either 2 (byte) or 4
   (word).

   N.B. Shifting is expensive on early 8-bit processors because you
   can only shift one bit at a time, so we try to minimize that
   here.  */
void puthex(unsigned char len, unsigned short data)
{
  char buf[4];
  unsigned char i = len;
  while (i > 0) {
    unsigned char val;
    i--;
    val = data & 0x0f;
    data >>= 4;
    if (val < 0xa)
      val += '0';
    else
      val += 'A' - 0xa;
    buf[i] = val;
  }
  while (i < len) {
    putchar(buf[i++]);
  }
}

unsigned short parsehex(unsigned char len, char *data)
{
  unsigned short result = 0;
  unsigned char i = 0;
  while (i < len) {
    unsigned char val;
    val = data[i];
    if (val >= 'a')
      val -= 'a' - 0xa;
    else if (val >= 'A')
      val -= 'A' - 0xa;
    else
      val -= '0';
    val &= 0x0f;
    result <<= 4;
    result |= val;
    i++;
  }
  return result;
}

/* TODO: Every time after calling gethex(), check if we are stuck on
   an invalid non-hex char.  */
unsigned short gethex(unsigned char maxlen, char *rch)
{
  unsigned short result;
  char ch;
  char rdbuf[4];
  unsigned rdbuf_len = 0;
  if (maxlen > 4) /* programmer error, i.e. assert() failure */
    return 0;
  ch = *rch;
  while (ch != '\0' && rdbuf_len < maxlen && ishex(ch)) {
    rdbuf[rdbuf_len++] = (char)ch;
    ch = *g_monLineBuf++;
  }
  *rch = ch;
  result = parsehex(rdbuf_len, rdbuf);
  return result;
}

void dumphex(unsigned short addr, unsigned short end_addr,
             unsigned char one_line)
{
#ifdef USE_XOR_CK
  unsigned char xor_cksum[XOR_CK_LEN] = { 0, 0/*, 0, 0*/ };
  unsigned char xor_pos = 0;
#endif
  puthex(4, addr); putchar('-');
  /* TODO FIXME: I trid to fold the last iteration into here to reduce
     code, but that introduces a bug that does not properly handle
     "0000.ffff".  Fix this.  */
  /* N.B. If end_addr < addr, we print one byte at addr,
     similar to the Apple II monitor.  */
  do {
    unsigned char val = monMemAccess(addr++, false, 0);
#ifdef USE_XOR_CK
    xor_cksum[xor_pos++] ^= val;
    xor_pos &= XOR_CK_LEN - 1;
#endif
    putchar(' ');
    puthex(2, val);
    if ((addr & 0x07) == 0x00) {
#ifdef USE_XOR_CK
      /* Print XOR checksum.  */
      putchar(' ');
      putchar('X');
      puthex(4, ((unsigned short)xor_cksum[0] << 8) | xor_cksum[1]);
      /* puthex(4, ((unsigned short)xor_cksum[2] << 8) | xor_cksum[3]); */
      xor_cksum[0] = 0; xor_cksum[1] = 0;
      /* xor_cksum[2] = 0; xor_cksum[3] = 0; */
#endif
      if (one_line)
        break;
      if (addr <= end_addr) {
        putchar('\n');
        puthex(4, addr); putchar('-');
      }
    }
  } while (addr <= end_addr);
  putchar('\n');
  last_addr = addr;
}

void writehex(char *rch)
{
  char ch;
  unsigned short addr = last_addr;
#ifdef USE_XOR_CK
  unsigned char xor_cksum[XOR_CK_LEN] = { 0, 0/*, 0, 0*/ };
  unsigned char xor_pos = 0;
#endif
  ch = *g_monLineBuf++;
  if (ch == '\0')
    goto cleanup;
  do {
    unsigned char val;
    while (ch == ' ')
      ch = *g_monLineBuf++;
    if (ch == '\0' || ch == '\n' || ch == 'X' || ch == 'x')
      break;
    val = (unsigned char)gethex(2, &ch);
#ifdef USE_XOR_CK
    xor_cksum[xor_pos++] ^= val;
    xor_pos &= XOR_CK_LEN - 1;
#endif
    monMemAccess(addr++, true, val);
  } while (ch != '\n' && ch != 'X' && ch != 'x');
#ifdef USE_XOR_CK
  if (ch == 'X' || ch == 'x') {
    /* Read and validate XOR checksum.  */
    unsigned char rd_cksum[XOR_CK_LEN] = { 0, 0/*, 0, 0*/ };
    ch = *g_monLineBuf++;
    if (ch == '\0')
      goto cleanup;
    rd_cksum[0] = (unsigned char)gethex(2, &ch);
    rd_cksum[1] = (unsigned char)gethex(2, &ch);
    /* rd_cksum[2] = (unsigned char)gethex(2, &ch);
    rd_cksum[3] = (unsigned char)gethex(2, &ch); */
    if (xor_cksum[0] != rd_cksum[0] ||
        xor_cksum[1] != rd_cksum[1] /* ||
        xor_cksum[2] != rd_cksum[2] ||
        xor_cksum[3] != rd_cksum[3] */) {
      putchar('\a'); putchar('E');
      /* With our current checksumming algorithm, after 128 detected
         errors, it is pretty much guaranteed that there may be one
         undetected error.  */
      if (error_count >= 128)
        { putchar('\a'); putchar('!'); }
      else
        error_count++;
      putchar('\n');
      /* Rewind to `last_addr' on error.  */
      addr = last_addr;
    }
  }
#endif
  last_addr = addr;
 cleanup:
  *rch = ch;
}

/********************************************************************/
/* `simavr` support module */

/*
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <signal.h>

#include "sim_avr.h"
#include "avr_ioport.h"
#include "avr_timer.h"
#include "sim_elf.h"
#include "sim_gdb.h"
#include "sim_vcd_file.h"

#include "arduino_sdef.h"
#include "pram-lib.h"
*/

static const char * bench_irq_names[5] =
  { "BENCH.SEC1", "BENCH.CE*", "BENCH.CLK",
    "BENCH.DATA.IN", "BENCH.DATA.OUT*" };

// simavr variables
avr_t *avr = NULL;
avr_vcd_t vcd_file;
avr_irq_t *bench_irqs = NULL;

avr_cycle_count_t notify_timeup(avr_t *avr, avr_cycle_count_t when,
                                void *param)
{
  g_waitTimeUp = true;
  if (g_timePoll)
    return avr->cycle + g_timePoll;
  return 0;
}

// Start recording VCD signal waveforms for RTC pins.  Only applicable
// when running under simulation.
void simRec(void)
{
    printf("Starting VCD trace\n");
    avr_vcd_start(&vcd_file);
}

// Stop recording VCD signal waveforms for RTC pins.  Only applicable
// when running under simulation.
void simNoRec(void)
{
    printf("Stopping VCD trace\n");
    avr_vcd_stop(&vcd_file);
}

void pin_change_notify(avr_irq_t *irq, uint32_t value, void *param)
{
  if (irq == bench_irqs + IRQ_SEC1 && value)
    sec1Isr();
  else if (irq == bench_irqs + IRQ_DATA_OUT) {
    // Only write the updated value to the buffer register if the VIA
    // is in the input mode.  Also, note that the value we receive is
    // inverted.
    if (bitRead(vBase[vDirB], rtcData) == DIR_IN)
      bitWrite(vBase[vBufB], rtcData, !value);
  }
}

static void
sig_int(int sign)
{
  printf("signal caught, simavr terminating\n");
  if (avr)
    avr_terminate(avr);
  pramDestroy();
  exit(0);
}

int setupSimAvr(char *progName, const char *fname, bool8_t interactMode)
{
  elf_firmware_t f;

  if (elf_read_firmware(fname, &f) != 0) {
    fprintf(stderr, "%s: firmware '%s' invalid\n", progName, fname);
    return 1;
  }
  strcpy(f.mmcu, "attiny85");
  //f.frequency = 8000000;
  // DEBUG NOTE: I'm only able to do real-time simulation at 400 kHz.
  f.frequency = 400000;
  
  printf("firmware %s f=%d mmcu=%s\n", fname, (int)f.frequency, f.mmcu);

  avr = avr_make_mcu_by_name(f.mmcu);
  if (!avr) {
    fprintf(stderr, "%s: AVR '%s' not known\n", progName, f.mmcu);
    return 1;
  }
  avr_init(avr);
  avr_load_firmware(avr, &f);

  // Initialize our host circuit "peripheral."

  // Setup IRQ connections and connect our test bench and AVR
  // together.
  bench_irqs = avr_alloc_irq(&avr->irq_pool, 0, 5, bench_irq_names);

  avr_connect_irq(avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('B'), 5),
                  bench_irqs + IRQ_SEC1);
  avr_connect_irq(bench_irqs + IRQ_CE,
                  avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('B'), 0));
  avr_connect_irq(bench_irqs + IRQ_CLK,
                  avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('B'), 2));

  // Since we use open-drain signaling on data, this a bit trickier to
  // connect to, but this is how to do it.
  avr_connect_irq(bench_irqs + IRQ_DATA_IN,
                  avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('B'), 1));
  avr_connect_irq(avr_iomem_getirq(avr, AVR_IO_TO_DATA(0x17), "RTC.DATA.OUT*", 1),
                  bench_irqs + IRQ_DATA_OUT);

  // Register notify functions for inputs to test bench (outputs):
  avr_irq_register_notify(bench_irqs + IRQ_SEC1,
                          pin_change_notify, NULL);
  avr_irq_register_notify(bench_irqs + IRQ_DATA_OUT,
                          pin_change_notify, NULL);

  // Give the RTC input pins sane initial values.
  avr_raise_irq(bench_irqs + IRQ_CE, 1);
  avr_raise_irq(bench_irqs + IRQ_CLK, 0);
  avr_raise_irq(bench_irqs + IRQ_DATA_IN, 0);

  // NOTE: Propagation of connected IRQs is unidirectional, so we need
  // special handling for the bi-directional communication pin.
  // Actually, we always need special handling due to our quirk used
  // for open collector communication.  We always end up using two
  // different IRQs, and we decide whether to listen or ignore outputs
  // based off of the VIA direction register.

  // even if not setup at startup, activate gdb if crashing
  avr->gdb_port = 1234;
  if (0) {
    //avr->state = cpu_Stopped;
    avr_gdb_init(avr);
  }

  /*
   *    VCD file initialization
   *    
   *    This will allow you to create a "wave" file and display it in
   *    gtkwave.  Use the `sim-rec`/`sim-no-rec` commands to
   *    start/stop recording pin changes.
   */
  avr_vcd_init(avr, "gtkwave_trace.vcd", &vcd_file, 10000 /* usec */);

  // ATTiny85 PINB == 0x16
  // ATTiny85 DDRB == 0x17
  // ATTiny85 PORTB == 0x18

  avr_vcd_add_signal(&vcd_file,
    avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('B'), 5),
    1  /* bits */,
    "RTC.SEC1" );
  avr_vcd_add_signal(&vcd_file,
    avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('B'), 0),
    1  /* bits */,
    "RTC.CE*" );
  avr_vcd_add_signal(&vcd_file,
    avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('B'), 2),
    1  /* bits */,
    "RTC.CLK" );

  // Since we use open-drain signaling on data, this a bit trickier to
  // monitor, but this is how to do it.
  avr_vcd_add_signal(&vcd_file,
    avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('B'), 1),
    1  /* bits */,
    "RTC.DATA.IN" );
  avr_irq_t *rtc_data_out_irq =
    avr_iomem_getirq(avr, AVR_IO_TO_DATA(0x17), "RTC.DATA.OUT*", 1);
  // Let's just process inverted data for now.
  /* uint8_t flags = avr_irq_get_flags(rtc_data_out_irq);
  flags |= IRQ_FLAG_NOT;
  avr_irq_set_flags(rtc_data_out_irq, flags); */
  avr_vcd_add_signal(&vcd_file, rtc_data_out_irq, 1  /* bits */,
    "RTC.DATA.OUT*" );

  // TIMER0_OVF == 5
  avr_vcd_add_signal(&vcd_file,
                     avr_get_interrupt_irq(avr, 5),
                     1  /* bits */ ,
                     "TIMER0_OVF" );

  // printf("Starting VCD trace\n");
  // avr_vcd_start(&vcd_file);

  if (interactMode) {
    // Configure non-blocking mode on standard input so that the
    // simulator can still run when we're waiting for user input.
    int fflags = fcntl(STDIN_FILENO, F_GETFL);
    int result;
    if (fflags == -1) {
      perror("error getting stdin flags");
      return 1;
    }
    fflags |= O_NONBLOCK;
    result = fcntl(STDIN_FILENO, F_SETFL, fflags);
    if (result == -1) {
      perror("error setting stdin flags");
      return 1;
    }
  }

  fputs( "\nSimulation launching:\n", stdout);

  signal(SIGINT, sig_int);
  signal(SIGTERM, sig_int);

  return 0;
}

// Run a single step of the AVR simulation, return true if the
// simulation should continue, false if it should stop.
bool8_t simAvrStep(void)
{
  // Simulation main loop.
  int state = avr_run(avr);
  if ((state == cpu_Done) || (state == cpu_Crashed))
    return false;
  return true;

  // NOTE: In the main loop, if we're using multiple threads and
  // message passing, we can check if we should send an I/O
  // peripheral IRQ message.
}

/********************************************************************/
/* Automated test suite module */

/*
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "arduino_sdef.h"
#include "via-emu.h"
#include "pram-lib.h"
#include "a2mon-pram.h"
*/

struct timespec g_tsStartTm;

// Print the elapsed time in the test suite.
void prTestTime(void)
{
  struct timespec tv, tvDiff;
  clock_gettime(CLOCK_MONOTONIC, &tv);
  tvDiff.tv_sec = tv.tv_sec - g_tsStartTm.tv_sec;
  tvDiff.tv_nsec = tv.tv_nsec - g_tsStartTm.tv_nsec;
  if (tvDiff.tv_nsec < 0) {
    tvDiff.tv_sec--;
    tvDiff.tv_nsec += 1000000000;
  }
  printf("[ %3d.%09d ] ", tvDiff.tv_sec, tvDiff.tv_nsec);
}

void prTsStat(const char *status)
{
  prTestTime();
  fputs(status, stdout);
}

bool8_t autoTestSuite(bool8_t verbose, bool8_t simRealTime,
                      bool8_t testXPram)
{
  uint8_t failCount = 0;
  uint8_t skipCount = 0;
  const uint8_t numTests = 18;

  clock_gettime(CLOCK_MONOTONIC, &g_tsStartTm);

  // Use a non-deterministic seed for randomized tests... but print
  // out the value just in case we want to go deterministic.
  time_t seed = time(NULL);
  prTsStat("INFO:");
  printf("random seed = 0x%08x\n", seed);
  srand(seed);

  if (!simRealTime) {
    prTsStat("SKIP:");
    fputs("1-second interrupt line\n", stdout);
    skipCount++;
  } else {
    /* Listen for 1-second ping, compare with host clock to verify
       second counting is working correctly.  */
    bool8_t result = false;
    uint8_t tries = 0;
    // Retry up to one time simply because we might cross a one-second
    // time boundary intermittently.
    do {
      // Check that the 1-second line interrupt is working as expected
      // for three seconds.
      uint32_t expectTimeSecs, actualTimeSecs;
      expectTimeSecs = getTime();
      waitOneSec(); expectTimeSecs++;
      actualTimeSecs = getTime();
      if (verbose) {
        prTsStat("INFO:");
        printf("0x%08x ?= 0x%08x\n", expectTimeSecs, actualTimeSecs);
      }
      result = (expectTimeSecs == actualTimeSecs);
      if (!result)
        continue;
      waitOneSec(); expectTimeSecs++;
      actualTimeSecs = getTime();
      if (verbose) {
        prTsStat("INFO:");
        printf("0x%08x ?= 0x%08x\n", expectTimeSecs, actualTimeSecs);
      }
      result = (expectTimeSecs == actualTimeSecs);
      if (!result)
        continue;
      waitOneSec(); expectTimeSecs++;
      actualTimeSecs = getTime();
      if (verbose) {
        prTsStat("INFO:");
        printf("0x%08x ?= 0x%08x\n", expectTimeSecs, actualTimeSecs);
      }
      result = (expectTimeSecs == actualTimeSecs);
      if (!result)
        continue;
    } while (!result && ++tries < 2);
    prTsStat((result) ? "PASS:" : "FAIL:");
    fputs("1-second interrupt line\n", stdout);
    if (!result) failCount++;
  }

  { /* Do a test write, just because we can.  Yes, even though it does
       absolutely nothing.  */
    bool8_t result = false;
    testWrite();
    result = true;
    prTsStat((result) ? "PASS:" : "FAIL:");
    fputs("Test write\n", stdout);
    if (!result) failCount++;
  }

  if (!simRealTime) {
    prTsStat("SKIP:");
    fputs("Read clock registers\n", stdout);
    skipCount++;
  } else {
    /* Read the clock registers into host memory to sync our time.  */
    bool8_t result = dumpTime();
    prTsStat((result) ? "PASS:" : "FAIL:");
    fputs("Read clock registers\n", stdout);
    if (!result) failCount++;
  }

  if (!simRealTime) {
    prTsStat("SKIP:");
    fputs("Write and read clock time registers\n", stdout);
    skipCount++;
  } else {
    /* Test writing and reading all bytes of the clock time in seconds
       register.  Code that doesn't properly cast to long can result
       in inability to write the high-order bytes.  */
    bool8_t result = false;
    uint8_t tries = 0;
    // Retry up to one time simply because we might cross a one-second
    // time boundary intermittently.
    do {
      uint32_t testTimeSecs = 0x983b80d5;
      uint32_t readTimeSecs;
      setTime(testTimeSecs);
      dumpTime();
      readTimeSecs = getTime();
      if (verbose) {
        prTsStat("INFO:");
        printf("0x%08x ?= 0x%08x\n", readTimeSecs, testTimeSecs);
      }
      result = (readTimeSecs == testTimeSecs);
    } while (!result && ++tries < 2);
    prTsStat((result) ? "PASS:" : "FAIL:");
    fputs("Write and read clock time registers\n", stdout);
    if (!result) failCount++;
  }

  { /* Set/clear write-protect, test seconds registers, traditional
       PRAM, and XPRAM writes and reads with write-protect set and
       clear.  */
    bool8_t result = false;
    byte oldVal, newVal, actualVal;
    setWriteProtect();
    oldVal = genSendReadCmd(0x07);
    newVal = ~oldVal;
    genSendWriteCmd(0x07, newVal);
    actualVal = genSendReadCmd(0x07);
    if (verbose) {
      prTsStat("INFO:");
      printf("0x%02x ?!= 0x%02x\n", actualVal, newVal);
    }
    result = (actualVal != newVal);
    prTsStat((result) ? "PASS:" : "FAIL:");
    fputs("Clock register write nulled with write-protect enabled\n",
          stdout);
    if (!result) failCount++;

    clearWriteProtect();
    oldVal = genSendReadCmd(0x07);
    newVal = ~oldVal;
    genSendWriteCmd(0x07, newVal);
    actualVal = genSendReadCmd(0x07);
    if (verbose) {
      prTsStat("INFO:");
      printf("0x%02x ?= 0x%02x\n", actualVal, newVal);
    }
    result = (actualVal == newVal);
    prTsStat((result) ? "PASS:" : "FAIL:");
    fputs("Clock register write with write-protect disabled\n", stdout);
    if (!result) failCount++;

    setWriteProtect();
    oldVal = genSendReadCmd(0x08);
    newVal = ~oldVal;
    genSendWriteCmd(0x08, newVal);
    actualVal = genSendReadCmd(0x08);
    if (verbose) {
      prTsStat("INFO:");
      printf("0x%02x ?!= 0x%02x\n", actualVal, newVal);
    }
    result = (actualVal != newVal);
    prTsStat((result) ? "PASS:" : "FAIL:");
    fputs("Traditional PRAM write nulled with write-protect enabled\n",
          stdout);
    if (!result) failCount++;

    clearWriteProtect();
    oldVal = genSendReadCmd(0x08);
    newVal = ~oldVal;
    genSendWriteCmd(0x08, newVal);
    actualVal = genSendReadCmd(0x08);
    if (verbose) {
      prTsStat("INFO:");
      printf("0x%02x ?= 0x%02x\n", actualVal, newVal);
    }
    result = (actualVal == newVal);
    prTsStat((result) ? "PASS:" : "FAIL:");
    fputs("Traditional PRAM write with write-protect disabled\n", stdout);
    if (!result) failCount++;

    if (!testXPram) {
      prTsStat("SKIP:");
      fputs("XPRAM write nulled with write-protect enabled\n", stdout);
      skipCount++;
    } else {
      setWriteProtect();
      oldVal = genSendReadXCmd(0x30);
      newVal = ~oldVal;
      genSendWriteXCmd(0x30, newVal);
      actualVal = genSendReadXCmd(0x30);
      if (verbose) {
        prTsStat("INFO:");
        printf("0x%02x ?!= 0x%02x\n", actualVal, newVal);
      }
      result = (actualVal != newVal);
      prTsStat((result) ? "PASS:" : "FAIL:");
      fputs("XPRAM write nulled with write-protect enabled\n", stdout);
      if (!result) failCount++;
    }

    if (!testXPram) {
      prTsStat("SKIP:");
      fputs("XPRAM write with write-protect disabled\n", stdout);
      skipCount++;
    } else {
      clearWriteProtect();
      oldVal = genSendReadXCmd(0x30);
      newVal = ~oldVal;
      genSendWriteXCmd(0x30, newVal);
      actualVal = genSendReadXCmd(0x30);
      if (verbose) {
        prTsStat("INFO:");
        printf("0x%02x ?= 0x%02x\n", actualVal, newVal);
      }
      result = (actualVal == newVal);
      prTsStat((result) ? "PASS:" : "FAIL:");
      fputs("XPRAM write with write-protect disabled\n", stdout);
      if (!result) failCount++;
    }
  }

  { /* Test for expected memory overlap behavior for memory regions
       sharaed in common in both traditional PRAM and XPRAM.  Only
       applicable to XPRAM.  */
    bool8_t result = true;
    byte groupVal, xpramVal;

    if (!testXPram) {
      prTsStat("SKIP:");
      fputs("Group 1 and XPRAM memory overlap\n", stdout);
      skipCount++;
    } else {
      groupVal = genSendReadCmd(0x10);
      xpramVal = genSendReadXCmd(0x10);
      if (verbose) {
        prTsStat("INFO:");
        printf(" 0x%02x ?= 0x%02x\n", groupVal, xpramVal);
      }
      result &= (groupVal == xpramVal);
      genSendWriteCmd(0x10, ~groupVal);
      groupVal = genSendReadCmd(0x10);
      xpramVal = genSendReadXCmd(0x10);
      if (verbose) {
        prTsStat("INFO:");
        printf(" 0x%02x ?= 0x%02x\n", groupVal, xpramVal);
      }
      result &= (groupVal == xpramVal);
      prTsStat((result) ? "PASS:" : "FAIL:");
      fputs("Group 1 and XPRAM memory overlap\n", stdout);
      if (!result) failCount++;
    }

    if (!testXPram) {
      prTsStat("SKIP:");
      fputs("Group 2 and XPRAM memory overlap\n", stdout);
      skipCount++;
    } else {
      result = true;
      groupVal = genSendReadCmd(0x08);
      xpramVal = genSendReadXCmd(0x08);
      if (verbose) {
        prTsStat("INFO:");
        printf(" 0x%02x ?= 0x%02x\n", groupVal, xpramVal);
      }
      result &= (groupVal == xpramVal);
      genSendWriteCmd(0x08, ~groupVal);
      groupVal = genSendReadCmd(0x08);
      xpramVal = genSendReadXCmd(0x08);
      if (verbose) {
        prTsStat("INFO:");
        printf(" 0x%02x ?= 0x%02x\n", groupVal, xpramVal);
      }
      result &= (groupVal == xpramVal);
      prTsStat((result) ? "PASS:" : "FAIL:");
      fputs("Group 2 and XPRAM memory overlap\n", stdout);
      if (!result) failCount++;
    }
  }

  if (!simRealTime) {
    prTsStat("SKIP:");
    fputs("Consistent 1-second interrupt and clock reguister increment\n",
          stdout);
    skipCount++;
  } else {
    /* Test that we can read the contents of the clock, wait a few
       seconds, incrementing on the one-second interrupt, then read
       the clock register again.  The values should match
       equivalently.  */
    bool8_t result = false;
    uint8_t tries = 0;
    // Retry up to one time simply because we might cross a one-second
    // time boundary intermittently.
    do {
      uint32_t expectTimeSecs, actualTimeSecs;
      // Two one-second waits in succession, followed by a
      // three-second wait.
      dumpTime();
      waitOneSec();
      expectTimeSecs = getTime();
      dumpTime(); actualTimeSecs = getTime();
      if (verbose) {
        prTsStat("INFO:");
        printf("0x%08x ?= 0x%08x\n", expectTimeSecs, actualTimeSecs);
      }
      result = (expectTimeSecs == actualTimeSecs);
      if (!result)
        continue;
      waitOneSec();
      expectTimeSecs = getTime();
      dumpTime(); actualTimeSecs = getTime();
      if (verbose) {
        prTsStat("INFO:");
        printf("0x%08x ?= 0x%08x\n", expectTimeSecs, actualTimeSecs);
      }
      result = (expectTimeSecs == actualTimeSecs);
      if (!result)
        continue;
      waitOneSec();
      waitOneSec();
      waitOneSec();
      expectTimeSecs = getTime();
      dumpTime(); actualTimeSecs = getTime();
      if (verbose) {
        prTsStat("INFO:");
        printf("0x%08x ?= 0x%08x\n", expectTimeSecs, actualTimeSecs);
      }
      result = (expectTimeSecs == actualTimeSecs);
      if (!result)
        continue;
    } while (!result && ++tries < 2);
    prTsStat((result) ? "PASS:" : "FAIL:");
    fputs("Consistent 1-second interrupt and clock reguister increment\n",
          stdout);
    if (!result) failCount++;
  }

  { /* Write/read memory regions randomly and verify expected memory
       behavior.  */
    bool8_t result = true;
    /* Suitable traditional PRAM address range for testing, keep out
       of the clock, write-protect, test write, and extended command
       registers:
       0x08 - 0x0b
       0x10 - 0x1f
       Total 20 bytes

       Select 8 bytes at random for testing.
    */
    byte src_addrs[256];
    uint16_t src_addrs_len = 0;
    byte rnd_addrs[64], rnd_data[64];
    byte rnd_len = 0;
    byte i;
    // Draw and remove from a source address pool, this guarantees we
    // don't pick the same address twice.
    while (src_addrs_len < 20) {
      byte pick = 8 + src_addrs_len;
      if (pick >= 0x0c)
        pick += 4;
      src_addrs[src_addrs_len++] = pick;
    }
    while (rnd_len < 8) {
      byte pick = rand() % src_addrs_len;
      rnd_addrs[rnd_len] = src_addrs[pick];
      src_addrs[pick] = src_addrs[--src_addrs_len];
      rnd_data[rnd_len] = rand() & 0xff;
      genSendWriteCmd(rnd_addrs[rnd_len], rnd_data[rnd_len]);
      rnd_len++;
    }
    while (rnd_len > 0) {
      // Pick an element randomly, read-verify it, then delete it from
      // the list by overwriting it with the last element.
      byte pick = rand() % rnd_len;
      byte actualVal = genSendReadCmd(rnd_addrs[pick]);
      if (verbose) {
        prTsStat("INFO:");
        printf("0x%02x: 0x%02x ?= 0x%02x\n", rnd_addrs[pick],
               actualVal, rnd_data[pick]);
      }
      result &= (actualVal == rnd_data[pick]);
      rnd_len--;
      rnd_addrs[pick] = rnd_addrs[rnd_len];
      rnd_data[pick] = rnd_data[rnd_len];
    }
    prTsStat((result) ? "PASS:" : "FAIL:");
    fputs("Random traditional PRAM register write/read\n", stdout);
    if (!result) failCount++;

    if (!testXPram) {
      prTsStat("SKIP:");
      fputs("Random XPRAM register write/read\n", stdout);
      skipCount++;
    } else {
      result = true;
      src_addrs_len = 0;
      // Draw and remove from a source address pool, this guarantees we
      // don't pick the same address twice.
      while (src_addrs_len < 256) {
        src_addrs[src_addrs_len] = src_addrs_len;
        src_addrs_len++;
      }
      while (rnd_len < 64) {
        byte pick = rand() % src_addrs_len;
        rnd_addrs[rnd_len] = src_addrs[pick];
        src_addrs[pick] = src_addrs[--src_addrs_len];
        rnd_data[rnd_len] = rand() & 0xff;
        genSendWriteXCmd(rnd_addrs[rnd_len], rnd_data[rnd_len]);
        rnd_len++;
      }
      while (rnd_len > 0) {
        // Pick an element randomly, read-verify it, then delete it from
        // the list by overwriting it with the last element.
        byte pick = rand() % rnd_len;
        byte actualVal = genSendReadXCmd(rnd_addrs[pick]);
        if (verbose) {
          prTsStat("INFO:");
          printf("0x%02x: 0x%02x ?= 0x%02x\n", rnd_addrs[pick],
                 actualVal, rnd_data[pick]);
        }
        result &= (actualVal == rnd_data[pick]);
        rnd_len--;
        rnd_addrs[pick] = rnd_addrs[rnd_len];
        rnd_data[pick] = rnd_data[rnd_len];
      }
      prTsStat((result) ? "PASS:" : "FAIL:");
      fputs("Random XPRAM register write/read\n", stdout);
      if (!result) failCount++;
    }
  }

  { /* Load and dump and memory linearly, compare for expected memory
       behavior.  */
    bool8_t result = false;
    uint8_t oldMonMode = getMonMode();
    byte expectedXPram[256];
    uint16_t i;

    result = true;
    setMonMode(2);
    // Randomly initialize group 1 registers.
    for (i = 0; i < 16; i++)
      expectedXPram[group1Base+i] = rand() & 0xff;
    // Randomly initialize group 2 registers.
    for (i = 0; i < 4; i++)
      expectedXPram[group2Base+i] = rand() & 0xff;
    // Copy both groups to RTC.
    memcpy(pram + group1Base, expectedXPram + group1Base, 16);
    memcpy(pram + group2Base, expectedXPram + group2Base, 4);
    if (verbose) {
      prTsStat("INFO:Expected data:\n");
      execMonLine("0008.001f\n");
    }
    loadAllTradMem();
    // Zero our host copy to be sure we don't compare stale data.
    memset(pram + group1Base, 0, 16);
    memset(pram + group2Base, 0, 4);
    dumpAllTradMem();
    if (verbose) {
      prTsStat("INFO:Actual data:\n");
      execMonLine("0008.001f\n");
    }
    result &= (memcmp(pram + group1Base,
                      expectedXPram + group1Base, 16) == 0);
    result &= (memcmp(pram + group2Base,
                      expectedXPram + group2Base, 4) == 0);
    prTsStat((result) ? "PASS:" : "FAIL:");
    fputs("Load and dump traditional PRAM\n", stdout);
    if (!result) failCount++;

    if (!testXPram) {
      prTsStat("SKIP:");
      fputs("Load and dump XPRAM\n", stdout);
      skipCount++;
    } else {
      setMonMode(2);
      for (i = 0; i < 256; i++)
        expectedXPram[i] = rand() & 0xff;
      memcpy(pram, expectedXPram, 256);
      if (verbose) {
        prTsStat("INFO:Expected data:\n");
        execMonLine("0000.00ff\n");
      }
      loadAllXMem();
      // Zero our host copy to be sure we don't compare stale data.
      memset(pram, 0, 256);
      dumpAllXMem();
      if (verbose) {
        prTsStat("INFO:Actual data:\n");
        execMonLine("0000.00ff\n");
      }
      result = (memcmp(pram, expectedXPram, 256) == 0);
      prTsStat((result) ? "PASS:" : "FAIL:");
      fputs("Load and dump XPRAM\n", stdout);
      if (!result) failCount++;
    }

    setMonMode(oldMonMode);
  }

  { /* Send invalid communication bit sequence, de-select, re-select
       chip, then send a valid communication sequence.  Verify that
       chip can robustly recover from invalid communication
       sequences.

       It turns out that the protocol is actually quite robust, the
       only way to potentially cause an invalid communication state
       would be to disable the chip-enable line before a communication
       sequence is complete.  */
    bool8_t result = false;
    byte testVal;
    genSendWriteCmd(0x10, 0xcd);
    serialBegin();
    { /* Fragmented sendByte() that would otherwise clobber the byte
         we just wrote.  Send only 6 out of 8 bits.  */
      uint8_t data = genCmd(0x10, true);
      uint8_t bitNum = 0;
      viaBitWrite(vBase + vDirB, rtcData, DIR_OUT);
      while (bitNum <= 5) {
        uint8_t bit = (data >> (7 - bitNum)) & 1;
        bitNum++;
        viaBitWrite(vBase + vBufB, rtcData, bit);
        waitQuarterCycle();
        viaBitWrite(vBase + vBufB, rtcClk, 1);
        waitHalfCycle();
        viaBitWrite(vBase + vBufB, rtcClk, 0);
        waitQuarterCycle();
      }
    }
    serialEnd();
    testVal = genSendReadCmd(0x10);
    if (verbose) {
      prTsStat("INFO:");
      printf("0x%02x ?= 0x%02x\n", testVal, 0xcd);
    }
    result = (testVal == 0xcd);
    prTsStat((result) ? "PASS:" : "FAIL:");
    fputs("Recovery from invalid communication\n", stdout);
    if (!result) failCount++;
  }

  printf("\n%d passed, %d failed, %d skipped\n",
         numTests - failCount - skipCount, failCount, skipCount);
  return (failCount == 0);
}

/********************************************************************/
/* `test-rtc` main function module */

/*
#include <stdio.h>
#include <string.h>

#include "arduino_sdef.h"
#include "simavr-support.h"
#include "cmdline.h"
#include "auto-test-suite.h"
*/

int main(int argc, char *argv[])
{
  char *firmwareName = "";
  bool8_t interactMode = false;
  int retVal;

  { // Parse command-line arguments.
    unsigned i;
    for (i = 1; i < argc; i++) {
      if (strcmp(argv[i], "-h") == 0 ||
          strcmp(argv[i], "--help") == 0) {
        printf("Usage: %s [-i] FIRMWARE_FILE\n"
               "\n"
               "    -i  Run interactive mode\n"
               "\n", argv[0]);
        return 0;
      } else if (strcmp(argv[i], "-i") == 0)
        interactMode = true;
      else
        firmwareName = argv[i];
    }
  }
  pramInit();
  retVal = setupSimAvr(argv[0], firmwareName, interactMode);
  if (retVal != 0)
    return retVal;

  if (interactMode) {
    fputs("Launching interactive console.\n"
          "Type help for summary of commands.\n", stdout);
    if (!cmdLoop()) {
      avr_terminate(avr);
      pramDestroy();
      return 1;
    }
    avr_terminate(avr);
    pramDestroy();
    return 0;
  }

  // Run automated test suite.
  fputs("Running automated test suite.\n", stdout);
  retVal = !autoTestSuite(false, true, true);
  avr_terminate(avr);
  pramDestroy();
  return retVal;
}
