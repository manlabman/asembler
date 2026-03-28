;****************************************************************
; CONTADOR HEMATOLÓGICO CON PIC16F877A
; 8 teclas de conteo (Células específicas)
; Tecla RESET y tecla PORCENTAJE
; 3 displays de 7 segmentos (multiplexados)
; Sonido al llegar a 100 conteos
;****************************************************************

    LIST P=16F877A
    #INCLUDE <P16F877A.INC>
    
    ; Configuración del oscilador y watchdog
    __CONFIG _FOSC_HS & _WDT_OFF & _PWRTE_ON & _BOREN_ON & _LVP_OFF & _CPD_OFF & _WRT_OFF & _DEBUG_OFF

    ; Definición de variables
    CBLOCK 0x20
        CONTADOR        ; Contador principal (0-100)
        CONT_TEMP       ; Temporal para cálculos
        UNIDADES        ; Dígito de unidades
        DECENAS         ; Dígito de decenas
        CENTENAS        ; Dígito de centenas
        PORCENTAJE      ; Variable para porcentaje
        DISP_COUNT      ; Contador de multiplexado
        DISP_MUX        ; Selección de display
        TEMPO           ; Variable temporal
        TECLA_ANT       ; Tecla anterior para anti-rebote
        TECLA_ACT       ; Tecla actual
        RETARDO_CNT     ; Contador de retardo
        SONIDO_CNT      ; Contador para sonido
        FLAG_SONIDO     ; Bandera de sonido
    ENDC
    
    ; Definición de pines
    #DEFINE DISP1_SEL   PORTA,0    ; Selección display 1 (centenas)
    #DEFINE DISP2_SEL   PORTA,1    ; Selección display 2 (decenas)
    #DEFINE DISP3_SEL   PORTA,2    ; Selección display 3 (unidades)
    #DEFINE BUZZER      PORTC,0    ; Salida para sonido
    
    ; Definición de teclas (PORTB)
    ; RB0-RB7: Teclas 0-7 de conteo
    ; RB8: Tecla RESET
    ; RB9: Tecla PORCENTAJE
    
    ORG 0x0000
    GOTO INICIO
    
    ORG 0x0004
    GOTO INTERRUPCION
    
;****************************************************************
; INICIALIZACIÓN DEL SISTEMA
;****************************************************************
INICIO:
    ; Configuración de puertos
    BANKSEL TRISA
    CLRF    TRISA           ; PORTA como salida (selección displays)
    CLRF    TRISC           ; PORTC como salida (buzzer y segmentos)
    MOVLW   0xFF
    MOVWF   TRISB           ; PORTB como entrada (teclado)
    BANKSEL PORTA
    CLRF    PORTA
    CLRF    PORTC
    
    ; Configuración de interrupciones
    BANKSEL INTCON
    BCF     INTCON, INTF    ; Limpiar bandera INT
    BSF     INTCON, INTE    ; Habilitar interrupción externa (teclado)
    BSF     INTCON, GIE     ; Habilitar interrupciones globales
    
    ; Inicialización de variables
    BANKSEL CONTADOR
    CLRF    CONTADOR
    CLRF    PORCENTAJE
    CLRF    FLAG_SONIDO
    MOVLW   D'100'
    MOVWF   RETARDO_CNT
    
    ; Configuración del timer para multiplexado
    CALL    CONFIG_TIMER
    
    ; Bucle principal
MAIN_LOOP:
    CALL    MOSTRAR_DISPLAYS
    CALL    VERIFICAR_TECLAS
    GOTO    MAIN_LOOP
    
;****************************************************************
; CONFIGURACIÓN DEL TIMER PARA MULTIPLEXADO
;****************************************************************
CONFIG_TIMER:
    BANKSEL TMR0
    CLRF    TMR0
    BANKSEL OPTION_REG
    MOVLW   B'11000111'     ; Prescaler 1:256
    MOVWF   OPTION_REG
    BANKSEL INTCON
    BSF     INTCON, T0IE    ; Habilitar interrupción de TMR0
    RETURN
    
;****************************************************************
; INTERRUPCIÓN PARA MULTIPLEXADO Y TIMERS
;****************************************************************
INTERRUPCION:
    BANKSEL INTCON
    BTFSC   INTCON, T0IF    ; Verificar interrupción de TMR0
    CALL    ISR_TIMER
    
    BTFSC   INTCON, INTF    ; Verificar interrupción de teclado
    CALL    ISR_TECLADO
    
    RETFIE
    
