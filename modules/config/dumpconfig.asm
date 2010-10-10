;The MIT License
;
;Copyright (c) 2010 Dylan Smith
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

; Dump the contents of the configuration flash.
	include "../../rom/spectranet.asm"
	include "configdefs.asm"

	org 0x8000
	call PAGEIN
	call CLEAR42

	ld a, CFG_FLASH_PAGE
	call SETPAGEA
.start
	ld hl, str_size
	call PRINT42
	ld hl, CONFIG_BASE_ADDR
	call F_printint16
	inc hl
	inc hl
.configsections
	ld a, (hl)
	inc hl
	ld c, (hl)
	inc a
	inc c
	or c
	jr .done
	dec hl

	push hl
	ld hl, str_section
	call PRINT42
	pop hl
	call F_printint16
	inc hl
	inc hl

	push hl
	ld hl, str_sectionsize
	call PRINT42
	pop hl
	call F_printint16
	inc hl
	inc hl
.done
	ld hl, str_end
	call PRINT42
J_exit
	jp PAGEOUT

; print 16 bits pointed to by HL
F_printint16
	push hl
	inc hl
	ld a, (hl)
	ld hl, workspace
	call ITOH8
	ld hl, workspace
	call PRINT42
	pop hl
F_printint8			; and just do 8 bits
	push hl
	ld a, (hl)
	ld hl, workspace
	call ITOH8
	ld hl, workspace
	call PRINT42
	pop hl
	ret

str_size	defb "Config size: ",0
str_section	defb "\n\n--- SectionID: ",0
str_sectionsize defb "\nSecsize : ",0
str_stringid	defb "\nStringID: ",0
str_string	defb "\nString  : ",0
str_byteid	defb "\nByteID  : ",0
str_byte	defb " Byte: ",0
str_wordid	defb "\nWordID  : ",0
str_word	defb " Word: ",0
str_end		defb "\n---End of configuration.",0

workspace	defb 0

