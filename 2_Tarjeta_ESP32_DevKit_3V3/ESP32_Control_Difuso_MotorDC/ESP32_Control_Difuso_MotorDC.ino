/*
 * ============================================================================
 * TARJETA: ESP32 DevKit V1 (Lógica 3.3V)
 * ACTIVIDAD 2: CONTROL DIFUSO DE VELOCIDAD DE UN MOTOR DE CD CON ENCODER
 * Asignatura: Control Avanzado | Grupo: MTR09C
 *
 * ¡IMPORTANTE! ADAPTACIÓN DE ESCALAS (Punto 12 del PDF) PARA ESP32 3.3V:
 *   1) Voltaje lógico: 3.3V (Potenciómetro y Encoder alimentados a 3.3V, ¡NUNCA 5V!).
 *   2) Escala ADC del ESP32: 12 bits nativa (0 - 4095) para 0 - 3.3V.
 *      Se adapta internamente a la escala del controlador difuso (0 - 1023)
 *      mediante: pot_10bits = (adc_12bits * 1023.0) / 4095.0 (o analogReadResolution(10)).
 *   3) Salida PWM en ESP32: Canal LEDC / analogWrite de 8 bits (0 - 255) a 5 kHz.
 *
 * CONEXIÓN DE PINES EN ESP32 DEVKIT (3.3V):
 *   - GPIO 34 (ADC1_CH6) : Cursor del Potenciómetro 10k (Extremos a 3.3V y GND)
 *   - GPIO 18            : Fase A Encoder (Cable Amarillo) + Pull-up 47k a 3.3V
 *   - GPIO 19            : Fase B Encoder (Cable Verde)
 *   - GPIO 25            : ENA Puente H (PWM Velocidad Motor 1 - quitar jumper ENA)
 *   - GPIO 26            : IN1 Puente H (Dirección 1)
 *   - GPIO 27            : IN2 Puente H (Dirección 2)
 *   - Pin 3V3            : Alimentación 3.3V para Potenciómetro y Cable Azul Encoder
 *   - Pin GND            : Tierra común (Unida con GND del Puente H y Fuente 12V)
 * ============================================================================
 */

#include <Arduino.h>

// --- DEFINICIÓN DE PINES EXCLUSIVOS PARA ESP32 DEVKIT (3.3V) ---
const int PIN_POT   = 34;  // GPIO 34 (Entrada Analógica ADC1_CH6, solo entrada, 0 - 3.3V)
const int PIN_ENC_A = 18;  // GPIO 18 (Fase A Encoder - Cable Amarillo + Pull-up 47k a 3.3V)
const int PIN_ENC_B = 19;  // GPIO 19 (Fase B Encoder - Cable Verde)
const int PIN_ENA   = 25;  // GPIO 25 (Salida PWM hacia pin ENA del Puente H)
const int PIN_IN1   = 26;  // GPIO 26 (Salida digital hacia IN1 del Puente H)
const int PIN_IN2   = 27;  // GPIO 27 (Salida digital hacia IN2 del Puente H)

// --- PARÁMETROS DEL ENCODER Y MUESTREO (T = 0.04 s = 40 ms según PDF 2) ---
const float PULSOS_POR_VUELTA = 374.0;  // Motor GM25-370 (11 PPR * reducción 1:34)
const unsigned long T_MUESTREO_MS = 40; // T = 0.04 s (40 ms)

volatile long contadorPulsos = 0;
unsigned long ultimoTiempo = 0;

int lecturaADC_12bits = 0; // Lectura nativa del ESP32 (0 - 4095 para 0 - 3.3V)
int lecturaPot_10bits = 0; // Escala adaptada al FIS de MATLAB (0 - 1023)
float pwmDifuso = 0.0;
int pwmHardware = 0;
int pwmExternoMatlab = -1; // Si >= 0, aplica el PWM enviado en vivo por MATLAB
float rpmMedidas = 0.0;
float omegaRadS  = 0.0;

// --- INTERRUPCIÓN EN RAM (IRAM_ATTR REQUERIDO EN ESP32) ---
void IRAM_ATTR ISR_EncoderA() {
  if (digitalRead(PIN_ENC_B) == HIGH) {
    contadorPulsos++;
  } else {
    contadorPulsos--;
  }
}

// --- FUNCIÓN DE PERTENENCIA TRIANGULAR μ(x; a, b, c) ---
float trimf(float x, float a, float b, float c) {
  if (x <= a || x >= c) return 0.0f;
  else if (x == b) return 1.0f;
  else if (x < b) return (x - a) / (b - a);
  else return (c - x) / (c - b);
}

