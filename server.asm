;;server_3.asm

format elf64
public _start

extrn printf
extrn mydelay

include 'func.asm'

section '.data' writeable
  sent_gain_msg db '_C!_', 0xA,0
  sent_stop_msg db '_C#_', 0xA,0
  sent_win_msg db '_C^_', 0xA,0
  read_msg db '_r', 0

  debug_sem_msg db 'Текущее значение семафора: ',0
  debug_atomized_msg db 'Текущее значение атомарного счетчика: ',0

  DBG_to_others db 'Отправляю другим сообщение о взятии...', 0

  user_caused db '_event # caused by %d', 0xA, 0

  sending_dt db ' sent to %d', 0xA, 0
  msg_1 db 'Error bind', 0xa, 0
  msg_2 db 'Successfull bind', 0xa, 0
  msg_3 db 'New connection on server',0xA, 0
  score_msg db 'Игрок %d закончил игру со счетом %d', 0xA, 0
  msg_4 db 'Successfull listen', 0xa, 0
  reset_amount_msg db 'Перезапускаем игру для %d игроков', 0xA, 0
  win_msg db '>Победил пользователь %d со счетом %d<', 0xA, 0
  new_game_msg db 'Новая игра началась!', 0xA, 0
  ping_msg db '[ping%d]', 0xA, 0
  from_msg db '[usr%d]: ', 0xA, 0
  other_takes_msg db '<Игрок %d взял карту %d, его счет %d>', 0xA, 0
  other_stop_msg db '<Игрок %d остановился на счете %d>', 0xA, 0
  other_bets_msg db '<Игрок %d поставил %d$>', 0xA, 0
  other_lost_msg db '<Игрок %d проиграл со счетом %d>', 0xA, 0
  other_connected db '<Присоединился новый игрок - usr%d>', 0xA, 0
  left_players_msg db '<Осталось %d игроков>', 0xA, 0
  endgame_msg db 'Игра окончена. Подсчет результатов...', 0xA,0

  automated_response db 'ping client', 0xA, 0
  results_msg db 0xA, '____________ Результаты игры ____________', 0xA,0
results2_msg db 0xA,  '______________ Начало игры ______________', 0xA,0
  random_resp db 'Ваше число - %d', 0xA, 0
  new_player_stats db 'Имеется %d игроков, %d - активно.',0xA,0  
  nowin db 'Победителей нет!', 0xA, 0     
  user_left_msg db 'Игрок %d покинул игру, осталось %d игроков.', 0xA,0
  cards_scores_players_current dq 0 ; +0-63 scores (up to 64 players) , +64 - total players
  new_status db 0
  bets dq 0  ; +0-63 bets, +64 - current_ended
  inp_msg db '_in_', 0xA, 0
  message_to_all dq  0 ;+0-64 - msg
  dealer_score db 0, 0
  stack_alignment db 0
  temp db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  sent_at_req db 'Sent @ req for %d.' ,0xA,0
  some_write db '_w:', 0xA,0

  DBG_start_sem_loop db 'Пользователь написал, начинаю увеличивать семафор', 0xA,0
  DBG_end_sem_loop db 'Завершено!', 0xA,0
  DBG_amount_msg db 'Всего: %d, в игре: %d, не завершило ход: %d, не поставило: %d.', 0xA, 0
  DBG_start_copy db 'Пользователь написал, начинаю копировать сообщение', 0xA,0
  DBG_end_copy db 'Завершено', 0xA,0
  DBG_reduce_sem db 'Отправлено сообщение, уменьшаю семафор', 0xA,0
  DBG_message_cleared  db 'Буфер отправления очищен', 0xA,0
  sent_win_request db 'Отправлен  ^ пользователю %d о победе %d ', 0xA,0
  DBG_rcx db 'Значение rcx очищено: %d', 0xA,0
  


  ids dq 0
  val dq 0
    sm1 dw 0, -1, 4096 
   sm2 dw 0, 1, 4096   


  
  
section '.bss' writable
	
  buffer rb 100
  buffer_help rb 200

  read_buffer rb 100
  write_buffer rb 100

  

  random_desc rq 1
;;Структура для клиента
  struc sockaddr_in
{
  .sin_family dw 2         ; AF_INET
  .sin_port dw 0x4d9     ; port 
  .sin_addr dd 0           ; localhost
  .sin_zero_1 dd 0
  .sin_zero_2 dd 0
}
  addrstr sockaddr_in 
  addrlen = $ - addrstr
section '.text' executable
	
