/*
 * ============================================================================
 * PROYECTO OFICIAL EN ESP-IDF (C NATIVO + FreeRTOS)
 * TARJETA: ESP32 DevKit V1 (Lógica 3.3V)
 * ACTIVIDAD 2: CONTROL DIFUSO DE VELOCIDAD DE UN MOTOR DE CD CON ENCODER
 * Asignatura: Control Avanzado | Grupo: MTR09C | UPA
 *
 * PERIFÉRICOS NATIVOS DE ESP-IDF UTILIZADOS:
 *   1) ADC1 (12 bits: 0 - 4095, Atenuación 11dB / 12dB para 0 - 3.3V)
 *      -> Canal ADC1_CHANNEL_6 (GPIO 34): Lectura del Potenciómetro 10k.
 *      -> Escalado automático a 10 bits (0 - 1023) para el Controlador Difuso.
 *   2) LEDC (LED Control PWM de Hardware en ESP-IDF)
 *      -> GPIO 25, Timer 0, Modo Low Speed, Frecuencia 5000 Hz, Resolución 8 bits (0 - 255).
 *   3) GPIO + Interrupción en RAM (IRAM_ATTR)
 *      -> GPIO 18 (Fase A Encoder - Flanco de subida + Pull-up 47k a 3.3V)
 *      -> GPIO 19 (Fase B Encoder - Lectura de dirección)
 *      -> GPIO 26 (IN1 Puente H = 1), GPIO 27 (IN2 Puente H = 0)
 *   4) UART0 / Consola Serial (115200 baudios)
 *      -> Envía telemetría CSV cada T = 40 ms (0.04 s) hacia MATLAB:
 *         pot_10bits,pwm_fis,pwm_hw,rpm,rad_s,adc_12bits_raw
 *      -> Recibe comandos PWM en vivo desde MATLAB ("P<valor>\n" o "A\n").
 * ============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "driver/ledc.h"
#include "driver/uart.h"
#include "esp_timer.h"
#include "esp_attr.h"
#include "esp_idf_version.h"

/* Compatibilidad automática entre ESP-IDF v4.x (driver/adc.h) y ESP-IDF v5.x (esp_adc/adc_oneshot.h) */
#if ESP_IDF_VERSION >= ESP_IDF_VERSION_VAL(5, 0, 0)
#include "esp_adc/adc_oneshot.h"
static adc_oneshot_unit_handle_t adc1_handle;
#else
#include "driver/adc.h"
#endif

// --- DEFINICIÓN DE PINES EN ESP32 DEVKIT (3.3V) PARA ESP-IDF ---
#define GPIO_POT_ADC        34                  // GPIO 34 -> ADC1_CHANNEL_6 (Solo entrada, 0 - 3.3V)
#define ADC_POT_CHANNEL     ADC_CHANNEL_6       // Canal 6 del ADC1 corresponde a GPIO 34
#define GPIO_ENC_A          GPIO_NUM_18         // GPIO 18 -> Fase A Encoder (Cable Amarillo + Pull-up 47k a 3.3V)
#define GPIO_ENC_B          GPIO_NUM_19         // GPIO 19 -> Fase B Encoder (Cable Verde)
#define GPIO_PUENTE_H_ENA   GPIO_NUM_25         // GPIO 25 -> Salida PWM LEDC hacia ENA del Puente H
#define GPIO_PUENTE_H_IN1   GPIO_NUM_26         // GPIO 26 -> Dirección IN1 del Puente H
#define GPIO_PUENTE_H_IN2   GPIO_NUM_27         // GPIO 27 -> Dirección IN2 del Puente H

// --- CONFIGURACIÓN DEL PERIFÉRICO LEDC PWM (8 BITS: 0 - 255, 5 kHz) ---
#define LEDC_TIMER          LEDC_TIMER_0
#define LEDC_MODE           LEDC_LOW_SPEED_MODE
#define LEDC_CHANNEL        LEDC_CHANNEL_0
#define LEDC_DUTY_RES       LEDC_TIMER_8_BIT    // Resolución de 8 bits (0 a 255) igual que en MATLAB .fis
#define LEDC_FREQUENCY      5000                // 5 kHz para el Puente H L298N / L293D

