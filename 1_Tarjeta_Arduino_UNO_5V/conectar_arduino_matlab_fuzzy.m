%% ========================================================================
%  CONEXIÓN EN TIEMPO REAL: MATLAB (FUZZY .FIS) <---> ARDUINO UNO (MOTOR DC)
%  Lee el potenciómetro y las RPM del encoder desde el Arduino UNO,
%  evalúa el controlador difuso ControlDifusoMotorDC.fis en MATLAB en vivo,
%  envía la señal PWM de regreso al Arduino UNO y grafica/registra la Tabla 8.
%  ========================================================================
clear; clc;

% 1. Cargar el archivo .fis generado
fis = readfis('ControlDifusoMotorDC.fis');

% 2. Detectar automáticamente el puerto COM USB real del Arduino UNO (ignorando puertos Bluetooth)
puertosDisponibles = serialportlist("available");
if isempty(puertosDisponibles)
    error('No se detectó ningún Arduino conectado por USB. Conecta el Arduino UNO y verifica el puerto COM.');
end
puertoCOM = "";
[stPS, outPS] = system('powershell -NoProfile -Command "Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match ''\((COM\d+)\)'' -and $_.DeviceID -notmatch ''^BTHENUM'' } | ForEach-Object { if ($_.Name -match ''\((COM\d+)\)'') { $Matches[1] } } | Select-Object -First 1"');
if stPS == 0 && ~isempty(strtrim(outPS))
    puertoCOM = string(strtrim(outPS));
else
    puertoCOM = puertosDisponibles(end);
end
fprintf('Conectando a Arduino UNO en %s a 115200 baudios...\n', puertoCOM);

arduinoObj = serialport(puertoCOM, 115200);
configureTerminator(arduinoObj, "LF");
flush(arduinoObj);
pause(2.0); % Esperar reinicio del Arduino UNO

% 3. Preparar figura en tiempo real
fig = figure('Name', 'Control Difuso en Tiempo Real: MATLAB + Arduino UNO', ...
             'Position', [100 100 950 650], 'Color', 'w');
subplot(3,1,1);
hPot = animatedline('Color', 'k', 'LineWidth', 1.8);
title('Lectura del Potenciómetro en Arduino UNO (A0: 0 - 1023)');
ylabel('ADC [0-1023]'); ylim([0 1050]); grid on;

subplot(3,1,2);
hPWM = animatedline('Color', 'm', 'LineWidth', 1.8);
title('Salida del Controlador Difuso Mamdani (PWM Pin 9: 0 - 255)');
ylabel('PWM [0-255]'); ylim([0 265]); grid on;

subplot(3,1,3);
hRPM = animatedline('Color', 'b', 'LineWidth', 1.8);
title('Velocidad Real Medida con Encoder GM25-370 (Pin 2 y 3)');
xlabel('Tiempo (s)'); ylabel('Velocidad [RPM]'); ylim([0 160]); grid on;

fprintf('Adquiriendo datos en vivo (Presiona Ctrl+C o cierra la ventana para terminar)...\n');
fprintf('%-10s | %-12s | %-12s | %-12s\n', 'Pot (ADC)', 'PWM MATLAB', 'PWM Arduino', 'RPM Encoder');
fprintf('-------------------------------------------------------------\n');

t0 = tic;
lastSentPWM = -1;
while ishandle(fig)
    if arduinoObj.NumBytesAvailable > 0
        % Descartar tramas viejas acumuladas para evitar retraso ("reacciona tarde")
        while arduinoObj.NumBytesAvailable > 80
            readline(arduinoObj);
        end
        linea = readline(arduinoObj);
        datos = str2double(split(linea, ","));
        if numel(datos) == 5 && all(~isnan(datos))
            pot_val    = datos(1);
            pwm_ino    = datos(2);
            pwm_hw     = datos(3);
            rpm_val    = datos(4);
            omega_rads = datos(5);

            % Evaluar el controlador difuso directamente en MATLAB y enviarlo al Arduino
            pwm_matlab_live = evalfis(fis, pot_val);
            pwm_int = round(pwm_matlab_live);
            if pwm_int ~= lastSentPWM
                writeline(arduinoObj, sprintf('P%d', pwm_int));
                lastSentPWM = pwm_int;
            end

            t_actual = toc(t0);
            addpoints(hPot, t_actual, pot_val);
            addpoints(hPWM, t_actual, pwm_matlab_live);
            addpoints(hRPM, t_actual, rpm_val);
            drawnow limitrate;

            fprintf('%-10d | %-12.2f | %-12d | %-12.2f\n', ...
                pot_val, pwm_matlab_live, pwm_int, rpm_val);
        end
    end
end

try
    writeline(arduinoObj, 'A'); % Devolver control autónomo al Arduino al cerrar
catch
end
clear arduinoObj;