;****************************************************************
; ISR DEL TIMER - MANEJA EL MULTIPLEXADO
;****************************************************************
ISR_TIMER:
    BCF     INTCON, T0IF    ; Limpiar bandera
    
    ; Manejo del multiplexado de displays
    BANKSEL DISP_MUX
    INCF    DISP_MUX, F
    MOVLW   D'3'
    SUBWF   DISP_MUX, W
    BTFSC   STATUS, Z
    CLRF    DISP_MUX
    
    ; Seleccionar y mostrar el display correspondiente
    MOVF    DISP_MUX, W
    BTFSC   STATUS, Z
    CALL    MOSTRAR_CENTENAS
    BTFSC   DISP_MUX, 0
    BTFSC   DISP_MUX, 1
    GOTO    $+3
    CALL    MOSTRAR_DECENAS
    GOTO    $+2
    CALL    MOSTRAR_UNIDADES
    
    ; Manejo del sonido
    BANKSEL FLAG_SONIDO
    BTFSC   FLAG_SONIDO, 0
    CALL    GENERAR_SONIDO
    
    RETURN
    
;****************************************************************
; MOSTRAR DÍGITO EN DISPLAY DE CENTENAS
;****************************************************************
MOSTRAR_CENTENAS:
    BCF     DISP1_SEL       ; Desactivar display 1
    BCF     DISP2_SEL
    BCF     DISP3_SEL
    
    BANKSEL CENTENAS
    MOVF    CENTENAS, W
    CALL    TABLA_7SEG
    MOVWF   PORTC
    BSF     DISP1_SEL       ; Activar display centenas
    RETURN
    
;****************************************************************
; MOSTRAR DÍGITO EN DISPLAY DE DECENAS
;****************************************************************
MOSTRAR_DECENAS:
    BCF     DISP1_SEL
    BCF     DISP2_SEL
    BCF     DISP3_SEL
    
    BANKSEL DECENAS
    MOVF    DECENAS, W
    CALL    TABLA_7SEG
    MOVWF   PORTC
    BSF     DISP2_SEL       ; Activar display decenas
    RETURN
    
;****************************************************************
; MOSTRAR DÍGITO EN DISPLAY DE UNIDADES
;****************************************************************
MOSTRAR_UNIDADES:
    BCF     DISP1_SEL
    BCF     DISP2_SEL
    BCF     DISP3_SEL
    
    BANKSEL UNIDADES
    MOVF    UNIDADES, W
    CALL    TABLA_7SEG
    MOVWF   PORTC
    BSF     DISP3_SEL       ; Activar display unidades
    RETURN
    
;****************************************************************
; TABLA DE CONVERSIÓN A 7 SEGMENTOS (ÁNODO COMÚN)
;****************************************************************
TABLA_7SEG:
    ADDWF   PCL, F
    RETLW   B'11000000'     ; 0
    RETLW   B'11111001'     ; 1
    RETLW   B'10100100'     ; 2
    RETLW   B'10110000'     ; 3
    RETLW   B'10011001'     ; 4
    RETLW   B'10010010'     ; 5
    RETLW   B'10000010'     ; 6
    RETLW   B'11111000'     ; 7
    RETLW   B'10000000'     ; 8
    RETLW   B'10010000'     ; 9
    
;****************************************************************
; VERIFICACIÓN DE TECLAS (INTERRUPCIÓN EXTERNA)
;****************************************************************
ISR_TECLADO:
    BCF     INTCON, INTF    ; Limpiar bandera
    BANKSEL PORTB
    MOVF    PORTB, W
    MOVWF   TECLA_ACT
    
    ; Anti-rebote
    CALL    RETARDO_ANTIREBOTE
    
    MOVF    PORTB, W
    XORWF   TECLA_ACT, W
    BTFSS   STATUS, Z
    RETURN
    
    ; Verificar teclas de conteo (RB0-RB7)
    MOVF    TECLA_ACT, W
    ANDLW   0xFF
    BTFSS   STATUS, Z
    CALL    PROCESAR_TECLA
    
    RETURN
    
;****************************************************************
; PROCESAR TECLA PRESIONADA
;****************************************************************
PROCESAR_TECLA:
    ; Verificar tecla RESET (RB8)
    BANKSEL TECLA_ACT
    BTFSC   TECLA_ACT, 8
    CALL    RESET_CONTADOR
    
    ; Verificar tecla PORCENTAJE (RB9)
    BTFSC   TECLA_ACT, 9
    CALL    CALCULAR_PORCENTAJE
    
    ; Verificar teclas de conteo (0-7)
    MOVLW   0xFF
    ANDWF   TECLA_ACT, W
    MOVWF   TEMPO
    
    ; Incrementar contador por cada tecla presionada
    CALL    INCREMENTAR_CONTADOR
    
    RETURN
    
;****************************************************************
; INCREMENTAR CONTADOR
;****************************************************************
INCREMENTAR_CONTADOR:
    BANKSEL CONTADOR
    INCF    CONTADOR, F
    
    ; Verificar si llegó a 100
    MOVLW   D'100'
    SUBWF   CONTADOR, W
    BTFSS   STATUS, Z
    GOTO    ACTUALIZAR_DISPLAYS
    
    ; Llegó a 100, activar sonido
    BANKSEL FLAG_SONIDO
    MOVLW   0x01
    MOVWF   FLAG_SONIDO
    
    ; Reiniciar contador (opcional)
    CLRF    CONTADOR
    
