%% ========================================================================
%  ACTIVIDAD 2: CONTROL DIFUSO DE VELOCIDAD DE UN MOTOR DE CD
%  Asignatura: Control Avanzado | Grupo: MTR09C
%  Planta del Motor DC con Encoder (Evaluación Unidad 2):
%      Gp(s) = 24 / (s^2 + 11s + 24) = 24 / ((s+3)*(s+8))
%  Controlador Proporcional LGR (OS = 20%):
%      K = 5.0629
%  ========================================================================
clear; clc; close all;

outDir = pwd;
figDir = fullfile(outDir, 'figuras');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

%% 1. PARÁMETROS DEL MOTOR DC Y CONTROLADOR CLÁSICO (PDF 2)
num_Gp = 24;
den_Gp = [1 11 24];
Gp = tf(num_Gp, den_Gp);
K_lgr = 5.0629;        % Ganancia proporcional para OS = 20%
T_sample = 0.04;       % Periodo de muestreo discreto (40 ms)
Gp_z = c2d(Gp, T_sample, 'zoh');

% Escalas del motor físico GM25-370 (12V DC, 140 RPM máx)
V_max = 12.0;          % Voltaje nominal en Puente H (V)
PWM_max = 255.0;       % Escala máxima PWM de 8 bits en Arduino UNO
ADC_max = 1023.0;      % Escala máxima ADC de 10 bits en Arduino UNO (Potenciómetro)
gain_PWM_to_V = V_max / PWM_max;          % 12 / 255 = 0.0470588 V/PWM
gain_rad_to_RPM = 60 / (2 * pi);          % 9.5492966 RPM/(rad/s)
% Nota: Con Gp(0) = 1.0 rad/(s*V), a 12V el modelo entrega:
%   w_ss = 12.0 rad/s -> 114.59 RPM (ó 140 RPM con factor de escala 140/12 = 11.6667 RPM/(rad/s))
gain_w_to_RPM_nominal = 140.0 / 12.0;     % Escala ajustada a 140 RPM nominales a 12V

%% 2. PARTE A: DISEÑO DEL CONTROLADOR DIFUSO (MAMDANI) EN MATLAB
% Según pizarrón y guía de laboratorio:
% - 1 Entrada: Pot (0 - 1023)
%   5 Funciones de membresía: Baja, Media_baja, Media, Media_alta, Alta
% - 1 Salida: Velocidad_PWM (0 - 255)
%   5 Funciones de membresía: Lenta, Media_lenta, Media, Media_Veloz, Veloz

fis = mamfis('Name', 'ControlDifusoMotorDC', ...
             'AndMethod', 'min', ...
             'OrMethod', 'max', ...
             'ImplicationMethod', 'min', ...
             'AggregationMethod', 'max', ...
             'DefuzzificationMethod', 'centroid');

% --- Variable de Entrada: Pot (0 a 1023) ---
fis = addInput(fis, [0 1023], 'Name', 'Pot');
% Vértices equiespaciados (centros en 0, 255.75, 511.5, 767.25, 1023)
% Se usan funciones trapezoidales en los extremos o triangulares puras para cubrir todo el rango
fis = addMF(fis, 'Pot', 'trimf', [-255.75   0.00   255.75], 'Name', 'Baja');
fis = addMF(fis, 'Pot', 'trimf', [   0.00 255.75   511.50], 'Name', 'Media_baja');
fis = addMF(fis, 'Pot', 'trimf', [ 255.75 511.50   767.25], 'Name', 'Media');
fis = addMF(fis, 'Pot', 'trimf', [ 511.50 767.25  1023.00], 'Name', 'Media_alta');
fis = addMF(fis, 'Pot', 'trimf', [ 767.25 1023.00 1278.75], 'Name', 'Alta');

% --- Variable de Salida: Velocidad_PWM (0 a 255) ---
fis = addOutput(fis, [0 255], 'Name', 'Velocidad_PWM');
% Vértices equiespaciados (centros en 0, 63.75, 127.5, 191.25, 255)
% Extendemos los extremos [-63.75 0 63.75] y [191.25 255 318.75] para que el centroide
% cubra desde 0 hasta 255 de manera estrictamente creciente y lineal.
fis = addMF(fis, 'Velocidad_PWM', 'trimf', [-63.75   0.00  63.75], 'Name', 'Lenta');
fis = addMF(fis, 'Velocidad_PWM', 'trimf', [  0.00  63.75 127.50], 'Name', 'Media_lenta');
fis = addMF(fis, 'Velocidad_PWM', 'trimf', [ 63.75 127.50 191.25], 'Name', 'Media');
fis = addMF(fis, 'Velocidad_PWM', 'trimf', [127.50 191.25 255.00], 'Name', 'Media_Veloz');
fis = addMF(fis, 'Velocidad_PWM', 'trimf', [191.25 255.00 318.75], 'Name', 'Veloz');

