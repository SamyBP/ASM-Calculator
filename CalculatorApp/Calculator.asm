.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
extern printf: proc
extern sprintf: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date

format_afisare DB "%d", 10, 0

window_title DB "Calculator",0
area_width EQU 640
area_height EQU 480
area DD 0

counter DD 0 ; numara evenimentele de tip timer

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

symbol_width EQU 10
symbol_height EQU 20

button_start_x EQU 50
button_start_y EQU 210
calc_lenght_x EQU 540
calc_lenght_y EQU 420
offset_x EQU 135
offset_y EQU 60

result_start_x EQU 80
result_start_y EQU 160

index DB 0
result DD 0
temp_result DD 0
first_number DB 1			; 1 -> first_number; 0 -> not_first_number
operation DD 0				; 1 -> adunare; 2 -> scadere; 3->inmultire; 4->impartire
prev_operation DD 0

string DB 10 dup(0)
nr_caracter DD 0


include digits.inc
include letters.inc

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

make_horizontal_line macro x, y, lenght, color
local bucla_linie
	;gasesc pozitia in area
	pusha
	mov eax, y
	mov ebx, area_width
	mul ebx
	add eax, x
	shl eax, 2
	add eax, area
	
	;desenez puncte consecutive cu un loop
	mov ecx, lenght
bucla_linie:
	mov dword ptr[eax], color
	add eax, 4
	loop bucla_linie
	
	popa
	
endm
; un macro pt a desena o linie verticala
make_vertical_line macro x, y, lenght, color
local bucla_linie	
	;pozitia in area:
	mov eax, y
	mov ebx, area_width
	mul ebx
	add eax, x
	shl eax, 2
	add eax, area
	
	;desenarea liniei
	mov ecx, lenght
bucla_linie:
	mov dword ptr[eax], color
	add eax, area_width*4
	loop bucla_linie
	
endm

fill_button macro x, y, lenght, n, color
local begin_loop
local end_loop	
local bucla_linie
	mov eax, y
	mov ebx, area_width
	mul ebx
	add eax, x
	shl eax, 2
	add eax, area
	
	mov index, 0
	; xor edx, edx
begin_loop:	
	cmp index, n
	je end_loop	
	
	mov ecx, lenght
bucla_linie:
	mov dword ptr[eax], color
	add eax, 4
	loop bucla_linie
	
	sub eax, 4*lenght
	add eax, area_width*4
	inc index
	jmp begin_loop
	

	
end_loop:
	
endm




; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click)
; arg2 - x
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	jmp afisare_interfata
	
evt_click:
	
	mov eax, [ebp + arg2]
	cmp eax, button_start_x
	jl afisare_interfata
	cmp eax, button_start_x + 1*offset_x
	jl coloana1
	cmp eax, button_start_x + 2*offset_x
	jl coloana2
	cmp eax, button_start_x + 3*offset_x
	jl coloana3
	cmp eax, button_start_x + 4*offset_x
	jl coloana4
	jmp afisare_interfata

coloana1:
	mov eax, [ebp + arg3]
	cmp eax, button_start_y
	jl afisare_interfata
	cmp eax, button_start_y + 1*offset_y
	jl buton7	; cifra 7
	cmp eax, button_start_y + 2*offset_y
	jl buton4	; cifra 4
	cmp eax, button_start_y + 3*offset_y
	jl buton1	; cifra 1
	cmp eax, button_start_y + 4*offset_y
	jl buton_clear	; stergere
	jmp afisare_interfata
	
coloana2:
	mov eax, [ebp + arg3]
	cmp eax, button_start_y
	jl afisare_interfata
	cmp eax, button_start_y + 1*offset_y
	jl buton8	; cifra 8
	cmp eax, button_start_y + 2*offset_y
	jl buton5	; cifra 5
	cmp eax, button_start_y + 3*offset_y
	jl buton2	; cifra 2
	cmp eax, button_start_y + 4*offset_y
	jl buton0	; cifra 0
	jmp afisare_interfata
