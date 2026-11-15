@echo off
chcp 65001 >nul
title Instalador y Lanzador Automatico - Control Difuso Motor DC (MATLAB + Simulink + Arduino UNO)
color 0A

echo ========================================================================================
echo   ACTIVIDAD 2: CONTROL DIFUSO DE VELOCIDAD DE UN MOTOR DE CD CON ENCODER (UPA - MTR09C)
echo   Instalador de Librerias, Compilador de Arduino UNO y Lanzador de MATLAB/Simulink
echo ========================================================================================
echo.

cd /d "%~dp0"

echo [PASO 1/4] Verificando Arduino CLI para compilar y subir el codigo sin abrir Arduino IDE...
where arduino-cli >nul 2>nul
if %errorlevel% neq 0 (
    if exist "C:\Program Files\Arduino CLI\arduino-cli.exe" (
        set "PATH=%PATH%;C:\Program Files\Arduino CLI"
    ) else (
        echo   - Instalando Arduino CLI automaticamente mediante winget...
        winget install -e --id ArduinoSA.CLI --accept-source-agreements --accept-package-agreements
        set "PATH=%PATH%;C:\Program Files\Arduino CLI"
    )
)

echo.
echo [PASO 2/4] Instalando nucleo Arduino UNO (arduino:avr) y librerias por CMD...
arduino-cli core update-index
arduino-cli core install arduino:avr
arduino-cli lib install "Encoder" "PID" "QuickPID"

echo.
echo [PASO 3/4] Compilando sketch Arduino_Control_Difuso_MotorDC.ino...
arduino-cli compile --fqbn arduino:avr:uno --output-dir "%~dp0Arduino_Control_Difuso_MotorDC\build" "%~dp0Arduino_Control_Difuso_MotorDC\Arduino_Control_Difuso_MotorDC.ino"

echo.
echo [Detectando si hay un Arduino UNO conectado por USB para subir el programa automaticamente...]
for /f "tokens=1" %%p in ('arduino-cli board list ^| findstr /i "COM"') do (
    echo   - Arduino detectado en el puerto %%p. Subiendo firmware...
    arduino-cli upload -p %%p --fqbn arduino:avr:uno --input-dir "%~dp0Arduino_Control_Difuso_MotorDC\build"
)

echo.
echo [PASO 4/4] Buscando MATLAB e iniciando las simulaciones de Fuzzy y los 3 modelos de Simulink...
set "MATLAB_EXE="
for /f "delims=" %%i in ('where matlab 2^>nul') do set "MATLAB_EXE=%%i"
if "%MATLAB_EXE%"=="" (
    for /d %%d in ("C:\Program Files\MATLAB\R*") do (
        if exist "%%d\bin\matlab.exe" set "MATLAB_EXE=%%d\bin\matlab.exe"
    )
)

if "%MATLAB_EXE%"=="" (
    echo [AVISO] No se encontro matlab.exe en la ruta estandar. Abre MATLAB manualmente y corre:
    echo         iniciar_todo_matlab_arduino
) else (
    echo   - MATLAB encontrado en: "%MATLAB_EXE%"
    echo   - Abriendo MATLAB con el proyecto cargado...
    "%MATLAB_EXE%" -sd "%~dp0" -r "run('iniciar_todo_matlab_arduino.m')"
)

echo.
echo ========================================================================================
echo   PROCESO COMPLETADO.
echo ========================================================================================
pause
