; boot.asm - Простейший загрузчик
[bits 16]
[org 0x7C00]

start:
    ; Настройка сегментов
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    ; Сохраняем номер диска
    mov [drive_number], dl

    ; Очистка экрана
    mov ax, 0x0003
    int 0x10

    ; Вывод сообщения
    mov si, msg_loading
    call print_string
    
    ; Загрузка ядра (32 сектора = 16 КБ)
    mov bx, 0x1000
    mov es, bx
    xor bx, bx
    
    mov ah, 0x02     ; Функция чтения диска
    mov al, 32       ; Количество секторов
    mov ch, 0        ; Цилиндр
    mov cl, 2        ; Сектор (начинается с 1)
    mov dh, 0        ; Головка
    mov dl, [drive_number]
    
    int 0x13
    jc disk_error
    
    ; Переход к ядру
    jmp 0x1000:0x0000

disk_error:
    mov si, error_msg
    call print_string
    jmp $

print_string:
    mov ah, 0x0E
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret

msg_loading db "Loading Neox OS...", 0x0D, 0x0A, 0
error_msg db "Disk error!", 0x0D, 0x0A, 0
drive_number db 0

; Заполнение до 512 байт и сигнатура загрузчика
times 510 - ($-$$) db 0
dw 0xAA55