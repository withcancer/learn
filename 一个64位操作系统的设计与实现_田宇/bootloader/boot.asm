;/***************************************************
;		版权声明
;
;	本操作系统名为：MINE
;	该操作系统未经授权不得以盈利或非盈利为目的进行开发，
;	只允许个人学习以及公开交流使用
;
;	代码最终所有权及解释权归田宇所有；
;
;	本模块作者：	田宇
;	EMail:		345538255@qq.com
;
;
;***************************************************/

;|----------------------|
;|	100000 ~ END	|
;|	   KERNEL	|
;|----------------------|
;|	E0000 ~ 100000	|
;| Extended System BIOS |
;|----------------------|
;|	C0000 ~ Dffff	|
;|     Expansion Area   |
;|----------------------|
;|	A0000 ~ bffff	|
;|   Legacy Video Area  |
;|----------------------|
;|	9f000 ~ A0000	|
;|	 BIOS reserve	|
;|----------------------|
;|	90000 ~ 9f000	|
;|	 kernel tmpbuf	|
;|----------------------|
;|	10000 ~ 90000	|
;|	   LOADER	|
;|----------------------|
;|	8000 ~ 10000	|
;|	  VBE info	|
;|----------------------|
;|	7e00 ~ 8000	|
;|	  mem info	|
;|----------------------|
;|	7c00 ~ 7e00	|
;|	 MBR (BOOT)	|
;|----------------------|
;|	0000 ~ 7c00	|
;|	 BIOS Code	|
;|----------------------|

	org	0x7c00	

BaseOfStack	equ	0x7c00

BaseOfLoader	equ	0x1000
OffsetOfLoader	equ	0x00

; equ后面 + 10进制的数
RootDirSectors	equ	14 ;根目录扇区的数量
SectorNumOfRootDirStart	equ	19 ; 根目录起始扇区号
SectorNumOfFAT1Start	equ	1 ; FAT1的起始扇区号
SectorBalance	equ	17	; 数据区起始扇区号平衡 = 23
	; FAT的表项位宽
	; FAT12就是一个FAT的表项为12bit
	; 目录项是一个32字节的结构体，根目录224 * 32 = 7168字节
	; 根目录区占用的扇区为 7168 / 512 = 14个扇区
	jmp	short Label_Start
	nop
	BS_OEMName	db	'MINEboot'
	BPB_BytesPerSec	dw	512 ; 一个扇区512字节
	BPB_SecPerClus	db	1 ; 一个簇一个扇区
	BPB_RsvdSecCnt	dw	1 ; 保留扇区数
	BPB_NumFATs	db	2
	BPB_RootEntCnt	dw	224 ; 最大目录数量
	BPB_TotSec16	dw	2880 ; 总扇区数量
	BPB_Media	db	0xf0 ; 介质
	BPB_FATSz16	dw	9 ; 每FAT扇区数
	BPB_SecPerTrk	dw	18 ; 每磁道扇区数
	BPB_NumHeads	dw	2 
	BPB_HiddSec	dd	0
	BPB_TotSec32	dd	0
	BS_DrvNum	db	0
	BS_Reserved1	db	0
	BS_BootSig	db	0x29
	BS_VolID	dd	0
	BS_VolLab	db	'boot loader'
	BS_FileSysType	db	'FAT12   '

Label_Start:

	mov	ax,	cs
	mov	ds,	ax
	mov	es,	ax
	mov	ss,	ax
	mov	sp,	BaseOfStack

;=======	clear screen

	mov	ax,	0600h
	mov	bx,	0700h
	mov	cx,	0
	mov	dx,	0184fh
	int	10h

;=======	set focus

	mov	ax,	0200h
	mov	bx,	0000h
	mov	dx,	0000h
	int	10h

;=======	display on screen : Start Booting......

	mov	ax,	1301h
	mov	bx,	000fh
	mov	dx,	0000h
	mov	cx,	10
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	StartBootMessage
	int	10h

