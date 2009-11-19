;The MIT License
;
;Copyright (c) 2009 Dylan Smith
;
;Permission is hereby granted, free of charge, to any person obtaining a copy
;of this software and associated documentation files (the "Software"), to deal
;in the Software without restriction, including without limitation the rights
;to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;copies of the Software, and to permit persons to whom the Software is
;furnished to do so, subject to the following conditions:
;
;The above copyright notice and this permission notice shall be included in
;all copies or substantial portions of the Software.
;
;THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
;THE SOFTWARE.

; Save snapshots in SNA format.

;--------------------------------------------------------------------------
; F_savesna48
; Save a 48K snapshot. Null terminated filename pointed to by HL.
UNPAGE	equ	0x007C
SAVERAM	equ	0x3600
MAINSPSAVE equ	0x35FE
TEMPSP	equ	0x81FE

F_snaptest
	ld hl, STR_saving
	call PRINT42

	ld hl, STR_filename
	ld de, 0x3000
	xor a
.loop
	ldi
	cp (hl)
	jr nz, .loop
.done
	ld (de), a
	ld hl, 0x3000
	call F_savesna
	jr c, .borked

	ld a, (v_border)		; Restore the border
	out (254), a
	ld a, (SNA_EIDI)		; Re.enable interrupts?
	and a				; No
	jr nz, .retei			; If yes, then EI on ret
	ld sp, NMISTACK-14		; Set SP to where the stack was
	pop af
	ex af, af'
	pop af
	pop bc
	pop de
	pop hl
	ld sp, (NMISTACK)
	jp UNPAGE			; RET
.borked
	ld a, 2
	out (254), a
	ret

.retei
	ld sp, NMISTACK-14
	pop af
	ex af, af'
	pop af
	pop bc
	pop de
	pop hl
	ld sp, (NMISTACK)
	jp UNPAGE-1			; EI; RET


STR_saving defb "Saving snapshot.sna...\n",0
STR_filename defb "snapshot.sna",0


;------------------------------------------------------------------------
; HL = pointer to filename string
; Entry to the NMI saves the folowing at NMISTACK-4:
; hl, de, bc, af, af'
F_savesna
	ld d, O_CREAT | O_TRUNC		; Flags
	ld e, O_WRONLY			; File mode
	call OPEN			; Open the snapshot file
	ret c
	ld (v_snapfd), a		; save the file descriptor

	ld hl, HEADER			; Clear down the header information
	ld de, HEADER+1			; temporary storage.
	ld bc, HEADERSZ-1
	ld (hl), l
	ldir

	ld hl, (STACK_HL)		; Start by saving the registers we can
	ld (SNA_HL), hl
	ld hl, (STACK_DE)
	ld (SNA_DE), hl
	ld hl, (STACK_BC)
	ld (SNA_BC), hl
	ld hl, (STACK_AFALT)
	ld (SNA_AFALT), hl
	ld hl, (STACK_AF)
	ld (SNA_AF), hl
	ld hl, (NMISTACK)		; SP when NMI happened
	ld (SNA_SP), hl
	ld (SNA_IX), ix
	ld (SNA_IY), iy
	exx				; do the alternate set
	ld (SNA_HLALT), hl
	ld (SNA_DEALT), de
	ld (SNA_BCALT), bc
	exx
	ld a, i				; also sets P/V flag if IFF2 is
	ld (SNA_I), a			; set (interrupts enabled)
	call pe, .setei
	
	ld a, (v_border)		; Copy the border colour into
	ld (SNA_BORDER), a		; the snapshot header.

	; Now something must be done to detect interrupt mode
	ld hl, 0x3600
	ld de, 0x3601
	ld bc, 258			; table is actually 0x100 bytes
	ld (hl), F_im2 % 256		; LSB of IM 2 routine.
	ldir
	ld a, 0x36			; MSB of the table
	ld i, a				; set the vector table

	ld hl, 0
	ld (v_intcount), hl		; reset IM 1 counter to detect IM 1
	ld hl, .continue		; "Return" address
	push hl				; on the stack so RETN
	retn				; takes us just to the next addr.

