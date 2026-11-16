%% ========================================================================
%  LANZADOR INTERACTIVO EXCLUSIVO PARA TARJETA 2: ESP32 DEVKIT (3.3V)
%  Compatible con MATLAB R2023a y posteriores
%  ========================================================================
clc;
fprintf('=========================================================================\n');
fprintf('  TARJETA 2: ESP32 DEVKIT V1 (LÓGICA 3.3V, ADC 12 BITS 0-4095 -> 0-1023)\n');
fprintf('  CONTROL DIFUSO DE VELOCIDAD DE MOTOR DC (MATLAB + SIMULINK + ESP32)\n');
fprintf('=========================================================================\n\n');

rootDir = fileparts(mfilename('fullpath'));
parentDir = fileparts(rootDir);
addpath(parentDir);

% 1. Cargar variables del motor y archivo .fis en el Workspace
num_Gp = 24;
den_Gp = [1 11 24];
Gp = tf(num_Gp, den_Gp);
K_lgr = 5.0629;
T_sample = 0.04;
Gp_z = c2d(Gp, T_sample, 'zoh');

fisPath = fullfile(parentDir, 'ControlDifusoMotorDC.fis');
if ~exist(fisPath, 'file')
    fisPath = 'ControlDifusoMotorDC.fis';
end
fis = readfis(fisPath);
assignin('base', 'fis', fis);
assignin('base', 'num_Gp', num_Gp);
assignin('base', 'den_Gp', den_Gp);
assignin('base', 'K_lgr', K_lgr);
assignin('base', 'T_sample', T_sample);

% Mostrar tabla de conversión de escalas para ESP32 (Punto 12 y Punto 8 del PDF)
pot_10bits = [0; 150; 300; 450; 600; 700; 1023];
adc_12bits_esp32 = round(pot_10bits * 4095 / 1023);
volt_3v3_esp32   = (pot_10bits / 1023) * 3.3;
pwm_matlab       = evalfis(fis, pot_10bits);

fprintf('=== TABLA DE ADAPTACIÓN DE ESCALAS PARA ESP32 DEVKIT (3.3V) ===\n');
fprintf('%-10s | %-15s | %-12s | %-12s | %-12s\n', ...
    'Pot(0-1023)', 'ADC ESP32(12b)', 'Voltaje 3.3V', 'PWM MATLAB', 'PWM ESP32(8b)');
fprintf('-------------------------------------------------------------------------\n');
for i = 1:length(pot_10bits)
    fprintf('%-10d | %-15d | %9.2f V  | %-12.2f | %-12d\n', ...
        pot_10bits(i), adc_12bits_esp32(i), volt_3v3_esp32(i), pwm_matlab(i), round(pwm_matlab(i)));
end

% 2. Abrir los 3 modelos de Simulink (formato MATLAB R2023a)
fprintf('\nAbriendo los 3 modelos de Simulink compatibles con MATLAB R2023a...\n');
open_system(fullfile(parentDir, 'Simulink_1_Motor_Sin_Control.slx'));
open_system(fullfile(parentDir, 'Simulink_2_Motor_Con_Control.slx'));
open_system(fullfile(parentDir, 'Simulink_3_Control_Difuso_Motor_Arduino.slx'));

fprintf('\nPara enlazar en vivo con el ESP32 DevKit conectado por USB, ejecuta:\n');
fprintf('  conectar_esp32_matlab_fuzzy\n');
