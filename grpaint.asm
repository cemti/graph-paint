INCLUDE stdlibc.inc

.MODEL small
.STACK
.386

.DATA
	copyr DB 'Copyright Cristian Cemirtan 2022', 0
	status DB 'Culori:    Supra:   Raza:       Instr.:', 30 DUP (' '), 'Graph Paint', 0
	fmtpx DB '%dpx ', 0
	txterr DB 'Nu este instalat driver pentru mouse.', 0

	r DW 50 ; raza in px
	color DB 15, 0 ; implicit alb si negru
	ov DB '-', 'C' ; suprapunere + instrument
	mouse DB 0 ; vizibil mouse
	xc DW ? ; poz. mouse orizontal
	yc DW ? ; poz. mouse vertical

.CODE
PROC draw_r
; ajustarea aratatorului pentru raza in px
	mov ah, 02h
	xor bx, bx
	mov dx, 001Ah ; randul 0, coloana 26
	int 10h

	push r
	lea si, fmtpx
	call printf
	add sp, 2
	ret
ENDP draw_r

PROC draw_color
; ajustarea aratatorului pentru culoare
	mov ah, 02h
	xor bx, bx
	mov dx, 0008h ; randul 0, coloana 8
	int 10h

	mov ax, 0ADBh
	mov bl, color
	and bl, 0Fh ; se scoate bitul superior
	mov cx, 1
	int 10h
	
	mov ah, 02h
	xor bx, bx
	mov dx, 0009h ; randul 0, coloana 9
	int 10h

	mov ax, 0ADBh
	mov bl, [color + 1]
	and bl, 0Fh ; se scoate bitul superior
	mov cx, 1
	int 10h
	ret
ENDP draw_color

PROC draw_overlay
	mov ah, 02h
	xor bx, bx
	mov dx, 0012h ; linia 0, coloana 18
	int 10h
	
	putchar ov
	
	mov ah, 02h
	xor bx, bx
	mov dx, 0028h ; linia 0, coloana 40
	int 10h
	
	putchar ov[1]
	ret
ENDP draw_overlay

	.STARTUP
; es la inceputul VRAM
	mov dx, 0A000h
	mov es, dx

; verifica daca este prezent driver pentru mouse
	xor ax, ax
	int 33h
	
	test ax, ax
	jnz set_video
	
	lea si, txterr
	call printf
	.EXIT 1
	
set_video:	
; 640x480 16-culori
	mov ax, 12h
	int 10h
	
; ajustarea aratatorului pentru status
	mov ah, 02h
	xor dx, dx ; randul 0, coloana 0
	int 10h
	
; macheta status
	lea si, status
	call printf

; printarea dimensiunea razei
	call draw_r
	
; printarea simbolului
	call draw_overlay

; culoarea
	call draw_color

reset_env:	
; umplerea spatiului de lucru cu negru
; 640 * 480 = 307200px total
; 38400 octeti deoarece sunt 8 culori/px
; 640 * 16 = 1280 octeti, pentru status, avand inaltimea de 16px
	mov bx, 37120 ; 640 * 480 / 8 - 1280
	
	clrscr:
		sub bx, 4
		mov DWORD PTR es:[bx + 1280], 0
		jnz clrscr

read_mouse:
; citirea starii mouse
	mov ax, 03h
	int 33h
	
	mov xc, cx
	mov yc, dx

; verificarea butoanelor apasate
	test bx, 3 ; biturile 0, 1 - click-urile stanga, dreapta
	jz show_mouse

; verificarea vizibilitatii a mouse
	test mouse, 1
	jz btn_chk

; ascunde mouse
	mov ax, 02h
	int 33h
	
	mov mouse, 0
	
btn_chk:
	push OFFSET read_key
	test bx, 1 ; e click stanga sau nu?
	jz square ; sterge cu square
	
	cmp [ov + 1], 'C'
	je cerc ; deseneaza un cerc
	
	add sp, 2
	
	xor [ov + 1], ' '
	call draw_overlay

; !BUG! DOSBox 0.74 corupteaza segmentul de cod
; la apelarea intreruperii 15h,
; celelalte simulatoare nu corupteaza.
; Conform documentatiei, aceasta apelare modifica doar flagul C si reg ah
; https://stanislavs.org/helppc/int_15-86.html
; se asteapta 125000 de microsecunde
	mov ah, 86h
	mov cx, 01h
	mov dx, 0E848h
	int 15h
	
	cmp [ov + 1], 'l'
	jne draw_line
	push xc yc
	jmp read_key

	draw_line:
		call line
		add sp, 4
		jmp read_key
	
