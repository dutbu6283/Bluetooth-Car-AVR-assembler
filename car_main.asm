;
; car_main_v2.asm
;
; Created: 2019-03-12 20:06:02
; Author : Dutsadi Bunliang
;

; ---------------------------------------
; --- INC START: usart.inc
; ---------------------------------------

	.equ	UBRR_VALUE = 7
	.equ	BUFFER_SIZE = 2

; ---------------------------------------
; --- INC END: usart.inc
; ---------------------------------------
	
; ---------------------------------------
; --- INC START: motor.inc
; ---------------------------------------

	; Instruction 
	.equ	MOTUR = $02
	.equ	MEDUR = $01
	.equ	FAST_STOP = $03
	.equ	FREE_STOP = $00
	; PWM output frequency 
	.equ	ICR1_TOP = 64	
	.equ	TOV1_PERIOD = 1039 
	; Motor ID
	.equ	MIDA = 0
	.equ	MIDB = 1

; ---------------------------------------
; --- INC END: motor.inc
; ---------------------------------------

; ---------------------------------------
; --- INC START: ultrasound.inc
; ---------------------------------------

	.equ	DIST_COUNT_TOP = 255
	.equ	OCR0_TOP = 23

; ---------------------------------------
; --- INC END: ultrasound.inc
; ---------------------------------------

	.org	0
	jmp		cold
	.org	URXCaddr  
	jmp		usart_buffer_RXC
	.org	OC0addr
	jmp		timer0_OCF
	
	.dseg
	.org	$60

; ---------------------------------------
; --- SRAM START: usart.asm
; ---------------------------------------

	TX_BUFFER_POS:
		.byte	1
	TX_BUFFER_BEGIN:
		.byte	1
	TX_BUFFER_END:
		.byte	1
	;
	RX_BUFFER_POS:
		.byte	1
	RX_BUFFER_BEGIN:
		.byte	1
	RX_BUFFER_END:
		.byte	1

; ---------------------------------------
; --- SRAM END: usart.asm
; ---------------------------------------

; ---------------------------------------
; --- SRAM START: motor.asm
; ---------------------------------------

	MOTOR_ID:		
		.byte	1
	MOTOR_SPEED:	
		.byte	1
	MOTOR_STATE:	
		.byte	1

; ---------------------------------------
; --- SRAM END: motor.asm
; ---------------------------------------

; ---------------------------------------
; --- SRAM START: ultrasound.asm
; ---------------------------------------

	DIST_COUNT:
		.byte	1

; ---------------------------------------
; --- SRAM END: ultrasound.asm
; ---------------------------------------

	.cseg

; ---------------------------------------
; --- START: car_main.asm
; ---------------------------------------

cold:
	ldi		r16, LOW(RAMEND)
	out		SPL, r16
	ldi		r16, HIGH(RAMEND)
	out		SPH, r16
	call	usart_hw_init
	call	motor_hw_init
	call	ultrasound_hw_init
	sei

start:
	; 
	ldi		YL, LOW(RX_BUFFER_BEGIN)
	ldi		YH, HIGH(RX_BUFFER_BEGIN)
	ld		r16, Y+
	push	r16
	ld		r16, Y
	call	status_update
	pop		r16
	call	status_update 
	; 
	ldi		YL, LOW(DIST_COUNT)
	ldi		YH, HIGH(DIST_COUNT)
	ld		r16, Y
	cpi		r16, DIST_COUNT_TOP
	brne	start
	;
	inc		r19
	cpi		r19, $A0
	brne	start
	clr		r19
	;
	call	get_distance
	call	usart_transmit
    jmp	start

; ---------------------------------------
; --- status_update: Update motors on the car.
; --- Argument: r16 (encoded data)
; --- Return: None
; --- Uses: r16, r17, r18, Y, Z
; --- Usage:
; --- ldi	YL, LOW(RX_BUFFER_BEGIN)
; --- ldi	YH, HIGH(RX_BUFFER_BEGIN)
; --- ld	r16, Y
; --- call	status_update
; ---------------------------------------
status_update:
	call	decode
	ldi		YL, LOW(MOTOR_ID)
	ldi		YH, HIGH(MOTOR_ID)
	st		Y+, r16
	st		Y+, r17
	st		Y, r18
	call	motor_update 
	ret

