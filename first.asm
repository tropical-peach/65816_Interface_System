;== Include memorymap, header info, and SNES initialization routines

;========================
; Start
;========================


Start:

	
	lda #$FF    ; make A all ones
	ldy #$AA	; make Y be 0xAA
	tax			; transfer A to X
	nop
	nop
	SEC			; set the carry flag to 1    
    

forever:
    jmp forever
	nop
	nop
	nop
	nop

