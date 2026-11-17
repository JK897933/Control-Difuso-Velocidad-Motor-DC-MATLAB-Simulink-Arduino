# ============================================================================
#  DETECTAR PUERTO COM (USB) Y SUBIR PROGRAMA - Arduino UNO / ESP32 DevKit
#  Uso:
#    powershell -ExecutionPolicy Bypass -File detectar_y_subir.ps1            (menu)
#    powershell -ExecutionPolicy Bypass -File detectar_y_subir.ps1 -Tarjeta uno
#    powershell -ExecutionPolicy Bypass -File detectar_y_subir.ps1 -Tarjeta esp32
#    powershell -ExecutionPolicy Bypass -File detectar_y_subir.ps1 -SoloListar
# ============================================================================
param(
    [ValidateSet("uno", "esp32", "")]
    [string]$Tarjeta = "",
    [string]$Puerto = "",
    [switch]$SoloListar
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# --- 1. Asegurar arduino-cli ---
if (-not (Get-Command arduino-cli -ErrorAction SilentlyContinue)) {
    if (Test-Path "C:\Program Files\Arduino CLI\arduino-cli.exe") {
        $env:Path += ";C:\Program Files\Arduino CLI"
    } else {
        Write-Host "Instalando Arduino CLI con winget..." -ForegroundColor Yellow
        winget install -e --id ArduinoSA.CLI --accept-source-agreements --accept-package-agreements
        $env:Path += ";C:\Program Files\Arduino CLI"
    }
}

# --- 2. Listar puertos COM USB reales (excluye Bluetooth) ---
function Get-PuertosUSB {
    Get-CimInstance Win32_PnPEntity |
        Where-Object { $_.Name -match "\((COM\d+)\)" -and $_.DeviceID -notmatch "^BTHENUM" } |
        ForEach-Object {
            $null = $_.Name -match "\((COM\d+)\)"
            $tipo = "Desconocido"
            if ($_.Name -match "Arduino")            { $tipo = "Arduino UNO (original)" }
            elseif ($_.Name -match "CH340|CH341")    { $tipo = "Clon Arduino UNO / ESP32 (CH340)" }
            elseif ($_.Name -match "CP210")          { $tipo = "ESP32 DevKit (CP210x)" }
            elseif ($_.Name -match "FTDI|FT232")     { $tipo = "FTDI USB-Serial" }
            elseif ($_.DeviceID -match "VID_2341|VID_2A03") { $tipo = "Arduino UNO (original)" }
            [PSCustomObject]@{ Puerto = $Matches[1]; Tipo = $tipo; Nombre = $_.Name; Estado = $_.Status }
        }
}

Write-Host "`n=== PUERTOS COM USB DETECTADOS ===" -ForegroundColor Cyan
$puertos = @(Get-PuertosUSB)

# Dispositivos USB sin driver (CH340/CP210x sin instalar)
$sinDriver = Get-CimInstance Win32_PnPEntity | Where-Object {
    $_.Status -ne "OK" -and $_.DeviceID -match "VID_1A86|VID_10C4|VID_2341|VID_0403"
}

if ($puertos.Count -eq 0) {
    Write-Host "No hay ningun Arduino/ESP32 conectado por USB." -ForegroundColor Red
    Write-Host "(Los COM Bluetooth se ignoran.)"
    if ($sinDriver) {
        Write-Host "`nSe detecto una placa SIN DRIVER:" -ForegroundColor Yellow
        $sinDriver | ForEach-Object { Write-Host "  - $($_.Name)  [$($_.DeviceID)]" }
        Write-Host "  VID_1A86 = CH340 -> instala: https://www.wch-ic.com/downloads/CH341SER_EXE.html"
        Write-Host "  VID_10C4 = CP210x -> instala: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers"
    }
    Write-Host "`nRevisa: 1) cable USB de DATOS (no solo de carga), 2) otro puerto USB, 3) driver CH340/CP210x."
    exit 1
}

$puertos | Format-Table Puerto, Tipo, Nombre, Estado -AutoSize
if ($SoloListar) { exit 0 }

# --- 3. Elegir puerto ---
if (-not $Puerto) {
    if ($puertos.Count -eq 1) { $Puerto = $puertos[0].Puerto }
    else { $Puerto = Read-Host "Escribe el puerto a usar (ej. COM5)" }
}
Write-Host "Puerto seleccionado: $Puerto" -ForegroundColor Green

# --- 4. Elegir tarjeta ---
if (-not $Tarjeta) {
    $sug = ($puertos | Where-Object Puerto -eq $Puerto).Tipo
    Write-Host "Tipo detectado: $sug"
    $op = Read-Host "Tarjeta: [1] Arduino UNO (5V)   [2] ESP32 DevKit (3.3V)"
    $Tarjeta = if ($op -eq "2") { "esp32" } else { "uno" }
}

# --- 5. Compilar y subir ---
if ($Tarjeta -eq "uno") {
    $fqbn = "arduino:avr:uno"
    $sketch = Join-Path $root "1_Tarjeta_Arduino_UNO_5V\Arduino_Control_Difuso_MotorDC"
    if (-not (Test-Path $sketch)) { $sketch = Join-Path $root "Arduino_Control_Difuso_MotorDC" }
    arduino-cli core install arduino:avr | Out-Null
} else {
    $fqbn = "esp32:esp32:esp32"
    $sketch = Join-Path $root "2_Tarjeta_ESP32_DevKit_3V3\ESP32_Control_Difuso_MotorDC"
    arduino-cli config init 2>$null | Out-Null
    arduino-cli config add board_manager.additional_urls https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json 2>$null
    arduino-cli core update-index | Out-Null
    arduino-cli core install esp32:esp32
}

Write-Host "`n=== COMPILANDO ($fqbn) ===" -ForegroundColor Cyan
arduino-cli compile --fqbn $fqbn "$sketch"
if ($LASTEXITCODE -ne 0) { Write-Host "Error de compilacion." -ForegroundColor Red; exit 1 }

Write-Host "`n=== SUBIENDO A $Puerto ===" -ForegroundColor Cyan
if ($Tarjeta -eq "esp32") { Write-Host "(Si se queda en 'Connecting...', manten presionado el boton BOOT de la ESP32)" -ForegroundColor Yellow }
arduino-cli upload -p $Puerto --fqbn $fqbn "$sketch"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Fallo la subida. Cierra Monitor Serie / MATLAB que esten usando $Puerto e intenta de nuevo." -ForegroundColor Red
    exit 1
}

Write-Host "`n PROGRAMA SUBIDO CORRECTAMENTE A $Puerto" -ForegroundColor Green
Write-Host "Para ver los datos: arduino-cli monitor -p $Puerto -c baudrate=115200"
Write-Host "O en MATLAB: conectar_arduino_matlab_fuzzy (UNO)  /  conectar_esp32_matlab_fuzzy (ESP32)"
