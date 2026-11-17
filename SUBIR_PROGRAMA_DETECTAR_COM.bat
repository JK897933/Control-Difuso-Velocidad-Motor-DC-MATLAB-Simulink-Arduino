@echo off
chcp 65001 >nul
title Detectar COM y Subir Programa (Arduino UNO / ESP32)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0detectar_y_subir.ps1" %*
pause