;=======	reset floppy

	xor	ah,	ah
	xor	dl,	dl
	int	13h

;=======	search loader.bin
	mov	word	[SectorNo],	SectorNumOfRootDirStart

Lable_Search_In_Root_Dir_Begin:

	cmp	word	[RootDirSizeForLoop],	0 ; 比较扇区号与0，相等时就是没有找到
	jz	Label_No_LoaderBin
	dec	word	[RootDirSizeForLoop]	; -1
	mov	ax,	00h ; ax = 0
	mov	es,	ax  ; es = 0
	mov	bx,	8000h ; bx = 8000，缓冲区起始地址
	mov	ax,	[SectorNo] ; ax = 根目录起始扇区号
	mov	cl,	1          ; cl = 1，设置读取扇区数量为1
	call	Func_ReadOneSector ; 读取一个扇区的数据，翻译过来就是一次读一个扇区，从19号扇区开始读，读出的数据放在ES:BX处
	mov	si,	LoaderFileName; si放入要搜索的文件名称
	mov	di,	8000h; di放入了缓冲区首地址
	cld          ; 复位DF
	mov	dx,	10h  ; 记录每个扇区可以容纳的目录/文件个数，一个扇区512/一个目录项32 = 16 = 0x10
	
Label_Search_For_LoaderBin:

	cmp	dx,	0
	jz	Label_Goto_Next_Sector_In_Root_Dir
	dec	dx
	mov	cx,	11; 记录每个目录项的文件名长度 11b

Label_Cmp_FileName:

	cmp	cx,	0
	jz	Label_FileName_Found
	dec	cx
	lodsb	; 从元地址DS:SI指定的位置加载数据到ax寄存器，DF=0时自动增加长度
	cmp	al,	byte	[es:di] ; 一个字节一个字节比较文件名称
	jz	Label_Go_On
	jmp	Label_Different

Label_Go_On:
	
	inc	di
	jmp	Label_Cmp_FileName

Label_Different:

	and	di,	0ffe0h
	add	di,	20h ; 文件起始名称就不一样，所以跳转到这里，然后对di加32字节，到下一个目录项的开头
	mov	si,	LoaderFileName
	jmp	Label_Search_For_LoaderBin

Label_Goto_Next_Sector_In_Root_Dir:
	
	add	word	[SectorNo],	1
	jmp	Lable_Search_In_Root_Dir_Begin
	
;=======	display on screen : ERROR:No LOADER Found

Label_No_LoaderBin:

	mov	ax,	1301h
	mov	bx,	008ch
	mov	dx,	0100h
	mov	cx,	21
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	NoLoaderMessage
	int	10h
	jmp	$

;=======	found loader.bin name in root director struct

Label_FileName_Found:

	mov	ax,	RootDirSectors ; ax = 14
	and	di,	0ffe0h         
	add	di,	01ah           ; di = 0x803a, 0003为起始簇号
	mov	cx,	word	[es:di] ; cx = 0x0003
	push	cx
	add	cx,	ax                ; cx = 17，相对偏移了17个扇区，数据区从2号开始，所以是17，相加得到文件数据开始时的扇区号
	add	cx,	SectorBalance     ; cx = 17 + 数据区起始簇号平衡数 17 = 34 = 0x22, 这是文件数据开始的扇区号
	mov	ax,	BaseOfLoader      ; ax = 0x1000
	mov	es,	ax                ; es = 0x1000
	mov	bx,	OffsetOfLoader    ; bx = 0x0000
	mov	ax,	cx                ; ax = 0x0022，文件数据的起始扇区号