show_mouse:
	test mouse, 1
	jnz read_key

; afiseaza mouse
	mov ax, 01h
	int 33h
	
	mov mouse, al
	
read_key:
; daca fost apasat un buton si se compari cu butoanele (caractere ASCII)
	mov ah, 06h
	mov dl, 0FFh
	int 21h ; caracter in al
	jz read_mouse ; se dude sus

color_inc:
	lea bx, color
	cmp al, 'x'
	jne color_dec

; se incrementeaza indicele culorii, pastrand bitul superior
	movsx ax, [bx]
	inc al
	jmp update_color
	
color_dec:
	cmp al, 'z'
	jne color2_inc

; se decrementeaza indicele culorii, pastrand bitul superior
	movsx ax, [bx]
	dec al
	jmp update_color
	
color2_inc:
	inc bx
	cmp al, 'v'
	jne color2_dec

; se incrementeaza indicele culorii, pastrand bitul superior
	movsx ax, [bx]
	inc al
	jmp update_color
	
color2_dec:
	cmp al, 'c'
	jne linear

; se decrementeaza indicele culorii, pastrand bitul superior
	movsx ax, [bx]
	dec al
	jmp update_color
	
linear:
	cmp al, 'a'
	jne overlay
	
	cmp [ov + 1], 'l'
	je overlay
	
; se schimba intre 'C' si 'L'
	xor [ov + 1], 15
	push OFFSET read_mouse
	jmp draw_overlay	
	
overlay:
	cmp al, ' '
	jne cls

; se inverseaza semnul
	xor WORD PTR [color], 8080h
	xor ov, 6
	push OFFSET read_mouse
	jmp draw_overlay
	
cls:
	cmp al, 'n'
	jne special_key

; ascunde mouse
	mov ax, 02h
	int 33h
	
	mov mouse, 0
	
; resetare instrument
	cmp [ov + 1], 'l'
	jne reset_env
	add sp, 4
	xor [ov + 1], ' '
	call draw_overlay
	jmp reset_env
	
special_key:
	test al, al
	jnz return
	int 21h
	
	cmp al, 48h ; sus
	je key_bigger_effect
	
	cmp al, 50h ; jos
	je key_smaller_effect

return:
; tasta ESC
	cmp al, 1Bh
	jne read_mouse
	
; revenire la regimul text
	mov ax, 3
	int 10h

	.EXIT 0
	
update_color:
; se pastreaza numai indicele culorii si bitul superior
; bitul superior este flagul suprapunerii
	and ax, 800Fh
	or al, ah
	
	mov [bx], al
	
; aplicarea culorii + elimin un salt in plus
	push OFFSET read_mouse
	jmp draw_color
	; se face salt la read_mouse
	
key_bigger_effect:
	cmp r, 239
	je read_mouse
	
	inc r
	jmp update_px
	
key_smaller_effect:
	cmp r, 1
	je read_mouse
	
	dec r
	jmp update_px
	
update_px:
; ajustarea aratatorului pentru raza in px
	push OFFSET read_mouse
	jmp draw_r
	
; urmeaza algoritmile pentru desen
	
PROC draw_pixel
; al - culoare, cx - orizontal, dx - vertical
	cmp cx, 640
	jae draw_pixel$failret
	
	cmp dx, 16
	jb draw_pixel$failret
	
	clc
	
	push bx ax
	mov ah, 0Ch
	xor bx, bx
	
	test al, al
	js draw_pixel$overlay
	
	int 10h
	
draw_pixel$ret:
	pop ax bx
	ret
	
draw_pixel$failret:
	stc
	ret
	
draw_pixel$overlay:
	inc ah
	int 10h ; se citeste culoarea de pe o pozitie de ecran

; suprapunerea se aplica la doi culori diferiti
	xor al, [esp] ; ax din stiva (little endian - octetul inferior)
	test al, 0Fh
	je draw_pixel$ret

	dec ah
	mov al, [esp]
	int 10h

	pop ax bx
	ret
draw_pixel ENDP
	
