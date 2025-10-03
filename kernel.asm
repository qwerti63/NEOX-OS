; kernel.asm - Ядро Neox OS с командной оболочкой и редактором
[bits 16]
[org 0x0000]

start:
    ; Настройка сегментов
    mov ax, 0x1000
    mov ds, ax
    mov es, ax
    
    ; Настройка стека
    mov ax, 0x9000
    mov ss, ax
    mov sp, 0xFFFF

    ; Очистка экрана
    mov ax, 0x0003
    int 0x10

    ; Вывод приветствия
    mov si, welcome_msg
    call print_string

main_loop:
    ; Вывод приглашения
    mov si, prompt
    call print_string

    ; Чтение команды
    mov di, command_buffer
    call read_string

    ; Обработка команды
    call process_command
    jmp main_loop

; ================== ФУНКЦИИ ==================

; Очистка экрана
clear_screen:
    mov ax, 0x0003
    int 0x10
    ret

; Вывод строки
print_string:
    mov ah, 0x0E
.print_loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .print_loop
.done:
    ret

; Чтение строки с клавиатуры
read_string:
    xor cx, cx
.read_loop:
    ; Ожидание нажатия клавиши
    mov ah, 0x00
    int 0x16
    
    ; Проверка на Enter
    cmp al, 0x0D
    je .done
    
    ; Проверка на Backspace
    cmp al, 0x08
    je .backspace
    
    ; Проверка на максимальную длину
    cmp cx, 63
    jge .read_loop
    
    ; Сохранение символа
    stosb
    inc cx
    
    ; Вывод символа
    mov ah, 0x0E
    int 0x10
    jmp .read_loop

.backspace:
    ; Проверка на пустой буфер
    cmp cx, 0
    je .read_loop
    
    ; Удаление символа
    dec di
    dec cx
    
    ; Удаление с экрана
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    
    jmp .read_loop

.done:
    ; Завершение строки
    mov al, 0
    stosb
    
    ; Перевод строки
    call new_line
    ret

; Перевод строки
new_line:
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

; Сравнение строк
; Вход: SI = первая строка, DI = вторая строка
; Выход: ZF = 1 если равны
strcmp:
    push si
    push di
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    test al, al
    jz .equal
    inc si
    inc di
    jmp .loop
.equal:
    pop di
    pop si
    cmp al, al  ; Установить ZF
    ret
.not_equal:
    pop di
    pop si
    mov al, 1
    test al, al ; Сбросить ZF
    ret

; Вывод символа
print_char:
    mov ah, 0x0E
    int 0x10
    ret

; ================== ОБРАБОТКА КОМАНД ==================

process_command:
    ; Пропуск пробелов в начале
    mov si, command_buffer
.skip_spaces:
    lodsb
    cmp al, ' '
    je .skip_spaces
    cmp al, 0
    je .empty
    dec si
    
    ; Сохраняем начало команды
    mov bx, si
    
    ; Находим конец команды
.find_end:
    lodsb
    cmp al, ' '
    je .found_space
    cmp al, 0
    jne .find_end
.found_space:
    dec si
    mov byte [si], 0
    
    ; Восстанавливаем начало команды
    mov si, bx
    
    ; Проверка команд
    mov di, cmd_help
    call strcmp
    je .help
    
    mov di, cmd_clear
    call strcmp
    je .clear
    
    mov di, cmd_echo
    call strcmp
    je .echo
    
    mov di, cmd_reboot
    call strcmp
    je .reboot
    
    mov di, cmd_time
    call strcmp
    je .time
    
    mov di, cmd_date
    call strcmp
    je .date
    
    mov di, cmd_edit
    call strcmp
    je .edit
    
    ; Неизвестная команда
    mov si, msg_unknown
    call print_string
    ret

.help:
    mov si, msg_help
    call print_string
    ret

.clear:
    call clear_screen
    ret

.echo:
    ; Пропускаем пробелы после команды
    lodsb
    cmp al, 0
    je .echo_done
    cmp al, ' '
    jne .echo_done
    call print_string
.echo_done:
    call new_line
    ret

.reboot:
    mov si, msg_reboot
    call print_string
    ; Задержка
    mov cx, 0xFFFF