Label_Go_On_Loading_File:
	push	ax                ; ax =  0x0022 
	push	bx                ; bx = 0x0000
	; 此时栈中有三个值，从上到下依次为bx 0x0000,ax: 0x0022,cx: 0x0003
	mov	ah,	0eh               ; 显示一个点
	mov	al,	'.'
	mov	bl,	0fh
	int	10h 
	pop	bx                            
	pop	ax

	mov	cl,	1                 ; 从数据区读取文件一个扇区的数据
	call	Func_ReadOneSector; 读取出来在0x10000上
	pop	ax
	call	Func_GetFATEntry
	cmp	ax,	0fffh             ; 如果到达了簇结尾标识，就认为文件已经被全部加载了
	jz	Label_File_Loaded
	push	ax
	mov	dx,	RootDirSectors
	add	ax,	dx         
	add	ax,	SectorBalance     ; 计算下一个文件下一个扇区的位置，此时=0x23
	add	bx,	[BPB_BytesPerSec] ; bx依然是512字节,0x200
	jmp	Label_Go_On_Loading_File

Label_File_Loaded:
	
	jmp	BaseOfLoader:OffsetOfLoader

;=======	read one sector from floppy

Func_ReadOneSector:
	
	push	bp
	mov	bp,	sp
	sub	esp,	2
	mov	byte	[bp - 2],	cl
	push	bx
	mov	bl,	[BPB_SecPerTrk]
	div	bl
	inc	ah
	mov	cl,	ah
	mov	dh,	al
	shr	al,	1
	mov	ch,	al
	and	dh,	1
	pop	bx
	mov	dl,	[BS_DrvNum]
Label_Go_On_Reading:
	mov	ah,	2
	mov	al,	byte	[bp - 2]
	int	13h ; al起始扇区号，ch磁道号的低8位，cl扇区数，dh磁头号，dl驱动器号，ES:BX数据缓冲区
	jc	Label_Go_On_Reading
	add	esp,	2
	pop	bp
	ret

;=======	get FAT Entry

Func_GetFATEntry:

	push	es
	push	bx
	push	ax
	; | STACK 0x7bf8 [0x0003] ax
 	; | STACK 0x7bfa [0x0000] bx
 	; | STACK 0x7bfc [0x1000] es
 	; | STACK 0x7bfe [0x7d20] ret
	mov	ax,	00  ; 直接为es置0即可，不需要栈内转换
	mov	es,	ax  ; es置0
	pop	ax      ; ax = 3,， 例如ax = 10, 下一个簇的标号，如果标号是奇数，则读取4个字节并右移，否则读取奇数个字节
	mov	byte	[Odd],	0 ; 奇数标志低位置0
	mov	bx,	3   ; bx = 3  ; 标号: 3对应的字节位置
	mul	bx      ; = mul ax, bx = 9
	mov	bx,	2   ; bx = 2
	div	bx      ; ax = 9 / 2 = 4
	cmp	dx,	0   ; dx中存储余数 1
	jz	Label_Even
	mov	byte	[Odd],	1 ; 奇数标志置1

Label_Even:

	xor	dx,	dx               ; dx = 0
	mov	bx,	[BPB_BytesPerSec]; 512字节 0x200
	div	bx                   ; ax = 3 / 512 = 0; dx = 4
	push	dx
	mov	bx,	8000h            ; 
	add	ax,	SectorNumOfFAT1Start
	mov	cl,	2
	call	Func_ReadOneSector ; 读取2个扇区的FAT1数据
	
	pop	dx  
	add	bx,	dx ; bx = 0x8004,准备取得从第四个字节开始的数据，这是根据0003起始簇号找到的下一个簇的数据
	mov	ax,	[es:bx] ; ax = 第一个字节; 也就是指示的0003的下一个簇 = 0004
	cmp	byte	[Odd],	1
	jnz	Label_Even_2
	shr	ax,	4

Label_Even_2:
	and	ax,	0fffh
	pop	bx
	pop	es
	ret

;=======	tmp variable

RootDirSizeForLoop	dw	RootDirSectors
SectorNo		dw	0
Odd			db	0

;=======	display messages

StartBootMessage:	db	"Start Boot"
NoLoaderMessage:	db	"ERROR:No LOADER Found"
LoaderFileName:		db	"LOADER  BIN",0

;=======	fill zero until whole sector

	times	510 - ($ - $$)	db	0
	dw	0xaa55