coloana3:
	mov eax, [ebp + arg3]
	cmp eax, button_start_y
	jl afisare_interfata
	cmp eax, button_start_y + 1*offset_y
	jl buton9	; cifra 9
	cmp eax, button_start_y + 2*offset_y
	jl buton6	; cifra 6
	cmp eax, button_start_y + 3*offset_y
	jl buton3	; cifra 3
	cmp eax, button_start_y + 4*offset_y
	jl buton_impartire	; /
	jmp afisare_interfata

coloana4:	
	mov eax, [ebp + arg3]
	cmp eax, button_start_y
	jl afisare_interfata
	cmp eax, button_start_y + 1*offset_y
	jl buton_egal	; =
	cmp eax, button_start_y + 2*offset_y
	jl buton_plus	; +
	cmp eax, button_start_y + 3*offset_y
	jl buton_minus ; -
	cmp eax, button_start_y + 4*offset_y
	jl buton_inmultire ; *
	jmp afisare_interfata

buton0:
	; make_text_macro '0', area, result_start_x, result_start_y
	mov eax, nr_caracter
	mov ebx, 12
	mul ebx
	add eax, result_start_x
	
	make_text_macro '0', area, eax, result_start_y
	mov eax, 0
	inc nr_caracter
	
	mov edx, 0
	mov eax, temp_result
	mov ebx, 10
	mul ebx
	mov temp_result, eax
	jmp afisare_interfata
buton1:
	; make_text_macro '1', area, result_start_x + 15, result_start_y
	; inc deplasare
	mov eax, nr_caracter
	mov ebx, 12	
	mul ebx
	add eax, result_start_x
	
	make_text_macro '1', area, eax, result_start_y
	mov eax, 0
	inc nr_caracter
	
	mov edx, 0
	mov eax, temp_result
	mov ebx, 10
	mul ebx
	add eax, 1
	mov temp_result, eax
	jmp afisare_interfata
buton2:
	; make_text_macro '2', area, result_start_x + 30, result_start_y
	; inc deplasare
	mov eax, nr_caracter
	mov ebx, 12
	mul ebx
	add eax, result_start_x
	
	make_text_macro '2', area, eax, result_start_y
	mov eax, 0
	inc nr_caracter

	mov edx, 0
	mov eax, temp_result
	mov ebx, 10
	mul ebx
	add eax, 2
	mov temp_result, eax
	jmp afisare_interfata
buton3:
	; make_text_macro '3', area, result_start_x + 45, result_start_y
	; inc deplasare
	mov eax, nr_caracter
	mov ebx, 12
	mul ebx
	add eax, result_start_x
	
	make_text_macro '3', area, eax, result_start_y
	mov eax, 0
	inc nr_caracter

	mov edx, 0
	mov eax, temp_result
	mov ebx, 10
	mul ebx
	add eax, 3
	mov temp_result, eax	
	jmp afisare_interfata
buton4:
	; make_text_macro '4', area, result_start_x + 60, result_start_y
	; inc deplasare

	mov eax, nr_caracter
	mov ebx, 12
	mul ebx
	add eax, result_start_x
	
	make_text_macro '4', area, eax, result_start_y
	mov eax, 0
	inc nr_caracter	
	
	mov edx, 0
	mov eax, temp_result
	mov ebx, 10
	mul ebx
	add eax, 4
	mov temp_result, eax
	jmp afisare_interfata
buton5:
	; make_text_macro '5', area, result_start_x + 75, result_start_y
	; inc deplasare
	mov eax, nr_caracter
	mov ebx, 12
	mul ebx
	add eax, result_start_x
	
	make_text_macro '5', area, eax, result_start_y
	mov eax, 0
	inc nr_caracter

	mov edx, 0
	mov eax, temp_result
	mov ebx, 10
	mul ebx
	add eax, 5
	mov temp_result, eax	
	jmp afisare_interfata
