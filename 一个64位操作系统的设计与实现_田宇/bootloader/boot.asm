org 0x7c00

BaseOfStack equ 0x7c00
BaseOfLoader equ 0x1000
OffsetOfLoader equ 0x00
RootDirSectors equ 14 ; 根目录占用的扇区数
SectorNumOfRootDirStart equ 19 ; 根目录起始扇区号
SectorNumOfAT1Start equ 1 ; FAT表1的起始扇区号
SectorBalance equ 17

jmp short Label_Start
nop
BS_OEMName db 'MINEBOOT'
BPB_BytesPerSec dw 512
BPB_SecPerClus db 1
BPB_RsvdSecCnt dw 1
BPB_NumFATs db 2
BPB_RootEntCnt dw 224
BPB_TotSec16 dw 2880
BPB_Media db 0xf0
BPB_FATSz16 dw 9
BPB_SecPerTrk dw 18
BPB_NumHeads dw 2
BPB_hiddSec dd 0
BPB_TotSec23 dd 0
BS_DrvNum db 0
BS_Reserved1 db 0
BS_BootSig db 29h
BS_VolID dd 0
BS_VolLab db 'boot loader'
BS_FileSysType db 'FAT12'

Label_Start:
    mov ax,cs
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov sp,BaseOfStack

mov ax, 0600h
mov bx, 0700h
mov cx, 0
mov dx, 0184h
int 10h
mov ax,0200h
mov bx,0000h
mov dx,0000h
int 10h
mov ax,1301h
mov bx,000fh
mov dx,0000h
mov cx,10
push ax
mov ax,ds
mov es,ax
pop ax
mov bp, StartBootMessage
int 10h
xor ah,ah ; ah置为0
xor dl,dl ; dl置为0
int 13h
jmp $

; 读取扇区数据
Func_ReadOneSector:
    push bp
    mov bp,sp
    sub esp,2
    mov byte [bp-2],cl
    push bx
    mov bl,[BPB_SecPerTrk]
    div bl
    inc ah
    mov cl,ah
    mov dh,al
    shr al,1
    mov ch,al
    and dh,1
    pop bx
    mov dl,[BS_DrvNum]
Label_Go_On_Reading:
    mov ah,2;int 13h的功能号ah=02
    mov al,byte[bp-2];读取的扇区数量
    int 13h
    jc Label_Go_On_Reading; 产生进位标志时，前往这个方法
    add esp,2
    pop bp
    ret
; 扇区查找程序
mov word [SectorNo], SectorNumOfRootDirStart
Label_Search_In_Root_Dir_Begin:
    cmp word [RootDirSizeForLoop], 0
    jz Label_No_LoaderBin
    dec word [RootDirSizeForLoop]
    mov ax,00h
    mov es,ax
    mov bx,8000h
    mov ax,[SectorNo]
    mov cl,1
    call Func_ReadOneSector
    mov si, LoaderFileName
    mov di, 8000h
    cld
    mov dx,10h
Label_Search_For_LoaderBin:
    cmp dx, 0
    jz Label_Goto_Next_Sector_In_Root_Dir
    dec dx
    mov cx,11
Label_Cmp_FileName:
    cmp cx, 0
    jz Label_FileName_Found
    dec cx
    lodsb
    cmp al, byte [es:di]
    jz Label_Go_On
    jmp Label_Different
Label_Go_On:
    inc di
    jmp Label_Cmp_FileName
Label_Different:
    and di,0ffe0h
    add di,20h
    mov si,LoaderFileName
    jmp Label_Search_For_LoaderBin
Label_Goto_Next_Sector_In_Root_Dir:
    add word [SectorNo],1
    jmp Label_Search_In_Root_Dir_Begin

Label_No_LoaderBin:
    ; 没有找到loader时进入这个方法
    mov ax, 1301h
    mov bx, 008ch
    mov dx, 0100h
    mov cx,21
    push ax
    mov ax,ds
    mov es,ax
    pop ax
    mov bp, NoLoaderMessage
    int 10h
    jmp $

Func_GetFATEntry:
    push es
    push bx
    push ax
    mov ax,00
    mov es,ax
    pop ax
    mov byte [Odd],0
    mov bx,3
    mul bx
    mov bx,2
    div bx
    cmp bx,0
    jz Label_Even
    mov byte [Odd],1
Label_Even:
    xor dx,dx
    mov bx,[BPB_BytesPerSec]
    div bx
    push dx
    mov bx,0800h
    add ax,SectorNumOfAT1Start
    mov cl,2
    call Func_ReadOneSector
    pop dx
    add bx,dx
    mov ax,[es:bx]
    cmp byte [Odd],1
    jnz Label_Even_2
    shr ax,4
Label_Even_2:
    and ax,0fffh
    pop bx
    pop es
    ret

Label_FileName_Found:
    mov ax, RootDirSectors
    and di,0ffe0h
    add di,01ah
    mov cx,word[es:di]
    push cx
    add cx,ax
    add cx,SectorBalance
    mov ax,BaseOfLoader
    mov es,ax
    mov bx,OffsetOfLoader
    mov ax,cx
Label_Go_On_Loading_File:
    push ax
    push bx
    mov ah,0eh
    mov al,'.'
    mov bl,0fh
    int 10h
    pop bx
    pop ax

    mov cl,1
    call Func_ReadOneSector
    pop ax
    call Func_GetFATEntry
    cmp ax,0fffh
    jz Label_File_Loaded
    push ax
    mov dx,RootDirSectors
    add ax,dx
    add ax,SectorBalance
    add bx,[BPB_BytesPerSec]
    jmp Label_Go_On_Loading_File

Label_File_Loaded:
    jmp BaseOfLoader:OffsetOfLoader

RootDirSizeForLoop dw RootDirSectors
SectorNo dw 0
Odd db 0

StartBootMessage: db "Start Boot Message"
NoLoaderMessage: db "Error: No Loader Found"
LoaderFileName: db "LOADER BIN",0
times 510 - ($ - $$) db 0
dw 0xaa55