# TARJETA 2: Manual Exclusivo para ESP32 DevKit V1 (Lógica de 3.3 V)

Este directorio (`2_Tarjeta_ESP32_DevKit_3V3/`) contiene todo el código, adaptación de escalas (`ADC 12 bits` $\rightarrow$ `FIS 10 bits`), instalador por CMD y manual de conexión física **exclusivamente para la tarjeta ESP32 DevKit (3.3 V)**, separado de la versión de Arduino UNO (5 V).

---

## 1. Diferencias Clave y Adaptación de Escalas: ESP32 DevKit (3.3 V) vs Arduino UNO (5 V)
*(Punto 12 de la práctica: "Adaptar las escalas de ADC y PWM a la plataforma elegida")*

| Característica | Tarjeta 1: Arduino UNO (`5V`) | Tarjeta 2: ESP32 DevKit V1 (`3.3V`) |
| :--- | :--- | :--- |
| **Voltaje Lógico de Pines (GPIOs)** | **$5.0\text{ V}$** | **$3.3\text{ V}$** (**¡NO tolera 5V en sus pines!**) |
| **Alimentación del Potenciómetro ($10\text{ k}\Omega$)** | Entre `5V` y `GND` | Entre **`3V3` ($3.3\text{ V}$)** y `GND` |
| **Alimentación del Encoder (Cable Azul)** | Al pin `5V` | Al pin **`3V3` ($3.3\text{ V}$)** *(El encoder GM25-370 soporta `3.3V/5V` según tu imagen de pinout)* |
| **Resistencia Pull-Up de $47\text{ k}\Omega$ (Cable Amarillo)** | Conectada entre Fase A y `5V` | Conectada entre Fase A (`GPIO 18`) y **`3V3` ($3.3\text{ V}$)** |
| **Resolución Nativa del ADC (Potenciómetro)** | **10 bits** (`0` a `1023` para `0–5 V`) | **12 bits** (`0` a `4095` para `0–3.3 V`, aten. `11 dB`) |
| **Ecuación de Escalado al Controlador Difuso** | Directa (`1:1`) | $\text{Pot}_{10\text{bits}} = \text{round}\left(\frac{\text{ADC}_{12\text{bits}} \times 1023}{4095}\right)$ |
| **Salida PWM hacia `ENA` del Puente H** | Pin `~9` (`0–255`, 8 bits) | **`GPIO 25`** (`0–255`, 8 bits mediante periférico LEDC) |

---

## 2. Tabla de Conexión Física Paso a Paso para ESP32 DevKit (3.3 V)

> **PRECAUCIÓN CRÍTICA PARA NO QUEMAR EL ESP32:**  
> Como los pines del ESP32 trabajan a **$3.3\text{ V}$**, tanto el **Potenciómetro**, como el **Cable Azul del Encoder (`3.3V/5V Encoder +`)** y la **Resistencia Pull-Up de $47\text{ k}\Omega$** deben ir conectados al riel de **`3V3` ($3.3\text{ V}$) del ESP32**, **JAMÁS a `5V` ni a `VIN`**.

### A) Conexión de los 6 Cables del Motor GM 25-370 Encoder hacia el ESP32 y Puente H

| Orden | Color del Cable | Nombre en el Pinout | ¿A dónde se conecta usando ESP32 DevKit (3.3V)? |
| :---: | :--- | :--- | :--- |
| **1** | **Rojo** | `M1 Motor -` | Tornillo superior de **`Entrada Motor 1` (`OUT1`)** del Puente H |
| **2** | **Negro** | `GND Encoder` | Pin **`GND`** del ESP32 DevKit (Tierra común en Protoboard) |
| **3** | **Amarillo** | `Fase A Encoder` | Pin **`GPIO 18` (`D18`)** del ESP32 **+ Resistencia Pull-up de $47\text{ k}\Omega$ hacia `3V3` ($3.3\text{ V}$)** |
| **4** | **Verde** | `Fase B Encoder` | Pin **`GPIO 19` (`D19`)** del ESP32 |
| **5** | **Azul** | `3.3V/5V Encoder +` | Pin **`3V3` ($3.3\text{ V}$)** del ESP32 (**¡Conectar a 3.3V para que los pulsos Amarillo/Verde sean de 3.3V!**) |
| **6** | **Blanco** | `M1 Motor +` | Tornillo inferior de **`Entrada Motor 1` (`OUT2`)** del Puente H |

### B) Conexión del Puente H al ESP32 DevKit (3.3 V) y Fuente de 12 V

| Terminal en el Puente H | ¿A dónde se conecta en el ESP32 DevKit? | Notas |
| :--- | :--- | :--- |
| **`ENA` (Quitar jumper negro)** | Pin **`GPIO 25` (`D25`)** del ESP32 | Recibe el PWM difuso (`0–255` a $3.3\text{ V}$, compatible con entrada lógica TTL del L298N/L293D). |
| **`IN1`** | Pin **`GPIO 26` (`D26`)** del ESP32 | Nivel lógico `HIGH` ($3.3\text{ V}$). |
| **`IN2`** | Pin **`GPIO 27` (`D27`)** del ESP32 | Nivel lógico `LOW` ($0\text{ V}$). |
| **`Voltaje de entrada` (+12V)** | Positivo (`+`) de la Fuente de Laboratorio a **$12\text{ V}$** | Alimenta la potencia del motor. |
| **`GND` (Bornera central)** | Negativo (`-`) de la Fuente de $12\text{ V}$ **Y TAMBIÉN** al pin **`GND` del ESP32** | Tierra común obligatoria entre Fuente de 12 V, Puente H y ESP32. |
| **`5v de Salida`** | **Dejar desconectado (libre)** | El ESP32 se alimenta por su propio cable Micro-USB / USB-C desde la PC. |

