# Manual de Conexión Física y Guía Paso a Paso en cualquier PC (MATLAB, Simulink y Arduino IDE)

Este manual está diseñado para que cualquier integrante del equipo pueda descargar el proyecto desde GitHub y ejecutarlo **en cualquier computadora del laboratorio o laptop personal**, utilizando únicamente **MATLAB/Simulink** y **Arduino IDE**, sin depender de ningún asistente externo.

---

## PARTE 1: Descargar el Proyecto en la PC del Laboratorio

### Opción A: Descargar como archivo `.ZIP` (Más rápido en PCs de laboratorio)
1. Abre el navegador y entra al repositorio:  
   **https://github.com/JK897933/Control-Difuso-Velocidad-Motor-DC-MATLAB-Simulink-Arduino**
2. Haz clic en el botón verde **`<> Code`** y selecciona **`Download ZIP`**.
3. Extrae la carpeta `.zip` en el `Escritorio` o en `Documentos` (por ejemplo: `C:\Users\Alumno\Desktop\Control-Difuso-Velocidad-Motor-DC`).

### Opción B: Clonar con Git (si tiene Git instalado)
Abre `cmd` o `PowerShell` y ejecuta:
```bash
git clone https://github.com/JK897933/Control-Difuso-Velocidad-Motor-DC-MATLAB-Simulink-Arduino.git
```

