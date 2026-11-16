@echo off
chcp 65001 >nul
title Compilador y Flasher ESP-IDF + Lanzador MATLAB R2023a (ESP32 DevKit 3.3V)
color 0B

echo ========================================================================================
echo   TARJETA 2: ESP32 DEVKIT V1 (3.3V) - PROYECTO OFICIAL ESP-IDF (C NATIVO + FreeRTOS)
echo   Compila con idf.py build, flashea al ESP32 y abre MATLAB R2023a / Simulink
echo ========================================================================================
echo.

cd /d "%~dp0"

echo [PASO 1/3] Buscando entorno ESP-IDF instalado en la PC...
set "IDF_EXPORT="
for /d %%d in ("C:\Espressif\frameworks\esp-idf-*") do (
    if exist "%%d\export.bat" set "IDF_EXPORT=%%d\export.bat"
)
if "%IDF_EXPORT%"=="" (
    if exist "%USERPROFILE%\esp\esp-idf\export.bat" set "IDF_EXPORT=%USERPROFILE%\esp\esp-idf\export.bat"
)
if "%IDF_EXPORT%"=="" (
    if exist "C:\esp\esp-idf\export.bat" set "IDF_EXPORT=C:\esp\esp-idf\export.bat"
)

if not "%IDF_EXPORT%"=="" (
    echo   - Entorno ESP-IDF encontrado en: "%IDF_EXPORT%"
    call "%IDF_EXPORT%"
    cd /d "%~dp0ESP32_ESP_IDF_Control_Difuso"
    echo.
    echo [PASO 2/3] Compilando proyecto ESP-IDF (main/main.c) para target esp32...
    call idf.py set-target esp32
    call idf.py build
    echo.
    echo   - Si tu ESP32 DevKit esta conectado por USB, flasheando automaticamente...
    for /f "tokens=1" %%p in ('mode ^| findstr /i "COM"') do (
        echo   - Intentando flashear con idf.py -p %%p flash ...
    )
    call idf.py flash
    cd /d "%~dp0"
) else (
    echo [AVISO] No se detecto C:\Espressif\frameworks\esp-idf en la ruta por defecto.
    echo         Si usas "ESP-IDF CMD" o la extension de VS Code ESP-IDF, entra a:
    echo           cd 2_Tarjeta_ESP32_DevKit_3V3\ESP32_ESP_IDF_Control_Difuso
    echo           idf.py set-target esp32
    echo           idf.py build
    echo           idf.py -p COMx flash
)

echo.
echo [PASO 3/3] Abriendo MATLAB (priorizando R2023a) con los 3 modelos de Simulink...
set "MATLAB_EXE="
if exist "C:\Program Files\MATLAB\R2023a\bin\matlab.exe" (
    set "MATLAB_EXE=C:\Program Files\MATLAB\R2023a\bin\matlab.exe"
)
if "%MATLAB_EXE%"=="" (
    for /f "delims=" %%i in ('where matlab 2^>nul') do set "MATLAB_EXE=%%i"
)
if "%MATLAB_EXE%"=="" (
    for /d %%d in ("C:\Program Files\MATLAB\R*") do (
        if exist "%%d\bin\matlab.exe" set "MATLAB_EXE=%%d\bin\matlab.exe"
    )
)

if "%MATLAB_EXE%"=="" (
    echo [AVISO] Abre MATLAB manualmente y corre: iniciar_todo_matlab_esp32
) else (
    "%MATLAB_EXE%" -sd "%~dp0" -r "run('iniciar_todo_matlab_esp32.m')"
)

echo.
echo ========================================================================================
echo   PROCESO ESP-IDF + MATLAB R2023a COMPLETADO.
echo ========================================================================================
pause
