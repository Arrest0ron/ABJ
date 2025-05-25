;;client_2.asm
format elf64
public _start

include 'func.asm'

section '.data' writeable
take_msg db 'Ваша карта: %d, сумма %d', 0xA,0
  gain_confirmed db '! confirmed', 0xA, 0
  stop_confirmed db '# confirmed', 0xA, 0
  win_confirmed db '^ confirmed', 0xA, 0
  msg_1 db 'Error bind', 0xa, 0
  msg_2 db 'Successfull bind', 0xa, 0
  msg_3 db 'Successful connect', 0xa, 0
  msg_4 db 'Error connect', 0xa, 0
  msg_enter db 'Вы присоединились к игре. Отправьте T, чтобы взять карту, или S, чтобы остановиться.', 0xa, 0
  number dq 0
  quit_msg db 'Вы покинули игру!', 0xA, 0
  msg_lost db 'Переполнение! Вы проиграли.', 0xA, 0
  ; reading_msg db '_r_', 0
  other_takes_msg db '<Игрок %d взял карту %d, сумма - %d>', 0xA, 0
  other_stops_msg db '<Игрок %d остановился на сумме %d>', 0xA, 0
  ender db 'Ending connection', 0xA, 0
  random_resp db 'Ваше число - %d', 0xA, 0
  stop_msg db 'Вы остановились на счете %d', 0xA,0
  RANDOM dq 0
  win_win db 'Игрок %d выиграл со счетом %d!.', 0xA, 0
  new_msg db '[Игрок%d]: %s', 0xA, 0

  new_game_bet db 'Перед началом игры введите сумму ставки. Ваш баланс - %d$', 0xA,0
  bet_accepted db 'Ваша ставка на сумму %d$ была принята. Обновленный баланс - %d$.', 0xA, 0
  balance dq 1000
  bet dq 0,0,0,0
  start_of_msg db 'Sent message:',0
   stack_alignment db 0
  end_of_msg db ':', 0
  two_symbol_buffer db 0,0
  quit db 'Q',0
  newgame db 1
  canstart db 0
  MAX dq 12
  MIN dq 2
  f  db "/dev/urandom",0
  sm1 dw 0, -1, 4096 
  sm2 dw 0,  1, 4096   
  ids dq 0
  current_score dq 0
section '.bss' writable
	random_desc rq 1
  buffer1 rb 101
  buffer2 rb 101
  temp rb 100
  server rq 1
  shared_memory rq 1

  

struc sockaddr_client
{
  .sin_family dw 2         ; AF_INET
  .sin_port dw 0    ; port 55556
  .sin_addr dd 0           ; localhost
  .sin_zero_1 dd 0
  .sin_zero_2 dd 0
}

addrstr_client sockaddr_client 
addrlen_client = $ - addrstr_client
  
struc sockaddr_server 
{
  .sin_family dw 2         ; AF_INET
  .sin_port dw 0x4d9     ; port 
  .sin_addr dd 0           ; localhost
  .sin_zero_1 dd 0
  .sin_zero_2 dd 0
}

addrstr_server sockaddr_server 
addrlen_server = $ - addrstr_server

section '.text' executable
	
extrn printf
extrn mydelay