// --- EVALUACIÓN DEL CONTROLADOR DIFUSO MAMDANI (IDÉNTICO A MATLAB .FIS) ---
// Entrada: pot en escala [0, 1023]
// Salida:  Velocidad_PWM en escala [0, 255]
float evaluarControlDifusoMamdani(float pot) {
  float mu_in[5];
  mu_in[0] = trimf(pot, -255.75f,    0.00f,  255.75f); // Baja
  mu_in[1] = trimf(pot,    0.00f,  255.75f,  511.50f); // Media_baja
  mu_in[2] = trimf(pot,  255.75f,  511.50f,  767.25f); // Media
  mu_in[3] = trimf(pot,  511.50f,  767.25f, 1023.00f); // Media_alta
  mu_in[4] = trimf(pot,  767.25f, 1023.00f, 1278.75f); // Alta

  const float out_a[5] = {-63.75f,   0.00f,  63.75f, 127.50f, 191.25f};
  const float out_b[5] = {  0.00f,  63.75f, 127.50f, 191.25f, 255.00f};
  const float out_c[5] = { 63.75f, 127.50f, 191.25f, 255.00f, 318.75f};

  const int N_PUNTOS = 201; // Mayor resolución en ESP32 gracias a su FPU de 32 bits (240 MHz)
  const float dy = 255.0f / (N_PUNTOS - 1);
  float num = 0.0f;
  float den = 0.0f;

  for (int k = 0; k < N_PUNTOS; k++) {
    float y = k * dy;
    float mu_agg = 0.0f;

    for (int r = 0; r < 5; r++) {
      if (mu_in[r] > 0.0f) {
        float mu_out_r = trimf(y, out_a[r], out_b[r], out_c[r]);
        float recorte = (mu_in[r] < mu_out_r) ? mu_in[r] : mu_out_r;
        if (recorte > mu_agg) {
          mu_agg = recorte;
        }
      }
    }
    num += y * mu_agg;
    den += mu_agg;
  }

  if (den == 0.0f) return 0.0f;
  float y_centroide = num / den;
  if (y_centroide < 0.0f)   y_centroide = 0.0f;
  if (y_centroide > 255.0f) y_centroide = 255.0f;
  return y_centroide;
}

void setup() {
  Serial.begin(115200);

  // Configurar resolución ADC del ESP32 a 12 bits (0 - 4095 para 0 - 3.3V)
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db); // Rango completo hasta ~3.3V

  // Configurar pines de dirección del Puente H
  pinMode(PIN_IN1, OUTPUT);
  pinMode(PIN_IN2, OUTPUT);
  pinMode(PIN_ENA, OUTPUT);

  // Sentido de giro fijo hacia adelante
  digitalWrite(PIN_IN1, HIGH);
  digitalWrite(PIN_IN2, LOW);
  analogWrite(PIN_ENA, 0);

  // Configurar pines del Encoder (alimentado a 3.3V para proteger los GPIOs del ESP32)
  pinMode(PIN_ENC_A, INPUT_PULLUP);
  pinMode(PIN_ENC_B, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(PIN_ENC_A), ISR_EncoderA, RISING);

  ultimoTiempo = millis();
}

void loop() {
  // Recibir comando PWM en vivo desde MATLAB/Simulink si está conectado ("P150\n" o "A\n")
  if (Serial.available() > 0) {
    char cmd = Serial.read();
    if (cmd == 'P' || cmd == 'p') {
      pwmExternoMatlab = Serial.parseInt();
      pwmExternoMatlab = constrain(pwmExternoMatlab, 0, 255);
    } else if (cmd == 'A' || cmd == 'a') {
      pwmExternoMatlab = -1;
    }
  }

  unsigned long ahora = millis();
  if (ahora - ultimoTiempo >= T_MUESTREO_MS) {
    float dt = (ahora - ultimoTiempo) / 1000.0f;
    ultimoTiempo = ahora;

    // 1. Leer pulsos acumulados del encoder
    noInterrupts();
    long pulsos = contadorPulsos;
    contadorPulsos = 0;
    interrupts();

    // 2. Calcular velocidad en RPM y rad/s
    rpmMedidas = (abs(pulsos) / PULSOS_POR_VUELTA) * (60.0f / dt);
    omegaRadS  = rpmMedidas * (2.0f * PI / 60.0f);

    // 3. Leer ADC de 12 bits (0-4095 a 3.3V) y adaptar escala a 10 bits (0-1023)
    //    (Cumple el Punto 12 del PDF: "Adaptar las escalas de ADC y PWM a la plataforma elegida")
    lecturaADC_12bits = analogRead(PIN_POT);
    float pot_escalado = (lecturaADC_12bits * 1023.0f) / 4095.0f;
    lecturaPot_10bits = constrain((int)round(pot_escalado), 0, 1023);

    // 4. Evaluar el Controlador Difuso Mamdani (0 - 255)
    pwmDifuso = evaluarControlDifusoMamdani(pot_escalado);

    // 5. Aplicar señal PWM (0 - 255) en GPIO 25 hacia ENA del Puente H
    if (pwmExternoMatlab >= 0) {
      pwmHardware = pwmExternoMatlab;
    } else {
      pwmHardware = (int)round(pwmDifuso);
    }
    pwmHardware = constrain(pwmHardware, 0, 255);
    analogWrite(PIN_ENA, pwmHardware);

    // 6. Enviar trama CSV hacia MATLAB / Monitor Serie (compatible con conectar_esp32_matlab_fuzzy.m):
    // Formato: pot_10bits,pwm_fis,pwm_hw,rpm,rad_s,adc_12bits_raw
    Serial.print(lecturaPot_10bits);
    Serial.print(",");
    Serial.print(pwmDifuso, 2);
    Serial.print(",");
    Serial.print(pwmHardware);
    Serial.print(",");
    Serial.print(rpmMedidas, 2);
    Serial.print(",");
    Serial.print(omegaRadS, 2);
    Serial.print(",");
    Serial.println(lecturaADC_12bits);
  }
}
