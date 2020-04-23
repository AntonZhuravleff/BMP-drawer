; - Журавлёв Антон А-07-17
; - 6 вариант
; -
; - 

.model small

.stack 100h  

.data  
 ; сообщения для вывода на экран
msgEnterFile db 'Enter filename:',10,13,'$'
errorOpenFile db 'Open file error',10,13,'$'
errorFileType db 'This is not BMP file',10,13,'$'
errorFileResolution db 'File can''t be more than 320x200',10,13,'$'
errorNotMonochrome db 'This is not monochrome file',10,13,'$'

additionalBits db 100 dup(0) ; буфер для дополнительных битов

filename db 100 dup (?) ; имя файла

handle dw ? ; описатель файла

saveMode db ? ; текущий режим

valX dw ? ; текущая X координата
valY dw ? ; текущая Y координата


maxX equ 320 ; максимальный X
maxY equ 200 ; максимальный Y

buffer db 320 dup (?) ; буфер для хранения считанных данных


;--------------------------- структура BMP файла-----------------------------------------

BitmapFileHeader struc
	bfType dw ? ; тип файла
	bfSize dd ? ;	размер файла в байтах.
	bfReserved1 dw 0 ; зарезервированы и должны содержать ноль
	bfReserved2 dw 0 ; зарезервированы и должны содержать ноль
	bfOffBits dd ? ; положение пиксельных данных относительно начала данной структуры (в байтах)
	BMPHeaderSize equ $-bfType ; размер BitmapFileHeader
BitmapFileHeader ends

BitmapInfo struc
	biSize dd ? ; размер данной структуры в байтах
	biWidth dd ? ; ширина в пикселях
	biHeight dd ? ; высота в пикселях
	biPlanes dw ? ; в bmp единица
	biBitCount dw ? ; количество бит на пиксель
	biCompression dd ? ; указывает на способ хранения пикселей
	biSizeImage dd ? ; размер пиксельных данных в байтах.
	biXPelsPerMeter dd ? ; количество пикселей на метр по горизонтали и вертикали
	biYPelsPerMeter dd ? ; количество пикселей на метр по горизонтали и вертикали
	biClrUsed dd ? ; размер таблицы цветов в ячейках
	biClrImportant dd ? ; количество ячеек от начала таблицы цветов до последней используемой (включая её саму)
	BMPInfoSize equ $-biSize ; размер BitmapInfo
BitmapInfo ends

RGBQuad struc
	 RGBBlue db ?
	 RGBGreen db ?
	 RGBRed db ?
	 RGBReserved db ?
	 RGBQuadSize equ $-RGBBlue; константа для хранения размеров палитры
RGBQuad ends


;----------------------------------------------------------------------------------------


bmFileHeader BitmapFileHeader <> 
bmInfo BitmapInfo <>
rgb1 RGBQuad <>
rgb2 RGBQuad <>
.code

Main proc
	mov ax, @data
	mov ds, ax ; инициализация ds
	  
start:
	; выводим сообщение о вводе имени файла
	mov ah,09h 
    mov dx,offset msgEnterFile
    int 21h
	
	call GetFilename ; записать в filename имя файла
	
	;открываем файл
    mov ax,3d00h ; открыть для чтения
    int 21h
	
	jc errorFileOpen ; если ошибка открытия файла
	
    mov handle, ax ; в ax описатель файла
    
    call ReadServiceInfo ; читаем заголовок файла и заголовок изображения
	
	cmp bmFileHeader.bfType, 'MB' ; если файл не BMP
	jne errorFileNotBmp
	
	cmp word ptr[bmInfo.biWidth], maxX ; если ширина больше maxX
	jg errorWrongResolution
	
	cmp word ptr[bmInfo.biHeight], maxY ; если высота больше maxY
	jg errorWrongResolution
	
	mov ax, bmInfo.biBitCount
	cmp ax,1
	jne errorNotMono
		
	call SetVideoMode ; сохраним текущий видеорежим, переключим видеоадаптер в 13h, загрузим в es сегментный адрес видеобуфера
	
	call SetBackground ; настройка палитры
	
    call ReadAndPrintImage ; читаем изображение и выводим его на экран
	
	; закрыть файл
    mov ah, 3eh 
	mov bx, handle 
	int 21h
	
	; ждем нажатия клавиши
	mov ah,0 
	int 16h
	
	; возвращаем прежний режим
	mov ah,0 
	mov al, saveMode
	int 10h
	
	jmp start
	
	jmp exitprog
	
