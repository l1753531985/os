%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
	mov byte [gs:0x00],'2'
	mov