_start:


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
    mov [cards_scores_players_current], rax
    mov [bets], rax
    add [bets], 64
    mov [message_to_all], rax
    add [message_to_all], 64
    add [message_to_all], 64


    mov rcx, 1023
    mov rsi, [cards_scores_players_current]
    .initial_clear:
        mov BYTE [rsi+rcx], 0
        dec rcx
        cmp rcx, -1
        jne .initial_clear


        

    ;;Создаем сокет
    mov rdi, 2 ;AF_INET - IP v4 
    mov rsi, 1 ;SOCK_STREAM
    mov rdx, 6 ;TCP
    mov rax, 41
    syscall
    
    ;;Сохраняем дескриптор сокета
    mov r9, rax
    
       
    ;;Связываем сокет с адресом
    
    mov rax, 49              ; SYS_BIND
    mov rdi, r9              ; дескриптор сервера
    mov rsi, addrstr        ; sockaddr_in struct
    mov rdx, addrlen         ; length of sockaddr_in
    syscall

    ;; Проверяем успешность вызова
    cmp        rax, 0
    jl         _bind_error
    
    mov rsi, msg_2
    call print_str
    
    ;;Запускаем прослушивание сокета
    mov rax, 50 ;sys_listen
    mov rdi, r9 ;дескриптор
    mov rsi, 10  ; количество клиентов
    syscall
    cmp rax, 0
    jl  _bind_error

    mov rsi, [cards_scores_players_current]
    mov BYTE [rsi+984], 0
    mov BYTE [rsi+992], 0
    mov BYTE [rsi+1000], 0
    mov BYTE [rsi+1008], 0
    mov BYTE [rsi+1016], 0

    lock inc BYTE [rsi+992]     ; СЕМАФОР
    
    ;;Главный цикл ожидания подключений
    .main_loop:
      mov rax, 43
      mov rdi, r9
      mov rsi, 0
      mov rdx, 0
      syscall
      ;;Сохраняем дескриптор сокета клиента
      mov r12, rax
      mov rsi, msg_3
      call print_str
      
      mov rsi, [cards_scores_players_current]

      

      ; lock inc BYTE [rsi+992]     ; СЕМАФОР
      call debug_atomized
        ;     push rdi
        ; mov rdi, 5
        ; call mydelay
        ; pop rdi
      lock inc BYTE [rsi+984]     ; НЕ ПОСТАВИВШИЕ
      lock inc BYTE [rsi+1000]    ; ВСЕ СУЩЕСТВОВАВШИЕ ИГРОКИ
      lock inc BYTE [rsi+1008]    ; АКТУАЛЬНОЕ ЧИСЛО ИГРОКОВ
      lock inc BYTE [rsi+1016]    ; ЧИСЛО НЕ ЗАВЕРШИВШИХ ХОД

      
      mov rdi, other_connected 
      xor rdx, rdx
      mov dl, [rsi+1000]
      
      mov rsi, rdx
      call safe_printf

      call debug_amounts
        ;     push rdi
        ; mov rdi, 5
        ; call mydelay
        ; pop rdi
     ;;Делаем fork for read
   
     mov rax, 57
     syscall
   
     cmp rax,0
     je _read
     
     mov rax, 57
     syscall

     cmp rax,0
     je _write
      
     jmp .main_loop


     .clean_memory:
    ;; выполняем системный вызов munmap, освобождая память
    mov rdi, [cards_scores_players_current]
    mov rsi, 1024
    mov rax, 11
    syscall
    call exit
    
_bind_error:
   mov rsi, msg_1
   call print_str
   call exit
   
