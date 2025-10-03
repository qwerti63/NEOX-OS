# compile.ps1 - Упрощенная компиляция без внешних утилит
Write-Host "Компиляция Neox OS..." -ForegroundColor Green

# Компиляция загрузчика
Write-Host "Компиляция загрузчика..."
nasm -f bin boot.asm -o boot.bin
if ($LASTEXITCODE -ne 0) {
    Write-Host "Ошибка компиляции загрузчика!" -ForegroundColor Red
    exit 1
}

# Компиляция ядра
Write-Host "Компиляция ядра..."
nasm -f bin kernel.asm -o kernel.bin
if ($LASTEXITCODE -ne 0) {
    Write-Host "Ошибка компиляции ядра!" -ForegroundColor Red
    exit 1
}

# Создание образа дискеты
Write-Host "Создание образа дискеты..."
$image = New-Object byte[] 1474560 # 1.44MB

# 1. Копируем загрузчик в первый сектор
$bootBytes = [System.IO.File]::ReadAllBytes("boot.bin")
[Array]::Copy($bootBytes, 0, $image, 0, $bootBytes.Length)

# 2. Копируем ядро после загрузчика (со второго сектора)
$kernelBytes = [System.IO.File]::ReadAllBytes("kernel.bin")
[Array]::Copy($kernelBytes, 0, $image, 512, $kernelBytes.Length)

# 3. Создаем простую структуру FAT12 вручную
# Загрузочная запись (BPB) - уже есть в загрузчике

# 4. Создаем корневой каталог (примерно с 19-го сектора)
$rootDirOffset = 19 * 512

# Создаем запись для KERNEL.BIN
$kernelEntry = New-Object byte[] 32
[Text.Encoding]::ASCII.GetBytes("KERNEL  BIN").CopyTo($kernelEntry, 0) # Имя файла
$kernelEntry[11] = 0x20 # Атрибуты (архивный)
[BitConverter]::GetBytes([UInt16]2).CopyTo($kernelEntry, 26) # Начальный кластер
[BitConverter]::GetBytes([UInt32]$kernelBytes.Length).CopyTo($kernelEntry, 28) # Размер файла

# Копируем запись в образ
[Array]::Copy($kernelEntry, 0, $image, $rootDirOffset, 32)

# 5. Создаем простую FAT-таблицу (с 1-го сектора)
# Первые 2 байта FAT - media descriptor и EOF marker
$image[512] = 0xF0
$image[513] = 0xFF
$image[514] = 0xFF
# Второй кластер (файл) помечаем как конец файла
$image[515] = 0xFF
$image[516] = 0xFF

# Сохраняем образ
[System.IO.File]::WriteAllBytes("disk.img", $image)

Write-Host "Образ disk.img успешно создан!" -ForegroundColor Green

# Запуск в QEMU
Write-Host "Запуск в QEMU..." -ForegroundColor Green
qemu-system-i386 -fda disk.img -m 16M