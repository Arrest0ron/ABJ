;;client_2.asm
format elf64
public _start

include 'func.asm'

section '.data' writeable
take_msg db 'Ваша карта: %d, сумма %d', 0xA,0
  we_got_input db 'Мы получили ввод' , 0xA, 0
  gain_confirmed db '! confirmed', 0xA, 0
  stop_confirmed db '# confirmed', 0xA, 0
  win_confirmed db '^ confirmed', 0xA, 0
  msg_1 db 'Error bind', 0xa, 0
  msg_2 db 'Successfull bind', 0xa, 0
  msg_3 db 'Successful connect', 0xa, 0
  dealer_got db 'Дилер получил %d очков.', 0xA, 0
  DBG_amount_msg db 'Новая игра: %d, баланс: %d, ставка: %d, очков: %d', 0xA,0 
  msg_4 db 'Error connect', 0xa, 0
  msg_enter db 'Вы присоединились к игре. Отправьте T, чтобы взять карту, S чтобы остановиться и B, чтобы получить информацию.', 0xa, 0
  number dq 0
  quit_msg db 'Вы покинули игру!', 0xA, 0
  msg_lost db 'Переполнение! Получив карту %d, вы проиграли со счетом %d.', 0xA, 0
  ; reading_msg db '_r_', 0
  other_takes_msg db '<Игрок %d взял карту %d, сумма - %d>', 0xA, 0
  other_stops_msg db '<Игрок %d остановился на сумме %d>', 0xA, 0
  ender db 'Ending connection', 0xA, 0
  random_resp db 'Ваше число - %d', 0xA, 0
  stop_msg db 'Вы остановились на счете %d', 0xA,0
  RANDOM dq 0
  win_win db ' ', 0xA, 0
  win_win_old db 'Игрок %d выиграл со счетом %d!.', 0xA, 0
  youwin db 'Вы (игрок %d) выиграли со счетом %d!.', 0xA, 0
  new_msg db '[Игрок%d]: %s', 0xA, 0
results2_msg db 0xA,  '______________ Начало игры ______________', 0xA,0
  new_game_bet db 'Перед началом игры введите сумму ставки. Ваш баланс - %d$', 0xA,0
  bet_accepted db 'Ваша ставка на сумму %d$ была принята. Обновленный баланс - %d$.', 0xA, 0
  balance dq 1000
  drop_input db 'Напишите любое сообщение для начала новой игры.', 0xA, 0
  win_increase db 'Вы удвоили %d$. Ваш баланс перед возвратом: %d$. После: %d$.', 0xA, 0
  tie_increase db 'Ничья. Вернули ваши %d$. Ваш баланс до %d$. После: %d$.', 0xA, 0
  loss db 'Проигрыш! Вы потеряли вашу ставку.', 0xA,0
  waiting_input db 'КЛАВИАТУРА: ', 0xA,0

  read_executed db 'Read executed: %d %d %d %d to %d :', 0xA, 0

  block_input db 0
    
  bet dq 0,0,0,0
  start_of_msg db 'Sent message:',0
   stack_alignment db 0
  ;  incorrect_input db 'Неверный вход:', 0xA,0
   incorrect_input_bytes db 'Неверный вход: %d %d %d :', 0xA,0
  end_of_msg db ':', 0
  two_symbol_buffer db 0,0
  quit db 'Q',0
  newgame db 1
  buf_clear db 'Буфер чтения очищен', 0xA,0
  MAX dq 12
  MIN dq 2
  f  db "/dev/urandom",0
  sm1 dw 0, -1, 4096 
  sm2 dw 0,  1, 4096   
  ids dq 0
  current_score dq 0
  shared_memory dq 0