_read:
  mov rdi, 50
  call mydelay

      mov rax, 0 ;номер системного вызова чтения
      mov rdi, r12 ;загружаем файловый дескриптор
      mov rsi, read_buffer ;указываем, куда помещать прочитанные данные
      mov rdx, 100 ;устанавливаем количество считываемых данных
      syscall ;выполняем системный вызов read

      ;;Если клиент ничего не прислал, продолжаем
 

      cmp rax, 0
      je _read    

      cmp BYTE [read_buffer], '$'
      jne .nobet

        mov rsi, [bets]
        xor rdx, rdx
        mov dl, [read_buffer+1]
        mov dh, [read_buffer+2]
        
        mov WORD [rsi+r12*2], dx
        mov rdi, other_bets_msg   ;строка для вводаx
        mov rsi, r12
    
        call safe_printf  
        mov rsi, [cards_scores_players_current]
        lock dec BYTE [rsi+984]

        call debug_amounts

        mov rsi, [cards_scores_players_current]
        cmp BYTE [rsi+984],0 
        jne .nostart
        

        .nostart:

        jmp _read
        
      .nobet:
    


      push rdi
        mov rdi, 50
        call mydelay
        pop rdi

      call debug_amounts
    
      ; mov rsi, [cards_scores_players_current]
      ; mov rbx, read_buffer

      ;; ПРОВЕРКА НА ВЗЯТИЕ КАРТЫ
      cmp BYTE [read_buffer], '!'
      jne .nocard

        xor rbx, rbx
        mov rdi, [message_to_all]
        mov rax, r12
        mov BYTE [rdi+0], al         ; кто взял
        mov BYTE  [rdi+1], '!'       ; взял!
        mov BYTE al, [read_buffer+1] 
        mov BYTE [rdi+2], al         ; сколько 
        mov rbx, r12
        mov rsi, [cards_scores_players_current]
        add rsi, rbx
        mov al, [rdi+2]
        add BYTE [rsi], al
        mov BYTE al, [rsi]
        mov BYTE [rdi+3], al        ; баланс взявшего 
        mov BYTE [rdi+4], 0          ; терминатор


        ; mov rdi, other_takes_msg   ;строка для ввода
        xor rsi, rsi
        xor rdx, rdx
        xor rcx, rcx

        mov BYTE sil, [rdi+0]
        mov BYTE dl, [rdi+2]
        mov BYTE cl, [rdi+3] ; сложим выпавшую карточку в rdx
        mov rdi, other_takes_msg
        call safe_printf  ; нам нужна строка в rdi, id в rsi, карточка в rdx, баланс в rcx
        
        ; mov rdi, 50

                 mov rsi, [cards_scores_players_current]
      mov rcx, [rsi+1008]
      mov rsi, DBG_start_sem_loop
      call print_str
      .semloop1:
          mov rsi, [cards_scores_players_current]
          lock inc BYTE [rsi+992]
      loop .semloop1
      mov rsi, DBG_end_sem_loop
      call print_str
      call debug_atomized
        
        jmp _read

        
        
      .nocard:


      ;; ПРОВЕРКА НА ОСТАНОВКУ
      cmp BYTE [read_buffer], '#'
      jne .nostop

        ; mov rdi, other_stop_msg   ;строка для ввода
        ; mov rsi, [cards_scores_players_current]
        ;  mov rbx, r12
        ; mov rdx, [rsi+rbx]
        ; mov rsi, r12
        ; call safe_printf  


        mov rdi, [message_to_all]
        mov rax, r12

        mov BYTE [rdi+0], al         ; кто остановился
        mov BYTE  [rdi+1], '#'       ; остановился!
        mov rbx, r12
        mov rsi, [cards_scores_players_current]
        mov rax, [rsi+rbx]
        mov BYTE [rdi+2], al        ; баланс остановившегося
        mov BYTE [rdi+3], 0          ; терминатор


        xor rsi, rsi
        xor rdx, rdx

        mov BYTE sil, [rdi+0]
        mov BYTE dl, [rdi+2]
        mov rdi, other_stop_msg
        call safe_printf

        ;;работает до этого момента!
        mov rsi, [cards_scores_players_current]
        lock dec BYTE [rsi+1016]    ; ЧИСЛО НЕ ЗАВЕРШИВШИХ ХОД
        
        mov rdi, 20000
        call mydelay
        call debug_amounts


        mov rsi, [cards_scores_players_current]
        mov al, 0
        cmp BYTE [rsi+1016], al
        jne .notend

             mov rsi, [cards_scores_players_current]
      mov rcx, [rsi+1008]
      mov rsi, DBG_start_sem_loop
      call print_str
      .semloop66:
          mov rsi, [cards_scores_players_current]
          lock inc BYTE [rsi+992]
      loop .semloop66
      mov rsi, DBG_end_sem_loop

        call game_over
        jmp _read
        .notend:


           mov rsi, [cards_scores_players_current]
      mov rcx, [rsi+1008]
      mov rsi, DBG_start_sem_loop
      call print_str
      .semloop2:
          mov rsi, [cards_scores_players_current]
          lock inc BYTE [rsi+992]
      loop .semloop2
      mov rsi, DBG_end_sem_loop
      call print_str
      call debug_atomized
        jmp _read

      .nostop:
      



      mov rsi, read_buffer
      call print_str
      call new_line
      mov rsi, DBG_start_copy
      call print_str

    mov rsi, [message_to_all]
    mov rcx, 64

    .copy_after_msg:
        ; mov BYTE [rsi+rcx], 0
        mov BYTE bl, [read_buffer+rcx]
        mov BYTE [rsi+rcx+1], bl
        dec rcx
        cmp rcx, -1
        jne .copy_after_msg

    xor rax, rax
    mov rbx, r12
    mov al, bl
    ; mov rsi, temp
    ; call number_str
    ; call print_str

    mov rsi, [message_to_all]
    mov BYTE [rsi], al

       mov rsi, [cards_scores_players_current]
      mov rcx, [rsi+1008]
      mov rsi, DBG_start_sem_loop
      call print_str
      .semloop_free:
          mov rsi, [cards_scores_players_current]
          lock inc BYTE [rsi+992]
      loop .semloop_free
      mov rsi, DBG_end_sem_loop
      call print_str
      call debug_atomized
          ; mov rax, 1
          ; mov rdi, r12
          ; mov rsi, [message_to_all]
          ; mov rdx, 64
          ; syscall



