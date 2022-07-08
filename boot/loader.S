	%include "boot.inc"
	section loader vstart=LOADER_BASE_ADDR ;编码位置
;	mov byte [gs:0x00],'2'
;	mov byte [gs:0x01],0xA4
;
;	mov byte [gs:0x02],' '
;	mov byte [gs:0x03],0xA4
;
;	mov byte [gs:0x04],'L'
;	mov byte [gs:0x05],0xA4
;
;	mov byte [gs:0x06],'O'
;	mov byte [gs:0x07],0xA4
;
;	mov byte [gs:0x08],'A'
;	mov byte [gs:0x09],0xA4
;
;	mov byte [gs:0x0a],'D'
;	mov byte [gs:0x0b],0xA4
;
;	mov byte [gs:0x0c],'E'
;	mov byte [gs:0x0d],0xA4
;
;	mov byte [gs:0x0e],'R'
;	mov byte [gs:0x0f],0xA4
;
;	jmp $
;
	LOADER_STACK_TOP equ LOADER_BASE_ADDR ;将0x900(loader)起始位置定义为栈顶
	jmp loader_start

	GDT_BASE:	dd 0x00000000
			dd 0x00000000

	CODE_DESC:	dd 0x0000FFFF
			dd DESC_CODE_HIGH4

	DATA_STACK_DESC:	dd 0x0000FFFF
				dd DESC_DATA_HIGH4

	VIDEO_DESC:	dd 0x80000007 ;limit=(0xbffff-0xb8000)/4k=0x7
			dd DESC_VIDEO_HIGH4

	GDT_SIZE equ $ - GDT_BASE
	GDT_LIMIT equ GDT_SIZE - 1 ;由于gdt第0个段描述符不可用，因此减一
	times 60 dq 0 
	SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0
	SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0
	SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0

	total_mem_bytes dd 0

	gdt_ptr dw GDT_LIMIT
		dd GDT_BASE

	ards_buf times 244 db 0
	ards_nr dw 0

	loadermsg db '2 loader in real'

loader_start:
	xor ebx,ebx
	mov edx,0x534d4150
	mov di,ards_buf
.e820_mem_get_loop:
	mov eax,0x0000e820
	mov ecx,20
	int 0x15
	jc .e820_failed_so_try_e801
	add di,cx
	inc word [ards_nr]
	cmp ebx,0
	jnz .e820_mem_get_loop
	
	mov cx,[ards_nr]
	mov ebx,ards_nr
	xor edx,edx
.find_max_mem_area:
	mov eax,[ebx]
	add eax,[ebx+8]
	add ebx,20
	cmp edx,eax
	jge .next_ards
	mov edx,eax
.next_ards:
	loop .find_max_mem_area
	jmp .mem_get_ok

.e820_failed_so_try_e801:
	mov ax,0xe801
	int 0x15
	jc .e801_failed_so_try88
	mov cx,0x400
	mul cx
	shl edx,16
	and eax,0x0000ffff
	or edx,eax
	add edx,0x100000
	mov esi,edx

	xor eax,eax
	mov ax,bx
	mov ecx,0x10000
	mul ecx

	mov edx,esi
	jmp .mem_get_ok

.e801_failed_so_try88:
	mov ah,0x88
	int 0x15
	jc.error_hlt
	and eax,0x0000ffff

	mov cx,0x400
	mul cx
	shl edx,16
	or edx,eax
	add edx,0x100000

.mem_get_ok:
	mov [total_mem_bytes],edx
;--------------------------------------------------
;INT 0x10 功能号:0x13 功能描述:打印字符串
;--------------------------------------------------
;输入:
;AH 子功能号=0x13
;BH = 页码
;CX = 字符串长度
;(DH,DL) = 坐标(行、列)
;ES:BP = 字符串地址
;AL = 显示输出方式
;	0---字符串中只含显示字符，其显示属性在BL中，显示后，光标位置不变
;	1---字符串中只含显示字符，其显示属性在BL中，显示后，光标位置改变
;	2---字符串中含显示字符和显示属性，显示后，光标位置不变
;	3---字符串中含显示字符和显示属性，显示后，光标位置改变
;无返回值
	mov sp,LOADER_BASE_ADDR
	mov bp,loadermsg ;ES:BP=字符串地址
	mov cx,17
	mov ax,0x1301
	mov bx,0x001f
	mov dx,0x1800

	int 0x10 ;调用10号中断

;------------------- 准备进入保护模式-------------------------------
;1 打开A20
;2 加载gdt
;3 将cr0的pe位置1

;------------------- 打开A20 -------------------------------
	in al,0x92
	or al,0000_0010B
	out 0x92,al

;------------------- 加载GDT -------------------------------
	lgdt[gdt_ptr]

;------------------- cr0 第0位置1-------------------------------
	mov eax,cr0
	mov eax,0x00000001
	mov cr0,eax

	jmp dword SELECTOR_CODE:p_mode_start
;
[bits 32]
p_mode_start:
	mov ax,SELECTOR_DATA
	mov ds,ax
	mov es,ax
	mov ss,ax

	mov esp,LOADER_STACK_TOP
	mov ax,SELECTOR_VIDEO
	mov gs,ax

	mov byte [gs:160],'P'
	jmp $