### ¿Dónde tengo que poner las cosas para que el `.bat` jale todo?
El archivo `INSTALAR_Y_EJECUTAR_TODO_CMD.bat` usa rutas relativas automáticas (`%~dp0`), así que **puedes poner la carpeta en cualquier lugar de la PC** (en el `Escritorio`, en `Documentos`, en `C:\ControlDifuso\` o en una memoria USB), **siempre y cuando todos los archivos del repositorio estén juntos dentro de esa misma carpeta**:

```text
📁 Control-Difuso-Velocidad-Motor-DC/   <-- (Puedes poner esta carpeta en Escritorio, Documentos, C:\, etc.)
 ├── ⚙️ INSTALAR_Y_EJECUTAR_TODO_CMD.bat          <-- ¡A ESTE LE DAS DOBLE CLIC!
 ├── 📄 iniciar_todo_matlab_arduino.m
 ├── 📄 generar_proyecto_fuzzy_motor.m
 ├── 📄 conectar_arduino_matlab_fuzzy.m
 ├── 📄 ControlDifusoMotorDC.fis
 ├── 📄 Simulink_1_Motor_Sin_Control.slx
 ├── 📄 Simulink_2_Motor_Con_Control.slx
 ├── 📄 Simulink_3_Control_Difuso_Motor_Arduino.slx
 └── 📁 Arduino_Control_Difuso_MotorDC/           <-- (Esta subcarpeta debe quedarse ahí adentro)
      ├── 📄 Arduino_Control_Difuso_MotorDC.ino
      └── 📁 build/
           └── 📄 Arduino_Control_Difuso_MotorDC.ino.hex
```

1. **Descomprimir todo el `.zip`:** Si lo bajaste como `.zip` de GitHub, dale **Clic derecho $\rightarrow$ Extraer todo...** (no abras el `.bat` desde adentro del `.zip` sin extraerlo, ni saques el `.bat` suelto fuera de la carpeta).
2. **Conectar el Arduino UNO por USB:** Enchufa el Arduino UNO al puerto USB antes de correr el `.bat` para que le suba el programa automáticamente.
3. **Ejecutar el `.bat`:** Dale **doble clic a `INSTALAR_Y_EJECUTAR_TODO_CMD.bat`** (o *Clic derecho $\rightarrow$ Ejecutar como administrador*).

---

## PARTE 2: Librerías Requeridas e Instalación Automática por CMD (`INSTALAR_Y_EJECUTAR_TODO_CMD.bat`)

### 2.1 ¿Qué librerías o paquetes ocupa el proyecto?
1. **En Arduino UNO:**
   - Nuestro código [`Arduino_Control_Difuso_MotorDC.ino`](Arduino_Control_Difuso_MotorDC/Arduino_Control_Difuso_MotorDC.ino) fue programado con el motor de inferencia Mamdani y la interrupción del encoder integrados en C/C++ nativo (`<Arduino.h>`), por lo que **no depende de librerías externas raras que fallen al compilar**.
   - Aun así, incluimos la instalación por CMD del núcleo oficial **`arduino:avr`** y las librerías **`Encoder`**, **`PID`** y **`QuickPID`**, además del binario ya precompilado (`.hex`) en [`Arduino_Control_Difuso_MotorDC/build/`](Arduino_Control_Difuso_MotorDC/build) listo para quemarse directo al Arduino UNO sin siquiera abrir Arduino IDE.
2. **En MATLAB (R2021a – R2025b):**
   - **Simulink** (para correr los 3 modelos `.slx`).
   - **Fuzzy Logic Toolbox** (para el archivo `.fis` y el bloque *Fuzzy Logic Controller*).
   - **Control System Toolbox** (para las funciones de transferencia `tf` y `c2d`).
   - **Comunicación Serial con Arduino:** Usa la función nativa `serialport` de MATLAB (incluida de fábrica en MATLAB sin necesidad de instalar el *Support Package* pesado de gigabytes).

### 2.2 Opción 1 (Automática con 1 Clic o por CMD): Ejecutar `INSTALAR_Y_EJECUTAR_TODO_CMD.bat`
En la carpeta descargada encontrarás el archivo **`INSTALAR_Y_EJECUTAR_TODO_CMD.bat`**. Al darle doble clic (o correrlo en `cmd`), hace todo esto solo:
1. Instala **Arduino CLI** usando `winget`.
2. Descarga e instala por línea de comandos el núcleo de **Arduino UNO (`arduino:avr`)** y las librerías (`Encoder`, `PID`, `QuickPID`).
3. Compila el código `.ino` y, si detecta tu Arduino UNO conectado por USB, **le sube el programa automáticamente**.
4. Abre **MATLAB** y ejecuta `iniciar_todo_matlab_arduino.m`, dejando abiertos los **3 modelos de Simulink** y las gráficas listas.

### 2.3 Comandos Manuales en CMD (si prefieres pegarlos tú mismo en la terminal de Windows)
Si estás en otra PC y quieres instalar las herramientas y subir el código al Arduino UNO desde `cmd` o `PowerShell`:

```bat
:: 1. Instalar Arduino CLI desde CMD con winget
winget install -e --id ArduinoSA.CLI --accept-source-agreements --accept-package-agreements
set "PATH=%PATH%;C:\Program Files\Arduino CLI"

:: 2. Instalar el núcleo oficial de Arduino UNO y librerías por CMD
arduino-cli core update-index
arduino-cli core install arduino:avr
arduino-cli lib install "Encoder" "PID" "QuickPID"

:: 3. Compilar el programa del Control Difuso
arduino-cli compile --fqbn arduino:avr:uno Arduino_Control_Difuso_MotorDC\Arduino_Control_Difuso_MotorDC.ino

:: 4. Subir al Arduino UNO (cambia COM3 por el puerto donde aparezca tu Arduino en 'arduino-cli board list')
arduino-cli upload -p COM3 --fqbn arduino:avr:uno Arduino_Control_Difuso_MotorDC\Arduino_Control_Difuso_MotorDC.ino
```

---

## PARTE 3: Manual de Conexión Física (Paso a Paso con Fuente Apagada)

> **IMPORTANTE ANTES DE EMPEZAR:**  
> Mantén la **fuente de alimentación de 12 V APAGADA** y el **cable USB del Arduino UNO desconectado** mientras armas el circuito en la protoboard.

### 3.1 Identificación de Pines de tus Componentes

| Pizarrón de Laboratorio | Pinout Motor GM 25-370 Encoder | Módulo Puente H (L298N) |
| :---: | :---: | :---: |
| ![Pizarrón](image.png) | ![Motor GM25-370](image%20copy.png) | ![Puente H](image%20copy%202.png) |

---

### 3.2 Paso 1: Preparar las líneas de alimentación en la Protoboard
1. Conecta un cable desde el pin **`5V`** del Arduino UNO hacia el riel positivo (**rojo `+`**) de tu protoboard.
2. Conecta un cable desde el pin **`GND`** del Arduino UNO hacia el riel negativo (**azul/negro `-`**) de tu protoboard.

---

### 3.3 Paso 2: Conectar el Potenciómetro de $10\text{ k}\Omega$
El potenciómetro tiene 3 patas (viéndolo de frente con la perilla hacia ti):
1. **Pata Izquierda (Pin 1):** Conéctala al riel **`GND`** de la protoboard.
2. **Pata Central (Pin 2 / Cursor):** Conéctala directamente al pin analógico **`A0`** del Arduino UNO.
3. **Pata Derecha (Pin 3):** Conéctala al riel de **`+5V`** de la protoboard.

---

### 3.4 Paso 3: Conectar los 6 Cables del Motor con Encoder (GM 25-370)
El conector blanco del motor tiene 6 cables de colores en orden. Conéctalos exactamente así:

| Orden | Color del Cable | Nombre en el Pinout | ¿Dónde conectarlo físicamente? |
| :---: | :--- | :--- | :--- |
| **1** | **Rojo** | `M1 Motor -` | En el tornillo superior de **`Entrada Motor 1` (`OUT1`)** del Puente H. |
| **2** | **Negro** | `GND Encoder` | Al riel **`GND`** de la protoboard (Tierra del Arduino). |
| **3** | **Amarillo** | `Fase A Encoder` | Al **Pin Digital `2`** del Arduino UNO **+ Resistencia Pull-up de $47\text{ k}\Omega$ hacia `+5V`** *(ver nota abajo)*. |
| **4** | **Verde** | `Fase B Encoder` | Al **Pin Digital `3`** del Arduino UNO. |
| **5** | **Azul** | `3.3V/5V Encoder +` | Al riel **`+5V`** de la protoboard (**¡Jamás lo conectes a los 12 V!**). |
| **6** | **Blanco** | `M1 Motor +` | En el tornillo inferior de **`Entrada Motor 1` (`OUT2`)** del Puente H. |

> **Cómo poner la resistencia de $47\text{ k}\Omega$ (Pull-up del encoder):**  
> En la protoboard, coloca una pata de la resistencia de $47\text{ k}\Omega$ en la misma fila donde llega el **cable Amarillo (Pin 2 del Arduino)** y la otra pata de la resistencia conéctala al riel de **`+5V`**. Esto limpia los pulsos del encoder óptico/Hall.

---

### 3.5 Paso 4: Conectar el Puente H al Arduino UNO y a la Fuente de 12 V
1. **Quitar el Jumper `ENA`:** En el Puente H, localiza el pin `ENA` (abajo a la izquierda de la fila de pines `IN1` a `IN4`, como indica tu imagen *"ENA: Jumper para activar Motor 1"*). **Retira la tapita negra (jumper)**.
2. **Pin `ENA` (el pin que quedó libre más cercano al borde):** Conéctalo con un cable jumper al **Pin Digital `9` (`~9` PWM)** del Arduino UNO.
3. **Pin `IN1` del Puente H:** Conéctalo al **Pin Digital `7`** del Arduino UNO.
4. **Pin `IN2` del Puente H:** Conéctalo al **Pin Digital `8`** del Arduino UNO.
5. **Bornera `Voltaje de entrada` (izquierda de la bornera azul de 3 tornillos):** Conecta ahí el caimán **Positivo (`+`)** de la Fuente de Laboratorio (ajustada a **$12\text{ V}$**).
6. **Bornera `GND` (tornillo central de la bornera azul):** Conecta ahí DOS cables:
   - El caimán **Negativo (`-`)** de la Fuente de Laboratorio de $12\text{ V}$.
   - Un cable jumper que vaya directo al riel **`GND`** de la protoboard (para unir el GND de la fuente con el GND del Arduino UNO).
7. **Bornera `5v de Salida` (tornillo derecho):** **Déjala libre (sin conectar)** porque el Arduino UNO ya se alimentará por el cable USB de la PC.

---

## PARTE 4: Cómo Abrir y Ejecutar las Simulaciones en MATLAB y Simulink (Paso a Paso)

### Paso 1: Ubicarse en la carpeta del proyecto dentro de MATLAB
1. Abre **MATLAB**.
2. En la barra de dirección superior (`Current Folder`), navega y entra a la carpeta donde descargaste el proyecto (donde están los archivos `.m`, `.fis` y `.slx`).

### Paso 2: Cargar las variables y el archivo `.fis` en el Workspace
En la ventana de comandos (`Command Window`) de MATLAB, escribe lo siguiente y presiona **Enter**:
```matlab
generar_proyecto_fuzzy_motor
```
**¿Qué hace este comando automáticamente?**
- Crea y carga en el `Workspace` la variable `fis` (el controlador difuso Mamdani) y guarda el archivo `ControlDifusoMotorDC.fis`.
- Abre y exporta las gráficas de las **5 funciones de membresía de entrada/salida** y la **curva característica del controlador**.
- Corre los **3 modelos de Simulink** y muestra en la `Command Window` la **Tabla del Punto 8 completa**.

---

### Paso 3: Cómo abrir e inspeccionar el Controlador Difuso en la interfaz gráfica (`fuzzyLogicDesigner`)
Si la profesora te pide mostrar las funciones de membresía, las reglas o el *Rule Viewer* en pantalla:
1. En el `Command Window` de MATLAB escribe:
   ```matlab
   fuzzyLogicDesigner('ControlDifusoMotorDC.fis')
   ```
2. Dentro de la ventana que se abre:
   - Haz doble clic sobre la caja amarilla **`Pot`** o la azul **`Velocidad_PWM`** para ver las **5 funciones de membresía** (`Baja`, `Media_baja`, `Media`, `Media_alta`, `Alta` / `Lenta`, `Media_lenta`, `Media`, `Media_Veloz`, `Veloz`).
   - En el menú superior selecciona **`View` $\rightarrow$ `Rules`** (o pestaña *Rule Viewer*) para mover la barra roja de `Pot` en `0, 150, 300, 450, 600, 700, 1023` y comprobar en vivo el valor de salida `PWM`.
   - En **`View` $\rightarrow$ `Surface`** puedes ver la curva Entrada–Salida creciente de $0\text{ a }1023$.

---

### Paso 4: Cómo abrir y correr manualmente cada uno de los 3 Modelos de Simulink

> **Nota importante:** Antes de darle al botón **Run (▶)** en cualquiera de los 3 modelos de Simulink, asegúrate de haber cargado primero el archivo `.fis` en el Workspace escribiendo en el `Command Window`:
> ```matlab
> fis = readfis('ControlDifusoMotorDC.fis');
> ```

#### 1) Modelo 1: Motor Sin Control (`Simulink_1_Motor_Sin_Control.slx`)
1. Haz doble clic sobre `Simulink_1_Motor_Sin_Control.slx` en el panel izquierdo de MATLAB (o escribe `open_system('Simulink_1_Motor_Sin_Control.slx')`).
2. Presiona el botón verde **Run (▶)** arriba en Simulink.
3. Haz doble clic en el bloque **`Scope_Velocidad_Sin_Control`** para ver la curva de respuesta en lazo abierto ante $12\text{ V}$ llegando a $\omega_{ss} = 12\text{ rad/s}$ ($140\text{ RPM}$ nominales).

#### 2) Modelo 2: Motor Con Control Clásico LGR (`Simulink_2_Motor_Con_Control.slx`)
1. Haz doble clic sobre `Simulink_2_Motor_Con_Control.slx`.
2. Presiona **Run (▶)**.
3. Abre el bloque **`Scope_Control_LGR`** para mostrar tanto la respuesta continua con el controlador proporcional $K = 5.0629$ (sobrepaso exacto del $20\%$) como la respuesta discreta con retenedor de orden cero ($\text{ZOH}$, $T = 0.04\text{ s}$).

#### 3) Modelo 3: Control Difuso + Planta del Motor (`Simulink_3_Control_Difuso_Motor_Arduino.slx`)
1. Haz doble clic sobre `Simulink_3_Control_Difuso_Motor_Arduino.slx`.
2. **Para simular con Entrada Rampa (`0` a `1023`):**
   - Asegúrate de que el switch manual (`Selector_Rampa_o_Constante`) apunte hacia arriba (`Entrada_Rampa_Pot_0_1023`).
   - Presiona **Run (▶)** y abre **`Scope_Fuzzy_Motor`**. Verás las 4 señales: Rampa del Potenciómetro, PWM del bloque *Fuzzy Logic Controller*, velocidad en $\text{rad/s}$ y velocidad en $\text{RPM}$.
3. **Para simular con Entradas Constantes (`0, 150, 300, 450, 600, 700, 1023`):**
   - Haz doble clic sobre el switch manual `Selector_Rampa_o_Constante` para que cambie a la posición inferior (`Entrada_Constante_Pot`).
   - Haz doble clic en el bloque **`Entrada_Constante_Pot`**, escribe el valor deseado (por ejemplo `600`), da clic en *OK* y presiona **Run (▶)**.

---

## PARTE 5: Cómo Ejecutar el Motor en Físico con el Arduino UNO y MATLAB

### Paso 1: Subir el código al Arduino UNO desde Arduino IDE
1. Conecta el Arduino UNO por cable USB a la PC (mantén la fuente de $12\text{ V}$ apagada por ahora).
2. Abre el programa **Arduino IDE**.
3. Ve a **`Archivo` $\rightarrow$ `Abrir...`** y selecciona el archivo:  
   `Arduino_Control_Difuso_MotorDC/Arduino_Control_Difuso_MotorDC.ino`
4. En el menú **`Herramientas` (`Tools`)**:
   - **Placa (`Board`):** Selecciona `Arduino Uno`.
   - **Puerto (`Port`):** Selecciona el puerto COM donde aparezca tu Arduino (ej. `COM3`, `COM4`, `COM5`).
5. Haz clic en el botón **Subir (`Upload` $\rightarrow$)** y espera a que diga *"Subida completada" (`Done uploading`)*.
6. **¡Importante!** Si abriste el *Monitor Serie* de Arduino IDE para probar, **ciérralo** antes de pasar a MATLAB para que el puerto COM no quede ocupado.

---

### Paso 2: Probar en Físico (Modo 1: Directo / Autónomo o con Monitor Serie)
1. Enciende la **Fuente de Alimentación de Laboratorio en $12.0\text{ V}$**.
2. Gira el potenciómetro de $10\text{ k}\Omega$ desde el mínimo hasta el máximo: el Arduino UNO ya tiene programado internamente el mismo controlador difuso Mamdani (`ControlDifusoMotorDC.fis`), por lo que el motor variará su velocidad inmediatamente de acuerdo con las reglas difusas.
3. Si abres el **Monitor Serie** en Arduino IDE (configurado a **`115200 baudios`**), verás impresa cada $40\text{ ms}$ la fila de datos para llenar tu tabla:
   ```text
   Pot, PWM_Fuzzy, PWM_Hardware, RPM_Medidas, Rad_s
   600, 151.37, 151, 81.45, 8.53
   ```

---

### Paso 3: Probar en Físico Conectado en Vivo a MATLAB (Modo 2: Co-simulación Serial)
Si quieres que **MATLAB** evalúe el archivo `ControlDifusoMotorDC.fis` en tiempo real, le mande el PWM al Arduino UNO y grafique en vivo las curvas del potenciómetro, PWM y RPM del encoder:

1. Asegúrate de que el **Monitor Serie de Arduino IDE esté cerrado**.
2. Con el Arduino UNO conectado por USB y la fuente de $12\text{ V}$ encendida, ve al `Command Window` de MATLAB y escribe:
   ```matlab
   conectar_arduino_matlab_fuzzy
   ```
3. Se abrirá una ventana gráfica en vivo en MATLAB con 3 gráficas animadas (**Potenciómetro `0-1023`**, **Salida Difusa `PWM 0-255`** y **Velocidad Real del Encoder en `RPM`**) mientras en la consola de MATLAB se imprimen los valores exactos para tu tabla.
4. Gira el potenciómetro a los puntos de la tabla (`0`, `150`, `300`, `450`, `600`, `700`, `1023`), anota las RPM medidas y cierra la ventana gráfica cuando termines.

---

## PARTE 6: Solución Rápida de Problemas en el Laboratorio (Troubleshooting)

| Problema | Causa Probable | Solución Rápida |
| :--- | :--- | :--- |
| **El motor no gira aunque el PWM sube** | 1. Falta unir `GND` de la fuente de $12\text{ V}$ con `GND` del Arduino.<br>2. No se quitó el jumper `ENA` o se conectó en el pin equivocado.<br>3. `Pot` está muy bajo (`< 35 PWM`, zona muerta). | 1. Verifica continuidad entre `GND` de la fuente y `GND` del Arduino.<br>2. Conecta el pin `9` del Arduino al pin superior de `ENA`.<br>3. Sube el potenciómetro arriba de `150`. |
| **Las RPM marcan siempre `0.00` aunque el motor gira** | 1. El encoder no recibe `5V` (cable Azul) o `GND` (cable Negro).<br>2. Falta la resistencia pull-up de $47\text{ k}\Omega$ entre el cable Amarillo (Pin 2) y `+5V`. | Verifica con el multímetro que entre el cable Negro y Azul del motor existan $5.0\text{ V}$, y que la resistencia de $47\text{ k}\Omega$ esté entre el Pin `2` y `5V`. |
| **Error en MATLAB: `Unable to connect to COM port`** | El *Monitor Serie* o *Serial Plotter* del Arduino IDE sigue abierto y bloquea el puerto USB. | Cierra la ventana del Monitor Serie en Arduino IDE y vuelve a ejecutar `conectar_arduino_matlab_fuzzy` en MATLAB. |
| **Error en Simulink: `Variable 'fis' does not exist`** | Abriste el archivo `.slx` sin haber cargado primero el `.fis` en el Workspace de MATLAB. | Escribe `fis = readfis('ControlDifusoMotorDC.fis');` en el `Command Window` de MATLAB y vuelve a presionar **Run (▶)** en Simulink. |