_start:

   mov rdi, f     
   mov rax, 2 
   mov rsi, 0o
   syscall 
   mov [random_desc], rax ;генерируем случайное число


  

    ;;Первый процесс создает разделяемую память
    mov rdi, 0    ;начальный адрес выберет сама ОС
    mov rsi, 1024   ;задаем размер области памяти
    mov rdx, 0x3  ;совмещаем флаги PROT_READ | PROT_WRITE
    mov r10, 0x21  ;задаем режим MAP_ANONYMOUS|MAP_SHARED
    mov r8, -1   ;указываем файловый дескриптор null
    mov r9, 0     ;задаем нулевое смещение
    mov rax, 9    ;номер системного вызова mmap
    syscall

    
    
    ;;Сохраняем адрес памяти
    mov [shared_memory], rax
    
   
  ;   call exit
    ;;Создаем семафор
    mov rdi, 0
    mov rsi, 1
    mov rdx, 438 ;;0o666
    or rdx, 512
    mov rax, 64
    syscall
    
    mov [ids], rax
    
    ;;Переводим семафор в состояние готовности
    mov rdi, [ids] ;дескриптор семафора
    mov rsi, 0     ;индекс в массиве
    mov rdx, 16    ;выполняемая команда
    mov r10, 0   ;начальное значение
    mov rax, 66
    syscall
    


    ;;Создаем сокет клиента
    mov rdi, 2 ;AF_INET - IP v4 
    mov rsi, 1 ;SOCK_STREAM
    mov rdx, 6 ;TCP
    mov rax, 41
    syscall
    cmp rax, 0
    je _bind_error


    ;;Сохраняем дескриптор сокета клиента
    mov r9, rax
    mov [server], rax
    
       
    ;;Связываем сокет с адресом
    
    mov rax, 49              ; SYS_BIND
    mov rdi, r9              ; дескриптор сервера
    mov rsi, addrstr_client  ; sockaddr_in struct
    mov rdx, addrlen_client  ; length of sockaddr_in
    syscall

    ;; Проверяем успешность вызова
    cmp        rax, 0
    jl         _bind_error
    
    mov rsi, msg_2
    call print_str
    
    ;;Подключаемся к серверу
    mov rax, 42 ;sys_connect
    mov rdi, r9 ;дескриптор
    mov rsi, addrstr_server 
    mov rdx, addrlen_server
    syscall
    
    cmp rax, 0
    jl  _connect_error

    mov rax, 57
     syscall
     cmp rax,0
     je _read
     
     mov rax, 57
     syscall
     cmp rax,0
     je _write

    ;   mov rsi, msg_enter
    ;  call print_str

    .main_loop:
    mov rdi, [ids]
    mov rsi, sm1
    mov rdx,1
    mov rax, 65
    syscall
    mov rsi, ender
    call print_str
    .end:
    call quit_game

    mov rdi, [ids]
    mov rsi, sm2
    mov rdx,1
    mov rax, 65
    syscall
    ; ;;Закрываем чтение, запись из клиентского сокета
    mov rax, 48
    mov rdi, r9
    mov rsi, 2
    syscall
          
    ;;Закрываем клиентский сокет
    mov rdi, r9
    mov rax, 3
    syscall
    
    call exit

    
_bind_error:
   mov rsi, msg_1
   call print_str
   call exit
   
_connect_error:
   mov rsi, msg_4
   call print_str
   call exit