; ---------------------------------------
; --- decode: Decode a byte.
; --- Argument: r16 (encoded data)
; --- Return: r16 (motor id), r17 (motor speed), r18 (motor state)
; --- Uses: r16, r17, r18
; --- Usage:
; --- ldi	YL, LOW(RX_BUFFER_BEGIN)
; --- ldi	YH, HIGH(RX_BUFFER_BEGIN)
; --- ld	r16, Y
; --- call	decode
; ---------------------------------------
decode:
	mov		r17, r16 
	mov		r18, r16
	andi    r16, 0b00000011 ; id
	andi	r17, 0b11110000 ; speed
	swap	r17
	andi	r18, 0b00001100 ; state
	lsr		r18
	lsr		r18
	ret

; ---------------------------------------
; --- END: car_main.asm
; ---------------------------------------

; ---------------------------------------
; --- START: usart.asm
; ---------------------------------------

; ---------------------------------------
; --- usart_transmit: Transmit a byte with USART.
; --- Argument: r16 (data)
; --- Return: None
; --- Uses: r16
; --- Usage:
; --- ldi	r16, $F0
; --- call	usart_transmit
; ---------------------------------------
usart_transmit:
	sbis	UCSRA, UDRE
	rjmp	usart_transmit
	out		UDR, r16
	ret

; ---------------------------------------
; --- usart_buffer_RXC: An interrupt that handle incoming datastream from the controller.
; --- Argument: None
; --- Return: None
; --- Uses: r16, Y
; ---------------------------------------
usart_buffer_RXC:
	push	r16
	in		r16, SREG
	push	r16
	push	YL
	push	YH
	;
	ldi		YL, LOW(RX_BUFFER_POS)
	ldi		YH, HIGH(RX_BUFFER_POS)
	ld		r16, Y
	inc		r16
	cpi		r16, BUFFER_SIZE + 1
	brlo	usart_buffer_incomplete
	ldi		r16, 1
	st		Y, r16
usart_buffer_incomplete:
	st		Y, r16	; Update buffer pos
	add		YL, r16
	clr		r16
	adc		YH, r16
	in		r16, UDR
	st		Y, r16 ; Store value in right position
	;
	pop		YH
	pop		YL
	pop		r16
	out		SREG, r16
	pop		r16
	reti

; ---------------------------------------
; --- usart_hw_init: Init. resources used by USART.
; --- Argument: None
; --- Return: None
; --- Uses: r16, Y
; --- Usage:
; --- call	usart_hw_init
; ---------------------------------------
usart_hw_init:
	; Init. port
	in		r16, DDRD
	ldi		r16, (1 << DDD1) 
	out		DDRD, r16
	; Init. USART 
	ldi		r16, HIGH(UBRR_VALUE)
	out		UBRRH, r16
	ldi		r16, LOW(UBRR_VALUE)
	out		UBRRL, r16
	;
	ldi		r16, (1 << RXCIE) | (1 << RXEN) | (1 << TXEN)
	out		UCSRB, r16
	;
	ldi		r16, (1 << URSEL) | (0 << UMSEL) | (1 << USBS) | (1 << UCSZ1) | (1 << UCSZ0)
	out		UCSRC, r16
	;
	clr		r16
	ldi		YL, LOW(TX_BUFFER_POS)
	ldi		YH, HIGH(TX_BUFFER_POS)
	st		Y, r16
	ldi		YL, LOW(RX_BUFFER_POS)
	ldi		YH, HIGH(RX_BUFFER_POS)
	st		Y, r16
	ret

; ---------------------------------------
; --- END: usart.asm
; ---------------------------------------

; ---------------------------------------
; --- START: motor.asm
; ---------------------------------------

; ---------------------------------------
; --- motor_update: Move motor A and B using motor id, motor state and motor speed in SRAM.
; --- Argument: None
; --- Return: None
; --- Uses: Y, Z
; --- Usage:
; --- call motor_update
; ---------------------------------------
motor_update:
	ldi		ZH, HIGH(MOTOR_ID)
	ldi		ZL, LOW(MOTOR_ID)
	ld		YL, Z+ ; Read motor_id
	ld		YH, Z+ ; Read motor_speed
	;
	cpi     YL, MIDA
	brne	PC + 2
	jmp		case_a
	;
	cpi     YL, MIDB
	brne	PC + 2
	jmp		case_b
	jmp		update_done
