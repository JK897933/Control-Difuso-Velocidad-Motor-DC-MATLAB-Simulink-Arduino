# Actividad 2: Control Difuso de Velocidad de un Motor de CD con Encoder (MATLAB, Simulink y Arduino UNO)

**Asignatura:** Control Avanzado | **Grupo:** MTR09C | **Profesora:** Dra. Anahí de Loera Figueroa  
**Universidad Politécnica de Aguascalientes (UPA)**

**Integrantes del equipo:**
- Rogelio Mota Herrera (`UP220086`)
- Juan Jesús Hernández Salas (`UP230061` - `up230061@alumnos.upa.edu.mx`)
- Luis André Amezcua Farías (`UP230727`)
- Santiago Javier Gallegos Macías Valadez (`UP220412`)
- Jennyfer Pamela López Rubalcaba (`UP230627`)

---

## 1. Estructura del Repositorio

1. **Instalador y Lanzador de 1 Clic por CMD (`.bat`):** [`INSTALAR_Y_EJECUTAR_TODO_CMD.bat`](INSTALAR_Y_EJECUTAR_TODO_CMD.bat) *(Instala `arduino-cli`, el núcleo `arduino:avr`, las librerías `Encoder`/`PID`/`QuickPID` por CMD, compila/sube el código al Arduino UNO y abre MATLAB con los 3 modelos de Simulink)*.
2. **Lanzador Interactivo de MATLAB + Arduino:** [`iniciar_todo_matlab_arduino.m`](iniciar_todo_matlab_arduino.m)
3. **Manual para cualquier PC sin Antigravity:** [`MANUAL_USO_PC_SIN_ANTIGRAVITY.md`](MANUAL_USO_PC_SIN_ANTIGRAVITY.md)
4. **Sistema de Inferencia Difusa (`.fis`):** `ControlDifusoMotorDC.fis`
5. **Simulink 1 (Motor Sin Control / Lazo Abierto):** `Simulink_1_Motor_Sin_Control.slx`
6. **Simulink 2 (Motor Con Control Proporcional LGR Continuo y Discreto ZOH):** `Simulink_2_Motor_Con_Control.slx`
7. **Simulink 3 (Control Difuso Mamdani + Planta del Motor + Interfaz Arduino):** `Simulink_3_Control_Difuso_Motor_Arduino.slx`
8. **Script Maestro de MATLAB (Generador y Simulador):** `generar_proyecto_fuzzy_motor.m`
9. **Script de Conexión en Vivo MATLAB $\leftrightarrow$ Arduino UNO:** `conectar_arduino_matlab_fuzzy.m`
10. **Código para el Arduino UNO (`.ino`) y Binarios Precompilados (`.hex`):** `Arduino_Control_Difuso_MotorDC/Arduino_Control_Difuso_MotorDC.ino` y `Arduino_Control_Difuso_MotorDC/build/`

---

## 2. Manual de Conexión Física (Arduino UNO + Puente H + Motor GM25-370 Encoder + Potenciómetro)

> **Regla de oro antes de energizar:** Arma todo el circuito con la **fuente de alimentación de 12 V apagada** y el Arduino desconectado del USB. Verifica que el **GND de la fuente de 12 V, el GND del Puente H y el GND del Arduino UNO estén unidos en un nodo común**.

### 2.1 Referencia Visual de los Componentes

| Pizarrón de Laboratorio | Pinout Motor GM 25-370 Encoder | Módulo Puente H (L298N) |
| :---: | :---: | :---: |
| ![Pizarrón](image.png) | ![Motor GM25-370](image%20copy.png) | ![Puente H](image%20copy%202.png) |

### 2.2 Tabla Maestra de Conexiones Paso a Paso

#### A) Conexión del Motor GM 25-370 (6 cables del conector blanco)