jmp _read

_write:
  ; mov rsi, message_to_all
  ; call print_str
   

    mov rsi, [message_to_all]
    cmp BYTE [rsi], 0
    je _write

    push rsi
    mov rsi, some_write
    call print_str
    pop rsi

    mov rax, r12
    mov rbx, 10000
    xor rdx, rdx
    mul rbx
    mov rdi, rax
    call mydelay

    mov rsi, [cards_scores_players_current]
    mov al, 1
    lock cmpxchg BYTE [rsi+992], al
    je .empty


    mov rsi, DBG_reduce_sem
    call print_str
    call new_line

    mov rsi, [cards_scores_players_current]
    lock dec BYTE [rsi+992]

 

    call debug_atomized
    push rdi
    mov rdi, 5
    call mydelay
    pop rdi



    mov rdi, user_caused
    mov rsi, r12
    call safe_printf

  xor rax, rax
  xor rbx, rbx
  mov rbx, r12
  mov al, bl
  mov rsi, [message_to_all]
    cmp BYTE [rsi], al
  je _write
  .notcopy:




    mov rax, 1
    mov rdi, r12
    mov rsi, [message_to_all]
    mov rdx, 64
    syscall
jmp _write
    .empty:
    mov rsi, [message_to_all]
    mov rcx, 64
    .clear_after_lock:
        mov BYTE [rsi+rcx], 0
        dec rcx
        cmp rcx, -1
        jne .clear_after_lock
    mov rsi, DBG_message_cleared
    call print_str

jmp _write


game_over:
call new_line
call new_line
call debug_atomized

   push rcx
          push rdi
      mov rdi, 1000000
      
      call mydelay
      pop rdi
      pop rcx

  mov BYTE [dealer_score], 16
  mov BYTE [dealer_score+1], 0 ;WINNERS AMOUNT

  

  mov rsi, endgame_msg
  call print_str
  ; mov WORD [dealer_score], 0
  mov rsi, [cards_scores_players_current]
  mov rcx, 63
  .game_over_loop:
  push rcx
  mov rsi, [cards_scores_players_current]
    mov BYTE al, [rsi+rcx]
    cmp al, 21
    jg .zero
    cmp al, 1
    jl .zero

    cmp BYTE al,[dealer_score]
    jl .zero

    cmp BYTE al,[dealer_score]
    je .zero  ;; после добавить ничью

    mov rdi, [message_to_all]
    add rdi, 1
    
    mov BYTE [rdi+1], '^'
    mov rax, rcx
    mov BYTE [rdi], al
    mov rax, [rsi+rcx]
    mov BYTE [rdi+2], al
    mov BYTE [rdi+3], 0
    lock inc BYTE [dealer_score+1]

    mov r10, 6
    .allloop:

;  cmp BYTE r10l, cl
;   jne .notcopy
;    mov rsi, [message_to_all]
;     add rsi, 1
;     mov BYTE [rsi], 'S'

  ; .notcopy:




    mov rax, 1
    mov rdi, r10
    mov rsi, [message_to_all]
    add rsi, 1
    mov rdx, 64
    push rcx
    syscall
    pop rcx

    mov rsi, [cards_scores_players_current]
    mov BYTE al, [rsi+rcx]
    
    mov rdi, [message_to_all]
    add rdi, 1
    
    mov BYTE [rdi+1], '^'
    mov rax, rcx
    mov BYTE [rdi], al
    mov rax, [rsi+rcx]
    mov BYTE [rdi+2], al
    mov BYTE [rdi+3], 0

      push rcx
    push r10
    push rax
    mov rdi, 1000000
    call mydelay
       pop rax
    pop r10
    pop rcx



   
    push rcx
    push r10
    push rax
     mov rdi, sent_win_request
    mov rsi, r10
    mov rdx, rcx

    call safe_printf
    pop rax
    pop r10
    pop rcx

    dec r10
    cmp r10, 3
    jne .allloop

    ; push rcx
    ;   mov rdi, 100
    ;   call mydelay
    ;   pop rcx
  mov rdi, win_msg
  
  xor rdx, rdx
  mov rsi, [cards_scores_players_current]
  mov dl, BYTE [rsi+rcx]
  mov rsi, rcx


  push rcx
  call safe_printf
  mov rsi, win_msg
  call print_str
  pop rcx

    
    .zero:
    mov rsi, [cards_scores_players_current]
    pop rcx
    mov BYTE [rsi+rcx], 0   
    mov rdi, DBG_rcx
    mov rsi, rcx
    push rcx
    call safe_printf 
    pop rcx
    dec rcx
    cmp rcx, -1
    jne .game_over_loop


  mov rsi, [cards_scores_players_current]
  mov al, BYTE [rsi+1008]    ; АКТУАЛЬНОЕ ЧИСЛО ИГРОКОВ
  mov  BYTE [rsi+1016], al
  mov rsi, results_msg
  call print_str 

  call debug_amounts

 

  mov BYTE dl, [dealer_score+1] ; ЕСЛИ ПОБЕДИТЕЛЕЙ 0
  cmp dl, 0
  je .no_winners_over

  
  jmp .over_over

  .no_winners_over:
  mov rdi, nowin
  call safe_printf


    .over_over:
        push rdi
        mov rdi, 5
        call mydelay
        pop rdi





mov rsi, results_msg
  call print_str 


  mov rsi, [message_to_all]
    
    mov BYTE [rsi], 99
    mov BYTE [rsi+1], '@'
    mov BYTE [rsi+2], 0

   mov rsi, [cards_scores_players_current]
      mov rcx, [rsi+1008]
      mov rsi, DBG_start_sem_loop
      call print_str
      .semloop_free:
          mov rsi, [cards_scores_players_current]
          lock inc BYTE [rsi+992]
      loop .semloop_free
      mov rsi, DBG_end_sem_loop
      call print_str
    ; mov r10, 10
    ; .allloop2:
    ; push r10

    ;   mov rsi, [message_to_all]
    ; add rsi, 1
    ; mov rax, r10
    ; mov BYTE [rsi], 99
    ; mov BYTE [rsi+1], '@'
    ; mov BYTE [rsi+2], 0

    ; mov rax, 1
    ; mov rdi, r10
    ; mov rsi, [message_to_all]
    ; add rsi, 1
    ; mov rdx, 64
    ; push rcx;
    ; syscall
    ; pop rcx

    ; mov rdi, sent_at_req
    ; mov rsi, r10

    ; push rcx
    ; push r10
    ; call safe_printf
    ; pop r10
    ; pop rcx

    ; mov rdi, 500000
    ; call mydelay
    ; pop r10
    ; dec r10
    ; cmp r10, 3
    ; jne .allloop2


    mov rsi, [cards_scores_players_current]
    mov BYTE al, [rsi+1008]
    mov BYTE [rsi+984], al

    call debug_amounts
   
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





debug_semop:
    ; Сохраняем регистры
    push rdi
    push rsi
    push rdx
    
    ; Выводим отладочное сообщение
    mov rsi, debug_sem_msg
    call print_str
    
        mov rdi, [ids]  ; Дескриптор семафора
    mov rsi, 0      ; Индекс семафора
    mov rdx, 12     ; Команда GETVAL
    xor r10, r10    ; Четвертый аргумент не используется
    mov rax, 66     ; Системный вызов semctl
    syscall
    mov rsi, temp
    call number_str
    call print_str
    call new_line
    
    ; Восстанавливаем регистры
    pop rdx
    pop rsi
    pop rdi
    
    ret

debug_atomized:
    ; Сохраняем регистры
    push rdi
    push rsi
    push rdx
    
    ; Выводим отладочное сообщение
    mov rsi, debug_atomized_msg
    call print_str
    mov rsi, [cards_scores_players_current]
    mov BYTE al, [rsi+992]

    mov rsi, temp
    call number_str
    call print_str
    call new_line
    
    ; Восстанавливаем регистры
    pop rdx
    pop rsi
    pop rdi
    
    ret


debug_amounts:
  push rax
  push rsi
  push rdx
  push rcx
  push rbx
  push rdi
  push r8
 
  mov rbx, [cards_scores_players_current]
  mov rsi, [rbx+1000]
  mov rdx, [rbx+1008]
  mov rcx, [rbx+1016]
  mov r8, [rbx+984]
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