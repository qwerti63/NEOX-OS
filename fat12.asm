; fat12.asm - Поддержка файловой системы FAT12
[bits 16]

; Структура BPB (должна совпадать с загрузчиком)
bpb_oem:            db 'NEOX OS '   ; 8 bytes
bpb_bytes_per_sector:   dw 512
bpb_sectors_per_cluster: db 1
bpb_reserved_sectors:   dw 1
bpb_fat_count:      db 2
bpb_dir_entries_count: dw 224
bpb_total_sectors:  dw 2880
bpb_media_descriptor_type: db 0xF0
bpb_sectors_per_fat:    dw 9
bpb_sectors_per_track:  dw 18
bpb_heads_count:    dw 2
bpb_hidden_sectors: dd 0
bpb_large_sector_count: dd 0

; Данные
fat_buffer equ 0x3000  ; Буфер для FAT (0x1000:0x3000)
root_dir_buffer equ 0x4000 ; Буфер для корневого каталога (0x1000:0x4000)

; Инициализация файловой системы
init_fat12:
    ; Вычисляем LBA корневого каталога
    ; = reserved_sectors + (fat_count * sectors_per_fat)
    mov ax, [bpb_sectors_per_fat]
    mov bl, [bpb_fat_count]
    xor bh, bh
    mul bx
    add ax, [bpb_reserved_sectors]
    mov [root_dir_lba], ax
    
    ; Вычисляем размер корневого каталога в секторах
    mov ax, [bpb_dir_entries_count]
    shl ax, 5                      ; Умножаем на 32 (размер записи)
    xor dx, dx
    div word [bpb_bytes_per_sector]
    mov [root_dir_sectors], ax
    
    ; Вычисляем LBA области данных
    add ax, [root_dir_lba]
    mov [data_sector_lba], ax
    
    ; Загружаем корневой каталог
    mov ax, [root_dir_lba]
    mov cx, [root_dir_sectors]
    mov bx, root_dir_buffer
    call read_sectors
    
    ; Загружаем FAT
    mov ax, [bpb_reserved_sectors]
    mov cx, [bpb_sectors_per_fat]
    mov bx, fat_buffer
    call read_sectors
    
    ret

; Чтение секторов
; AX = LBA, CX = количество секторов, BX = смещение буфера
read_sectors:
    pusha
    mov [lba_sector], ax
    mov [sectors_to_read], cx
    mov [buffer_offset], bx

.read_loop:
    ; Преобразование LBA в CHS
    mov ax, [lba_sector]
    xor dx, dx
    div word [bpb_sectors_per_track]
    mov cl, dl
    inc cl                      ; Сектора начинаются с 1
    
    xor dx, dx
    div word [bpb_heads_count]
    mov dh, dl                  ; Номер головки
    mov ch, al                  ; Номер цилиндра
    
    ; Чтение сектора
    mov ah, 0x02
    mov al, 1
    mov dl, 0                   ; Диск A:
    mov bx, [buffer_offset]
    int 0x13
    jc .error
    
    ; Увеличиваем LBA и смещение буфера
    inc word [lba_sector]
    add word [buffer_offset], 512
    dec word [sectors_to_read]
    jnz .read_loop
    
    popa
    ret

.error:
    mov si, disk_error_msg
    call print_string
    jmp $

; Поиск файла в корневом каталоге
; DS:SI = имя файла (11 символов, 8.3 формат)
; Возвращает: AX = начальный кластер, CF = 1 если не найден
find_file:
    push es
    push di
    push cx
    
    mov cx, [bpb_dir_entries_count]
    mov di, root_dir_buffer
    
.search_loop:
    push cx
    push si
    push di
    
    mov cx, 11
    repe cmpsb
    je .found
    
    pop di
    pop si
    pop cx
    add di, 32
    loop .search_loop
    
    ; Файл не найден
    stc
    pop cx
    pop di
    pop es
    ret

.found:
    pop di
    pop si
    pop cx
    mov ax, [di + 26]           ; Начальный кластер
    clc
    pop cx
    pop di
    pop es
    ret

; Загрузка файла
; AX = начальный кластер, ES:BX = буфер
load_file:
    pusha
    mov [current_cluster], ax
    mov [buffer_segment], es
    mov [buffer_offset], bx

.load_loop:
    ; Читаем кластер
    mov ax, [current_cluster]
    call cluster_to_lba
    mov cx, 1
    mov bx, [buffer_offset]
    call read_sectors
    
    ; Добавляем 512 байт к буферу
    add word [buffer_offset], 512
    
    ; Получаем следующий кластер из FAT
    mov ax, [current_cluster]
    call get_next_cluster
    cmp ax, 0x0FF8              ; Конец файла?
    jae .done
    
    mov [current_cluster], ax
    jmp .load_loop

.done:
    popa
    ret

; Преобразование кластера в LBA
; AX = номер кластера
cluster_to_lba:
    sub ax, 2
    xor ch, ch
    mov cl, [bpb_sectors_per_cluster]
    mul cx
    add ax, [data_sector_lba]
    ret

; Получение следующего кластера из FAT
; AX = текущий кластер
get_next_cluster:
    push bx
    push es
    
    ; Вычисляем смещение в FAT
    mov bx, ax
    shr bx, 1                   ; cluster / 2
    add bx, ax                  ; cluster * 1.5
    
    mov ax, [fat_buffer + bx]   ; Читаем значение из FAT
    
    test word [current_cluster], 1
    jnz .odd_cluster
    
    ; Четный кластер
    and ax, 0x0FFF
    jmp .done
    
.odd_cluster:
    ; Нечетный кластер
    shr ax, 4
    
.done:
    pop es
    pop bx
    ret

; Данные
lba_sector dw 0
sectors_to_read dw 0
buffer_offset dw 0
buffer_segment dw 0
current_cluster dw 0
root_dir_lba dw 0
root_dir_sectors dw 0
data_sector_lba dw 0

disk_error_msg db "Disk error!", 0x0D, 0x0A, 0