case_a:
	call	cycle_compute
	cli
	out		OCR1AH, YH
	out		OCR1AL, YL
	sei
	call	wait_next_TOV1
	; Clear prev. state
	cbi		PORTA, 0
	cbi		PORTA, 1
	; Write state
	ld		YL, Z ; Read motor_state
	jmp		update_state
case_b:
	call	cycle_compute
	cli
	out		OCR1BH, YH
	out		OCR1BL, YL
	sei
	call	wait_next_TOV1
	; Clear prev. state
	cbi		PORTA, 2
	cbi		PORTA, 3
	; Write state
	ld		YL, Z ; Read motor_state
	lsl		YL
	lsl		YL
update_state:
	in		YH, PORTA
	or		YL, YH
	out		PORTA, YL
update_done:
	ret	

; ---------------------------------------
; --- cycle_compute: Return a duty cycle constant.
; --- Argument: YL (motor_speed)
; --- Return: Y (duty cycle constant)
; --- Uses: Y, Z
; --- Usage:
; --- in	ZL, LOW(MOTOR_SPEED)
; --- in	ZH, HIGH(MOTOR_SPEED)
; --- ld	YL, Z
; --- call	cycle_compute
; --- mov	r16, YL
; --- mov	r17, YH
; ---------------------------------------
cycle_compute:
	push    ZH
	push    ZL
	; Check valid speed
	cpi		YH, 16
	brlo	cycle_in_range
	ldi		YH, 0
cycle_in_range:
	ldi		ZL, LOW(DUTY_CYCLE*2)			
	ldi		ZH, HIGH(DUTY_CYCLE*2)
	add		ZL, YH
	clr		YH
	adc		ZH, YH
	lpm		YL, Z 
	;
	pop     ZL
	pop     ZH
	ret

; ---------------------------------------
; --- wait_next_TOV1: Ensure that one TOV1 period has occurred.
; --- Argument: None
; --- Return: None
; --- Uses: Y
; --- Usage:
; --- call	wait_next_TOV1
; ---------------------------------------
wait_next_TOV1:
	ldi		YH, HIGH(TOV1_PERIOD)
	ldi		YL, LOW(TOV1_PERIOD)
wait_next0:
	sbiw	Y, 1
	brne	wait_next0
	ret

; ---------------------------------------
; --- pwm_start: Start timer1 in fast pwm mode.
; --- Argument:	None
; --- Return: None
; --- Uses: Y
; --- Usage:
; --- call	pwm_start
; ---------------------------------------
pwm_start:
	in		YL, TCCR1B
	ori		YL, (0 << ICNC1) | (0 << ICES1) | (0 << 5) | (1 << WGM13) | (1 << WGM12) | (0 << CS12) | (1 << CS11) | (1 << CS10) 
	out		TCCR1B, YL
	;
	in		YL, TCCR1A
	ori		YL, (1 << COM1A1) | (1 << COM1A0) | (1 << COM1B1) | (1 << COM1B0)  | (0 << FOC1A) | (0 << FOC1B) | (1 << WGM11) | (0 << WGM10)  
	out		TCCR1A, YL
	ret

; ---------------------------------------
; --- motor_hw_init: Init. resources used by motor.
; --- Argument:	None
; --- Return: None
; --- Uses: r16
; --- Usage:
; --- call	motor_hw_init
; ---------------------------------------
motor_hw_init:
	; Init. motor_state port
	in		r16, DDRA
	ori		r16, $0F
	out		DDRA, r16
	; Init. PWM port
	in		r16, DDRD
	ori		r16, (1 << PORTD4)|(1 << PORTD5)
	out		DDRD, r16
	; Setup idle 
	in	    r16, PORTA
	ori		r16, $0F
	out		PORTA, r16
	;
	ldi		YH, HIGH(ICR1_TOP)
	ldi		YL, LOW(ICR1_TOP)
	out		ICR1H, YH
	out		ICR1L, YL
	;
	ldi		YH, HIGH(ICR1_TOP-1)
	ldi		YL, LOW(ICR1_TOP-1)
	out		OCR1BH, YH
	out		OCR1BL, YL
	;
	out		OCR1AH, YH
	out		OCR1AL, YL
	call	pwm_start
	ret

