;
; bloetooth_v2.asm
;
; Created: 2019-03-12 20:47:25
; Author : Dutsadi Bunliang
;


; ---------------------------------------
; --- USART: Constant
;
	.equ	UBRR_VALUE = 7
	.equ	BUFFER_SIZE = 2

	.org	0
	jmp		cold
	.org	URXCaddr
	jmp		usart_RXC


	.dseg
	.org	$60

; ---------------------------------------
; --- SRAM: USART values layout
;
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

	.cseg
cold:
	ldi	r16, LOW(RAMEND)
	out	SPL, r16
	ldi	r16, HIGH(RAMEND)
	out	SPH, r16
	call	usart_hw_init
	sei
	
/* Test code
	ldi	YL, LOW(TX_BUFFER_BEGIN)
	ldi	YH, HIGH(TX_BUFFER_BEGIN)
	ldi	r16, 1
	st	Y+, r16
	ldi	r16, $F0
	st	Y, r16

start:
  call	usart_buffer_transmit
	call	wait
  rjmp	start

wait:
	ldi	r16, $FF
wait_loop:
	dec	r16
	brne	wait_loop
	ret
*/ Test code end

; ---------------------------------------
; --- START: usart.asm
; ---------------------------------------

usart_buffer_transmit:
	ldi	YL, LOW(TX_BUFFER_BEGIN)
	ldi	YH, HIGH(TX_BUFFER_BEGIN)
usart_buffer_loop0:
	ld	r16, Y+
	call	usart_transmit
	call	wait_RXC_complete
	cpi	YL, LOW(TX_BUFFER_END + 1)
	brne	usart_buffer_loop0
	cpi	YH, HIGH(TX_BUFFER_END + 1)
	brne	usart_buffer_loop0
	ret

wait_RXC_complete:
	ldi	r16, 10
wait_loop0:
	dec	r16
	brne	wait_loop0
	ret

usart_transmit:
	sbis	UCSRA, UDRE
	rjmp	usart_transmit
	out	UDR, r16
	ret

usart_buffer_RXC:
	push	r16
	in	r16, SREG
	push	r16
	push	YL
	push	YH
	;
	ldi	YL, LOW(RX_BUFFER_POS)
	ldi	YH, HIGH(RX_BUFFER_POS)
	ld	r16, Y
	inc	r16
	cpi	r16, BUFFER_SIZE + 1
	brlo	usart_buffer_incomplete
	ldi	r16, 1
	st	Y, r16
usart_buffer_incomplete:
	st	Y, r16	; Update buffer pos
	add	YL, r16
	clr	r16
	adc	YH, r16
	in	r16, UDR
	st	Y, r16 ; Store value in right position
	;
	pop	YH
	pop	YL
	pop	r16
	out	SREG, r16
	pop	r16
	reti

usart_RXC:
	cbi	PORTB, 1
	push	r16
	in	r16, SREG
	push	r16
	push	YL
	push	YH
	;
	in	r16, UDR
	ldi	YL, LOW(TX_BUFFER_BEGIN)
	ldi	YH, HIGH(TX_BUFFER_BEGIN)
	st	Y, r16
	pop	YH
	pop	YL
	pop	r16
	out	SREG, r16
	pop	r16
	reti

usart_hw_init:
	; Init. port
	in	r16, DDRD
	ldi	r16, (1 << DDD1)
	out	DDRD, r16
	; Init. USART
	ldi	r16, HIGH(UBRR_VALUE)
	out	UBRRH, r16
	ldi	r16, LOW(UBRR_VALUE)
	out	UBRRL, r16
	;
	ldi	r16, (1 << RXCIE) | (1 << RXEN) | (1 << TXEN)
	out	UCSRB, r16
	;
	ldi	r16, (1 << URSEL) | (0 << UMSEL) | (1 << USBS) | (1 << UCSZ1) | (1 << UCSZ0)
	out	UCSRC, r16
	;
	clr	r16
	ldi	YL, LOW(TX_BUFFER_POS)
	ldi	YH, HIGH(TX_BUFFER_POS)
	st	Y, r16
	ldi	YL, LOW(RX_BUFFER_POS)
	ldi	YH, HIGH(RX_BUFFER_POS)
	st	Y, r16
	ret

; ---------------------------------------
; --- END: usart.asm
; ---------------------------------------
