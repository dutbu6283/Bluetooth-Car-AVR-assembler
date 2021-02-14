;
; car_controller_main_v2.asm
;
; Created: 2019-03-12 20:08:49
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
; --- INC START: joystick.inc
; ---------------------------------------

	.equ JOYID_RIGHT_X = (1 << ADLAR) | PINA6
	.equ JOYID_RIGHT_Y = (1 << ADLAR) | PINA5
	;
	.equ JOYID_LEFT_X = (1 << ADLAR) | PINA4
	.equ JOYID_LEFT_Y = (1 << ADLAR) | PINA3

; ---------------------------------------
; --- INC END: joystick.inc
; ---------------------------------------

; ---------------------------------------
; --- INC START: lcd.inc
; ---------------------------------------

	.equ	LCD_RS = 2
	.equ	LCD_RW = 1
	.equ	LCD_E = 0

; ---------------------------------------
; --- INC END: lcd.inc
; ---------------------------------------

	.org	0
	jmp		cold
	.org	URXCaddr  
	jmp		usart_RXC

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
; --- SRAM START: lcd.asm
; ---------------------------------------

	RECIEVED_DATA:
		.byte	1
	JOYSTICK_X_DATA:
		.byte	1
	JOYSTICK_Y_DATA:
		.byte	1

; ---------------------------------------
; --- SRAM END: lcd.asm
; ---------------------------------------

	.cseg

; ---------------------------------------
; --- START: con_main.asm
; ---------------------------------------

cold:
	ldi		r16, LOW(RAMEND)
	out		SPL, r16
	ldi		r16, HIGH(RAMEND)
	out		SPH, r16
	call	joy_hw_init
	call	usart_hw_init
	call	lcd_init
	clr		r20
	sei

start:	
	; 
	ldi		XL, LOW(RX_BUFFER_BEGIN)
	ldi		XH, HIGH(RX_BUFFER_BEGIN)
	ld		r16, X
	ldi		XL, LOW(RECIEVED_DATA)
	ldi		XH, HIGH(RECIEVED_DATA)
	st		X+, r16	; Update lcd distance
	; 
	ldi		r16, MIDA
	ldi		YL, JOYID_LEFT_X
	call	read_ADC
	call	encode
	push	r16
	st		X+, YH 	; Update lcd x
	;
	ldi		r16, MIDB
	ldi		YL, JOYID_RIGHT_Y
	call	read_ADC
	call	encode
	st		X, YH ; Update lcd y
	; 
	ldi		YL, LOW(TX_BUFFER_BEGIN)
	ldi		YH, HIGH(TX_BUFFER_BEGIN)
	st		Y+, r16	
	pop		r16
	st		Y, r16
	call	usart_buffer_transmit
	; 
	inc		r20
	cpi		r20, $FF
	brne	start
	clr		r20 
	call	LCD_update
	jmp	start


; ---------------------------------------
; --- encode: Encode motor id, motor state and motor speed into a byte.
; --- Argument: r16 (motor id), YH (speed)
; --- Return: r16 
; --- Uses: r16, r17, r18
; --- Usage:
; --- ldi	r16, MIDB
; --- ldi	YL, JOYID_RIGHT_Y
; --- call	read_ADC
; --- call	encode
; ---------------------------------------
encode:
	mov		r18, YH	; speed
	cpi		r18, 116
	brlo	encode_motur
	cpi		r18, 140
	brsh	encode_medur
	ldi		YH, 128
encode_idle:
	clr		r18
	ldi		r17, FAST_STOP
	rjmp	encode_start
encode_motur:
	com		r18
	subi	r18, -128
	ldi		r17, MOTUR
	rjmp	encode_start
encode_medur:
	subi	r18, -128
	ldi		r17, MEDUR
encode_start:
	lsl		r17
	lsl		r17
	or		r16, r17
	lsr		r18
	lsr		r18
	lsr		r18
	swap	r18
	or		r16, r18
	ret

; ---------------------------------------
; --- END: con_main.asm
; ---------------------------------------

; ---------------------------------------
; --- START: usart.asm
; ---------------------------------------