% --- Base de 5 Reglas de Inferencia ---
% 1. IF Pot is Baja        THEN Velocidad_PWM is Lenta
% 2. IF Pot is Media_baja  THEN Velocidad_PWM is Media_lenta
% 3. IF Pot is Media       THEN Velocidad_PWM is Media
% 4. IF Pot is Media_alta  THEN Velocidad_PWM is Media_Veloz
% 5. IF Pot is Alta        THEN Velocidad_PWM is Veloz
ruleList = [
    1 1 1 1;
    2 2 1 1;
    3 3 1 1;
    4 4 1 1;
    5 5 1 1
];
fis = addRule(fis, ruleList);

% Guardar archivo .fis
fisFile = fullfile(outDir, 'ControlDifusoMotorDC.fis');
writeFIS(fis, fisFile);
fprintf('Archivo FIS guardado exitosamente en: %s\n', fisFile);

% Evaluar el controlador en los valores de prueba de la Tabla de Resultados (Punto 8)
pot_test = [0; 150; 300; 450; 600; 700; 1023];
pwm_matlab = evalfis(fis, pot_test);

fprintf('\n=== EVALUACIÓN EN MATLAB (evalfis) ===\n');
for i = 1:length(pot_test)
    fprintf('Pot = %4d  -->  PWM MATLAB = %6.2f\n', pot_test(i), pwm_matlab(i));
end

%% 3. GRÁFICAS DEL SISTEMA DIFUSO (PARTE A)
% Figura 1: Funciones de Membresía de Entrada y Salida
f1 = figure('Position', [100 100 950 650], 'Color', 'w');
subplot(2,1,1);
plotmf(fis, 'input', 1, 1000);
title('Funciones de Membresía de Entrada: Potenciómetro (0 - 1023 ADC)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Lectura del Potenciómetro (ADC 10 bits)');
ylabel('Grado de pertenencia \mu(x)');
grid on;

subplot(2,1,2);
plotmf(fis, 'output', 1, 1000);
title('Funciones de Membresía de Salida: Velocidad PWM (0 - 255)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Señal de Control PWM (8 bits)');
ylabel('Grado de pertenencia \mu(y)');
grid on;
exportgraphics(f1, fullfile(figDir, 'fig1_funciones_membresia.png'), 'Resolution', 200);

