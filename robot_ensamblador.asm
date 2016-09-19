#start=robot.exe#

;puertos E/S de comunicacion del robot
PUERTO_COMANDOS equ  9
PUERTO_DATOS    equ 10
PUERTO_ESTADO   equ 11

;estados del robot (para los datos del puerto de estado)
ROBOT_EXAMINANDO         equ 00000001b ;Activo si datos preparados
ROBOT_EJECUTANDO_COMANDO equ 00000010b ;Activo si ocupado
ROBOT_ERROR_COMANDO      equ 00000100b ;Activo si error



data segment
  comando db 15 DUP(?)
  subcadena_temp db 15 DUP(?)
  test1 db "hola", 0
  test2 db "hola", 0

  msj_bienvenida_c db 10,13,"BIENVENID@ A LA CONSOLA DE CONTROL",10,13
                   db " comandos disponibles:",10,13
                   db "   go: avanza",10,13
                   db "   turn left N: girar a la izquierda N veces",10,13
                   db "   turn right N: girar a la derecha N veces",10,13
                   db "   examine: examinar",10,13
                   db "   exit: salir del programa",10,13,10
                   db " acciones automaticas:",10,13
                   db "   1) tras examinar, si se encuentra una bombilla encendida se apaga",10,13
                   db "                     si se encuentra una bombilla apagada se enciende",10,13
                   db "   2) con 'go', el robot avanza y examina hasta que lo que tiene",10,13
                   db "      delante sea una pared o una bombilla (que enciende o apaga)",10,13,'$'

  msj_introduce_comando db 10,13,"alumn@IC: Introduce un comando>> $"

  msj_error_comando db 10,13,"    Comando erroneo$"
  msj_error_parametros_turn db 10,13,"    Parametro(s) erroneo(s)",10,13
                            db 10,13,"      Sintaxis: turn left n"
                            db 10,13,"                turn right n", 10,13
                            db 10,13,"        siendo n un valor numerico de 0 a 9",10,13,'$'

  msj_salida db 10,13,"Saliendo de la consola de control...$"

  cmd_go db "go",0
  cmd_turn db "turn",0
    param_left db "left",0
    param_right db "right",0
  cmd_examine db "examine",0
  cmd_exit db "exit",0
ends

stack segment
    dw   128  dup(0)
ends

code segment

;###################################################################
;############# PROCEDIMIENTOS ROBOT ################################
;###################################################################

;************************************************
; procedimiento que se queda en un bucle
; hasta que el robot completa la accion de examinar
esperar_ejecucion_examinar proc
    push ax

 chequea_ocupado_examen:
    in al, PUERTO_ESTADO
    test al, ROBOT_EXAMINANDO
    jz chequea_ocupado_examen

    pop ax
    ret
esperar_ejecucion_examinar endp



;************************************************
; procedimiento que se queda en un bucle
; hasta que el robot completa un comando
esperar_ejecucion_comando proc
    push ax

 chequea_ocupado_comando:
    in al, PUERTO_ESTADO
    test al, ROBOT_EJECUTANDO_COMANDO      ;test hace la AND entre los dos operandos
    jnz chequea_ocupado_comando            ;salto si !=0

    pop ax
    ret
esperar_ejecucion_comando endp



;************************************************
; procedimiento que chequea si el comando
; enviado al robot se ejecuto exitosamente o no
; S: AH=0 --> sin error ; AH=1 --> error
; TODO: no esta
chequear_ejecucion_comando proc
    in al, PUERTO_ESTADO
    test al, ROBOT_ERROR_COMANDO
    jnz ejecucion_comando_incorrecto
    xor ah, ah                            ;similar a un mov 0
    jmp fin_chequeo
 ejecucion_comando_incorrecto:
    mov ah, 1
 fin_chequeo:

    ret
chequear_ejecucion_comando endp


;************************************************
;procedimiento que envia un comando nulo al robot para reiniciar PUERTO_COMANDOS
limpiar_comando proc
    push ax

  repetir_limpiar_comando:
    mov al, 0
    out PUERTO_COMANDOS, al

    call esperar_ejecucion_comando

    pop ax

    ret
limpiar_comando endp


