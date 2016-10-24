---
layout: post
title: Programming Arduino with Assembly
---

{{ page.title }}
================

<p class="meta">23 Oct 2016</p>

Arduino is typically programmed with Arduino IDE with a set of C/C++ functions.
The canonical blink sketch which turns a led on/off every 1 second looks like:

```
void setup() {
  pinMode(13, OUTPUT);      // initialize digital pin 13 as an output
}

void loop() {
  digitalWrite(13, HIGH);   // turn the LED on (HIGH is the voltage level)
  delay(1000);              // wait for a second
  digitalWrite(13, LOW);    // turn the LED off by making the voltage LOW
  delay(1000);              // wait for a second
}
```

`pinMode`, `digitalWrite` and `delay` functions are defined by the Arduino
standard library. For the most part this works pretty well, and there are plenty
of libraries and example sketches.

For the sake of getting close to the metal, let's write the above sketch in
assembly instead. Before we do that we need to install couple depedencies. Assuming you're on OSX and you have brew install you'll need to do:

```
brew tap osx-cross/avr
brew install avr-libc avrdude
```

Here's an example from
[here](https://www.cypherpunk.at/2014/09/native-assembler-programming-on-arduino/).
Save it as `simple_led_blink.s`

```
.equ RAMEND, 0x8ff
.equ SREG, 0x3f
.equ SPL, 0x3d
.equ SPH, 0x3e
.equ PORTB, 0x05
.equ DDRB, 0x04
.equ PINB, 0x03

.org 0
rjmp main

main:
  ldi r16,0     ; reset system status
  out SREG,r16  ; init stack pointer
  ldi r16,lo8(RAMEND)
  out SPL,r16
  ldi r16,hi8(RAMEND)
  out SPH,r16

  ldi r16,0x20  ; set port bits to output mode
  out DDRB,r16

  clr r17

mainloop:
  eor r17,r16   ; invert output bit
  out PORTB,r17 ; write to port
  call wait     ; wait some time
  rjmp mainloop ; loop forever

wait:
  push r16
  push r17
  push r18

  ldi r16,0x40 ; loop 0x400000 times
  ldi r17,0x00 ; ~12 million cycles
  ldi r18,0x00 ; ~0.7s at 16Mhz

_w0:
  dec r18
  brne _w0
  dec r17
  brne _w0
  dec r16
  brne _w0

  pop r18
  pop r17
  pop r16
  ret
```

Explaining what the above assembly code does is out of scope of this small blog
post.

Now connect your Arduino to your computer with usb and run the following
commands from your terminal:

```
avr-as -g -mmcu=atmega328p -o simple_led_blink.o simple_led_blink.s
avr-ld -o simple_led_blink.elf simple_led_blink.o
avr-objcopy -O ihex -R .eeprom simple_led_blink.elf simple_led_blink.hex
avrdude  -p atmega328p -c arduino -P /dev/tty.usbmodem14221 -b 115200 -D -U flash:w:simple_led_blink.hex:i
```

You'll most likely need to change `/dev/tty.usbmodem14221` to whatever usb port
your Arduino is connected to. To find which one run `ls /deve/tty.*` and pick
the one without `Bluetooth` in the file name.

Most of the above instructions are from
[here](https://www.cypherpunk.at/2014/09/native-assembler-programming-on-arduino/),
frankly without it this process would've been much longer and way more tedious.