% Figura 2: Curva característica Entrada - Salida del Controlador Difuso
pot_vec = linspace(0, 1023, 500)';
pwm_vec = evalfis(fis, pot_vec);
f2 = figure('Position', [100 100 800 500], 'Color', 'w');
plot(pot_vec, pwm_vec, 'b-', 'LineWidth', 2.2); hold on;
plot(pot_test, pwm_matlab, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
for i = 1:length(pot_test)
    text(pot_test(i)+15, pwm_matlab(i)-6, sprintf('(%d, %.1f)', pot_test(i), pwm_matlab(i)), 'FontSize', 9, 'FontWeight', 'bold');
end
title('Curva Entrada-Salida del Controlador Difuso Mamdani (Pot vs PWM)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Entrada: Lectura del Potenciómetro [0 - 1023]');
ylabel('Salida: Ciclo de Trabajo PWM [0 - 255]');
legend('Curva Característica FIS (Centroide)', 'Puntos de Prueba (Tabla 8)', 'Location', 'northwest');
grid on; xlim([0 1120]); ylim([0 270]);
exportgraphics(f2, fullfile(figDir, 'fig2_curva_entrada_salida_fis.png'), 'Resolution', 200);

%% 4. CREACIÓN DE LOS 3 MODELOS DE SIMULINK
% Asignar variables al base workspace para que Simulink las encuentre
assignin('base', 'fis', fis);
assignin('base', 'num_Gp', num_Gp);
assignin('base', 'den_Gp', den_Gp);
assignin('base', 'K_lgr', K_lgr);
assignin('base', 'T_sample', T_sample);

% =========================================================================
% MODELO 1: Simulink_1_Motor_Sin_Control.slx
% Descripción: Respuesta en lazo abierto (Sin Control) del motor con encoder
%              ante escalón de 12V y escalones de voltaje equivalentes.
% =========================================================================
mdl1 = 'Simulink_1_Motor_Sin_Control';
if bdIsLoaded(mdl1), close_system(mdl1, 0); end
if exist(fullfile(outDir, [mdl1 '.slx']), 'file'), delete(fullfile(outDir, [mdl1 '.slx'])); end
new_system(mdl1);
open_system(mdl1);
set_param(mdl1, 'StopTime', '2.5', 'Solver', 'ode45', 'MaxStep', '0.005');

% Bloques lazo abierto 12V
add_block('simulink/Sources/Step', [mdl1 '/Voltaje_12V'], ...
    'Time', '0', 'Before', '0', 'After', '12', 'Position', [50 80 80 110]);
add_block('simulink/Continuous/Transfer Fcn', [mdl1 '/Motor_DC_Encoder_Gp'], ...
    'Numerator', '[24]', 'Denominator', '[1 11 24]', 'Position', [160 72 270 118]);
add_block('simulink/Math Operations/Gain', [mdl1 '/Rad_s_a_RPM_Teorico'], ...
    'Gain', '60/(2*pi)', 'Position', [340 40 390 75]);
add_block('simulink/Math Operations/Gain', [mdl1 '/Rad_s_a_RPM_Nominal_GM25'], ...
    'Gain', '140/12', 'Position', [340 115 390 150]);
add_block('simulink/Sinks/Scope', [mdl1 '/Scope_Velocidad_Sin_Control'], ...
    'NumInputPorts', '3', 'Position', [480 65 525 135]);
add_block('simulink/Sinks/To Workspace', [mdl1 '/w_rad_s_LA'], ...
    'VariableName', 'w_LA', 'SaveFormat', 'Timeseries', 'Position', [470 175 540 205]);

add_line(mdl1, 'Voltaje_12V/1', 'Motor_DC_Encoder_Gp/1', 'autorouting', 'on');
add_line(mdl1, 'Motor_DC_Encoder_Gp/1', 'Rad_s_a_RPM_Teorico/1', 'autorouting', 'on');
add_line(mdl1, 'Motor_DC_Encoder_Gp/1', 'Scope_Velocidad_Sin_Control/2', 'autorouting', 'on');
add_line(mdl1, 'Motor_DC_Encoder_Gp/1', 'Rad_s_a_RPM_Nominal_GM25/1', 'autorouting', 'on');
add_line(mdl1, 'Rad_s_a_RPM_Teorico/1', 'Scope_Velocidad_Sin_Control/1', 'autorouting', 'on');
add_line(mdl1, 'Rad_s_a_RPM_Nominal_GM25/1', 'Scope_Velocidad_Sin_Control/3', 'autorouting', 'on');
add_line(mdl1, 'Motor_DC_Encoder_Gp/1', 'w_rad_s_LA/1', 'autorouting', 'on');

save_system(mdl1, fullfile(outDir, [mdl1 '.slx']));
simOut1 = sim(mdl1);
close_system(mdl1);
fprintf('Modelo 1 generado y simulado: %s.slx\n', mdl1);

% =========================================================================
% MODELO 2: Simulink_2_Motor_Con_Control.slx
% Descripción: Sistema en lazo cerrado con el Controlador Proporcional K=5.0629
%              sintonizado por LGR (OS = 20%) tanto en tiempo continuo como
%              discretizado con ZOH (T = 0.04 s) según el segundo PDF.
% =========================================================================
mdl2 = 'Simulink_2_Motor_Con_Control';
if bdIsLoaded(mdl2), close_system(mdl2, 0); end
if exist(fullfile(outDir, [mdl2 '.slx']), 'file'), delete(fullfile(outDir, [mdl2 '.slx'])); end
new_system(mdl2);
open_system(mdl2);
set_param(mdl2, 'StopTime', '1.5', 'Solver', 'ode45', 'MaxStep', '0.002');

% Rama 1: Lazo cerrado continuo con K = 5.0629 (Escalón unitario y Escalón 12 rad/s)
add_block('simulink/Sources/Step', [mdl2 '/Referencia_w_ref'], ...
    'Time', '0', 'Before', '0', 'After', '1', 'Position', [40 75 70 105]);
add_block('simulink/Math Operations/Sum', [mdl2 '/Sum_Error_Cont'], ...
    'Inputs', '+-', 'Position', [120 75 145 105]);
add_block('simulink/Math Operations/Gain', [mdl2 '/Controlador_Gc_K'], ...
    'Gain', '5.0629', 'Position', [185 72 245 108]);
add_block('simulink/Continuous/Transfer Fcn', [mdl2 '/Motor_DC_Gp'], ...
    'Numerator', '[24]', 'Denominator', '[1 11 24]', 'Position', [285 67 390 113]);
add_block('simulink/Sinks/Scope', [mdl2 '/Scope_Control_LGR'], ...
    'NumInputPorts', '2', 'Position', [490 70 535 130]);
add_block('simulink/Sinks/To Workspace', [mdl2 '/w_LC_cont'], ...
    'VariableName', 'w_LC_cont', 'SaveFormat', 'Timeseries', 'Position', [480 20 550 50]);

add_line(mdl2, 'Referencia_w_ref/1', 'Sum_Error_Cont/1', 'autorouting', 'on');
add_line(mdl2, 'Sum_Error_Cont/1', 'Controlador_Gc_K/1', 'autorouting', 'on');
add_line(mdl2, 'Controlador_Gc_K/1', 'Motor_DC_Gp/1', 'autorouting', 'on');
add_line(mdl2, 'Motor_DC_Gp/1', 'Scope_Control_LGR/1', 'autorouting', 'on');
add_line(mdl2, 'Motor_DC_Gp/1', 'w_LC_cont/1', 'autorouting', 'on');
add_line(mdl2, 'Motor_DC_Gp/1', 'Sum_Error_Cont/2', 'autorouting', 'on');

% Rama 2: Lazo cerrado discreto ZOH (T = 0.04 s) del Reactivo 4 y 5
add_block('simulink/Math Operations/Sum', [mdl2 '/Sum_Error_Disc'], ...
    'Inputs', '+-', 'Position', [120 205 145 235]);
add_block('simulink/Math Operations/Gain', [mdl2 '/Controlador_K_Disc'], ...
    'Gain', '5.0629', 'SampleTime', '0.04', 'Position', [185 202 245 238]);
add_block('simulink/Discrete/Discrete Transfer Fcn', [mdl2 '/Motor_DC_Gp_z_ZOH'], ...
    'Numerator', '[0.016617 0.014351]', 'Denominator', '[1 -1.613069 0.643936]', ...
    'SampleTime', '0.04', 'Position', [285 197 425 243]);
add_block('simulink/Sinks/To Workspace', [mdl2 '/w_LC_disc'], ...
    'VariableName', 'w_LC_disc', 'SaveFormat', 'Timeseries', 'Position', [480 205 550 235]);

add_line(mdl2, 'Referencia_w_ref/1', 'Sum_Error_Disc/1', 'autorouting', 'on');
add_line(mdl2, 'Sum_Error_Disc/1', 'Controlador_K_Disc/1', 'autorouting', 'on');
add_line(mdl2, 'Controlador_K_Disc/1', 'Motor_DC_Gp_z_ZOH/1', 'autorouting', 'on');
add_line(mdl2, 'Motor_DC_Gp_z_ZOH/1', 'Scope_Control_LGR/2', 'autorouting', 'on');
add_line(mdl2, 'Motor_DC_Gp_z_ZOH/1', 'w_LC_disc/1', 'autorouting', 'on');
add_line(mdl2, 'Motor_DC_Gp_z_ZOH/1', 'Sum_Error_Disc/2', 'autorouting', 'on');

save_system(mdl2, fullfile(outDir, [mdl2 '.slx']));
simOut2 = sim(mdl2);
close_system(mdl2);
fprintf('Modelo 2 generado y simulado: %s.slx\n', mdl2);

% =========================================================================
% MODELO 3: Simulink_3_Control_Difuso_Motor_Arduino.slx
% Descripción: Modelo completo de la Parte B y C del PDF 1:
%   1) Cadena de Simulación: Entrada Simulada (Rampa 0->1023 o Constante)
%      -> Ganancia de Escalado (1) -> Fuzzy Logic Controller (fis)
%      -> Saturación (0 a 255) -> Conversión PWM a Voltaje (12/255)
%      -> Modelo del Motor DC Gp(s) = 24/(s^2+11s+24) -> Conversión a RPM -> Scope.
%   2) Comparación en paralelo de la respuesta con Lazo Cerrado y Lazo Abierto.
%   3) Bloque de Interfaz de Hardware para Arduino UNO (Lectura A0 -> FIS -> PWM Pin 9).
% =========================================================================
mdl3 = 'Simulink_3_Control_Difuso_Motor_Arduino';
if bdIsLoaded(mdl3), close_system(mdl3, 0); end
if exist(fullfile(outDir, [mdl3 '.slx']), 'file'), delete(fullfile(outDir, [mdl3 '.slx'])); end
new_system(mdl3);
open_system(mdl3);
set_param(mdl3, 'StopTime', '10.0', 'Solver', 'ode45', 'MaxStep', '0.01');