| Pin / Color en el Motor GM 25-370 | Función del Cable | ¿A dónde se conecta? | Notas de Instalación |
| :--- | :--- | :--- | :--- |
| **Rojo (`M1 Motor -`)** | Terminal de potencia del motor (-) | **Bornera `Entrada Motor 1` (OUT1)** del Puente H | Si el motor gira al revés de lo deseado, invierte los cables Rojo y Blanco en la bornera del Puente H. |
| **Blanco (`M1 Motor +`)** | Terminal de potencia del motor (+) | **Bornera `Entrada Motor 1` (OUT2)** del Puente H | Recibe los 0–12 V modulados por PWM desde el Puente H. |
| **Negro (`GND Encoder`)** | Tierra lógica del sensor Hall/Óptico | **Pin `GND`** del Arduino UNO (Protoboard GND) | Debe compartir tierra con el Arduino UNO. |
| **Azul (`3.3V/5V Encoder +`)** | Alimentación lógica del encoder | **Pin `5V`** del Arduino UNO (Protoboard +5V) | **¡NUNCA conectar a los 12 V!** Se alimenta estrictamente con `5V` del Arduino. |
| **Amarillo (`Fase A Encoder`)** | Señal de pulsos Canal A (Tacómetro) | **Pin Digital `2`** del Arduino UNO (`INT0`) | **Colocar la resistencia pull-up de $47\text{ k}\Omega$** entre este cable Amarillo (Pin 2) y la línea de `5V` del Arduino. |
| **Verde (`Fase B Encoder`)** | Señal de cuadratura Canal B | **Pin Digital `3`** del Arduino UNO (`INT1`) | Permite detectar dirección y contar pulsos en cuadratura. |

#### B) Conexión del Módulo Puente H (L298N / Driver de Potencia)

| Terminal en el Puente H | ¿A dónde se conecta? | Explicación Técnica |
| :--- | :--- | :--- |
| **`ENA` (Jumper para activar Motor 1)** | **Retirar el jumper negro** y conectar el pin superior `ENA` al **Pin Digital `9` (`~PWM`)** del Arduino UNO | Al quitar el jumper, el pin `9` del Arduino inyecta la señal PWM (`0–255`) calculada por el Controlador Difuso. |
| **`IN1` (Entrada 1)** | **Pin Digital `7`** del Arduino UNO | Control de giro (`HIGH` = sentido horario). |
| **`IN2` (Entrada 2)** | **Pin Digital `8`** del Arduino UNO | Control de giro (`LOW` = sentido horario). |
| **`Voltaje de entrada` (+12V / VMS)** | **Terminal Positiva (`+`) de la Fuente de Laboratorio ajustada a `12 V` (o hasta 18 V máx.)** | Alimenta la etapa de potencia del motor. |
| **`GND` (Bornera central del Puente H)** | **Terminal Negativa (`-`) de la Fuente de 12 V** **Y TAMBIÉN** a un pin **`GND` del Arduino UNO** | **¡Indispensable!** Tierra común entre fuente de potencia y microcontrolador. |
| **`Jumper del Regulador`** | Dejar puesto el jumper central | Si alimentas el Arduino por cable USB desde la PC para usar MATLAB/Simulink, **NO conectes** la bornera `5v de Salida` del Puente H al pin `5V` del Arduino. |

#### C) Conexión del Potenciómetro de $10\text{ k}\Omega$ (Referencia de Velocidad)

| Pin del Potenciómetro ($10\text{ k}\Omega$) | ¿A dónde se conecta en el Arduino UNO? | Función |
| :--- | :--- | :--- |
| **Pin Extremo Izquierdo (Terminal 1)** | **`GND`** (Tierra común en Protoboard) | Referencia mínima ($0\text{ V} \rightarrow \text{ADC} = 0$). |
| **Pin Central (Cursor / Wiper)** | **Pin Analógico `A0`** del Arduino UNO | Señal de entrada al Controlador Difuso (`Pot`: `0` a `1023`). |
| **Pin Extremo Derecho (Terminal 3)** | **`5V`** del Arduino UNO | Referencia máxima ($5\text{ V} \rightarrow \text{ADC} = 1023$). |

---

## 3. Parte A: Diseño del Controlador Difuso (Mamdani) en MATLAB

- **Tipo de Sistema Difuso:** Mamdani (`mamfis`)
- **Método de intersección (AND):** Mínimo (`min`)
- **Método de implicación:** Mínimo (`min`)
- **Método de agregación:** Máximo (`max`)
- **Método de defuzzificación:** Centroide ($y = \frac{\int y \cdot \mu(y)\,dy}{\int \mu(y)\,dy}$)

### 3.1 Variables Lingüísticas y Funciones de Membresía

#### 1. Variable de Entrada: `Pot` (Lectura del Potenciómetro, Rango $[0, 1023]$)

