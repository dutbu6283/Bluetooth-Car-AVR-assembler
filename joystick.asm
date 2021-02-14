;
; joy_v1.asm
;
; Created: 2019-02-14 07:48:54
; Author : Dutsadi Bunliang
;

	.org 0
	.cseg
	jmp		main_cold

; ---------------------------------------
; --- JOYSTICK: Constant
;
	.equ JOYID_RIGHT_X = (1 << ADLAR) | PINA6
	//.equ JOYID_RIGHT_Y = (1 << ADLAR) | PINA5
	;
	//.equ JOYID_LEFT_X = (1 << ADLAR) | PINA4
	.equ JOYID_LEFT_Y = (1 << ADLAR) | PINA3

; ---------------------------------------
; --- START: joystick.asm
; ---------------------------------------

	.dseg
; ---------------------------------------
; --- JOYSTICK: SRAM layout
;
AXIS_X:
	.byte	1
AXIS_Y:
	.byte	1

	.cseg

; TEST
main_cold:
	ldi		r16, HIGH(RAMEND)
	out		SPH, r16
	ldi		r16, LOW(RAMEND)
	out		SPL, r16
	ldi		r16, $FF
	out		DDRB, r16
	call	joy_hw_init

main_start:
    ldi		YL, JOYID_LEFT_Y
	call	read_ADC
	out		PORTB, YH
    rjmp	 main_start

; ---------------------------------------
; --- read_ADC: Read ADC pin and return digital representation 
; --- Argument YL (ADC pin)
; --- Return: YL (data)
; --- Uses: YL
; --- Usage:
; --- ldi	YL, ADMC7 ; Enable coverting on pin ADC7
; --- call	read_ADC
; --- mov	r16, YL	
;
read_ADC:
	out		ADMUX, YL
	sbi		ADCSRA, ADSC
read_adc_wait0:
	sbic	ADCSRA, ADSC
	rjmp	read_adc_wait0
	in		YL, ADCL
	in		YH, ADCH
	ret

; ---------------------------------------
; --- write_SRAM: Write 1 byte to SRAM
; --- Argument: r16 (data), Y (SRAM address)
; --- Return: None
; --- Uses: r16, Y
; --- Usage:
; --- ldi	r16, $0A
; --- ldi	YL, LOW(AXIS_X)
; --- ldi	YH, HIGH(AXIS_X)
; --- call	write_SRAM
;	
write_SRAM:
	st	Y, r16
	ret

; ---------------------------------------
; --- read_SRAM: Return 1 byte from SRAM
; --- Argument: Y (SRAM address)
; --- Return: r16 (data)
; --- Uses: r16, Y
; --- Usage:
; --- ldi	YL, LOW(AXIS_X)
; --- ldi	YH, HIGH(AXIS_X)
; --- call	write_SRAM
; --- mov	YL, r16
;
read_SRAM:
	ld	r16, Y
	ret

; ---------------------------------------
; --- joy_hw_init: 
; --- Argument: None
; --- Return: None
; --- Uses: r16
; --- Usage:
; --- call	joy_hw_init
; 
joy_hw_init:
	; Init. port
	in		r16, DDRA
	andi	r16, (1 << DDA7) | (0 << DDA6) | (0 << DDA5) | (0 << DDA4) | (0 << DDA3) | (1 << DDA2) | (1 << DDA1) | (1 << DDA0) 
	out		DDRA, r16
	; Init. ADC
	ldi		r16, (1 << ADEN) | (1 << ADSC)| (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0) //125kHz
	out		ADCSRA, r16
	ret

; ---------------------------------------
; --- END: joystick.asm
; ---------------------------------------