% --- Subsistema / Cadena Principal Parte B: Entrada Rampa y Constante ---
add_block('simulink/Sources/Ramp', [mdl3 '/Entrada_Rampa_Pot_0_1023'], ...
    'Slope', '102.3', 'Start', '0', 'InitialOutput', '0', 'Position', [40 60 75 95]);
add_block('simulink/Sources/Constant', [mdl3 '/Entrada_Constante_Pot'], ...
    'Value', '600', 'Position', [40 130 75 165]);
add_block('simulink/Signal Routing/Manual Switch', [mdl3 '/Selector_Rampa_o_Constante'], ...
    'sw', '1', 'Position', [115 82 145 128]);

add_block('simulink/Math Operations/Gain', [mdl3 '/Ganancia_Escalado_ADC'], ...
    'Gain', '1', 'Position', [180 88 225 122]);
add_block('simulink/Discontinuities/Saturation', [mdl3 '/Lim_ADC_0_1023'], ...
    'UpperLimit', '1023', 'LowerLimit', '0', 'Position', [255 88 290 122]);

% Cargar la librería fuzblock e inspeccionar el nombre exacto del bloque Fuzzy Logic Controller
load_system('fuzblock');
fuzBlks = find_system('fuzblock', 'SearchDepth', 1);
for kb = 1:length(fuzBlks)
    fprintf('  Bloque en fuzblock [%d]: %s\n', kb, strrep(fuzBlks{kb}, newline, ' '));