ACTUALIZAR_DISPLAYS:
    CALL    ACTUALIZAR_DIGITOS
    RETURN
    
;****************************************************************
; ACTUALIZAR DÍGITOS DE LOS DISPLAYS
;****************************************************************
ACTUALIZAR_DIGITOS:
    BANKSEL CONTADOR
    MOVF    CONTADOR, W
    MOVWF   CONT_TEMP
    
    ; Calcular centenas
    MOVLW   D'100'
    SUBWF   CONT_TEMP, W
    BTFSS   STATUS, C
    GOTO    SIN_CENTENAS
    MOVWF   CONT_TEMP
    MOVLW   0x01
    MOVWF   CENTENAS
    GOTO    CALC_DECENAS
    
SIN_CENTENAS:
    CLRF    CENTENAS
    
CALC_DECENAS:
    ; Calcular decenas
    MOVF    CONT_TEMP, W
    MOVWF   CONTADOR
    MOVLW   D'10'
    CALL    DIVISION
    MOVWF   DECENAS       ; Cociente (decenas)
    MOVF    CONTADOR, W
    MOVWF   UNIDADES      ; Resto (unidades)
    
    RETURN
    
;****************************************************************
; DIVISIÓN SIMPLE (W dividido por CONTADOR)
;****************************************************************
DIVISION:
    CLRF    DECENAS
    MOVWF   CONT_TEMP
    
DIV_LOOP:
    MOVLW   D'10'
    SUBWF   CONT_TEMP, W
    BTFSS   STATUS, C
    GOTO    DIV_FIN
    MOVWF   CONT_TEMP
    INCF    DECENAS, F
    GOTO    DIV_LOOP
    
DIV_FIN:
    MOVF    DECENAS, W
    RETURN
    
;****************************************************************
; RESET DEL CONTADOR
;****************************************************************
RESET_CONTADOR:
    BANKSEL CONTADOR
    CLRF    CONTADOR
    CLRF    CENTENAS
    CLRF    DECENAS
    CLRF    UNIDADES
    CLRF    FLAG_SONIDO
    BCF     BUZZER          ; Apagar buzzer
    CALL    ACTUALIZAR_DIGITOS
    RETURN
    
;****************************************************************
; CALCULAR PORCENTAJE (100%)
;****************************************************************
CALCULAR_PORCENTAJE:
    BANKSEL CONTADOR
    MOVF    CONTADOR, W
    MOVWF   PORCENTAJE
    
    ; Mostrar porcentaje en displays
    MOVF    PORCENTAJE, W
    CALL    ACTUALIZAR_DIGITOS
    
    ; Temporizador para mostrar porcentaje
    MOVLW   D'50'
    MOVWF   TEMPO
    
PORC_LOOP:
    CALL    MOSTRAR_DISPLAYS
    DECFSZ  TEMPO, F
    GOTO    PORC_LOOP
    
    ; Volver a mostrar contador normal
    MOVF    CONTADOR, W
    CALL    ACTUALIZAR_DIGITOS
    RETURN
    
;****************************************************************
; MOSTRAR DISPLAYS (MAIN LOOP)
;****************************************************************
MOSTRAR_DISPLAYS:
    ; Función llamada desde el bucle principal
    RETURN
    
;****************************************************************
; GENERAR SONIDO AGRADABLE
;****************************************************************
GENERAR_SONIDO:
    BANKSEL SONIDO_CNT
    INCF    SONIDO_CNT, F
    
    ; Generar tono de 1kHz con modulación
    MOVLW   D'100'
    SUBWF   SONIDO_CNT, W
    BTFSC   STATUS, C
    CLRF    SONIDO_CNT
    
    ; Alternar salida del buzzer
    MOVLW   D'50'
    SUBWF   SONIDO_CNT, W
    BTFSC   STATUS, C
    GOTO    TONO_ALTO
    BSF     BUZZER
    RETURN
    
TONO_ALTO:
    BCF     BUZZER
    
    ; Apagar sonido después de 2 segundos
    BANKSEL TEMPO
    INCF    TEMPO, F
    MOVLW   D'200'
    SUBWF   TEMPO, W
    BTFSC   STATUS, C
    CLRF    FLAG_SONIDO
    
    RETURN
    
;****************************************************************
; RETARDO ANTI-REBOTE
;****************************************************************
RETARDO_ANTIREBOTE:
    MOVLW   D'20'
    MOVWF   RETARDO_CNT
    
RETARDO_LOOP:
    DECFSZ  RETARDO_CNT, F
    GOTO    RETARDO_LOOP
    RETURN
    
    END