section '.bss' writable
	random_desc rq 1
  buffer1 rb 101
  buffer2 rb 101
  temp rb 100
  server rq 1

  

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
    mov rsi, [shared_memory]
    mov BYTE [rsi], 1

    mov QWORD [rsi+8], 1000

    push rax
    push rsi
    mov rsi, results2_msg
    call print_str
    pop rsi
    pop rax

  ;  mov rax, 0 ;
  ;   mov rdi, [random_desc]
  ;   mov rsi, number
  ;   mov rdx, 1
  ;   syscall
  
    ; mov rax, [number]
    ; xor rdx, rdx
    ; mov rcx, 100
    ; div rcx
    ; inc rdx
    ; add [addrstr_client+2], rdx
    ; xor rdx,rdx
    ; mov rax, [addrstr_client+2]
    ; mov rsi, buffer1
    ; call number_str
    ; call print_str
    ; call exit


  ;  call take_card
  ;   call exit
    
   
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
      
    ; push rsi
    ; push rdi
    ; push rbx
    ; push rdx
    ; push r8
    ; push rcx
    ; push r9

    ; xor rdx, rdx
    ; xor rbx, rbx
    ; xor r8,r8
    ; xor rcx, rcx
    ; xor rsi, rsi
    

    ; mov rdi, read_executed
    ; mov BYTE dl, [buffer1+1]
    ; mov BYTE cl, [buffer1+2]
    ; mov BYTE r8l, [buffer1+3]
    ; mov r9l, r12l
    ; mov BYTE bl, [buffer1]
    ; mov rsi, rbx
    ; call safe_printf

    ; pop r9
    ; pop rcx
    ; pop r8
    ; pop rdx
    ; pop rbx
    ; pop rdi
    ; pop rsi

      cmp BYTE [buffer1+0], 0
      jne .okay
      ; mov rsi, incorrect_input
      ; call print_str
      xor rsi, rsi
      xor rdx, rdx
      xor rcx, rcx
      mov rdi, incorrect_input_bytes
      mov BYTE sil, [buffer1+1]
      mov BYTE dl, [buffer1+2]
      mov BYTE cl, [buffer1+3]
      call safe_printf
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
  

      ; mov rcx, 100
      ; mov rax, 0
      ; .lab4:
      ;   mov [buffer1+rcx], 0
      ; loop .lab4

      ; call debug_amounts

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
    ; mov QWORD [buffer1], 0


      ; mov rcx, 100
      ; mov rax, 0
      ; .lab1:
      ;   mov [buffer1+rcx], 0
      ; loop .lab1

      ; call debug_amounts

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
    mov rax, 'S'
    cmp BYTE al, [buffer1]
    jne .notequal
    mov rdi, youwin

    push rcx
      mov rdi, 10
      call mydelay
      pop rcx
    push rsi
    
    mov rdi, win_increase ; 
    mov rbx, [shared_memory]
    mov rsi, [rbx+16]
    add rsi, [rbx+16]
    
    mov rdx, [rbx+8]

    add [rbx+8], rsi 
    mov rcx, [rbx+8]
    call safe_printf
    pop rsi
    .notequal:
    
    call safe_printf  
    ; call print_str  
    pop r11
    pop r10
    pop r9
    pop r8
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rax

    ; mov QWORD [buffer1], 0
      ;     mov rcx, 100
      ; mov rax, 0

      ; .lab2:
      ;   mov [buffer1+rcx], 0
      ; loop .lab2

      ; call debug_amounts
    jmp _read

      .co3:
  
    cmp BYTE [buffer1+1], '@'
    jne .co4
    
    mov rsi, [shared_memory]
    cmp WORD [rsi+24], 0
    je .end_game

    mov BYTE [rsi+24], 0


    
    ; ;                       ; mov rsi, win_confirmed
    ; ;                       ; call print_str

    
    push rax
    push rsi
    mov rsi, results2_msg
    call print_str
    mov rsi, drop_input
    call print_str
    mov rsi, [shared_memory]
    mov BYTE [rsi], 1
    pop rsi
    pop rax

    xor rax, rax
    mov BYTE al, [buffer1+2]
    mov rsi, rax
    mov rdi, dealer_got 
    call safe_printf

    xor rax, rax
    mov BYTE al, [buffer1+2]
    mov rsi, [shared_memory]
    mov byte bl, [rsi+32]

    cmp BYTE bl, 21
    jg .nowin
    
    cmp BYTE al, 21
    jg .win
    

    cmp BYTE al, bl
    je .tie

    cmp BYTE al, bl
    jg .nowin


    ; xor rsi, rsi
    ; xor rdx, rdx 
    .win:
    mov rdi, [shared_memory]
    mov rsi, [rdi+16]
    mov  rdx, [rdi+8]
    add  [rdi+8], RSI
    add [rdi+8], RSI
    mov RCX, [rdi+8]
    mov rdi, win_increase
    call safe_printf


    mov rdi, 10000
    call mydelay

    jmp .end_game


    .nowin:
    mov rsi, loss
    call print_str


    mov rdi, 10000
    call mydelay
    jmp .end_game
    
    .tie:
      mov rdi, [shared_memory]
    mov rsi, [rdi+16]
    mov  rdx, [rdi+8]
    add [rdi+8], RSI
    mov RCX, [rdi+8]
    mov rdi, tie_increase
    call safe_printf


    mov rdi, 10000
    call mydelay

    jmp .end_game

    .end_game:

      ; call debug_amounts




      ; mov 
        mov rcx, 100
      mov rax, 0
      .labX:
        mov [buffer1+rcx], 0
      loop .labX
      mov rsi, buf_clear

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
    .clear:
    ;   ;;Очищаем буффер, чтобы он не хранил старые значения
      mov rcx, 100
      mov rax, 0
      .lab:
        mov [buffer1+rcx], 0
      loop .lab 
      mov rsi, buf_clear
      ; call print_str




