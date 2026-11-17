/*
 * ============================================================================
 * ACTIVIDAD 2: CONTROL DIFUSO DE VELOCIDAD DE UN MOTOR DE CD CON ENCODER
 * Asignatura: Control Avanzado | Grupo: MTR09C
 * Hardware:
 *   - Arduino UNO
 *   - Motor DC 12V con Encoder Cuadratura GM25-370 (140 RPM nominales a 12V)
 *   - Módulo Puente H (L298N / L293D)
 *   - Potenciómetro de 10 kOhm
 *
 * Modos de operación simultáneos:
 *   1) Modo Autónomo (Control Difuso Mamdani integrado en Arduino con centroide
 *      idéntico al archivo ControlDifusoMotorDC.fis de MATLAB).
 *   2) Modo Conectado a MATLAB / Simulink por Puerto Serial (115200 baudios):
 *      - Envía telemetría en tiempo real: POT, PWM_FIS, RPM_MEDIDAS, RAD_S
 *      - Permite recibir el valor PWM directamente calculado por MATLAB/Simulink
 *        si se envía por Serial como "P<valor>\n" (ej. "P141\n").
 * ============================================================================
 */

// --- DEFINICIÓN DE PINES (SEGÚN MANUAL DE CONEXIÓN) ---
const int PIN_POT   = A0;  // Entrada analógica del Potenciómetro 10k (0 - 1023)
const int PIN_ENC_A = 2;   // Fase A Encoder (Cable Amarillo) - Interrupción 0 (+ resistencia pull-up 47k a 5V)
const int PIN_ENC_B = 3;   // Fase B Encoder (Cable Verde)    - Entrada digital 3
const int PIN_ENA   = 9;   // PWM Puente H (Activar Motor 1 - quitar jumper ENA)
const int PIN_IN1   = 7;   // Dirección 1 Puente H (IN1)
const int PIN_IN2   = 8;   // Dirección 2 Puente H (IN2)

// --- PARÁMETROS DEL ENCODER Y MUESTREO (T = 0.04 s = 40 ms según PDF 2) ---
// Nota: El motor GM25-370 (140 RPM) tiene Típicamente 11 PPR en el eje trasero
// y relación de reducción ~1:34 (34 * 11 = 374 pulsos por vuelta en Fase A).
// Ajusta PULSOS_POR_VUELTA si tu versión de caja reductora varía.
const float PULSOS_POR_VUELTA = 374.0;
const unsigned long T_MUESTREO_MS = 40; // T = 0.04 s (igual que en la Transformada Z del PDF 2)

volatile long contadorPulsos = 0;
unsigned long ultimoTiempo = 0;

int lecturaPot = 0;
float pwmDifuso = 0.0;
int pwmHardware = 0;
int pwmExternoMatlab = -1; // Si >= 0, usa el PWM enviado desde MATLAB/Simulink en vivo
float rpmMedidas = 0.0;
float omegaRadS  = 0.0;

// --- INTERRUPCIÓN EXTERNA PARA EL ENCODER (FASE A) ---
void ISR_EncoderA() {
  if (digitalRead(PIN_ENC_B) == HIGH) {
    contadorPulsos++;
  } else {
    contadorPulsos--;
  }
}

// --- FUNCIÓN DE PERTENENCIA TRIANGULAR μ(x; a, b, c) ---
float trimf(float x, float a, float b, float c) {
  if (x <= a || x >= c) return 0.0;
  else if (x == b) return 1.0;
  else if (x < b) return (x - a) / (b - a);
  else return (c - x) / (c - b);
}