end
fuzBlockPath = sprintf('fuzblock/Fuzzy Logic \nController');
add_block(fuzBlockPath, [mdl3 '/Fuzzy_Logic_Controller_Mamdani'], ...
    'FIS', 'fis', 'Position', [330 80 410 130]);

add_block('simulink/Discontinuities/Saturation', [mdl3 '/Saturacion_PWM_0_255'], ...
    'UpperLimit', '255', 'LowerLimit', '0', 'Position', [450 88 485 122]);

% Adaptación de escala PWM (0-255) a Voltaje de armadura del Puente H (0-12V)
add_block('simulink/Math Operations/Gain', [mdl3 '/Driver_L293D_PWM_a_Voltaje'], ...
    'Gain', '12/255', 'Position', [525 85 585 125]);

% Planta del Motor DC con Encoder del PDF 2: Gp(s) = 24 / (s^2 + 11s + 24)
add_block('simulink/Continuous/Transfer Fcn', [mdl3 '/Modelo_Motor_DC_Gp'], ...
    'Numerator', '[24]', 'Denominator', '[1 11 24]', 'Position', [625 82 730 128]);

% Conversión de rad/s a RPM (140 RPM nominales a 12V del GM25-370, y conversión física 60/(2*pi))
add_block('simulink/Math Operations/Gain', [mdl3 '/Encoder_rad_s_a_RPM'], ...
    'Gain', '140/12', 'Position', [770 85 830 125]);

% Scopes y salidas a Workspace
add_block('simulink/Sinks/Scope', [mdl3 '/Scope_Fuzzy_Motor'], ...
    'NumInputPorts', '4', 'Position', [900 55 950 155]);
add_block('simulink/Sinks/To Workspace', [mdl3 '/Pot_Simulink'], ...
    'VariableName', 'pot_sim', 'SaveFormat', 'Timeseries', 'Position', [330 20 400 50]);
add_block('simulink/Sinks/To Workspace', [mdl3 '/PWM_Simulink'], ...
    'VariableName', 'pwm_sim', 'SaveFormat', 'Timeseries', 'Position', [520 20 590 50]);
add_block('simulink/Sinks/To Workspace', [mdl3 '/w_rad_Simulink'], ...
    'VariableName', 'w_rad_sim', 'SaveFormat', 'Timeseries', 'Position', [765 20 835 50]);