; ---------------------------------------
; --- usart_buffer_transmit: Iterate over tx_buffer in SRAM and transmit the data with USART. Start at tx_buffer_begin and stop at tx_buffer_end.
; --- Argument: SRAM, whole tx_buffer
; --- Return: None
; --- Uses: r16, Y
; --- Usage:
; --- 	ldi		YL, LOW(TX_BUFFER_BEGIN)
; --- 	ldi		YH, HIGH(TX_BUFFER_BEGIN)
; --- 	st		Y+, r16	
; --- 	pop		r16
; --- 	st		Y, r16
; --- 	call	usart_buffer_transmit
; ---------------------------------------
usart_buffer_transmit:
	ldi		YL, LOW(TX_BUFFER_BEGIN)
	ldi		YH, HIGH(TX_BUFFER_BEGIN)
usart_buffer_loop0:
	ld		r16, Y+
	call	usart_transmit
	call	wait_RXC_complete
	cpi		YL, LOW(TX_BUFFER_END + 1)
	brne	usart_buffer_loop0
	cpi		YH, HIGH(TX_BUFFER_END + 1)
	brne	usart_buffer_loop0
	ret

; ---------------------------------------
; --- wait_RXC_complete: Wait a period of an usart_buffer_RXC interrupt.
; --- Argument: None
; --- Return: None
; --- Uses: r16
; --- Usage:
; --- call	wait_RXC_complete
; ---------------------------------------
wait_RXC_complete:
	ldi		r16, 10
wait_loop0:
	dec		r16
	brne	wait_loop0
	ret

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
; --- usart_RXC: An interrupt that handle incoming data from the car.
; --- Argument: None
; --- Return: None
; --- Uses: r16, Y
; ---------------------------------------
usart_RXC:
	cbi		PORTB, 1
	push	r16
	in		r16, SREG
	push	r16
	push	YL
	push	YH
	;
	in		r16, UDR
	ldi		YL, LOW(RX_BUFFER_BEGIN)
	ldi		YH, HIGH(RX_BUFFER_BEGIN)
	st		Y, r16
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
; --- START: joystick.asm
; ---------------------------------------

; ---------------------------------------
; --- read_ADC: Read ADC pin and return digital representation.
; --- Argument YL (ADC pin)
; --- Return: Y (data)
; --- Uses: Y
; --- Usage:
; --- ldi	YL, JOYID_LEFT_X
; --- call	read_ADC
; ---------------------------------------
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
; --- joy_hw_init: Init. resources used by joystick.
; --- Argument: None
; --- Return: None
; --- Uses: r16
; --- Usage:
; --- call	joy_hw_init
; ---------------------------------------
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

; ---------------------------------------
; --- START: lcd.asm
; ---------------------------------------
lcd_init:
	ldi		r16, $50 ;start delay
	call	delay
	ldi		r16, $FF
	out		DDRB, r16
	ldi		r16, $07
	out		DDRA, r16
	call	setup
	call	function_set
	call	display_on
	call	display_clear
	call	entry_mode
	ret

lcd_update:
	call	display_clear
	call	distance_printer
	call	joystick_direction
	ret

joystick_direction:
	ldi		r21, $C0
	call	setup_enable
	call	X_print
	call	joystick_X
	call	adaptive_byte
//	ldi		r21, $20 ; Write space between Y and X
//	call	write_to_lcd
	ldi		r21, $C7
	call	setup_enable
	call	Y_print
	call	joystick_Y
	call	adaptive_byte
	ret
	
distance_printer:
	call	write_distance
	call	sensor_data
	call	adaptive_byte
	call	cm_print
	ret

; --------------------------------------
; --- function_set:	set 2-line mode, sets transfer to 8-bit and 5x11 mode
; --- Argument: none
; --- Return: none
; --- Uses: r21

function_set:
	ldi		r21, $3F ; function set
	call	Setup_Enable
	nop
	ret
	
; --------------------------------------
; --- display_on: turns on the display
; --- Argument: none
; --- Return: none
; --- Uses: r21

display_on:
	ldi		r21, $0E ; display and cursor working
	call	Setup_Enable
	nop
	ret
	
; --------------------------------------
; --- display_clear: clears the display
; --- Argument: none
; --- Return: none
; --- Uses: r21

display_clear:
	ldi		r21, $01 ; display clear
	call	Setup_Enable
	ldi		r16, $2A ; 1,53ms delay
	call	delay
	ret
	
; --------------------------------------
; --- entry_mode: cursor mode set
; --- Argument: none
; --- Return: none
; --- Uses: r21

entry_mode:
	ldi		r21, $06 ; entry mode set
	call	Setup_Enable
	ldi		r16, $A0 ; lång delay innan skrivning
	call	delay
	ret