// --- EVALUACIÓN DEL CONTROLADOR DIFUSO MAMDANI (IDÉNTICO A MATLAB .FIS) ---
// 5 Funciones de Membresía de Entrada (Pot: 0 - 1023):
//   Baja, Media_baja, Media, Media_alta, Alta
// 5 Funciones de Membresía de Salida (Velocidad PWM: 0 - 255):
//   Lenta, Media_lenta, Media, Media_Veloz, Veloz
// Implicación: min | Agregación: max | Defuzzificación: Centroide
float evaluarControlDifusoMamdani(float pot) {
  // 1. Fuzzificación de la entrada Pot (0 a 1023)
  float mu_in[5];
  mu_in[0] = trimf(pot, -255.75,    0.00,  255.75); // Baja
  mu_in[1] = trimf(pot,    0.00,  255.75,  511.50); // Media_baja
  mu_in[2] = trimf(pot,  255.75,  511.50,  767.25); // Media
  mu_in[3] = trimf(pot,  511.50,  767.25, 1023.00); // Media_alta
  mu_in[4] = trimf(pot,  767.25, 1023.00, 1278.75); // Alta

  // Vértices de las 5 funciones de membresía de salida (Velocidad PWM: 0 a 255)
  const float out_a[5] = {-63.75,   0.00,  63.75, 127.50, 191.25};
  const float out_b[5] = {  0.00,  63.75, 127.50, 191.25, 255.00};
  const float out_c[5] = { 63.75, 127.50, 191.25, 255.00, 318.75};

  // 2, 3 y 4. Inferencia Mamdani (min), Agregación (max) y Defuzzificación (Centroide)
  // Integramos numéricamente en el universo de discurso de salida y in [0, 255]
  const int N_PUNTOS = 101;
  const float dy = 255.0 / (N_PUNTOS - 1);
  float num = 0.0;
  float den = 0.0;

  for (int k = 0; k < N_PUNTOS; k++) {
    float y = k * dy;
    float mu_agg = 0.0;

    // Evaluar las 5 reglas: IF Pot is MF_i THEN PWM is MF_i
    for (int r = 0; r < 5; r++) {
      if (mu_in[r] > 0.0) {
        float mu_out_r = trimf(y, out_a[r], out_b[r], out_c[r]);
        // Implicación Mamdani: recorte con min(grado_activacion, mu_salida)
        float recorte = (mu_in[r] < mu_out_r) ? mu_in[r] : mu_out_r;
        // Agregación: máximo de todas las reglas
        if (recorte > mu_agg) {
          mu_agg = recorte;
        }
      }
    }
    num += y * mu_agg;
    den += mu_agg;
  }

  if (den == 0.0) return 0.0;
  float y_centroide = num / den;
  if (y_centroide < 0.0)   y_centroide = 0.0;
  if (y_centroide > 255.0) y_centroide = 255.0;
  return y_centroide;
}

void setup() {
  Serial.begin(115200);

  // Configurar pines del Puente H
  pinMode(PIN_ENA, OUTPUT);
  pinMode(PIN_IN1, OUTPUT);
  pinMode(PIN_IN2, OUTPUT);

  // Configurar sentido de giro fijo hacia adelante (IN1 = HIGH, IN2 = LOW)
  digitalWrite(PIN_IN1, HIGH);
  digitalWrite(PIN_IN2, LOW);
  analogWrite(PIN_ENA, 0);

  // Configurar pines del Encoder (Fase A lleva la resistencia pull-up externa de 47k a 5V)
  pinMode(PIN_ENC_A, INPUT_PULLUP);
  pinMode(PIN_ENC_B, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(PIN_ENC_A), ISR_EncoderA, RISING);

  ultimoTiempo = millis();
}

void loop() {
  // Verificar si MATLAB/Simulink envió un comando PWM por puerto serial (Formato: "P150\n" o "A\n" para autónomo)
  if (Serial.available() > 0) {
    char cmd = Serial.read();
    if (cmd == 'P' || cmd == 'p') {
      pwmExternoMatlab = Serial.parseInt();
      pwmExternoMatlab = constrain(pwmExternoMatlab, 0, 255);
    } else if (cmd == 'A' || cmd == 'a') {
      pwmExternoMatlab = -1; // Regresar a modo Fuzzy interno
    }
  }

  unsigned long ahora = millis();
  if (ahora - ultimoTiempo >= T_MUESTREO_MS) {
    float dt = (ahora - ultimoTiempo) / 1000.0;
    ultimoTiempo = ahora;

    // 1. Leer pulsos acumulados de forma segura
    noInterrupts();
    long pulsos = contadorPulsos;
    contadorPulsos = 0;
    interrupts();

    // 2. Calcular velocidad en RPM y rad/s
    rpmMedidas = (abs(pulsos) / PULSOS_POR_VUELTA) * (60.0 / dt);
    omegaRadS  = rpmMedidas * (2.0 * PI / 60.0);

    // 3. Leer Potenciómetro (0 - 1023) - doble lectura para estabilizar potenciómetro de 100 kOhm
    analogRead(PIN_POT);
    delayMicroseconds(150);
    lecturaPot = analogRead(PIN_POT);

    // 4. Calcular salida del Controlador Difuso Mamdani (0 - 255)
    pwmDifuso = evaluarControlDifusoMamdani((float)lecturaPot);

    // 5. Seleccionar señal PWM a aplicar en el Puente H
    if (pwmExternoMatlab >= 0) {
      pwmHardware = pwmExternoMatlab;
    } else {
      pwmHardware = (int)round(pwmDifuso);
    }
    pwmHardware = constrain(pwmHardware, 0, 255);
    analogWrite(PIN_ENA, pwmHardware);

    // 6. Enviar trama CSV hacia MATLAB / Serial Plotter:
    // Formato: pot,pwm_fis,pwm_hw,rpm,rad_s
    Serial.print(lecturaPot);
    Serial.print(",");
    Serial.print(pwmDifuso, 2);
    Serial.print(",");
    Serial.print(pwmHardware);
    Serial.print(",");
    Serial.print(rpmMedidas, 2);
    Serial.print(",");
    Serial.println(omegaRadS, 2);
  }
}