add_block('simulink/Sinks/To Workspace', [mdl3 '/RPM_Simulink'], ...
    'VariableName', 'rpm_sim', 'SaveFormat', 'Timeseries', 'Position', [890 180 960 210]);

% Conexiones de la cadena Fuzzy + Motor (Sin control / lazo directo desde Fuzzy)
add_line(mdl3, 'Entrada_Rampa_Pot_0_1023/1', 'Selector_Rampa_o_Constante/1', 'autorouting', 'on');
add_line(mdl3, 'Entrada_Constante_Pot/1', 'Selector_Rampa_o_Constante/2', 'autorouting', 'on');
add_line(mdl3, 'Selector_Rampa_o_Constante/1', 'Ganancia_Escalado_ADC/1', 'autorouting', 'on');
add_line(mdl3, 'Ganancia_Escalado_ADC/1', 'Lim_ADC_0_1023/1', 'autorouting', 'on');
add_line(mdl3, 'Lim_ADC_0_1023/1', 'Fuzzy_Logic_Controller_Mamdani/1', 'autorouting', 'on');
add_line(mdl3, 'Lim_ADC_0_1023/1', 'Pot_Simulink/1', 'autorouting', 'on');
add_line(mdl3, 'Lim_ADC_0_1023/1', 'Scope_Fuzzy_Motor/1', 'autorouting', 'on');
add_line(mdl3, 'Fuzzy_Logic_Controller_Mamdani/1', 'Saturacion_PWM_0_255/1', 'autorouting', 'on');
add_line(mdl3, 'Saturacion_PWM_0_255/1', 'Driver_L293D_PWM_a_Voltaje/1', 'autorouting', 'on');
add_line(mdl3, 'Saturacion_PWM_0_255/1', 'PWM_Simulink/1', 'autorouting', 'on');
add_line(mdl3, 'Saturacion_PWM_0_255/1', 'Scope_Fuzzy_Motor/2', 'autorouting', 'on');
add_line(mdl3, 'Driver_L293D_PWM_a_Voltaje/1', 'Modelo_Motor_DC_Gp/1', 'autorouting', 'on');
add_line(mdl3, 'Modelo_Motor_DC_Gp/1', 'Encoder_rad_s_a_RPM/1', 'autorouting', 'on');
add_line(mdl3, 'Modelo_Motor_DC_Gp/1', 'w_rad_Simulink/1', 'autorouting', 'on');
add_line(mdl3, 'Modelo_Motor_DC_Gp/1', 'Scope_Fuzzy_Motor/3', 'autorouting', 'on');
add_line(mdl3, 'Encoder_rad_s_a_RPM/1', 'Scope_Fuzzy_Motor/4', 'autorouting', 'on');
add_line(mdl3, 'Encoder_rad_s_a_RPM/1', 'RPM_Simulink/1', 'autorouting', 'on');

% --- Cadena adicional en el mismo modelo: Lazo Cerrado Fuzzy + Controlador K ---
% Convierte la salida deseada del Fuzzy (escalada a velocidad de referencia 0-12 rad/s)
% y cierra el lazo con el sensor encoder y ganancia K = 5.0629
add_block('simulink/Math Operations/Gain', [mdl3 '/PWM_a_Ref_w_rad_s'], ...
    'Gain', '12/255', 'Position', [525 260 585 300]);
add_block('simulink/Math Operations/Sum', [mdl3 '/Sum_Feedback_Encoder'], ...
    'Inputs', '+-', 'Position', [620 265 645 295]);
add_block('simulink/Math Operations/Gain', [mdl3 '/Controlador_K_LGR'], ...
    'Gain', '5.0629', 'Position', [675 262 735 298]);
add_block('simulink/Continuous/Transfer Fcn', [mdl3 '/Motor_DC_Lazo_Cerrado'], ...
    'Numerator', '[24]', 'Denominator', '[1 11 24]', 'Position', [765 257 860 303]);
add_block('simulink/Math Operations/Gain', [mdl3 '/Encoder_LC_a_RPM'], ...
    'Gain', '140/12', 'Position', [890 260 945 300]);
add_block('simulink/Sinks/To Workspace', [mdl3 '/RPM_LC_Fuzzy_Sim'], ...
    'VariableName', 'rpm_lc_sim', 'SaveFormat', 'Timeseries', 'Position', [970 265 1040 295]);