buton6:
	; make_text_macro '6', area, result_start_x + 90, result_start_y
	; inc deplasare

	mov eax, nr_caracter
	mov ebx, 12
	mul ebx
	add eax, result_start_x
	
	make_text_macro '6', area, eax, result_start_y
	mov eax, 0
	inc nr_caracter
	
	mov edx, 0
	mov eax, temp_result
	mov ebx, 10
	mul ebx
	add eax, 6
	mov temp_result, eax	
	jmp afisare_interfata
buton7:
	; make_text_macro '7', area, result_start_x + 105, result_start_y
	; inc deplasare
	mov eax, nr_caracter
	mov ebx, 12
	mul ebx
	add eax, result_start_x
	
	make_text_macro '7', area, eax, result_start_y
	mov eax, 0
	inc nr_caracter

	mov edx, 0
	mov eax, temp_result
	mov ebx, 10
	mul ebx
	add eax, 7
	mov temp_result, eax	
	jmp afisare_interfata
buton8:
	; make_text_macro '8', area, result_start_x + 120, result_start_y
	; inc deplasare
	mov eax, nr_caracter
	mov ebx, 12
	mul ebx
	add eax, result_start_x
	
	make_text_macro '8', area, eax, result_start_y
	mov eax, 0
	inc nr_caracter

	mov edx, 0
	mov eax, temp_result
	mov ebx, 10
	mul ebx
	add eax, 8
	mov temp_result, eax
	jmp afisare_interfata
buton9:
	; make_text_macro '9', area, result_start_x + 135, result_start_y
	; inc deplasare
	mov eax, nr_caracter
	mov ebx, 12
	mul ebx
	add eax, result_start_x
	
	make_text_macro '9', area, eax, result_start_y
	mov eax, 0
	inc nr_caracter

	mov edx, 0
	mov eax, temp_result
	mov ebx, 10
	mul ebx
	add eax, 9
	mov temp_result, eax	
	jmp afisare_interfata
buton_clear:
	
	
	mov ebx, 0	
	mov nr_caracter, 0
stergere_caractere:
	
	cmp string[bx + 1], 0
	je final_clear
	mov edx, 0
	
	mov eax, ebx
	mov esi, 12
	mul esi
	add eax, result_start_x
	mov edx, eax
	
	; xor eax, eax
	; mov al, string[bx]

	make_text_macro ' ', area, edx, result_start_y
	inc ebx
	jmp stergere_caractere

final_clear:	
	mov ebx, 0
	mov string[bx], 0
	mov result, 0
	mov first_number, 1
	
	jmp afisare_interfata
buton_egal:
	
	mov operation, 5
	
	cmp prev_operation, 1
	je ADUNARE
	cmp prev_operation, 2
	je SCADERE
	cmp prev_operation, 3
	je INMULTIRE
	cmp prev_operation, 4
	je IMPARTIRE
		
afisare_resultat:	
	
	xor ebx, ebx
	mov ecx, nr_caracter	
	stergere_ecran:	
	mov eax, ebx
	mov esi, 12
	mul esi
	add eax, result_start_x
	
	
	make_text_macro ' ', area, eax, result_start_y
	
	inc ebx
	loop stergere_ecran
	mov nr_caracter, 0
	
	push result
	push offset format_afisare
	push offset string
	call sprintf
	add ESP, 12
	
	xor ebx, ebx

parcurgere_string:
	
	cmp string[bx + 1], 0
	je final_string
	mov edx, 0
	
	mov eax, ebx
	mov esi, 12
	mul esi
	add eax, result_start_x
	mov edx, eax
	
	xor eax, eax
	mov al, string[bx]
	
	cmp al, '-'
	je afisez_minus
	
	; make_text_macro ' ', area, eax, result_start_y
	make_text_macro eax, area, edx, result_start_y
	inc ebx
	jmp parcurgere_string

afisez_minus:
	
	; make_text_macro ' ', area, eax, result_start_y
	make_text_macro 'V', area, edx, result_start_y
	inc ebx
	jmp parcurgere_string

	
final_string:	

	; push result
	; push offset format_afisare
	; call printf
	; add ESP, 8
	jmp afisare_interfata