.delay:
    nop
    loop .delay
    ; Перезагрузка
    int 0x19
    ret

.time:
    mov si, msg_time
    call print_string
    ; Получение времени от BIOS
    mov ah, 0x02
    int 0x1A
    ; Вывод времени
    mov al, ch
    call print_bcd
    mov al, ':'
    call print_char
    mov al, cl
    call print_bcd
    mov al, ':'
    call print_char
    mov al, dh
    call print_bcd
    call new_line
    ret

.date:
    mov si, msg_date
    call print_string
    ; Получение даты от BIOS
    mov ah, 0x04
    int 0x1A
    ; Вывод даты
    mov al, dl
    call print_bcd
    mov al, '/'
    call print_char
    mov al, dh
    call print_bcd
    mov al, '/'
    call print_char
    mov ax, cx
    call print_bcd_word
    call new_line
    ret

.edit:
    call editor_start
    ret

.empty:
    ret

; Вывод BCD числа (байт)
print_bcd:
    push ax
    shr al, 4
    add al, '0'
    call print_char
    pop ax
    and al, 0x0F
    add al, '0'
    call print_char
    ret

; Вывод BCD числа (слово)
print_bcd_word:
    push ax
    mov al, ah
    call print_bcd
    pop ax
    call print_bcd
    ret

; ================== ТЕКСТОВЫЙ РЕДАКТОР ==================

editor_start:
    pusha
    
    ; Очистка экрана
    mov ax, 0x0003
    int 0x10

    ; Вывод приветствия
    mov si, editor_msg
    call print_string

    ; Основной цикл редактора
    mov di, text_buffer
.editor_loop:
    ; Ожидание нажатия клавиши
    mov ah, 0x00
    int 0x16
    
    ; Проверка на специальные клавиши
    cmp al, 0x1B  ; Escape
    je .exit
    cmp al, 0x0D  ; Enter
    je .new_line
    cmp al, 0x08  ; Backspace
    je .backspace
    
    ; Проверка на максимальную длину
    cmp di, text_buffer + 1024
    jge .editor_loop
    
    ; Сохранение символа
    stosb
    
    ; Вывод символа
    mov ah, 0x0E
    int 0x10
    jmp .editor_loop

.new_line:
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char
    mov al, 0
    stosb
    jmp .editor_loop

.backspace:
    cmp di, text_buffer
    je .editor_loop
    dec di
    mov byte [di], 0
    
    ; Удаление с экрана
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .editor_loop

.exit:
    ; Возврат в оболочку
    mov ax, 0x0003
    int 0x10
    popa
    ret

; ================== ДАННЫЕ ==================

welcome_msg db "Neox OS alpfa-0.3", 0x0D, 0x0A, \
               "Type 'help' for available commands", 0x0D, 0x0A, 0x0D, 0x0A, 0
prompt db "-> ", 0
msg_unknown db "Unknown command. Type 'help' for available commands.", 0x0D, 0x0A, 0
msg_help db "Available commands:", 0x0D, 0x0A, \
           "  help    - Show this help", 0x0D, 0x0A, \
           "  clear   - Clear screen", 0x0D, 0x0A, \
           "  echo    - Print text", 0x0D, 0x0A, \
           "  time    - Show current time", 0x0D, 0x0A, \
           "  date    - Show current date", 0x0D, 0x0A, \
           "  reboot  - Reboot system", 0x0D, 0x0A, \
           "  edit    - Simple text editor", 0x0D, 0x0A, 0
msg_reboot db "Rebooting system...", 0x0D, 0x0A, 0
msg_time db "Current time: ", 0
msg_date db "Current date: ", 0
editor_msg db "Simple Text Editor (Press ESC to exit)", 0x0D, 0x0A, 0

; Команды
cmd_help db "help", 0
cmd_clear db "clear", 0
cmd_echo db "echo", 0
cmd_reboot db "reboot", 0
cmd_time db "time", 0
cmd_date db "date", 0
cmd_edit db "edit", 0

; Буфер для команды
command_buffer times 64 db 0

; Буфер для текстового редактора
text_buffer times 1024 db 0

; Заполнение до 16KB
times 16384 - ($ - $$) db 0