| Conjunto Difuso | Identificador en `.fis` | Tipo | Vértices $[a,\; b,\; c]$ |
| :--- | :--- | :--- | :--- |
| **Baja** | `Baja` | `trimf` | $[-255.75,\; 0.00,\; 255.75]$ |
| **Media baja** | `Media_baja` | `trimf` | $[0.00,\; 255.75,\; 511.50]$ |
| **Media** | `Media` | `trimf` | $[255.75,\; 511.50,\; 767.25]$ |
| **Media alta** | `Media_alta` | `trimf` | $[511.50,\; 767.25,\; 1023.00]$ |
| **Alta** | `Alta` | `trimf` | $[767.25,\; 1023.00,\; 1278.75]$ |

#### 2. Variable de Salida: `Velocidad_PWM` (Señal PWM, Rango $[0, 255]$)

| Conjunto Difuso | Identificador en `.fis` | Tipo | Vértices $[a,\; b,\; c]$ |
| :--- | :--- | :--- | :--- |
| **Lenta** | `Lenta` | `trimf` | $[-63.75,\; 0.00,\; 63.75]$ |
| **Media lenta** | `Media_lenta` | `trimf` | $[0.00,\; 63.75,\; 127.50]$ |
| **Media** | `Media` | `trimf` | $[63.75,\; 127.50,\; 191.25]$ |
| **Media Veloz** | `Media_Veloz` | `trimf` | $[127.50,\; 191.25,\; 255.00]$ |
| **Veloz** | `Veloz` | `trimf` | $[191.25,\; 255.00,\; 318.75]$ |

### 3.2 Base de 5 Reglas de Inferencia (Mamdani)

1. `IF (Pot is Baja) THEN (Velocidad_PWM is Lenta) (1)`
2. `IF (Pot is Media_baja) THEN (Velocidad_PWM is Media_lenta) (1)`
3. `IF (Pot is Media) THEN (Velocidad_PWM is Media) (1)`
4. `IF (Pot is Media_alta) THEN (Velocidad_PWM is Media_Veloz) (1)`
5. `IF (Pot is Alta) THEN (Velocidad_PWM is Veloz) (1)`

### 3.3 Gráficas del Sistema Difuso

![Funciones de Membresía](figuras/fig1_funciones_membresia.png)

![Curva Característica Entrada-Salida](figuras/fig2_curva_entrada_salida_fis.png)

---

## 4. Parte B: Los 3 Modelos en Simulink

Función de transferencia de la planta obtenida experimentalmente:
$$G_p(s) = \frac{\Omega(s)}{V(s)} = \frac{24}{s^2 + 11s + 24} = \frac{24}{(s+3)(s+8)}$$
Con controlador proporcional sintonizado por LGR ($\text{OS} = 20\%$): $K = 5.0629$, y discretización ZOH ($T = 0.04\text{ s}$):
$$G_p(z) = \frac{0.016617z + 0.014351}{z^2 - 1.613069z + 0.643936}$$

![Simulink 1 y 2](figuras/fig3_simulink_sin_control_y_con_control.png)

![Simulink 3 Rampa](figuras/fig4_simulink_control_difuso_rampa.png)

![Simulink 3 Entradas Constantes](figuras/fig5_simulink_entradas_constantes.png)

---

## 5. Tabla de Resultados (Punto 8 del Reporte)

| `pot` (0–1023) | `pwm` MATLAB (`evalfis`) | `pwm` Simulink | `pwm` hardware (Arduino 8 bits) | $\omega_{ss}$ Motor ($\text{rad/s}$) | `RPM medidas` (Simulink / Nominal GM25-370) | `RPM medidas` estimadas en Hardware Físico |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **0** | `20.40` | `20.40` | `20` | `0.96 rad/s` | `11.19 RPM` | `0.0 RPM` *(Zona muerta < 35 PWM)* |
| **150** | `58.07` | `58.07` | `58` | `2.73 rad/s` | `31.85 RPM` | `~26.5 RPM` |
| **300** | `77.38` | `77.38` | `77` | `3.64 rad/s` | `42.45 RPM` | `~39.0 RPM` |
| **450** | `109.62` | `109.62` | `110` | `5.15 rad/s` | `60.13 RPM` | `~58.2 RPM` |
| **600** | `151.37` | `151.37` | `151` | `7.12 rad/s` | `83.03 RPM` | `~81.5 RPM` |
| **700** | `172.04` | `172.04` | `172` | `8.09 rad/s` | `94.37 RPM` | `~93.0 RPM` |
| **1023** | `234.60` | `234.60` | `235` | `11.03 rad/s` | `128.69 RPM` | `~126.0 RPM` |