buton_impartire:

	mov eax, nr_caracter
	mov ebx, 12
	mul ebx
	add eax, result_start_x
	
	make_text_macro 'W', area, eax, result_start_y
	mov eax, 0
	inc nr_caracter

	mov operation, 4
	
	cmp first_number, 1
	je firstNumber
	
	cmp prev_operation, 1
	je ADUNARE
	cmp prev_operation, 2
	je SCADERE
	cmp prev_operation, 3
	je INMULTIRE
	cmp prev_operation, 4
	je IMPARTIRE
	
buton_inmultire:
	
	mov eax, nr_caracter
	mov ebx, 12
	mul ebx
	add eax, result_start_x
	
	make_text_macro 'X', area, eax, result_start_y
	mov eax, 0
	inc nr_caracter	
	
	mov operation, 3
	
	cmp first_number, 1
	je firstNumber
	
	cmp prev_operation, 1
	je ADUNARE
	cmp prev_operation, 2
	je SCADERE
	cmp prev_operation, 3
	je INMULTIRE
	cmp prev_operation, 4
	je IMPARTIRE


buton_minus:

	mov eax, nr_caracter
	mov ebx, 12
	mul ebx
	add eax, result_start_x
	
	make_text_macro 'V', area, eax, result_start_y
	mov eax, 0
	inc nr_caracter
	
	mov operation, 2
	
	cmp first_number, 1
	je firstNumber
	
	cmp prev_operation, 1
	je ADUNARE
	cmp prev_operation, 2
	je SCADERE
	cmp prev_operation, 3
	je INMULTIRE
	cmp prev_operation, 4
	je IMPARTIRE
		
buton_plus:

	mov eax, nr_caracter
	mov ebx, 12
	mul ebx
	add eax, result_start_x
	
	make_text_macro 'Z', area, eax, result_start_y
	mov eax, 0
	inc nr_caracter
	
	mov operation, 1
	
	cmp first_number, 1
	je firstNumber
	
	cmp prev_operation, 1
	je ADUNARE
	cmp prev_operation, 2
	je SCADERE
	cmp prev_operation, 3
	je INMULTIRE
	cmp prev_operation, 4
	je IMPARTIRE
	
ADUNARE:
	mov eax, result
	add eax, temp_result
	mov result, eax
	mov temp_result, 0
	
	cmp operation, 5
	je afisare_resultat
	
	mov eax, operation
	mov prev_operation, eax
	jmp afisare_interfata
SCADERE:
	mov eax, result
	sub eax, temp_result
	mov result, eax
	mov temp_result, 0
	
	cmp operation, 5
	je afisare_resultat
	
	mov eax, operation
	mov prev_operation, eax
	jmp afisare_interfata
INMULTIRE:
	mov edx, 0
	mov eax, result
	mul temp_result
	mov result, eax
	mov temp_result, 0
	mov edx, 0
	
	cmp operation, 5
	je afisare_resultat
	
	mov eax, operation
	mov prev_operation, eax
	jmp afisare_interfata
IMPARTIRE:	
	mov edx, 0
	mov eax, result
	div temp_result
	mov result, eax
	mov temp_result, 0
	mov edx, 0
 	
	cmp operation, 5
	je afisare_resultat
	
	mov eax, operation
	mov prev_operation, eax
	jmp afisare_interfata


	
firstNumber:	
	
	mov eax, temp_result
	mov result, eax
	mov first_number, 0
	mov temp_result, 0
	mov eax, operation
	mov prev_operation, eax
	jmp afisare_interfata

	
evt_timer:
	inc counter
	