jmp _read

_write:

    mov rsi, [shared_memory]
    cmp BYTE [rsi], 1
    jne .continue
    
    mov rdi, new_game_bet
     mov rsi, [shared_memory]
    mov QWORD rsi, [rsi+8]
    call safe_printf
    mov rsi, bet
    call input_keyboard
    call str_number
    push rsi
    
     mov rsi, [shared_memory]
    mov [rsi+16], rax
    pop rsi
    mov rdi, bet_accepted
    mov rsi, [shared_memory]
    mov rsi, [rsi+16]
    mov rdx, [shared_memory]
    sub [rdx+8], rsi
    mov rdx, [shared_memory]
    mov rdx, [rdx+8]
    call safe_printf

    call place_bet
    mov rax, 1
    mov rdi, [server]
    mov rsi, buffer2
    mov rdx, 100
    syscall
    
   push rdi
    mov rdi, 20
    call mydelay
    pop rdi


    push rsi
    push rcx
    push r10
    mov rsi, msg_enter
    call print_str
    pop r10
    pop rcx
    pop rsi

    call take_card
    mov rax, 1
    mov rdi, [server]
    mov rsi, buffer2
    mov rdx, 100
    syscall

    push rdi
    mov rdi, 200000
    call mydelay
    pop rdi

    call take_card
    mov rax, 1
    mov rdi, [server]
    mov rsi, buffer2
    mov rdx, 100
    syscall

    mov rsi, [shared_memory]
    dec BYTE [rsi]

    .continue:
    mov rsi, [shared_memory]
    cmp BYTE  [rsi+24], 1
    je _write
    mov rsi, waiting_input
    ; call print_str
    mov rsi, buffer2
    call input_keyboard

    mov rsi, [shared_memory]
    cmp BYTE [rsi], 1
    je _write

    
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
    jmp .nextEND
  


    .next1:
    cmp byte [buffer2], 'S'
    jne .next2
    call stop_take
    
    


    mov rsi, [shared_memory]

    mov BYTE [rsi+24], 1


    
    jmp .nextEND

    .next2:
    cmp byte [buffer2], 'B'
    jne .next3
    call debug_amounts
    jmp _write
  
    
    .nextEND:
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
    push rdx
    push rax
    push rcx
    mov rdi, msg_lost
    mov rdx, [current_score]
    mov rsi, [RANDOM]
    call safe_printf
    pop rcx
    pop rax
    pop rdx
    
    
    jmp wh_l     ;;

    .nnnext:      ;; cюда если меньше 22 - сразу
    mov rdx, [current_score]
    push rax
    call safe_printf
    pop rax
    mov rax, [RANDOM]

    wh_l:
    mov rax, [RANDOM]
    mov BYTE [buffer2], '!'
    mov BYTE [buffer2+1], al
    mov BYTE [buffer2+2], 0
    mov BYTE [buffer2+3], 0

    mov rsi, [shared_memory]
    mov rax, [current_score]
    mov [rsi+32], rax

    cmp [current_score], 21
    jle .end_take


    mov rax, 1
    mov rdi, [server]
    mov rsi, buffer2
    mov rdx, 100
    syscall

    
    mov rdi, 500000
    call mydelay
    mov BYTE [buffer2], 'S'
    mov BYTE [buffer2+1], 0
    jmp _write.next1
    
    .end_take:
    
    ret

stop_take:
    push rax
    push rsi
    push rcx
    push rdi

    mov rdi, stop_msg
    mov rsi, [current_score]

    ; push rax
    call safe_printf
    ; pop rax

    pop rdi
    pop rcx
    pop rsi
    pop rax
    
    mov BYTE [buffer2], '#'
    mov BYTE [buffer2+1], 'e'
    mov BYTE [buffer2+2], 0
    mov [current_score], 0
    ret

place_bet:

    mov BYTE [buffer2], '$'
    push rsi
    mov rsi, [shared_memory]
    mov rax, [rsi+16]
    pop rsi
    mov word [buffer2+1], ax
    xor rax, rax
    mov BYTE [buffer2+3], 0
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



debug_amounts:
  push rax
  push rsi
  push rdx
  push rcx
  push rbx
  push rdi
  push r8
 
  mov rbx, [shared_memory]
  mov rsi, [rbx]
  mov rdx, [rbx+8]
  mov rcx, [rbx+16]
  mov r8, [rbx+32]
  mov rdi, DBG_amount_msg

  call safe_printf

  pop r8
  pop rdi
  pop rbx
  pop rcx
  pop rdx
  pop rsi
  pop rax
  
  ret