errorFileOpen:	
    ; выводим сообщение об ошибке открытия файла
    mov ah,09h 
    mov dx,offset errorOpenFile
    int 21h
	jmp exitprog
	
errorFileNotBmp:	
	; выводим сообщение о том, что файл не BMP
    mov ah,09h 
    mov dx,offset errorFileType
    int 21h
	jmp exitprog
	
errorWrongResolution:	
	; выводим сообщение о том, что разрешение файла больше чем 320*200
    mov ah,09h 
    mov dx,offset errorFileResolution
    int 21h
	jmp exitprog
	
errorNotMono:
	; выводим сообщение о том, что файл не монохромный
    mov ah,09h 
    mov dx,offset errorNotMonochrome
    int 21h
	jmp exitprog
	
exitprog:
	mov ax,4C00h ; выход из программы
	int 21h
	
Main endp	

;ввод файла с клавиатуры
GetFilename proc 
	lea si, filename
read:
    mov ah,01h  ; считываем символ
    int 21h 
	
	cmp al, 27 ; esc?
	je ex1t
	
    cmp al, 13 ; символ возврата?             
    je done 
	
    mov [si], al ; записываем символ в filename           
    inc si             
    jmp read                
    
done: 
	;записываем сивол конца строки
	push ax
	mov ax, '$' ;   				
    mov [si],ax  
	pop ax	
	
	lea dx, filename ; в dx смещение имени файла
    ret  
	
ex1t:
	mov ax,4C00h ; выход из программы
	int 21h
GetFilename endp


; функция для чтения BitmapFileHeader, BitmapInfoHeader и RGBQuad
ReadServiceInfo proc

 ; считываем заголовок файла
	mov ah, 3fh ; чтение из файла
	mov bx, handle ; описатель файла	
	mov cx, BMPHeaderSize ; число считываемых байт
	lea dx, bmFileHeader ; адрес буфера для чтения
	int 21h  
   
 ;считываем заголовок изображения 
	mov ah, 3fh; чтение из файла
	mov bx, handle ; описатель файла	
	mov cx, BMPInfoSize ; число считываемых байт
	lea dx, bmInfo.biSize ; адрес буфера для чтения
	int 21h
	
	  ;считываем  палитру    
    mov ah,3fh; ф-ия для чтения из файла
	mov bx,handle; дескриптор файла
	mov cx,RGBQuadSize; размер структуры
	lea dx,rgb1; адрес на начала буфера	
	int 21h
	
	  ;считываем  палитру    
    mov ah,3fh; ф-ия для чтения из файла
	mov bx,handle; дескриптор файла
	mov cx,RGBQuadSize; размер структуры
	lea dx,rgb2; адрес на начала буфера	
	int 21h
	
	ret
ReadServiceInfo endp	

; считывает картинку и выводит ее на экран
ReadAndPrintImage proc

	; переход на начало битового массива
	mov al, 0 ; от начала файла
	mov ah,42h
	mov bx,handle
	mov dx,word ptr [bmFileHeader.bfOffBits]
	mov cx,word ptr [bmFileHeader.bfOffBits+1] ; на указатель файла на начало битового массива
	int 21h
	
	;строки дополняются до кратного 4 байтам размера, поэтому нужно высчитать кол-во дополнительных битов
    mov dx,0
	mov ax, word ptr[bmInfo.biWidth]
	mov bx, 32 ; делим на 8, чтобы перевести в байта а потом на 4, чтобы проверить кратность 4
	div bx
	cmp dx, 0 
	jz nobits ; если кратно то нет дополнительных битов
	
	;вычитаем из 4 байт(32 бита) остаток от деления, для получения добавленных битов	
	mov bx,dx
	mov ax,32
	sub ax ,bx
    
	mov word ptr[additionalBits], ax ; записываем их в additionalBits
	
	nobits:

	; установка X и Y
	mov valX,0 ; в X ставим 0
	
	; установка Y
	mov ax, maxY
	dec ax
	mov valY, ax ; отображать будем с нижнего края
	
	mov cx,word ptr [bmInfo.biHeight]
 printBMP:
	 ; читаем из файла  
     mov	ah,3fh  
     mov	bx,handle
     lea	dx, buffer
     int	21h     
	
	 cmp ax,0; если конец файла, то выходим
	 jz break
	
	 call PrintBuffer ; выводим их на экран
	
	 loop PrintBMP; читаем следующий блок

