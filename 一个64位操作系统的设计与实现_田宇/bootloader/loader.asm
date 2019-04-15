BaseOfStack equ 0x7c00
BaseOfLoader equ 0x1000
OffsetOfLoader equ 0x00
RootDirSectors equ 14
SectorNumOfRootDirStart equ 19
SectorNumOfAT1Start equ 1
SectorBalance equ 17

jmp short Label_Start
nop
BS_OEMName db
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
BPB_DrvNum db 0
BS_Reserved1 db 0
BS_BootSig db 29h
BS_VolID dd 0
BS_VolLab db 'boot loader'
BS_FileSysType db 'FAT12   '
; 读取扇区数据
Func_ReadOneSector:
    push bp
    mov bp
    sub esp,2
    mov byte [bp-2], cl
    push bx
    mov bl, [BPB_SecPerTrk]
    div bl
    inc ah
    mov cl, ah
    mov dh,al
    shr al, l
    mov ch,al
    and dh,l
    pop bx
    mov dl,[BS_DrvNum]
Label_Go_On_Reading:
    mov ah,2
    mov al, byte[bp-2]
    int 13h
    jc Label_Go_On_Reading
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
    mov ax, [SectorNo]
    mov cl, l
    call Func_ReadOne_Sector
    mov si, LoaderFileName
    mov di, 8000h
    cld
    mov dx,10h
Label_Search_For_LoaderBin:
    cmp dx, 0
    jz Label_Goto_Next_Sector_In_Boot_Dir
    dec dx
    mov cx,11
Label_Cmp_FileName:
    cmp cx, 0
    jz Label_FileName_Found
    dec cx
    lodsb
    cmp al, byte [es:di]
    jz Lable_Go_On
    jmp Label_Different
Label_Different:
    and di, 0ffe0h
    add di,20h
    mov si, LoaderFileName
    jmp Label_Search_For_LoaderBin
Lable_Goto_Next_Sector_In_Root_Dir:
    add word [SectorNo], 1
    jmp Label_Search_In_Root_Dir_Begin

Label_No_LoaderBin:
    mov ax, 1301h
    mov bx, 008ch
    mov dx, 0100h
    mov cx,21
    push ax
    mov ax,ds
    mov es,ax
    pop ax
    mov bp, NoLoaderMessage
    int 1301h
    jmp $