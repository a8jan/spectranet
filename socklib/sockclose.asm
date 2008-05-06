; int __FASTCALL__ sockclose(int fd);
XLIB sockclose
LIB libsocket

	include "spectranet.asm"
.sockclose
	ld a, l		; file descriptor in lsb of hl
	ld hl, CLOSE
	call HLCALL
	jr c, err_close
	ld hl, 0	; return code 0
	ret
.err_close
	ld hl, -1
	ret