;************************************************
;procedimiento que envia al robot el comando para avanzar una casilla
ir_adelante proc
    push ax

  repetir_ir_adelante:
    call limpiar_comando

    mov al, 1
    out PUERTO_COMANDOS, al

    call esperar_ejecucion_comando

    call chequear_ejecucion_comando
    cmp ah, 0
    je salir_ir_adelante

    call examinar
    in al, PUERTO_DATOS
    ; 0 indica que el cuadrante esta vacio
    cmp al, 0
    je repetir_ir_adelante


  salir_ir_adelante:
    pop ax
    ret
ir_adelante endp


;************************************************
;procedimiento de giro a la derecha del robot
girar_derecha proc
    push ax

  repetir_giro_derecha:
  call limpiar_comando

  mov al, 3
  out PUERTO_COMANDOS, al

  call esperar_ejecucion_comando

  call chequear_ejecucion_comando
  test al, ROBOT_ERROR_COMANDO
  jnz  repetir_giro_derecha

  pop ax
  ret
girar_derecha endp


;************************************************
;procedimiento de giro a la izquierda del robot
girar_izquierda proc
    push ax

  repetir_giro_izquierda:
  call limpiar_comando

  mov al, 2
  out PUERTO_COMANDOS, al

  call esperar_ejecucion_comando

  call chequear_ejecucion_comando
  test al, ROBOT_ERROR_COMANDO
  jnz  repetir_giro_izquierda

  pop ax
  ret
girar_izquierda endp

;************************************************
;procedimiento que pide al robot que examine cuadrante frente al robot
examinar proc
    push ax

    call limpiar_comando

    mov al, 4
    out PUERTO_COMANDOS, al
    call esperar_ejecucion_examinar

    pop ax

    ret
examinar endp


;###################################################################
;############# PROCEDIMIENTOS YA CONOCIDOS #########################
;###################################################################

;************************************************
;En el registro DX se debe indicar la direccion de la cadena donde
;almacenar� el resultado de la lectura por teclado
;fuerza que el caracter de final de cadena sea 0 en vez de 13
LeerCadena PROC
    push ax
    push bx
    push si

    mov ah, 0ah
    int 21h
    mov bx, dx
    mov si, [bx+1]
    and si, 00FFh
    mov [bx+si+2], 0

    pop si
    pop bx
    pop ax
    ret
LeerCadena ENDP


;************************************************
;compara 2 cadenas, ambas tienes que terminar en 0 para poder compararlas
;E: SI apunta a la direccion de la primera cadena
;   DI apunta a la direccion de la segunda cadena
;S: AH=0 si las cadenas son distintas; AH=1 si las cadenas son iguales
compararCadenas PROC
  push bx
  mov dx, 0
  mov ah, 1

  loop bcomparar_cadenas
  mov bh, [si]
  mov bl, [di]
  cmp bl, bh
  jne comparar_cadenas_falso

  cmp bh, 0
  je salir_comparar_cadenas

  inc si
  inc di

  bcomparar_cadenas:
  comparar_cadenas_falso:
  mov ah, 0

  salir_comparar_cadenas:
  pop bx
  ret
compararCadenas ENDP

;************************************************
;Copia  parte  de  una  cadena  origen  en  otra  cadena  destino.  Coloca  un  0
;como caracter final
;E: BX apunta a la direccion de la cadena origen
;   DI apunta a la direccion de la cadena destino
;   SI contiene la posicion a partir de la que se copiaran las cadenas
;   CX contiene el numero de caracteres que se copiaran
;S: Se modifica la memoria a partir de la direccion de DI
subCadena PROC

    ret
subCadena ENDP


;************************************************
;E: En el registro DX se debe indicar la direccion de la cadena a imprimir
Imprimir PROC
    push ax

    mov ah, 9
    int 21h

    pop ax
    ret
Imprimir ENDP


start:
    mov ax, data
    mov ds, ax
    mov es, ax

    lea si, test1
    lea di, test2
    call compararCadenas
    ;lea dx, msj_bienvenida_c
    ;call Imprimir

    ;call ir_adelante
    ;call girar_izquierda
    ;call ir_adelante

    mov ax, 4c00h
    int 21h

ends

end start