add_line(mdl3, 'Saturacion_PWM_0_255/1', 'PWM_a_Ref_w_rad_s/1', 'autorouting', 'on');
add_line(mdl3, 'PWM_a_Ref_w_rad_s/1', 'Sum_Feedback_Encoder/1', 'autorouting', 'on');
add_line(mdl3, 'Sum_Feedback_Encoder/1', 'Controlador_K_LGR/1', 'autorouting', 'on');
add_line(mdl3, 'Controlador_K_LGR/1', 'Motor_DC_Lazo_Cerrado/1', 'autorouting', 'on');
add_line(mdl3, 'Motor_DC_Lazo_Cerrado/1', 'Encoder_LC_a_RPM/1', 'autorouting', 'on');
add_line(mdl3, 'Motor_DC_Lazo_Cerrado/1', 'Sum_Feedback_Encoder/2', 'autorouting', 'on');
add_line(mdl3, 'Encoder_LC_a_RPM/1', 'RPM_LC_Fuzzy_Sim/1', 'autorouting', 'on');

% Simular con entrada Rampa (0 a 1023 en 10 segundos)
simOut3_rampa = sim(mdl3);

% Evaluar en Simulink cada uno de los valores constantes de la Tabla 8 (0, 150, 300, 450, 600, 700, 1023)
set_param([mdl3 '/Selector_Rampa_o_Constante'], 'sw', '0'); % Cambiar a entrada constante
set_param(mdl3, 'StopTime', '2.5');

pwm_simulink_table = zeros(size(pot_test));
w_simulink_table   = zeros(size(pot_test));
rpm_simulink_table = zeros(size(pot_test));

for i = 1:length(pot_test)
    set_param([mdl3 '/Entrada_Constante_Pot'], 'Value', num2str(pot_test(i)));
    simOut_const = sim(mdl3);
    pwm_simulink_table(i) = simOut_const.pwm_sim.Data(end);
    w_simulink_table(i)   = simOut_const.w_rad_sim.Data(end);
    rpm_simulink_table(i) = simOut_const.rpm_sim.Data(end);
end

% Dejar el modelo listo en modo Rampa (StopTime = 10 s) y guardarlo
set_param([mdl3 '/Selector_Rampa_o_Constante'], 'sw', '1');
set_param(mdl3, 'StopTime', '10.0');
save_system(mdl3, fullfile(outDir, [mdl3 '.slx']));
close_system(mdl3);
fprintf('Modelo 3 generado y simulado: %s.slx\n', mdl3);