// --- PARÁMETROS DEL MOTOR GM25-370 Y PERIODO DE MUESTREO (T = 0.04 s = 40 ms) ---
#define PULSOS_POR_VUELTA   374.0f              // 11 PPR * reducción 1:34 del GM25-370 (140 RPM a 12V)
#define T_MUESTREO_MS       40                  // T = 0.04 s (igual que en la Transformada Z del PDF 2)
#ifndef M_PI
#define M_PI                3.14159265358979323846f
#endif

static volatile int32_t contador_pulsos = 0;
static int pwm_externo_matlab = -1; // Si >= 0, aplica el PWM enviado por MATLAB en vivo

// --- RUTINA DE INTERRUPCIÓN (ISR EN IRAM) PARA EL ENCODER EN ESP-IDF ---
static void IRAM_ATTR encoder_isr_handler(void *arg)
{
    int nivel_b = gpio_get_level(GPIO_ENC_B);
    if (nivel_b == 1) {
        contador_pulsos++;
    } else {
        contador_pulsos--;
    }
}

// --- FUNCIÓN DE MEMBRESÍA TRIANGULAR μ(x; a, b, c) ---
static float trimf(float x, float a, float b, float c)
{
    if (x <= a || x >= c) return 0.0f;
    else if (x == b) return 1.0f;
    else if (x < b) return (x - a) / (b - a);
    else return (c - x) / (c - b);
}