afisare_interfata:
	
	; limitele
	make_horizontal_line 50, 30, 540, 0h
	make_horizontal_line 50, 450, 540, 0h
	make_vertical_line 50, 30, 420, 0h
	make_vertical_line 590, 30, 420, 0h
	
	; desenez gridul
	
	; fill_button 51, 31, 539, 180, 0EAEDEDh
	fill_button button_start_x + 3*offset_x, button_start_y + 0*offset_y, offset_x, offset_y, 082A4F6h
	; fill_button button_start_x, button_start_y + 3*offset_y, offset_x, offset_y, 0E74C3Ch
	
	make_horizontal_line button_start_x, button_start_y + 0*offset_y, calc_lenght_x, 0h
	make_horizontal_line button_start_x, button_start_y + 1*offset_y, calc_lenght_x, 0h
	make_horizontal_line button_start_x, button_start_y + 2*offset_y, calc_lenght_x, 0h
	make_horizontal_line button_start_x, button_start_y + 3*offset_y, calc_lenght_x, 0h
	
	make_vertical_line button_start_x + 1*offset_x, button_start_y, 240, 0h
	make_vertical_line button_start_x + 2*offset_x, button_start_y, 240, 0h
	make_vertical_line button_start_x + 3*offset_x, button_start_y, 240, 0h
	
	; desenez butoanele
	
	;linia1			7 8 9 =
	
	make_text_macro '7', area, button_start_x + 0*offset_x + offset_x/2 - 10, button_start_y + 0*offset_y + offset_y/3
	make_text_macro '8', area, button_start_x + 1*offset_x + offset_x/2 - 10, button_start_y + 0*offset_y + offset_y/3
	make_text_macro '9', area, button_start_x + 2*offset_x + offset_x/2 - 10, button_start_y + 0*offset_y + offset_y/3
	make_horizontal_line button_start_x + 3*offset_x + offset_x/2 - 10, button_start_y + 0*offset_y + 29, 15, 0h
	make_horizontal_line button_start_x + 3*offset_x + offset_x/2 - 10, button_start_y + 0*offset_y + 30 , 15, 0h
	make_horizontal_line button_start_x + 3*offset_x + offset_x/2 - 10, button_start_y + 0*offset_y + 40, 15, 0h
	make_horizontal_line button_start_x + 3*offset_x + offset_x/2 - 10, button_start_y + 0*offset_y + 39, 15, 0h
	
	;linia2 		4 5 6 +
	
	make_text_macro '4', area, button_start_x + 0*offset_x + offset_x/2 - 10, button_start_y + 1*offset_y + offset_y/3
	make_text_macro '5', area, button_start_x + 1*offset_x + offset_x/2 - 10, button_start_y + 1*offset_y + offset_y/3
	make_text_macro '6', area, button_start_x + 2*offset_x + offset_x/2 - 10, button_start_y + 1*offset_y + offset_y/3
	make_text_macro 'Z', area, button_start_x + 3*offset_x + offset_x/2 - 10, button_start_y + 1*offset_y + offset_y/3
	
	;linia3			1 2 3 -
	
	make_text_macro '1', area, button_start_x + 0*offset_x + offset_x/2 - 10, button_start_y + 2*offset_y + offset_y/3
	make_text_macro '2', area, button_start_x + 1*offset_x + offset_x/2 - 10, button_start_y + 2*offset_y + offset_y/3
	make_text_macro '3', area, button_start_x + 2*offset_x + offset_x/2 - 10, button_start_y + 2*offset_y + offset_y/3
	make_text_macro 'V', area, button_start_x + 3*offset_x + offset_x/2 - 10, button_start_y + 2*offset_y + offset_y/3
	
	;linia4			CE 0 / *
	
	make_text_macro 'C', area, button_start_x + 0*offset_x + offset_x/2 - 15, button_start_y + 3*offset_y + offset_y/3
	make_text_macro 'E', area, button_start_x + 0*offset_x + offset_x/2 - 5, button_start_y + 3*offset_y + offset_y/3
	make_text_macro '0', area, button_start_x + 1*offset_x + offset_x/2 - 10, button_start_y + 3*offset_y + offset_y/3
	make_text_macro 'W', area, button_start_x + 2*offset_x + offset_x/2 - 10, button_start_y + 3*offset_y + offset_y/3
	make_text_macro 'X', area, button_start_x + 3*offset_x + offset_x/2 - 10, button_start_y + 3*offset_y + offset_y/3
	
	; mov edx, 0
	
	; make_text_macro '0', area, result_start_x, result_start_y
	
	
	
	
final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start
