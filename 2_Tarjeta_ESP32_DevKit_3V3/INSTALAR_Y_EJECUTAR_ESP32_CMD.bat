@echo off
chcp 65001 >nul
title Instalador y Lanzador Automatico - TARJETA 2: ESP32 DevKit (3.3V) + MATLAB R2023a
color 0B

echo ========================================================================================
echo   TARJETA 2: ESP32 DEVKIT V1 (LOGICA 3.3V) - CONTROL DIFUSO DE VELOCIDAD MOTOR DC
echo   Instalador de Core ESP32, Compilador y Lanzador de MATLAB R2023a / Simulink
echo ========================================================================================
echo.

cd /d "%~dp0"

echo [PASO 1/4] Verificando Arduino CLI...
where arduino-cli >nul 2>nul
if %errorlevel% neq 0 (
    if exist "C:\Program Files\Arduino CLI\arduino-cli.exe" (
        set "PATH=%PATH%;C:\Program Files\Arduino CLI"
    ) else (
        echo   - Instalando Arduino CLI mediante winget...
        winget install -e --id ArduinoSA.CLI --accept-source-agreements --accept-package-agreements
        set "PATH=%PATH%;C:\Program Files\Arduino CLI"
    )
)

echo.
echo [PASO 2/4] Configurando soporte para tarjeta ESP32 DevKit (espressif:esp32)...
arduino-cli config init >nul 2>nul
arduino-cli config add board_manager.additional_urls https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
arduino-cli core update-index
arduino-cli core list | findstr /i "esp32:esp32" >nul
if %errorlevel% neq 0 (
    echo   - Instalando nucleo oficial ESP32 (esp32:esp32) por CMD...
    arduino-cli core install esp32:esp32
) else (
    echo   - [OK] Nucleo esp32:esp32 ya esta instalado.
)

echo.
echo [PASO 3/4] Compilando sketch exclusivo para ESP32 DevKit (3.3V)...
arduino-cli compile --fqbn esp32:esp32:esp32 "%~dp0ESP32_Control_Difuso_MotorDC\ESP32_Control_Difuso_MotorDC.ino"

echo.
echo [Detectando si hay un ESP32 DevKit conectado por USB para subir el programa...]
for /f "tokens=1" %%p in ('arduino-cli board list ^| findstr /i "COM"') do (
    echo   - Puerto detectado en %%p. Subiendo firmware para ESP32 DevKit...
    arduino-cli upload -p %%p --fqbn esp32:esp32:esp32 "%~dp0ESP32_Control_Difuso_MotorDC\ESP32_Control_Difuso_MotorDC.ino"
)

echo.
echo [PASO 4/4] Abriendo MATLAB (priorizando R2023a) con la configuracion de ESP32 3.3V...
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
echo   PROCESO PARA ESP32 DEVKIT (3.3V) COMPLETADO.
echo ========================================================================================
pause