// --- MOTOR DE INFERENCIA DIFUSA MAMDANI EN C (IDÉNTICO A ControlDifusoMotorDC.fis) ---
// 1 Entrada: Pot [0, 1023] -> 5 Funciones: Baja, Media_baja, Media, Media_alta, Alta
// 1 Salida:  PWM [0, 255]  -> 5 Funciones: Lenta, Media_lenta, Media, Media_Veloz, Veloz
// Operador AND / Implicación: min | Agregación: max | Defuzzificación: Centroide
static float evaluar_control_difuso_mamdani(float pot)
{
    float mu_in[5];
    mu_in[0] = trimf(pot, -255.75f,    0.00f,  255.75f); // Baja
    mu_in[1] = trimf(pot,    0.00f,  255.75f,  511.50f); // Media_baja
    mu_in[2] = trimf(pot,  255.75f,  511.50f,  767.25f); // Media
    mu_in[3] = trimf(pot,  511.50f,  767.25f, 1023.00f); // Media_alta
    mu_in[4] = trimf(pot,  767.25f, 1023.00f, 1278.75f); // Alta

    const float out_a[5] = {-63.75f,   0.00f,  63.75f, 127.50f, 191.25f};
    const float out_b[5] = {  0.00f,  63.75f, 127.50f, 191.25f, 255.00f};
    const float out_c[5] = { 63.75f, 127.50f, 191.25f, 255.00f, 318.75f};

    const int N_PUNTOS = 201;
    const float dy = 255.0f / (float)(N_PUNTOS - 1);
    float num = 0.0f;
    float den = 0.0f;

    for (int k = 0; k < N_PUNTOS; k++) {
        float y = (float)k * dy;
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

// --- INICIALIZACIÓN DE PERIFÉRICOS EN ESP-IDF ---
static void inicializar_perifericos_espidf(void)
{
    // 1. Configurar GPIOs de dirección del Puente H (IN1 = GPIO 26, IN2 = GPIO 27)
    gpio_config_t io_conf_dir = {
        .intr_type = GPIO_INTR_DISABLE,
        .mode = GPIO_MODE_OUTPUT,
        .pin_bit_mask = (1ULL << GPIO_PUENTE_H_IN1) | (1ULL << GPIO_PUENTE_H_IN2),
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .pull_up_en = GPIO_PULLUP_DISABLE
    };
    gpio_config(&io_conf_dir);
    gpio_set_level(GPIO_PUENTE_H_IN1, 1); // Sentido de giro horario fijo
    gpio_set_level(GPIO_PUENTE_H_IN2, 0);

    // 2. Configurar GPIOs del Encoder (GPIO 18 con interrupción RISING, GPIO 19 entrada)
    gpio_config_t io_conf_enc_a = {
        .intr_type = GPIO_INTR_POSEDGE,
        .mode = GPIO_MODE_INPUT,
        .pin_bit_mask = (1ULL << GPIO_ENC_A),
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .pull_up_en = GPIO_PULLUP_ENABLE
    };
    gpio_config(&io_conf_enc_a);

    gpio_config_t io_conf_enc_b = {
        .intr_type = GPIO_INTR_DISABLE,
        .mode = GPIO_MODE_INPUT,
        .pin_bit_mask = (1ULL << GPIO_ENC_B),
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .pull_up_en = GPIO_PULLUP_ENABLE
    };
    gpio_config(&io_conf_enc_b);

    gpio_install_isr_service(0);
    gpio_isr_handler_add(GPIO_ENC_A, encoder_isr_handler, NULL);

    // 3. Configurar PWM con el periférico LEDC de ESP-IDF en GPIO 25 (8 bits: 0 - 255)
    ledc_timer_config_t ledc_timer = {
        .speed_mode       = LEDC_MODE,
        .timer_num        = LEDC_TIMER,
        .duty_resolution  = LEDC_DUTY_RES,
        .freq_hz          = LEDC_FREQUENCY,
        .clk_cfg          = LEDC_AUTO_CLK
    };
    ledc_timer_config(&ledc_timer);

    ledc_channel_config_t ledc_channel = {
        .speed_mode     = LEDC_MODE,
        .channel        = LEDC_CHANNEL,
        .timer_sel      = LEDC_TIMER,
        .intr_type      = LEDC_INTR_DISABLE,
        .gpio_num       = GPIO_PUENTE_H_ENA,
        .duty           = 0,
        .hpoint         = 0
    };
    ledc_channel_config(&ledc_channel);

    // 4. Configurar ADC1 Canal 6 (GPIO 34) a 12 bits (0 - 4095) para rango 0 - 3.3V
#if ESP_IDF_VERSION >= ESP_IDF_VERSION_VAL(5, 0, 0)
    adc_oneshot_unit_init_cfg_t init_config1 = {
        .unit_id = ADC_UNIT_1,
    };
    adc_oneshot_new_unit(&init_config1, &adc1_handle);

    adc_oneshot_chan_cfg_t config = {
        .bitwidth = ADC_BITWIDTH_12,
        .atten = ADC_ATTEN_DB_12,
    };
    adc_oneshot_config_channel(adc1_handle, ADC_POT_CHANNEL, &config);
#else
    adc1_config_width(ADC_WIDTH_BIT_12);
    adc1_config_channel_atten(ADC1_CHANNEL_6, ADC_ATTEN_DB_11);
#endif

    // 5. Configurar UART0 (115200 baudios) para enlace no bloqueante con MATLAB
    uart_config_t uart_config = {
        .baud_rate = 115200,
        .data_bits = UART_DATA_8_BITS,
        .parity    = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
        .source_clk = UART_SCLK_DEFAULT,
    };
    uart_driver_install(UART_NUM_0, 256, 0, 0, NULL, 0);
    uart_param_config(UART_NUM_0, &uart_config);
}

static int leer_adc_12bits_gpio34(void)
{
    int raw = 0;
#if ESP_IDF_VERSION >= ESP_IDF_VERSION_VAL(5, 0, 0)
    adc_oneshot_read(adc1_handle, ADC_POT_CHANNEL, &raw);
#else
    raw = adc1_get_raw(ADC1_CHANNEL_6);
#endif
    if (raw < 0) raw = 0;
    if (raw > 4095) raw = 4095;
    return raw;
}

// --- TAREA PRINCIPAL DE CONTROL DIFUSO EN FREERTOS (PERIODO EXACTO T = 40 ms) ---
void app_main(void)
{
    inicializar_perifericos_espidf();

    uint8_t rx_buf[64];
    int64_t t_anterior_us = esp_timer_get_time();
    TickType_t xLastWakeTime = xTaskGetTickCount();
    const TickType_t xFrequency = pdMS_TO_TICKS(T_MUESTREO_MS);

    while (1) {
        vTaskDelayUntil(&xLastWakeTime, xFrequency);

        // 1. Verificar si MATLAB envió comando PWM por UART0 ("P150\n" o "A\n")
        int len = uart_read_bytes(UART_NUM_0, rx_buf, sizeof(rx_buf) - 1, 0);
        if (len > 0) {
            rx_buf[len] = '\0';
            if (rx_buf[0] == 'P' || rx_buf[0] == 'p') {
                int val = atoi((const char *)&rx_buf[1]);
                if (val < 0) val = 0;
                if (val > 255) val = 255;
                pwm_externo_matlab = val;
            } else if (rx_buf[0] == 'A' || rx_buf[0] == 'a') {
                pwm_externo_matlab = -1;
            }
        }

        // 2. Calcular dt exacto en segundos
        int64_t t_actual_us = esp_timer_get_time();
        float dt = (float)(t_actual_us - t_anterior_us) / 1000000.0f;
        if (dt <= 0.0f) dt = 0.04f;
        t_anterior_us = t_actual_us;

        // 3. Leer y reiniciar contador de pulsos del encoder
        int32_t pulsos = contador_pulsos;
        contador_pulsos = 0;
        if (pulsos < 0) pulsos = -pulsos;

        // 4. Calcular velocidad angular en RPM y rad/s
        float rpm_medidas = ((float)pulsos / PULSOS_POR_VUELTA) * (60.0f / dt);
        float omega_rads  = rpm_medidas * (2.0f * M_PI / 60.0f);

        // 5. Leer Potenciómetro en GPIO 34 (ADC 12 bits: 0 - 4095 a 3.3V)
        //    y escalar al universo de discurso [0, 1023] del controlador difuso (Punto 12 del PDF)
        int adc_12bits = leer_adc_12bits_gpio34();
        float pot_escalado = ((float)adc_12bits * 1023.0f) / 4095.0f;
        int pot_10bits = (int)lroundf(pot_escalado);
        if (pot_10bits < 0) pot_10bits = 0;
        if (pot_10bits > 1023) pot_10bits = 1023;

        // 6. Evaluar el Controlador Difuso Mamdani (0 - 255)
        float pwm_difuso = evaluar_control_difuso_mamdani(pot_escalado);

        // 7. Actualizar el ciclo de trabajo PWM en el periférico LEDC (GPIO 25)
        int pwm_hw = (pwm_externo_matlab >= 0) ? pwm_externo_matlab : (int)lroundf(pwm_difuso);
        if (pwm_hw < 0) pwm_hw = 0;
        if (pwm_hw > 255) pwm_hw = 255;

        ledc_set_duty(LEDC_MODE, LEDC_CHANNEL, (uint32_t)pwm_hw);
        ledc_update_duty(LEDC_MODE, LEDC_CHANNEL);

        // 8. Imprimir trama CSV hacia MATLAB / Monitor de ESP-IDF:
        // Formato: pot_10bits,pwm_fis,pwm_hw,rpm,rad_s,adc_12bits_raw
        printf("%d,%.2f,%d,%.2f,%.2f,%d\n",
               pot_10bits, pwm_difuso, pwm_hw, rpm_medidas, omega_rads, adc_12bits);
    }
}