_read:
    ; push rdi
    ; mov rdi, 500000
    ; ; add rdi, [RANDOM]
    ; call mydelay
    ; pop rdi
    ; pop rdi
    ; mov rsi, reading_msg ;powerful debug
    ; call print_str

    ; mov rsi, reading_msg
    ; call print_str
      mov rax, 0 ;номер системного вызова чтения
      mov rdi, r9 ;загружаем файловый дескриптор
      mov rsi, buffer1 ;указываем, куда помещать прочитанные данные
      mov rdx, 100 ;устанавливаем количество считываемых данных
                                        ; push rsi
                                        ; mov rsi, msg_3
                                        ; call print_str
                                        ; pop rsi
      syscall ;выполняем системный вызов read
                                        ; push rsi
                                        ; mov rsi, msg_3
                                        ; call print_str
                                        ; pop rsi
    ;   ;;Если клиент ничего не прислал, продолжаем
      ; mov rsi, buffer1
      ; call number_str
      ; call print_str
      cmp rax, 0
      je _read    

      cmp BYTE [buffer1+0], 0
      jne .okay
      ;;;INCORRECT INPUT
      jmp _read

      .okay:

            

      ; jne _read
      cmp BYTE [buffer1+1], '!'
      jne .co1
                                ; mov rsi, gain_confirmed
                                ; call print_str
  

    mov rdi, other_takes_msg     
    xor rax, rax
    mov BYTE al, [buffer1+0]   ; r12
    mov rsi, rax
    xor rax, rax
    mov BYTE al, [buffer1+2]   ;dl
    mov rdx, rax
    xor rax, rax
    mov BYTE al, [buffer1+3] ; al
    mov rcx, rax
    xor rax, rax          
    call safe_printf          
  
    mov QWORD [buffer1], 0
    jmp _read

    .co1:
    cmp BYTE [buffer1+1], '#'
    jne .co2
                      ; mov rsi, stop_confirmed
                      ; call print_str
    push rax
    push rdi
    push rsi
    push rdx
    push rcx
    push r8
    push r9
    push r10
    push r11

    mov rdi, other_stops_msg     
    xor rax, rax
    mov BYTE al, [buffer1]   ; r12
    mov rsi, rax
    mov BYTE al, [buffer1+2]   ;dl
    mov rdx, rax
    ; mov BYTE al, [buffer1+3] ; al
    ; mov rcx, rax
    xor rax, rax          
    call safe_printf     

    pop r11
    pop r10
    pop r9
    pop r8
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rax
    mov QWORD [buffer1], 0


      mov rcx, 100
      mov rax, 0
      .lab1:
        mov [buffer1+rcx], 0
      loop .lab1

    jmp _read

    .co2:
    cmp BYTE [buffer1+1], '^'
    jne .co3
                          ; mov rsi, win_confirmed
                          ; call print_str
    push rax
    push rdi
    push rsi
    push rdx
    push rcx
    push r8
    push r9
    push r10
    push r11

    mov rdi, win_win
    xor rax, rax
    mov BYTE al, [buffer1]   ; r12
    mov rsi, rax
    mov BYTE al, [buffer1+2]   ;dl
    mov rdx, rax
    ; mov BYTE al, [buffer1+3] ; al
    ; mov rcx, rax
    xor rax, rax          
    call safe_printf          
    pop r11
    pop r10
    pop r9
    pop r8
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rax

    mov QWORD [buffer1], 0
          mov rcx, 100
      mov rax, 0

      .lab2:
        mov [buffer1+rcx], 0
      loop .lab2
    jmp _read

.co3:
cmp BYTE [buffer1+1], '@'
    jne .co4
    ; mov rsi, msg_enter
    ;   call print_str  
   

    cmp [buffer1+2], 'S'
    jne .co4   ;покачто

;  cmp [buffer1+3], 'S'
;     jne .co4   ;покачто


    ; push rdi
    ; mov rdi, 100000
    ; ; add rdi, [RANDOM]
    ; call mydelay
    ; pop rdi


   
    mov QWORD [buffer1], 0
          mov rcx, 100
      mov rax, 0

      .lab3:
        mov [buffer1+rcx], 0
      loop .lab3

      mov rsi, [shared_memory]
      mov BYTE [rsi], 1
           mov rsi, msg_enter
     call print_str  

      
    jmp _read

      .co4:
      ; mov rdi, buffer1


     
      xor rax, rax
      mov BYTE al, [buffer1]

      mov rdi, new_msg
      mov rsi, rax
      mov rdx, buffer1
      inc rdx
      

      call safe_printf



      ; mov rsi, buffer1
      ; inc rsi
      ; push rcx
      ; call print_str
      ; pop rcx
      ; call new_line



    .clear:
    ;   ;;Очищаем буффер, чтобы он не хранил старые значения
      mov rcx, 100
      mov rax, 0
      .lab:
        mov [buffer1+rcx], 0
      loop .lab 
jmp _read

