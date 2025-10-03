@echo off
echo Компиляция Neox OS...

:: Компиляция загрузчика
echo Компиляция загрузчика...
nasm -f bin boot.asm -o boot.bin
if errorlevel 1 (
    echo Ошибка компиляции загрузчика!
    pause
    exit /b 1
)

:: Компиляция ядра
echo Компиляция ядра...
nasm -f bin kernel.asm -o kernel.bin
if errorlevel 1 (
    echo Ошибка компиляции ядра!
    pause
    exit /b 1
)

:: Создание образа дискеты
echo Создание образа дискеты...
powershell -command "$boot = [System.IO.File]::ReadAllBytes('boot.bin'); $kernel = [System.IO.File]::ReadAllBytes('kernel.bin'); $image = New-Object byte[] 1474560; [Array]::Copy($boot, 0, $image, 0, $boot.Length); [Array]::Copy($kernel, 0, $image, 512, $kernel.Length); [System.IO.File]::WriteAllBytes('disk.img', $image)"

if errorlevel 1 (
    echo Ошибка создания образа!
    pause
    exit /b 1
)

:: Запуск в QEMU
echo Запуск QEMU...
qemu-system-i386 -fda disk.img -m 16M
pause