; ---------------------------------------
; --- FLASH: Duty cycle constant
; --- It is important that OCRnX its not equal 0 and ICRI_TOP, because it will lead to interrups crashes. Read about timer1 in datasheet!.
; ---------------------------------------
DUTY_CYCLE:	
	.db		120, 112, 104, 96, 88, 80, 72, 64, 56, 48, 40, 32, 24, 16, 8, 1

; ---------------------------------------
; --- END: motor.asm
; ---------------------------------------

; ---------------------------------------
; --- START: ultrasound.asm
; ---------------------------------------

; ---------------------------------------
; --- get_distance: Start the ultrasound module and return a distance between 3-100 cm.
; --- Argument:	none
; --- Return: r16 (distance in cm)
; --- Uses: r16, Y, Z
; --- Usage:
; --- call	get_distance
; ---------------------------------------
get_distance:	
	; Setup 
	cbi		PORTA, 6
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
	cli
	call	dist_count_reset
	sei	
wait_echo_low:
	sbic	PINA, 5
	rjmp	wait_echo_low
	call	distance_compute
	push	r16
	cli
	call	dist_count_reset
	sei 
	pop		r16
	ret

; ---------------------------------------
; --- distance_compute: Use DIST_COUNT to get the distance.
; --- Argument:	DIST_COUNT
; --- Return: r16 (distance in cm)
; --- Uses: r16, Y, Z
; --- Usage:
; --- call	distance_compute
; ---------------------------------------
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
	lpm		r16, Z 
	ret

; ---------------------------------------
; --- dist_count_reset: Reset DIST_COUNT to zero.
; --- Argument:	None
; --- Return: None
; --- Uses: r16, Y
; --- Usage:
; --- cli
; --- call	dist_count_reset
; --- sei 
; ---------------------------------------
dist_count_reset:
	ldi		YL, LOW(DIST_COUNT)
	ldi		YH, HIGH(DIST_COUNT)
	clr		r16
	st		Y, r16
	ret

; ---------------------------------------
; --- timer0_start: Start timer0.
; --- Argument:	None
; --- Return: None
; --- Uses: r16
; --- Usage:
; --- call	timer0_start
; ---------------------------------------
timer0_start:
	ldi		r16, (0 << COM01) | (0 << COM00) | (1 << WGM01) |(0 << WGM00) | (0 << CS02) | (1 << CS01) | (1 << CS00)
	cli
	out		TCCR0, r16
	sei
	ret

; ---------------------------------------
; --- timer0_OCF: An interrupt that increment DIST_COUNT by one every 100 microsecond. The increment is stop when DIST_COUNT reach DIST_COUNT_TOP, DIST_COUNT will not change until it is cleard.
; --- Argument:	None
; --- Return: None
; --- Uses: r16, Y
; ---------------------------------------
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

; ---------------------------------------
; --- ultrasound_hw_init: Init. resources used by ultrasound.
; --- Argument:	None
; --- Return: None
; --- Uses: r16
; --- Usage:
; --- call	ultrasound_hw_init
; ---------------------------------------
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
	call	dist_count_reset
	call	timer0_start
	ret

; ---------------------------------------
; --- FLASH: Distance constant in cm.
; ---------------------------------------
DISTANCE_TABLE:
	.db		3, 3, 3, 5, 5, 5, 10, 10, 10, 15, 15, 15, 20, 20, 20, 25, 25, 25, 30, 30, 30, 30, 30, 30, 40, 40, 40, 40, 40, 40, 50, 50, 50, 50, 50, 50, 60, 60, 60, 60, 60, 60, 70, 70, 70, 70, 70, 70, 80, 80, 80, 80, 80, 80, 90, 90, 90, 90, 90, 90, 90, 100, 100, 100, 100, 100, 100, $00

; ---------------------------------------
; --- END: ultrasound.asm
; ---------------------------------------