return_home:
	ldi		r21, $02 ; display clear
	call	Setup_Enable
	ldi		r16, $2A ; 1,53ms delay
	call	delay
	ret

Setup_Enable:
	call	setup
	call	enable
	ret 

; -----------------------------------------------------------------
; --- write_distance: print word from .db
; --- Argument: none
; --- Return: none
; --- Uses: r21

write_distance:
	push	r21
	push	ZH
	push	ZL
	ldi		ZH, HIGH(DISTANCE*2)
	ldi		ZL, LOW(DISTANCE*2)
write_distance_inner:
	lpm		r21, Z
	cpi		r21, 0	
	breq	finished
	lpm		r21, Z+
	call	write_to_lcd
	jmp		write_distance_inner
finished:
	pop		ZL
	pop		ZH
	pop		r21
	ret


write_to_lcd:
	call	write
	call	enable
	ldi		r16, $10
	call	delay	
	ret

; -----------------------------------------------------------------
; --- write: the sequense to do something with the display 
; --- Argument: none
; --- Return: none
; --- Uses: r21

write:
	sbi		PORTA, LCD_RS ; RS hög
	cbi		PORTA, LCD_RW ; RW låg
	out		PORTB, r21	; DATA UT
	ret	


setup:
	cbi		PORTA, LCD_RS ; RS låg
	cbi		PORTA, LCD_RW ; RW låg
	out		PORTB, r21	; DATA UT
	ret	


enable:
	nop
	sbi		PORTA, LCD_E ; E hög
	ldi		r16, $04
	call	delay
	cbi		PORTA, LCD_E ; E låg
	nop
	cbi		PORTA, LCD_RS ; RS låg
	cbi		PORTA, LCD_RW ; RW låg
	ret

; --------------------------------------------------------------------
; --- delay: delay function
; --- Argument: none
; --- Return: none
; --- Uses: r16, r17

delay: 
	push	r17
inner_delay1:
	ldi		r17, $FF
inner_delay2: 
	dec		r17
	brne	inner_delay2
	dec		r16
	brne	inner_delay1
	pop		r17
	ret

/////////////// 1 byte translation to 3 bytes /////////////////////

joystick_X:
	push	ZH
	push	ZL
	ldi		ZH, HIGH(JOYSTICK_X_DATA)
	ldi		ZL, LOW(JOYSTICK_X_DATA)
	rjmp	split_number
joystick_Y:
	push	ZH
	push	ZL
	ldi		ZH, HIGH(JOYSTICK_Y_DATA)
	ldi		ZL, LOW(JOYSTICK_Y_DATA)
	rjmp	split_number
Sensor_data:
	push	ZH
	push	ZL
	ldi		ZH, HIGH(RECIEVED_DATA)
	ldi		ZL, LOW(RECIEVED_DATA)
split_number:
	clr		r26 ;hundra sek
	clr		r25 ;tio sek
	clr		r24 ;sek
	clr		r23
	ld		r23, Z
hundred_loop:
	cpi		r23, 100
	brlo	ten_loop
	inc		r26
	subi	r23, 100
	rjmp	hundred_loop	

ten_loop: 

	cpi		r23, 10
	brlo	singular_loop
	inc		r25
	subi	r23, 10
	rjmp	ten_loop	

singular_loop:
	cpi		r23, 0
	breq	done
	inc		r24
	subi	r23, 1
	rjmp	singular_loop	


done:
	pop		ZL
	pop		ZH
	ret

adaptive_byte:
	cpi		r26, $00 
	brne	first_byte
	cpi		r25, $00
	brne	second_byte
	rjmp	third_byte

first_byte:
	mov		r19, r26
	call	write_byte
second_byte:
	mov 	r19, r25
	call	write_byte
third_byte:
	mov		r19, r24
	call	write_byte
	ret

write_byte:
	subi	r19, -$30 ; lägg till addi till assembler SNÄLLA 
	mov		r21, r19
	call	write_to_lcd
	ret

cm_print:
	ldi		r21, $63
	call	write_to_lcd
	ldi		r21, $6d
	call	write_to_lcd
	ret


Y_print:
	ldi		r21, $59
	call	write_to_lcd
	ldi		r21, $3A
	call	write_to_lcd
	ret
X_print:
	ldi		r21, $58
	call	write_to_lcd
	ldi		r21, $3A
	call	write_to_lcd
	ret


DISTANCE:
	.db		"DISTANCE:", $00 

; ---------------------------------------
; --- END: lsd.asm
; ---------------------------------------
