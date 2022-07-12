;主引导程序
;--------------------------------------------------
%include "boot.inc"
SECTION MBR vstart=0x7c00
	mov ax,cs
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov fs,ax
	mov sp,0x7c00
        mov ax,0xb800
	mov gs,ax

;清屏
;利用0x06号功能，上卷全部行，则可清屏
;--------------------------------------------------
; INT 0x10 功能号：0x06 功能描述: 上卷窗口
;--------------------------------------------------
;输入：
;AH = 功能号=0x06
;AL = 上卷的行数(如果是0表示全部)
;BH = 上卷的行属性
;(CL,CH) = 窗口左上角(x,y)的位置
;(DL,DH) = 窗口右下角(x,y)的位置
;无返回值
	mov ax,0x0600
	mov bx,0x0700
	mov cx,0         ;左上角: (0,0)
	mov dx,0x184f    ;右下角: (80,25)
;因为VGA文本模式中，一行只能容纳80个字符,共25行
;下标从0开始,所以0x18=24, 0x4f=79

	int 0x10         ;10号中断开始上卷

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;打印字符串;;;;;;;;;;;;;;;;;;;;

;获取光标位置
;--------------------------------------------------
; INT 0x10 功能号：0x03 功能描述: 获取光标位置 
;--------------------------------------------------
;输入：
;AH = 功能号=0x03
;BH = 待获取光标的页号
;输出:
;CH = 光标开始行
;CL = 光标结束行
;DH = 光标所在行号
;DL = 光标所在列号
;	mov ah,3
;	mov bh,0
;	int 0x10

;打印字符串
;--------------------------------------------------
; INT 0x10 功能号：0x13 功能描述: 显示字符及属性
;--------------------------------------------------
;将源数据的偏移地址赋给bp，此时段地址es与cs一致,被sreg初始化
;	mov ax,message
;	mov bp,ax

;光标位置用dx寄存器中内容,cx光标位置忽略，因此直接使用cx
;cx为串长度，不包含结束符0的字符个数
;输入:
;AH = 功能号 = 0x13
;AL = 设置写字符方式 = 0x01 (显示字符串，光标跟随移动)
;BH = 存储要显示的页号 = 0x00
;BL = 字符属性 = 0x02 (黑底绿字)
;	mov cx,5
;	mov ax,0x1301
;	mov bx,0x2
;	int 0x10

;	message db "1 MBR"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;打印字符结束;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;直接进行显卡操作代替打印字符串;;;;;;;;;;;;;;;;;;;;
;输出背景色绿色，前景色红色，并且跳动的字符串"1 MBR"
;显存地址分布: 
;0xc000~0xc7fff 32k 显示适配器bios
;0xb800~0xbffff 32k 用于文本模式显示适配器
;0xb000~0xb7fff 32k 用于黑白显示适配器
;0xa000~0xaffff 64k 用于彩色显示适配器
;此处段寄存器gs在之前已经初始化为0xb800以适配文本
;因此在gs:0x0000处写入将直接显示在左上角(0,0)处
;一个字符为为两个字节16个位，低字节为字符的ASCII码,高字节为字节的元属性
;其中元属性字节,低4位控制前景色且最后一位控制亮度，高4位控制背景色且最后一位控制是否闪烁,其余位RGB形成各类颜色
;以第一个前景红色，背景绿色，且跳动的字符'1'为例
;由于bochs为小端，因此一个字节内与线路一致,低位在后,高位在前,但对于字节，则低字节在前，高字节在后
;低字节为'1'的ASCII码, 
;高字节的高4位为0xA(背景红色闪烁)，低4位为0x4(前景色绿色)
	mov byte [gs:0x00],'1'
	mov byte [gs:0x01],0xA4

	mov byte [gs:0x02],' '
	mov byte [gs:0x03],0xA4
	
	mov byte [gs:0x04],'M'
	mov byte [gs:0x05],0xA4

	mov byte [gs:0x06],'B'
	mov byte [gs:0x07],0xA4

	mov byte [gs:0x08],'R'
	mov byte [gs:0x09],0xA4


	mov eax,LOADER_START_SECTOR
	mov bx,LOADER_BASE_ADDR
	mov cx,4 ;注意在loader大小变化时要进行修改
	call rd_disk_m_16
	jmp LOADER_BASE_ADDR + 0x300

;--------------------------------------------------
; 功能：读取硬盘n个扇区
rd_disk_m_16:
;--------------------------------------------------
	mov esi,eax
	mov di,cx
	
;由于硬盘端口没有进行内存映射,因此无法直接使用mov来进行操作，而需要使用in和out指令
	mov dx,0x1f2
	mov al,cl
	out dx,al

	mov eax,esi


	mov dx,0x1f3
	out dx,al

	mov cl,8
	shr eax,cl ;将eax寄存器的0~7位左移置为零
	mov dx,0x1f4
	out dx,al

	shr eax,cl
	mov dx,0x1f5
	out dx,al

	shr eax,cl
	and al,0x0f
	or al,0xe0
	mov dx,0x1f6
	out dx,al

	mov dx,0x1f7
	mov al,0x20 ;0x1f7端口在写操作时为命令寄存器(端口),0x20表示读扇区命令
	out dx,al

.not_ready: 
	nop
	in al,dx ;0x1f7端口在读操作时为状态寄存器(端口)
	and al,0x88
	cmp al,0x08
	jnz .not_ready

	mov ax,di ;最开始在cx中写入读取扇区数为1，后将cx值传给di
	mov dx,256 
	mul dx ;mul指令另一个乘数放在ax寄存器中即mul ax,dx
	mov cx,ax
	mov dx,0x1f0
.go_on_read:
	in ax,dx ;从端口读出来的数据一律使用ax寄存器进行数据存储
	mov [bx],ax ;bx从开始就被初始化为loader在内存中的位置地址
	add bx,2
	loop .go_on_read ;在执行loop指令时，先将cx寄存器值减1，判断cx是否为0，不为零跳转到标号，为0则向下执行
	ret

	times 510-($-$$) db 0
	db 0x55,0xaa