_write:
    cmp [newgame], 1
    jne .continue

    mov rdi, new_game_bet
    mov QWORD rsi, [balance]
    call safe_printf
    mov rsi, bet
    call input_keyboard
    call str_number
    mov [bet], rax
    mov rdi, bet_accepted
    mov rsi, [bet]
    sub [balance], rsi
    mov rdx, [balance]
    call safe_printf

    call place_bet
    mov rax, 1
    mov rdi, [server]
    mov rsi, buffer2
    mov rdx, 100
    syscall
    push rdi
    .waiting:
    ;; ожидаем остальных..
    
    mov rdi, 3
    
    
    mov rdi, [shared_memory]
    cmp BYTE [rdi+0], 1
    
    jne .waiting
    lock dec BYTE [rdi+0]
    pop rdi



  ;  push rdi
  ;   mov rdi, 100000
  ;   ; add rdi, [RANDOM]
  ;   call mydelay
  ;   pop rdi

  push rdi
    push rcx
    mov rdi, 3000000
    call mydelay
    pop rcx
    pop rdi

    call take_card
    mov rax, 1
    mov rdi, [server]
    mov rsi, buffer2
    mov rdx, 100
    syscall

    push rdi
    push rcx
    mov rdi, 1000000000
    call mydelay
    pop rcx
    pop rdi

    call take_card
    mov rax, 1
    mov rdi, [server]
    mov rsi, buffer2
    mov rdx, 100
    syscall

    dec [newgame]

    .continue:


    
    mov rsi, buffer2
    call input_keyboard

    
    cmp byte [buffer2], 'Q'
    jne .next3
    call quit_game
    mov rax, 1
    mov rdi, [server]
    mov rsi, buffer2
    mov rdx, 100
    syscall
    jmp _start.end
    .next3:

    cmp byte [buffer2], 'T'
    jne .next1
    call take_card
    jmp .next2
  


    .next1:
    cmp byte [buffer2], 'S'
    jne .next2
    call stop_take

    
    ; jmp _write
    .next2:
    
    ;;Отправляем сообщение на сервер
    mov rax, 1
    mov rdi, [server]
    mov rsi, buffer2
    mov rdx, 100
    syscall

jmp _write


take_card:
    mov rax, 0 ;
    mov rdi, [random_desc]
    mov rsi, number
    mov rdx, 1
    syscall
    mov rax, [MAX]
    sub rax, [MIN]
    mov rcx, rax ;rcx=5
    mov rax, [number] ;rax = rand
    xor rdx, rdx
    div rcx
    mov rax, rdx
    add rax, [MIN]
    mov [RANDOM], rax
    mov rdi, take_msg
    mov rsi, [RANDOM]
    add [current_score], rax
    cmp [current_score], 22
    jl .nnnext     
    mov rsi, msg_lost
    call print_str
    mov [current_score], 0
    jmp wh_l     ;;

    .nnnext:      ;; cюда если меньше 22 - сразу
    mov rdx, [current_score]
    push rax
    call safe_printf
    pop rax
    mov rax, [RANDOM]
    wh_l:
    mov BYTE [buffer2], '!'
    mov BYTE [buffer2+1], al
    mov BYTE [buffer2+2], 0
    mov BYTE [buffer2+3], 0
    
    
    ret

stop_take:
    
    mov rdi, stop_msg
    mov rsi, [current_score]
    push rax
    call safe_printf
    pop rax
    mov BYTE [buffer2], '#'
    mov BYTE [buffer2+1], 'e'
    mov BYTE [buffer2+2], 0
    mov [current_score], 0
    ret

place_bet:

    mov BYTE [buffer2], '$'
    mov rax, [bet]
    mov word [buffer2+1], ax
    xor rax, rax
    mov BYTE [buffer2+3], 0

    push rdi
    mov rdi, 50000
    call mydelay
    pop rdi
    ret

quit_game:
    mov rdi, quit_msg
    push rax
    call safe_printf
    pop rax
    mov BYTE [buffer2], '|'
    mov BYTE [buffer2+1], 0
    mov [current_score], 0
    ret





; rdi = форматная строка
; остальные аргументы printf передаются как обычно
safe_printf:
    ; Проверяем текущее выравнивание стека
    test rsp, 0xF
    jz .aligned
    
    ; Если стек не выровнен, сохраняем факт коррекции
    mov byte [stack_alignment], 1
    push rax    ; Корректируем стек (теперь он выровнен)
    jmp .call_printf
    
.aligned:
    mov byte [stack_alignment], 0
    
.call_printf:
    ; Сохраняем все используемые регистры
    push rdi
    push rsi
    push rdx
    push rcx
    push r8
    push r9
    push r10
    push r11
    
    ; Вызов printf
    xor eax, eax    ; 0 floating point args
    call printf
    
    ; Восстанавливаем регистры
    pop r11
    pop r10
    pop r9
    pop r8
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    
    ; Проверяем, делали ли мы коррекцию
    cmp byte [stack_alignment], 1
    jne .done
    
    ; Если делали коррекцию - убираем ее
    pop rax
    mov byte [stack_alignment], 0
    
.done:
    ret


