
; lcd.asm
;
; Created: 2019-02 
; Author : Sebbe Börjeteg
;

; ---------------------------------------
; --- INC START: lcd.inc
; ---------------------------------------

	.equ	LCD_RS = 2
	.equ	LCD_RW = 1
	.equ	LCD_E = 0

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