.continue
	xor a
	ld (SNA_IM), a			; clear IM x
	ei
	halt				; wait for an interrupt
	ld a, (SNA_IM)			; Did the IM 2 routine update
	and a				; the interrupt mode?
	jr nz, .donewithinterrupts	; Done.

	inc a				 
	ld (SNA_IM), a			; set interrupt mode 1

	; Now it's all over bar the shouting.
.donewithinterrupts
	di

	; Restore the I register
	ld a, (SNA_I)
	ld i, a

	; Detect whether we're saving a 48K or a 128K snapshot
	ld a, (v_machinetype)		
	and 1				; Bit 1 set = 128K
	jr nz, .save128snap

	call .savemain			; save header and memory
.writedone
	ld a, (v_snapfd)		; close the file
	call VCLOSE
	ret

.writeerr
	push af
	ld a, (v_snapfd)
	call VCLOSE
	pop af
	ret
.setei
	ld a, 4
	ld (SNA_EIDI), a
	ret

.save128snap
	; copy port 0x7FFD value to the header
	ld a, (v_port7ffd)
	ld (SNA_7FFD), a

	; adjust header suitably for 128K snapshots
	ld hl, (SNA_SP)			; The stack pointer must be
	ld e, (hl)			; adjusted and the PC must be
	inc hl				; obtained.
	ld d, (hl)			; PC now in DE
	inc hl
	ld (SNA_SP), hl			; Set the snapshot SP.
	ld (SNA_PC), de			; Set the PC
	xor a
	ld (SNA_TRDOS), a		; TRDOS always 0
	call .savemain			; the header + 48K
	jr c, .writeerr

	ld hl, SNA_PC			; Save the 128K second header
	ld bc, 4			; (4 bytes long)
	ld a, (v_snapfd)
	call WRITE
	jr c, .writeerr

	; Save the 128K pages at 0xC000.
	ld a, (SNA_7FFD)		; Skip the page we've aready
	and 7				; saved (as it was in 0xC000)
	ld e, a
	xor a				; start from page 0
.save128loop
	cp e				; skip the page that was already
	jr z, .next			; saved, also skip pages 2 and 5
	cp 0x02
	jr z, .next
	cp 0x05
	jr z, .next
	ld bc, 0x7FFD			; set the page we want to save
	out (c), a

	push af
	push de
	ld hl, 0xC000
	ld bc, 0x4000
	call F_saveblock
	jr c, .writeerr128
	pop de
	pop af
.next
	inc a
	cp 0x08				; all pages have been saved
	jr nz, .save128loop
	ld a, (SNA_7FFD)		; restore 128K paging but with
	and 0xF7			; but ensure the normal screen
	ld bc, 0x7FFD			; is in use for the NMI menu
	out (c), a
	jr .writedone

.writeerr128
	pop de
	pop de				; don't overwrite AF
	jr .writeerr

.savemain
	; TODO: Something ought to be done with the R register, really.
	; Save the interrupts-and-stuff block.
	ld hl, HEADER
	ld bc, HEADERSZ
	ld a, (v_snapfd)
	call WRITE
	ret c

	; Save memory. First, restore screen memory so that it can be
	; saved to the file.
	ld a, 0xDA
        call SETPAGEA
        ld hl, 0x1000
        ld de, 0x4000
        ld bc, 0x1000
        ldir
        ld a, 0xDB
        call SETPAGEA
        ld hl, 0x1000
        ld de, 0x5000
        ld bc, 0xB00
        ldir

	ld hl, 16384			; Start saving from this address
	ld bc, 49152			; For this many bytes
	call F_saveblock
	ret

;-----------------------------------------------------------------------
; F_saveblock
; Save a block of memory.
; HL = start address, BC = bytes to write, v_snapfd = fd to write to
F_saveblock
	ld d, b				; Set bytes remaining
	ld e, c				; in DE
.writeloop
	ld a, (v_snapfd)
	push hl
	push de
	call WRITE
	ret c
	pop de
	pop hl
	ex de, hl			; Calculate remaining bytes
	sbc hl, bc
	ret z				; and if none are left, leave.
	ex de, hl
	add hl, bc			; Calculate next address
	ld b, d				; set requested number of bytes
	ld c, e				; to write out.
	jr .writeloop
	ret
