; -------------------------------------------------------------------
; programa: porcentaje.asm
; calcula el porcentaje de un número respecto a un total
; nasm -f elf64 porcentaje.asm -o porcentaje.o
; ld porcentaje.o -o porcentaje
; ./porcentaje
; -------------------------------------------------------------------

section .data
    prompt1     db  "Ingrese el número (parte): ", 0
    len1        equ $ - prompt1
    prompt2     db  "Ingrese el total: ", 0
    len2        equ $ - prompt2
    msg_result  db  "El porcentaje es: ", 0
    len_res     equ $ - msg_result
    msg_error   db  "Error: el total no puede ser cero.", 10, 0
    len_err     equ $ - msg_error
    newline     db  10, 0
    buffer      db  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0   ; buffer para entrada y salida

section .bss
    num_part    resq 1      ; almacena la parte
    num_total   resq 1      ; almacena el total
    result      resq 1      ; almacena el porcentaje

section .text
    global _start

_start:
    ; ----- leer la parte -----
    mov rax, 1              ; sys_write
    mov rdi, 1              ; stdout
    mov rsi, prompt1
    mov rdx, len1
    syscall

    call read_int           ; retorna el entero en rax
    mov [num_part], rax

    ; ----- leer el total -----
    mov rax, 1
    mov rdi, 1
    mov rsi, prompt2
    mov rdx, len2
    syscall

    call read_int
    mov [num_total], rax

    ; ----- verificar que total != 0 -----
    cmp rax, 0
    je error_zero

    ; ----- calcular porcentaje: (parte * 100) / total -----
    mov rax, [num_part]
    mov rbx, 100
    imul rbx                ; rax = parte * 100 (resultado en rdx:rax, pero parte*100 cabe en 64 bits)
    mov rbx, [num_total]
    xor rdx, rdx            ; limpia rdx para división
    div rbx                 ; rax = cociente, rdx = resto
    mov [result], rax

    ; ----- mostrar resultado -----
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_result
    mov rdx, len_res
    syscall

    mov rax, [result]
    call print_int

    ; imprimir '%' y nueva línea
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall

    jmp exit

error_zero:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_error
    mov rdx, len_err
    syscall

exit:
    mov rax, 60             ; sys_exit
    xor rdi, rdi
    syscall

; -------------------------------------------------------------------
; read_int: lee una línea desde stdin y la convierte a entero (64 bits)
; entrada:  ninguna
; salida:   rax = entero leído
; -------------------------------------------------------------------
read_int:
    push rbx
    push rcx
    push rdx

    mov rax, 0              ; sys_read
    mov rdi, 0              ; stdin
    mov rsi, buffer
    mov rdx, 11             ; máximo 10 dígitos + signo (por seguridad)
    syscall
    ; rax contiene la cantidad de bytes leídos (incluyendo el \n)

    mov rsi, buffer
    xor rax, rax            ; resultado = 0
    xor rcx, rcx            ; índice
    mov rbx, 10             ; base decimal

.loop:
    movzx rdx, byte [rsi + rcx]
    cmp dl, 10              ; fin de línea?
    je .done
    cmp dl, 0
    je .done
    sub dl, '0'
    js .done                ; si es menor que '0', terminar
    cmp dl, 9
    jg .done
    imul rax, rbx
    add rax, rdx
    inc rcx
    jmp .loop

.done:
    pop rdx
    pop rcx
    pop rbx
    ret

; -------------------------------------------------------------------
; print_int: imprime un entero de 64 bits en decimal
; entrada:   rax = entero a imprimir
; -------------------------------------------------------------------
print_int:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    mov rcx, buffer + 10    ; apuntar al final del buffer (reserva 11 bytes)
    mov byte [rcx], 0       ; terminador nulo (opcional)
    dec rcx
    mov rbx, 10

    ; si el número es 0, imprimir '0'
    cmp rax, 0
    jne .convert
    mov byte [rcx], '0'
    dec rcx
    jmp .print

.convert:
    xor rdx, rdx
    div rbx                 ; rax = cociente, rdx = resto
    add dl, '0'
    mov [rcx], dl
    dec rcx
    cmp rax, 0
    jne .convert

.print:
    inc rcx                 ; rcx apunta al primer dígito
    mov rsi, rcx
    ; calcular longitud
    mov rdi, buffer + 10
    sub rdi, rsi
    mov rdx, rdi            ; longitud en rdx

    mov rax, 1
    mov rdi, 1
    syscall

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