; ax, dx
symm_pixel MACRO
	push cx si di
	
	mov si, xc
	mov di, yc
	
	push ax dx ; x, y
	
	mov cx, si

	add cx, ax
	add dx, di
	
	mov al, color
	
	call draw_pixel ; xc + x, yc + y

	mov cx, si
	sub cx, [esp + 2]
	
	call draw_pixel ; xc - x, yc + y
	
	mov cx, si
	mov dx, di
	
	add cx, [esp + 2]
	sub dx, [esp]
	
	call draw_pixel ; xc + x, yc - y

	mov cx, si	
	sub cx, [esp + 2]
	
	call draw_pixel ; xc - x, yc - y

	mov cx, si
	mov dx, di
	
	add cx, [esp]
	add dx, [esp + 2]
	
	call draw_pixel ; xc + y, yc + x

	mov cx, si
	sub cx, [esp]
	
	call draw_pixel ; xc - y, yc + x

	mov cx, si
	mov dx, di
	
	add cx, [esp]
	sub dx, [esp + 2]
	
	call draw_pixel ; xc + y, yc - x

	mov cx, si	
	sub cx, [esp]
	
	call draw_pixel ; xc - y, yc - x

	pop dx ax di si cx
ENDM symm_pixel

; Rasterizarea cercului
; Bazata pe algoritmul lui Bresenham
; deseneaza odata opt octante (arc de 45 de grade)
PROC cerc
	push eax ebx ecx edx

; Fie eax = x, edx = y, ecx = d (precizie)
	movzx ebx, r

	xor eax, eax
	mov edx, ebx ; raza
	
; d = 3 - 2 * r
	lea ecx, [2 * ebx - 3]
	neg ecx

cond:
	symm_pixel

	cmp eax, edx
	jg proc_end
	
	inc eax
	
; determinam daca precizia este negativa
	test ecx, ecx
	jns jos
	
; d += 6 + 4 * x
	lea ecx, [ecx + 4 * eax + 6]
	jmp cond
	
jos:
	dec edx
	
; d += 10 + 4 * (x - y)
	mov ebx, eax
	sub ebx, edx
	
	lea ecx, [ecx + 4 * ebx + 10]
	jmp cond
	
proc_end:
	pop edx ecx ebx eax
	ret
ENDP cerc

PROC square
	push ax bx cx dx si di
	
	mov al, [color + 1]
	
	mov si, xc
	mov di, yc
	mov cx, r
	
	mov bx, si
	sub bx, cx
	push bx ; xc - r
	
	add si, cx
	
	mov dx, di
	sub dx, cx
	
	add di, cx
	
	loop1:		
		mov cx, [esp] ; bx salvat
	
		loop2:
			call draw_pixel
			
		loop2_dec:
			inc cx
			cmp cx, si
			jle loop2
		
	loop1_dec:
		inc dx
		cmp dx, di
		jle loop1

	add sp, 2
	pop di si dx cx bx ax
	ret
ENDP square

PROC line
	push eax ebx cx dx si di bp
	mov bp, sp
	
	; ax - dx, bx - dy
	; cx - x0, dx - y0, si - x1, di - y1
	
	mov cx, [bp + 22] ; xc precedent
	mov dx, [bp + 20] ; yc precedent
	
	mov si, xc
	mov di, yc

line$sx_sy:
	cmp cx, si
	setl al
	
	cmp dx, di
	setl bl
	
	movzx eax, al
	movzx ebx, bl
	
	lea eax, [eax + eax - 1] ; -1 daca 0, 1 daca 1
	lea ebx, [ebx + ebx - 1]
	
	push ax bx ; sx, sy in stiva [bp - 2], [bp - 4]

line$dx:
	mov ax, si
	sub ax, cx
	jns line$dy
	neg ax ; abs

line$dy:
	mov bx, di
	sub bx, dx
	jns line$err
	neg bx ; abs
	
line$err:
	cmp ax, bx
	jle line$push_neg_dy
	push ax ; [bp - 6]
	jmp line$div2
	
line$push_neg_dy:
	push bx ; [bp - 6]
	neg WORD PTR [esp]

line$div2:
	sar WORD PTR [esp], 1
	push ax ; temp, ax nu are rol specific [bp - 8]

line$loop:
	push ax
	mov al, color
	call draw_pixel
	jc line$ret
	
	cmp cx, si ; x0 == x1
	sete al
	
	cmp dx, di ; y0 == y1
	sete ah

	test al, ah
	jnz line$ret
	
; temp > -dx
	mov ax, [bp - 6]
	mov [bp - 8], ax ; se salveaza err

	pop ax
	neg ax
	
	cmp [bp - 6], ax
	jle line$err_lt_dy
	
	sub [bp - 6], bx
	add cx, [bp - 2]
	
; temp < dy
line$err_lt_dy:
	neg ax
	cmp [bp - 8], bx
	jge line$loop

	add [bp - 6], ax
	add dx, [bp - 4]
	
	jmp line$loop

line$ret:
	mov sp, bp
	pop bp di si dx cx ebx eax
	ret
ENDP line
END