### C) Conexión del Potenciómetro de $10\text{ k}\Omega$ al ESP32 (3.3 V)

| Pata del Potenciómetro | ¿A dónde se conecta en el ESP32 DevKit? |
| :--- | :--- |
| **Pata 1 (Izquierda)** | Riel **`GND`** del ESP32 ($0\text{ V} \rightarrow \text{ADC}_{12\text{b}} = 0 \rightarrow \text{Pot} = 0$) |
| **Pata 2 (Central / Cursor)** | Pin **`GPIO 34` (`D34` / `ADC1_CH6`)** del ESP32 |
| **Pata 3 (Derecha)** | Riel **`3V3` ($3.3\text{ V}$)** del ESP32 ($3.3\text{ V} \rightarrow \text{ADC}_{12\text{b}} = 4095 \rightarrow \text{Pot} = 1023$) |

---

## 3. Tabla de Equivalencia de Escalas y Resultados para ESP32 DevKit (3.3 V)

| `pot` Escala FIS (10 bits: 0–1023) | Lectura Nativa ADC ESP32 (12 bits: 0–4095) | Voltaje en Pin `GPIO 34` (0–3.30 V) | `pwm` MATLAB (`evalfis`) | `pwm` Simulink | `pwm` hardware ESP32 (`GPIO 25`) | `RPM medidas` (Modelo GM25-370) |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **0** | `0` | `0.00 V` | `20.40` | `20.40` | `20` | `11.19 RPM` *(0 RPM físico por zona muerta)* |
| **150** | `600` | `0.48 V` | `58.07` | `58.07` | `58` | `31.85 RPM` |
| **300** | `1201` | `0.97 V` | `77.38` | `77.38` | `77` | `42.45 RPM` |
| **450** | `1801` | `1.45 V` | `109.62` | `109.62` | `110` | `60.13 RPM` |
| **600** | `2402` | `1.94 V` | `151.37` | `151.37` | `151` | `83.03 RPM` |
| **700** | `2802` | `2.26 V` | `172.04` | `172.04` | `172` | `94.37 RPM` |
| **1023** | `4095` | `3.30 V` | `234.60` | `234.60` | `235` | `128.69 RPM` |

---

## 4. Cómo Compilar y Flashear en ESP-IDF (Oficial Espressif C Nativo + FreeRTOS)

Dentro de esta carpeta tienes el proyecto completo de **ESP-IDF** en:
- **`2_Tarjeta_ESP32_DevKit_3V3/ESP32_ESP_IDF_Control_Difuso/`**
  - [`CMakeLists.txt`](ESP32_ESP_IDF_Control_Difuso/CMakeLists.txt)
  - [`main/CMakeLists.txt`](ESP32_ESP_IDF_Control_Difuso/main/CMakeLists.txt)
  - [`main/main.c`](ESP32_ESP_IDF_Control_Difuso/main/main.c) — Programado con las APIs nativas de **ESP-IDF** (`driver/ledc.h`, `driver/gpio.h`, `driver/uart.h`, `esp_adc/adc_oneshot.h` / `driver/adc.h`, `esp_timer.h` y tarea periódica de FreeRTOS `vTaskDelayUntil` cada $T = 40\text{ ms}$).

### Opción A: Con 1 clic usando `COMPILAR_Y_FLASHEAR_ESP_IDF.bat`
1. Dale doble clic a **[`COMPILAR_Y_FLASHEAR_ESP_IDF.bat`](COMPILAR_Y_FLASHEAR_ESP_IDF.bat)**.
2. El script localiza automáticamente tu instalación de `C:\Espressif\frameworks\esp-idf-*`, activa `export.bat`, compila `main/main.c` con `idf.py build`, flashea tu ESP32 con `idf.py flash` y abre **MATLAB R2023a**.

### Opción B: Desde la terminal **ESP-IDF CMD / PowerShell** o **VS Code ESP-IDF Extension**
1. Abre tu terminal **ESP-IDF 5.x / 4.x CMD** (o abre la carpeta `2_Tarjeta_ESP32_DevKit_3V3/ESP32_ESP_IDF_Control_Difuso` en VS Code con la extensión oficial de Espressif IDF).
2. Ejecuta los comandos estándar de ESP-IDF:
   ```bash
   cd 2_Tarjeta_ESP32_DevKit_3V3\ESP32_ESP_IDF_Control_Difuso
   idf.py set-target esp32
   idf.py build
   idf.py -p COM3 flash
   ```
   *(Cambia `COM3` por el puerto COM donde aparezca tu ESP32 DevKit).*
3. Si quieres ver los datos primero en la consola de ESP-IDF (`idf.py -p COM3 monitor`), verás cada $40\text{ ms}$:
   ```text
   600,151.37,151,83.03,8.69,2402
   ```
   *(Presiona `Ctrl + ]` para salir del monitor de ESP-IDF y liberar el puerto COM antes de abrir MATLAB).*
4. En **MATLAB R2023a**, corre:
   ```matlab
   cd 2_Tarjeta_ESP32_DevKit_3V3
   iniciar_todo_matlab_esp32
   conectar_esp32_matlab_fuzzy
   ```

### Opción C: Alternativa con Arduino CLI / Arduino IDE (también conservada sin borrar)
Si en alguna PC no tienen instalado el entorno completo de ESP-IDF, también se dejó conservada la carpeta [`ESP32_Control_Difuso_MotorDC/ESP32_Control_Difuso_MotorDC.ino`](ESP32_Control_Difuso_MotorDC/ESP32_Control_Difuso_MotorDC.ino) y el script [`INSTALAR_Y_EJECUTAR_ESP32_CMD.bat`](INSTALAR_Y_EJECUTAR_ESP32_CMD.bat).
