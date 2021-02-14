
; ultrasound_v1.asm
;
; Created: 2019-02-22 21:30:57
; Author : Dutsadi Bunliang
;

; ---------------------------------------
; --- Ultrasound: Constant
; ---------------------------------------
	.equ	DIST_COUNT_TOP = 255
	.equ	OCR0_TOP = 23

	.org	0
	jmp		cold
	.org	OC0addr
	jmp		timer0_OCF

	.dseg
; ---------------------------------------
; --- SRAM: Ultrasound values layout
; ---------------------------------------
DIST_COUNT:
	.byte	1

	.cseg
cold:
	ldi		r16, LOW(RAMEND)
	out		SPL, r16
	ldi		r16, HIGH(RAMEND)
	out		SPH, r16
	ldi		r16, 1
	out		DDRA, r16
	call	ultrasound_hw_init
	sei
	;call	timer0_start

start:
	; Distance
	;call	get_distance
	call	distance_compute
	; Wait for next 
s:
	sbi		PORTA, 0
	rjmp	s 
    rjmp	start

; ---------------------------------------
; --- START: ultrasound.asm
; ---------------------------------------

get_distance:	
	; Setup 
	cbi		PORTA, 6
	call	clr_dist_count
	; Start ultrasound sensor
	sbi		PORTA, 6
	ldi		r16, 52
wait_10us:
	dec		r16
	brne	wait_10us
	cbi		PORTA, 6 
wait_echo_high:
	sbis	PINA, 5
	rjmp	wait_echo_high	
	call	timer0_start
wait_echo_low:
	sbic	PINA, 5
	rjmp	wait_echo_low
	call	timer0_sreset
	ret

distance_compute:
	ldi		YL, LOW(DIST_COUNT)
	ldi		YH, HIGH(DIST_COUNT)
	ldi		ZL, LOW(DISTANCE_TABLE*2)
	ldi		ZH, HIGH(DISTANCE_TABLE*2)
	ld		r16, Y		
	cpi		r16, 67
	brlo	not_max_dist
	ldi		r16, 66
not_max_dist:
	add		ZL, r16
	clr		r16
	adc		ZH, r16		
	lpm		r16, Z		//Get DIST_CONST
	ret

clr_dist_count:
	ldi		YL, LOW(DIST_COUNT)
	ldi		YH, HIGH(DIST_COUNT)
	clr		r16
	st		Y, r16
	ret

	// 100us per count
timer0_start:
	ldi		r16, (0 << COM01) | (0 << COM00) | (1 << WGM01) |(0 << WGM00) | (0 << CS02) | (1 << CS01) | (1 << CS00)
	out		TCCR0, r16
	ret

timer0_sreset:
	ldi		r16, (0 << COM01) | (0 << COM00) | (1 << WGM01) |(0 << WGM00) | (0 << CS02) | (0 << CS01) | (0 << CS00)
	out		TCCR0, r16
	clr		r16
	cli
	out		TCNT0, r16
	sei
	ret

timer0_OCF:
	push	r16
	in		r16, SREG
	push	r16
	push	YL
	push	YH
	;
	ldi		YL, LOW(DIST_COUNT)
	ldi		YH, HIGH(DIST_COUNT)
	ld		r16, Y
	cpi		r16, DIST_COUNT_TOP
	brne	timer0_inc
	cbi		PINA, 5
	rjmp	timer0_done
timer0_inc:
	inc		r16
	st		Y, r16
timer0_done: 
	;  
	pop		YH
	pop		YL
	pop		r16
	out		SREG, r16
	pop		r16
	reti

ultrasound_hw_init:
	; Init. port
	in		r16, DDRA
	ori		r16, (1 << DDA6) | (0 << DDA5)
	out		DDRA, r16
	;
	ldi		r16, OCR0_TOP
	out		OCR0, r16
	; Init. timer0 
	in		r16, TIMSK
	ori		r16, (1 << OCIE0)
	out		TIMSK, r16
	;
	ret

DISTANCE_TABLE:
	.db		3, 3, 3, 5, 5, 5, 10, 10, 10, 15, 15, 15, 20, 20, 20, 25, 25, 25, 30, 30, 30, 30, 30, 30, 40, 40, 40, 40, 40, 40, 50, 50, 50, 50, 50, 50, 60, 60, 60, 60, 60, 60, 70, 70, 70, 70, 70, 70, 80, 80, 80, 80, 80, 80, 90, 90, 90, 90, 90, 90, 90, 100, 100, 100, 100, 100, 100, $00

; ---------------------------------------
; --- END: ultrasound.asm
; ---------------------------------------