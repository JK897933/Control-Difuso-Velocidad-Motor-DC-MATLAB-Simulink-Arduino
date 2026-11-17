function sfun_arduino_hil(block)
% SFUN_ARDUINO_HIL  Level-2 MATLAB S-Function para enlazar Simulink 3 en vivo
% con el Arduino UNO (o ESP32) por Puerto Serial USB (ej. COM10) sin
% requerir paquetes adicionales.
%   Entrada (1):  PWM calculado por el bloque Fuzzy Logic Controller (0-255)
%   Salida  (1):  Lectura del Potenciómetro en Arduino A0 (0-1023)
%   Salida  (2):  Velocidad medida por el Encoder en RPM

setup(block);
end

function setup(block)
    block.NumInputPorts  = 1;
    block.NumOutputPorts = 2;

    block.SetPreCompInpPortInfoToDynamic;
    block.SetPreCompOutPortInfoToDynamic;

    block.InputPort(1).Dimensions        = 1;
    block.InputPort(1).DatatypeID        = 0; % double
    block.InputPort(1).Complexity        = 'Real';
    block.InputPort(1).DirectFeedthrough = false; % Evita lazo algebraico

    block.OutputPort(1).Dimensions       = 1;
    block.OutputPort(1).DatatypeID       = 0;
    block.OutputPort(1).Complexity       = 'Real';

    block.OutputPort(2).Dimensions       = 1;
    block.OutputPort(2).DatatypeID       = 0;
    block.OutputPort(2).Complexity       = 'Real';

    block.NumDialogPrms  = 0;
    block.SampleTimes    = [0.04 0]; % T = 40 ms (0.04 s)
    block.SimStateCompliance = 'DefaultSimState';

    block.RegBlockMethod('Start',     @Start);
    block.RegBlockMethod('Outputs',   @Outputs);
    block.RegBlockMethod('Update',    @Update);
    block.RegBlockMethod('Terminate', @Terminate);
end

function Start(block)
    st.s       = [];
    st.lastPot = 0;
    st.lastRPM = 0;
    st.lastPWM = -1;
    st.tLast   = tic;

    % Detectar puerto COM USB real (ignorando puertos Bluetooth)
    puertos = serialportlist("available");
    puertoCOM = "";
    [stPS, outPS] = system('powershell -NoProfile -Command "Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match ''\((COM\d+)\)'' -and $_.DeviceID -notmatch ''^BTHENUM'' } | ForEach-Object { if ($_.Name -match ''\((COM\d+)\)'') { $Matches[1] } } | Select-Object -First 1"');
    if stPS == 0 && ~isempty(strtrim(outPS))
        puertoCOM = string(strtrim(outPS));
    elseif ~isempty(puertos)
        puertoCOM = puertos(end);
    end

    if strlength(puertoCOM) > 0
        try
            fprintf('[Simulink 3 HIL] Conectando con Arduino en %s a 115200 baudios...\n', puertoCOM);
            s = serialport(puertoCOM, 115200, 'Timeout', 1);
            configureTerminator(s, "LF");
            flush(s);
            pause(1.8); % Esperar reinicio del Arduino UNO al abrir el puerto
            st.s = s;
        catch ME
            warning('[Simulink 3 HIL] No se pudo abrir %s (%s). Continuando solo simulación.', puertoCOM, ME.message);
        end
    else
        fprintf('[Simulink 3 HIL] No se detectó Arduino USB. Ejecutando solo simulación.\n');
    end
    set_param(block.BlockHandle, 'UserData', st);
end

function Outputs(block)
    st = get_param(block.BlockHandle, 'UserData');
    if ~isempty(st) && ~isempty(st.s) && isvalid(st.s)
        % Vaciar lecturas viejas para trabajar en tiempo real sin retraso
        while st.s.NumBytesAvailable > 80
            readline(st.s);
        end
        if st.s.NumBytesAvailable > 0
            try
                linea = readline(st.s);
                datos = str2double(split(linea, ","));
                if numel(datos) >= 4 && all(~isnan(datos(1:4)))
                    st.lastPot = datos(1);
                    st.lastRPM = datos(4);
                end
            catch
            end
        end

        % Sincronizar paso de Simulink con el reloj real (0.04 s por paso)
        dt_wait = 0.04 - toc(st.tLast);
        if dt_wait > 0.001
            pause(dt_wait);
        end
        st.tLast = tic;
        set_param(block.BlockHandle, 'UserData', st);
    end

    block.OutputPort(1).Data = st.lastPot;
    block.OutputPort(2).Data = st.lastRPM;
end

function Update(block)
    st = get_param(block.BlockHandle, 'UserData');
    if ~isempty(st) && ~isempty(st.s) && isvalid(st.s)
        pwm_val = round(min(max(block.InputPort(1).Data, 0), 255));
        if pwm_val ~= st.lastPWM
            try
                writeline(st.s, sprintf('P%d', pwm_val));
                st.lastPWM = pwm_val;
                set_param(block.BlockHandle, 'UserData', st);
            catch
            end
        end
    end
end

function Terminate(block)
    st = get_param(block.BlockHandle, 'UserData');
    if ~isempty(st)
        try
            if ~isempty(st.s) && isvalid(st.s)
                writeline(st.s, 'A'); % Regresar Arduino a modo autónomo
                delete(st.s);
            end
        catch
        end
        set_param(block.BlockHandle, 'UserData', []);
    end
    fprintf('[Simulink 3 HIL] Puerto serial cerrado correctamente.\n');
end
