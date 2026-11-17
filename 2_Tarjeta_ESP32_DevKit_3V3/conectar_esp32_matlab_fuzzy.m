%% ========================================================================
%  TARJETA: ESP32 DevKit V1 (Lógica 3.3V, ADC 12 bits 0-4095 -> 0-1023)
%  CONEXIÓN EN TIEMPO REAL: MATLAB (FUZZY .FIS) <---> ESP32 DEVKIT (MOTOR DC)
%  Lee el potenciómetro (escalado de 12 bits a 0-1023) y las RPM del encoder
%  desde el ESP32, evalúa el controlador difuso ControlDifusoMotorDC.fis en
%  MATLAB en vivo, envía la señal PWM (0-255) al ESP32 y grafica la Tabla 8.
%  ========================================================================
clear; clc;

% 1. Cargar el archivo .fis (busca en carpeta actual o en la carpeta raíz)
if exist('ControlDifusoMotorDC.fis', 'file')
    fis = readfis('ControlDifusoMotorDC.fis');
elseif exist(fullfile('..', 'ControlDifusoMotorDC.fis'), 'file')
    fis = readfis(fullfile('..', 'ControlDifusoMotorDC.fis'));
else
    error('No se encontró ControlDifusoMotorDC.fis');
end

% 2. Detectar automáticamente el puerto COM USB real del ESP32 DevKit (ignorando Bluetooth)
puertosDisponibles = serialportlist("available");
if isempty(puertosDisponibles)
    error('No se detectó ningún ESP32 conectado por USB. Conecta el ESP32 DevKit y verifica el driver CP210x/CH340.');
end
puertoCOM = "";
[stPS, outPS] = system('powershell -NoProfile -Command "Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match ''\((COM\d+)\)'' -and $_.DeviceID -notmatch ''^BTHENUM'' } | ForEach-Object { if ($_.Name -match ''\((COM\d+)\)'') { $Matches[1] } } | Select-Object -First 1"');
if stPS == 0 && ~isempty(strtrim(outPS))
    puertoCOM = string(strtrim(outPS));
else
    puertoCOM = puertosDisponibles(end);
end
fprintf('Conectando a ESP32 DevKit (3.3V) en %s a 115200 baudios...\n', puertoCOM);

esp32Obj = serialport(puertoCOM, 115200);
configureTerminator(esp32Obj, "LF");
flush(esp32Obj);
pause(1.5);

% 3. Preparar figura en tiempo real
fig = figure('Name', 'Control Difuso en Tiempo Real: MATLAB + ESP32 DevKit (3.3V)', ...
             'Position', [100 100 950 680], 'Color', 'w');
subplot(3,1,1);
hPot = animatedline('Color', [0 0.45 0.74], 'LineWidth', 1.8);
title('Lectura del Potenciómetro en ESP32 GPIO 34 (3.3V: ADC 0-4095 escalado a 0-1023)');
ylabel('Pot [0-1023]'); ylim([0 1050]); grid on;

subplot(3,1,2);
hPWM = animatedline('Color', [0.85 0.33 0.10], 'LineWidth', 1.8);
title('Salida del Controlador Difuso Mamdani (PWM ESP32 GPIO 25: 0 - 255)');
ylabel('PWM [0-255]'); ylim([0 265]); grid on;

subplot(3,1,3);
hRPM = animatedline('Color', [0.47 0.67 0.19], 'LineWidth', 1.8);
title('Velocidad Real Medida con Encoder GM25-370 a 3.3V (GPIO 18 y GPIO 19)');
xlabel('Tiempo (s)'); ylabel('Velocidad [RPM]'); ylim([0 160]); grid on;

fprintf('Adquiriendo datos del ESP32 en vivo (Presiona Ctrl+C o cierra la ventana para terminar)...\n');
fprintf('%-12s | %-12s | %-12s | %-12s | %-12s\n', ...
    'ADC12(0-4095)', 'Pot(0-1023)', 'PWM MATLAB', 'PWM ESP32', 'RPM Encoder');
fprintf('--------------------------------------------------------------------------\n');

t0 = tic;
while ishandle(fig)
    if esp32Obj.NumBytesAvailable > 0
        linea = readline(esp32Obj);
        datos = str2double(split(linea, ","));
        if numel(datos) >= 5 && all(~isnan(datos(1:5)))
            pot_10bits = datos(1);
            pwm_esp32  = datos(2);
            pwm_hw     = datos(3);
            rpm_val    = datos(4);
            omega_rads = datos(5);
            if numel(datos) >= 6 && ~isnan(datos(6))
                adc_12bits = datos(6);
            else
                adc_12bits = round(pot_10bits * 4095 / 1023);
            end

            % Evaluar el controlador difuso en MATLAB y enviar el PWM al ESP32
            pwm_matlab_live = evalfis(fis, pot_10bits);
            cmdPWM = sprintf('P%d\n', round(pwm_matlab_live));
            writeline(esp32Obj, cmdPWM);

            t_actual = toc(t0);
            addpoints(hPot, t_actual, pot_10bits);
            addpoints(hPWM, t_actual, pwm_matlab_live);
            addpoints(hRPM, t_actual, rpm_val);
            drawnow limitrate;

            fprintf('%-12d | %-12d | %-12.2f | %-12d | %-12.2f\n', ...
                adc_12bits, pot_10bits, pwm_matlab_live, round(pwm_matlab_live), rpm_val);
        end
    end
end

clear esp32Obj;
