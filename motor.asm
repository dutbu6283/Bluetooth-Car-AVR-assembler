;
; motor_v3.asm
;
; Created: 2019-03-12 21:30:11
; Author : Dutsadi Bunliang
;

	.org	0
	jmp		main_cold



; ---------------------------------------
; --- Motor: Constant
; ---------------------------------------
	; Intruction 
	.equ	MOTUR = $02
	.equ	MEDUR = $01
	.equ	FAST_STOP = $03
	.equ	FREE_STOP = $00
	; PWM output frequency 
	.equ	ICR1_TOP = 121 //64	// 896
	.equ	TOV1_PERIOD = 1960//1039 //64 14366 //8  1792
	; Motor ID
	.equ	MIDA = 0
	.equ	MIDB = 1

; ---------------------------------------
; --- START: motor.asm
; ---------------------------------------

	.dseg
; ---------------------------------------
; --- SRAM: Motor values layout
; 
MOTOR_ID:		
	.byte	1
MOTOR_SPEED:	
	.byte	1
MOTOR_STATE:	
	.byte	1

	.cseg 


	; TEST
main_cold:
	; Init. SP
	ldi		r16, HIGH(RAMEND)
	out		SPH, r16
	ldi		r16, LOW(RAMEND)
	out		SPL, r16
	; Init. hardware
	call	motor_hw_init
	sei
	call	wait_next_TOV1
	
main_start:
	; test1
	ldi		r16, MIDB
	push	r16
	ldi		r16, 8
	push	r16
	ldi		r16, MOTUR
	push	r16
	call	motor_write
	pop		r16
	pop		r16
	pop		r16
	;
	call	motor_update
	;
	ldi		r16, MIDA
	push	r16
	ldi		r16, 15
	push	r16
	ldi		r16, MEDUR
	push	r16
	call	motor_write
	pop		r16
	pop		r16
	pop		r16
	;
	call	motor_update
s:
	jmp s 
	jmp		main_start

; ---------------------------------------
; --- motor_update: Move motor A and B using motor values in SRAM
; --- Argument: None
; --- Return: None
; --- Uses: Y, Z
; --- Usage:
; --- call motor_update
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
; --- cycle_compute: Return a duty cycle constant i FLASH
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
;
cycle_compute:
	push    ZH
	push    ZL
	; Check valid speed
	cpi		YH, 16
	brlo	cycle_in_range
	ldi		YH, 0
cycle_in_range:
	;
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
; --- wait_next_TOV1: Ensure that one TOV1 period has occurred
; --- Argument: None
; --- Return: None
; --- Uses: Y
; --- Usage:
; --- call	wait_next_TOV1
;
wait_next_TOV1:
	ldi		YH, HIGH(TOV1_PERIOD)
	ldi		YL, LOW(TOV1_PERIOD)
wait_next0:
	sbiw	Y, 1
	brne	wait_next0
	ret

; ---------------------------------------
; --- motor_write: Update motor values stored in SRAM
; --- Argument:	3 push with values in fallowing order, MOTOR_ID (push nr1), MOTOR_SPEED (push nr2), MOTOR_STATE (push nr3)
; --- Return: None
; --- Uses: r16, Y, Z
; --- Usage:
; --- ldi	r16, MIDA ; motor_id
; --- ldi	r17, $FF ; motor_speed
; --- ldi	r18, MOTUR ; motor_state
; --- push	r16
; --- push	r17
; --- push	r18
; --- call	motor_write
; --- pop	r16
; --- pop   r16
; --- pop	r16
;
motor_write:
	in		ZH, SPH
	in		ZL, SPL
	ldi		YL, LOW(MOTOR_STATE+1)
	ldi		YH, HIGH(MOTOR_STATE+1)
	; set motor_state
	ldd		r16, Z + 3
	st		-Y, r16
	; set motor_speed
	ldd		r16, Z + 4
	st		-Y, r16
	; set motor_id
	ldd		r16, Z + 5
	st		-Y, r16
	ret

; ---------------------------------------
; --- motor_read: Return motor values stored in SRAM
; --- Argument:	3 push
; --- Return: 3 pop with value in fallowing order, MOTOR_STATE (pop nr1), MOTOR_SPEED (pop nr2), MOTOR_ID (pop nr3)
; --- Uses:	r16, Y, Z
; --- Usage:
; --- push	r16
; --- push	r16
; --- push	r16
; --- call	motor_read
; --- pop	r16	; motor_state
; --- pop	r17 ; motor_speed
; --- pop	r18 ; motor_id
; 
motor_read:
	in		ZH, SPH
	in		ZL, SPL
	ldi		YL, LOW(MOTOR_STATE+1)
	ldi		YH, HIGH(MOTOR_STATE+1)
	; get motor_state
	ld		r16, -Y
	std		Z + 3, r16
	; get motor_speed
	ld		r16, -Y
	std		Z + 4, r16
	; get motor_id
	ld		r16, -Y
	std		Z + 5, r16
	ret
	
; ---------------------------------------
; --- pwm_sreset: Stop and reset timer1 
; --- Argument: None
; --- Return: None
; --- Uses: YL
; --- Usage:
; --- call	pwm_sreset
; 
pwm_sreset:
	in		YL, TCCR1B
	andi	YL, (1 << ICNC1) | (1 << ICES1) | (1 << 5) | (0 << WGM13) | (0 << WGM12) | (0 << CS12) | (0 << CS11) | (0 << CS10) 
	out		TCCR1B, YL
	in		YL, TCCR1A
	andi	YL, (0 << COM1A1) | (0 << COM1A0) | (0 << COM1B1) | (0 << COM1B0) | (1 << FOC1A) | (1 << FOC1B)  | (0 << WGM11) | (0 << WGM10) 
	out		TCCR1A, YL
	;
	clr		YL
	out		TCNT1H, YL
	out		TCNT1L, YL
	ret

; ---------------------------------------
; --- pwm_start: Start timer1 fast pwm mode
; --- Argument:	None
; --- Return: None
; --- Uses: Y
; --- Usage:
; --- call	pwm_start
; 
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
; --- motor_hw_init: Init. ports used by motor
; --- Argument:	None
; --- Return: None
; --- Uses: r16
; --- Usage:
; --- call	motor_hw_init
; 
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
;
	
DUTY_CYCLE:	// VIKTIG! OCRnX får INTE vara lika med TOP och BOTTOM
	.db		120, 112, 104, 96, 88, 80, 72, 64, 56, 48, 40, 32, 24, 16, 8, 1, $00
; ---------------------------------------
; --- END: motor.asm
; ---------------------------------------