%% 5. GENERAR GRÁFICAS DE LAS SIMULACIONES DE SIMULINK
% Figura 3: Comparación Modelo 1 (Sin Control) vs Modelo 2 (Con Control Continuo y Discreto ZOH)
f3 = figure('Position', [100 100 950 620], 'Color', 'w');
subplot(2,1,1);
plot(simOut1.w_LA.Time, simOut1.w_LA.Data, 'b-', 'LineWidth', 2.2); hold on;
yline(12.0, 'r--', 'Régimen Permanente \omega_{ss} = 12.0 rad/s (140 RPM)', 'LineWidth', 1.5);
title('Simulink 1 (Sin Control / Lazo Abierto): Respuesta del Motor DC ante Escalón de 12V', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Tiempo (segundos)');
ylabel('\omega(t) [rad/s]');
grid on; legend('Respuesta Lazo Abierto G_p(s)', 'Valor Final 12.0 rad/s', 'Location', 'southeast');

subplot(2,1,2);
plot(simOut2.w_LC_cont.Time, simOut2.w_LC_cont.Data, 'b-', 'LineWidth', 2.0); hold on;
stairs(simOut2.w_LC_disc.Time, simOut2.w_LC_disc.Data, 'r-', 'LineWidth', 1.6);
yline(1.0, 'k:', 'Referencia Unitaria r(t) = 1.0', 'LineWidth', 1.2);
yline(5.0629/(1+5.0629), 'g--', 'Estado Estable c_{ss} = 0.8351 (e_{ss} = 16.49%)', 'LineWidth', 1.2);
title('Simulink 2 (Con Control K = 5.0629): Lazo Cerrado Continuo vs Discreto ZOH (T = 0.04 s, OS = 20%)', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Tiempo (segundos)');
ylabel('Velocidad Normalizada c(t)');
grid on; legend('Lazo Cerrado Continuo T_p(s)', 'Lazo Cerrado Discreto ZOH (T=40ms)', 'Referencia', 'Estado Estable', 'Location', 'southeast');
exportgraphics(f3, fullfile(figDir, 'fig3_simulink_sin_control_y_con_control.png'), 'Resolution', 200);

% Figura 4: Respuesta del Modelo 3 (Control Difuso en Simulink ante Entrada Rampa y Constantes)
f4 = figure('Position', [100 100 950 750], 'Color', 'w');
subplot(3,1,1);
plot(simOut3_rampa.pot_sim.Time, simOut3_rampa.pot_sim.Data, 'k-', 'LineWidth', 2);
title('Simulink 3 (Control Difuso): Entrada Rampa del Potenciómetro (0 \rightarrow 1023 ADC)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Potenciómetro [ADC]'); grid on;

subplot(3,1,2);
plot(simOut3_rampa.pwm_sim.Time, simOut3_rampa.pwm_sim.Data, 'm-', 'LineWidth', 2);
title('Salida del Bloque Fuzzy Logic Controller en Simulink: Señal PWM (0 \rightarrow 255)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('PWM [8 bits]'); grid on;

subplot(3,1,3);
plot(simOut3_rampa.rpm_sim.Time, simOut3_rampa.rpm_sim.Data, 'b-', 'LineWidth', 2.2); hold on;
plot(simOut3_rampa.rpm_lc_sim.Time, simOut3_rampa.rpm_lc_sim.Data, 'r--', 'LineWidth', 1.8);
title('Respuesta de Velocidad del Motor DC GM25-370 con Encoder (RPM)', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Tiempo (segundos)');
ylabel('Velocidad [RPM]');
legend('Fuzzy Directo a Planta G_p(s)', 'Fuzzy + Lazo Cerrado K=5.0629', 'Location', 'northwest');
grid on;
exportgraphics(f4, fullfile(figDir, 'fig4_simulink_control_difuso_rampa.png'), 'Resolution', 200);

% Figura 5: Respuesta ante las 7 entradas constantes de la tabla
f5 = figure('Position', [100 100 900 500], 'Color', 'w');
hold on;
colors = lines(length(pot_test));
load_system(fullfile(outDir, [mdl3 '.slx']));
set_param(mdl3, 'StopTime', '2.5');
set_param([mdl3 '/Selector_Rampa_o_Constante'], 'sw', '0');
for i = 1:length(pot_test)
    set_param([mdl3 '/Entrada_Constante_Pot'], 'Value', num2str(pot_test(i)));
    s_i = sim(mdl3);
    plot(s_i.rpm_sim.Time, s_i.rpm_sim.Data, 'LineWidth', 1.8, 'Color', colors(i,:), ...
        'DisplayName', sprintf('Pot = %4d -> PWM = %5.1f -> %.1f RPM', pot_test(i), pwm_simulink_table(i), rpm_simulink_table(i)));
end
close_system(mdl3, 0);
title('Simulink 3: Respuesta del Motor con Control Difuso para Entradas Constantes (Tabla 8)', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Tiempo (segundos)');
ylabel('Velocidad del Motor [RPM]');
legend('Location', 'eastoutside');
grid on;
exportgraphics(f5, fullfile(figDir, 'fig5_simulink_entradas_constantes.png'), 'Resolution', 200);

%% 6. IMPRIMIR TABLA DE RESULTADOS COMPLETA
fprintf('\n=========================================================================================\n');
fprintf('  TABLA DE RESULTADOS (PUNTO 8 DEL REPORTE)\n');
fprintf('=========================================================================================\n');
fprintf('%-8s | %-12s | %-14s | %-14s | %-14s | %-14s\n', ...
    'Pot', 'PWM MATLAB', 'PWM Simulink', 'PWM Hardware*', 'w_ss (rad/s)', 'RPM Motor (GM25)');
fprintf('-----------------------------------------------------------------------------------------\n');
for i = 1:length(pot_test)
    pwm_hw = round(pwm_matlab(i));
    % Considerando zona muerta típica de ~30 PWM en hardware real para referencia
    if pwm_hw < 25
        rpm_hw_est = 0.0;
    else
        rpm_hw_est = rpm_simulink_table(i);
    end
    fprintf('%-8d | %-12.2f | %-14.2f | %-14d | %-14.2f | %-14.2f\n', ...
        pot_test(i), pwm_matlab(i), pwm_simulink_table(i), pwm_hw, w_simulink_table(i), rpm_simulink_table(i));
end
fprintf('=========================================================================================\n');
