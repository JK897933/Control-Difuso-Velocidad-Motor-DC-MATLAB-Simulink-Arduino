%% ========================================================================
%  LANZADOR INTERACTIVO EN CUALQUIER PC (SIN ANTIGRAVITY)
%  Actividad 2: Control Difuso de Velocidad de un Motor de CD con Encoder
%  Este script verifica librerías/toolboxes de MATLAB, carga el archivo .fis,
%  abre los 3 modelos de Simulink y ofrece subir el código al Arduino UNO
%  e iniciar la gráfica en tiempo real.
%  ========================================================================
clc;
fprintf('=========================================================================\n');
fprintf('  ACTIVIDAD 2: CONTROL DIFUSO DE VELOCIDAD DE MOTOR DC (MATLAB + ARDUINO)\n');
fprintf('=========================================================================\n\n');

% 1. Verificar Toolboxes requeridos en MATLAB
v = ver;
toolboxes = {v.Name};
req = {'MATLAB', 'Simulink', 'Control System Toolbox', 'Fuzzy Logic Toolbox'};
fprintf('[1/4] Verificando librerías y Toolboxes de MATLAB instalados:\n');
for i = 1:length(req)
    if any(strcmpi(toolboxes, req{i}))
        fprintf('  [OK] %s está instalado.\n', req{i});
    else
        warning('Falta el Toolbox: %s. Instálalo desde MATLAB Add-On Explorer.', req{i});
    end
end

% 2. Cargar el Sistema Difuso (.fis) y variables en el Workspace (Compatible con MATLAB R2023a)
fprintf('\n[2/4] Cargando variables del motor y sistema difuso Mamdani (.fis) para MATLAB R2023a...\n');
num_Gp = 24;
den_Gp = [1 11 24];
Gp = tf(num_Gp, den_Gp);
K_lgr = 5.0629;
T_sample = 0.04;
Gp_z = c2d(Gp, T_sample, 'zoh');

if exist('ControlDifusoMotorDC.fis', 'file')
    fis = readfis('ControlDifusoMotorDC.fis');
    assignin('base', 'fis', fis);
    assignin('base', 'num_Gp', num_Gp);
    assignin('base', 'den_Gp', den_Gp);
    assignin('base', 'K_lgr', K_lgr);
    assignin('base', 'T_sample', T_sample);
    pot_test = [0; 150; 300; 450; 600; 700; 1023];
    pwm_matlab = evalfis(fis, pot_test);
    fprintf('  [OK] ControlDifusoMotorDC.fis cargado en Workspace.\n');
    for i = 1:length(pot_test)
        fprintf('       Pot = %4d  -->  PWM MATLAB = %6.2f\n', pot_test(i), pwm_matlab(i));
    end
else
    run('generar_proyecto_fuzzy_motor.m');
end

% 3. Abrir los 3 Modelos de Simulink para que queden visibles en pantalla
fprintf('\n[3/4] Abriendo los 3 modelos de Simulink en pantalla...\n');
open_system('Simulink_1_Motor_Sin_Control.slx');
open_system('Simulink_2_Motor_Con_Control.slx');
open_system('Simulink_3_Control_Difuso_Motor_Arduino.slx');

% 4. Verificar si hay un Arduino UNO conectado por USB
fprintf('\n[4/4] Buscando placa Arduino UNO en puertos COM...\n');
puertos = serialportlist("available");
if isempty(puertos)
    fprintf('  -> No se detectó Arduino conectado en este momento.\n');
    fprintf('  -> Cuando conectes tu Arduino UNO por USB, ejecuta en Command Window:\n');
    fprintf('       conectar_arduino_matlab_fuzzy\n');
else
    fprintf('  -> Puertos serie detectados: %s\n', join(puertos, ", "));
    % Si existe arduino-cli instalado, ofrecer quemar el .hex automáticamente
    [statusCli, ~] = system('where arduino-cli >nul 2>nul');
    if statusCli ~= 0 && exist('C:\Program Files\Arduino CLI\arduino-cli.exe', 'file')
        setenv('PATH', [getenv('PATH') ';C:\Program Files\Arduino CLI']);
        statusCli = 0;
    end
    if statusCli == 0 && exist(fullfile(pwd, 'Arduino_Control_Difuso_MotorDC', 'build'), 'dir')
        fprintf('  -> Subiendo firmware precompilado al Arduino UNO en %s...\n', puertos(1));
        cmdUpload = sprintf('arduino-cli upload -p %s --fqbn arduino:avr:uno --input-dir "%s"', ...
            puertos(1), fullfile(pwd, 'Arduino_Control_Difuso_MotorDC', 'build'));
        system(cmdUpload);
    end
    fprintf('  -> Para iniciar el control difuso en tiempo real con el motor físico, escribe:\n');
    fprintf('       conectar_arduino_matlab_fuzzy\n');
end