break:
	ret
ReadAndPrintImage endp


; сохраним текущий видеорежим, переключим видеоадаптер в 13h, загрузим в es сегментный адрес видеобуфера
SetVideoMode proc 

	mov ax,0a000h
	mov es,ax ; в es на начало видеопамяти
	
	;сохраним текущий режим
	mov ah, 0fh
	int 10h
	mov saveMode, al
	
	mov ah, 0
	mov al,13h ; графический режим , 256 цветов, 320x200
	int 10h
	
	ret
SetVideoMode endp

; настройка палитры
SetBackground proc

	mov ax,1010h ; биос функция для изменения палитры
	mov bx,0 ; индекс палитры
	mov dh,rgb1.RGBRed ; красный
	mov ch,rgb1.RGBGreen ; зеленый
	mov cl,rgb1.RGBBlue ; синий
	int 10h ; 
	
	mov ax,1010h ; биос функция для изменения палитры
	mov bx,1 ; индекс палитры
	mov dh,rgb2.RGBRed ; красный
	mov ch,rgb2.RGBGreen ; зеленый
	mov cl,rgb2.RGBBlue; синий
	int 10h 

	ret
SetBackground endp


; отображает биты из буфера
PrintBuffer proc
	push cx
	push dx
	push ax
	
	lea si, buffer ; в si адрес буфера
	mov cx, ax ; в ax кол-во считанных байт
	
byteloop:
	push cx
	
	mov dl,[si] ; в dl байт из массива
	
	mov cx,8 ; 8 бит => в bitloop отобразим весь байт
	mov dh, 10000000b ; маска для выбора бита
	
	; в каждой итерации отображаем бит и сдвигаем битовую маску на 1,
	bitloop:		
		
		test dh,dl ; выбираем бит 
		jz zeropalette ; если бит 0 ставим в al 0(черный цвет)
		mov al,1 ; индекс палитры 1(белый цвет)		
		jmp putpix 
		
	zeropalette:
		mov al,0
		

	putpix:
		
		push ax
		mov ax, word ptr [bmInfo.biWidth]
		
		;если Х больше ширины изображения, то не отображаем биты
		cmp valX,ax
		pop ax
		jge noDraw
		
		call PutPixel ; отображаем бит

	noDraw:
		inc valX ; увеличиваем Х	
		
		push dx
		mov dx,word ptr [bmInfo.biWidth]
		add dx, word ptr [additionalBits] 
		push bx
		mov bx, dx
		cmp valX, bx ; если X больше ширины изображения с учетом доп.битов, значит новая строка
		pop bx
		pop dx
		jne ext
		
		mov valX,0
		dec valY ; переход на строку выше
	
	ext:
			
		shr dh,1 ; сдвигаем маску на 1 вправо

	loop bitloop
	
	pop cx
	inc si ; берем слудующий байт из буфера
	
loop byteloop

exit:
pop ax
pop dx
pop cx
ret
PrintBuffer endp

; отображение пикселя
PutPixel proc
	; сохраняем значения регистров		
	push ax

	push dx	
	mov ax, maxX ; длина строки в ax
	mul valY ; умножаем на Y для получения текущей строки
	add ax, valX ; добавляем X для получения координаты
	pop dx
	
	mov di,ax ; в di смещение видеобуфера
	pop ax
	
	mov byte ptr es:[di],al ;индекс палитры в видеопамять

	;восстанавливаем значения регистров	
	
	ret
PutPixel endp

end Main
