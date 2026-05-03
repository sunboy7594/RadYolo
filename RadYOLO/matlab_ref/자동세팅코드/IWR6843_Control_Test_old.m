f    clc;
clear all;
close all;

%% 경로 설정
mmWaveStudio_Path = genpath('C:\ti\mmwave_studio_02_01_01_00');
addpath(mmWaveStudio_Path);

%% 레이더 파라미터
Frame_Num = 1;

numADCSamples = 256;
numRx = 4;
numTx = 3;
numVirtualAnt = numTx * numRx;

sampling_rate_sps = 4652E3;

fft_point = 256;
fft_doppler_point = 256;
fft_angle_point = 16;

C = 3E8;
PRI = 60E-6;
BW = 240E6;
Fc = 60E9;

freq_step = 0 : (sampling_rate_sps/fft_point) : (sampling_rate_sps - sampling_rate_sps/fft_point);
range_step = (C * PRI * freq_step) / (2 * BW);

T_doppler = fft_doppler_point * numTx * PRI;
Vres = C * (1/T_doppler) / (2 * Fc);
step_doppler_Vel = -Vres*(fft_doppler_point/2) : Vres : Vres*(fft_doppler_point/2 - 1);

step_Angle_Freq = -fft_angle_point/2 : fft_angle_point/2 - 1;
step_Angle_value = (180 * asin(2 * step_Angle_Freq / fft_angle_point)) / pi;

loadChirp = 255;

%% mmWave Studio 실행
% /lua 플래그 제거 — mmWave Studio가 자동으로 Startup.lua 실행
% Startup.lua 끝에 RSTD.NetStart()가 있어서 포트 2777 자동 오픈됨
[~, mmwave_running] = system('tasklist /FI "IMAGENAME eq mmWaveStudio.exe" 2>NUL | find /I "mmWaveStudio.exe"');
if isempty(strfind(mmwave_running, 'mmWaveStudio.exe'))
    system('"C:\ti\mmwave_studio_02_01_01_00\mmWaveStudio\RunTime\mmWaveStudio.exe" &');
    disp('mmWave Studio 실행 중...');
    pause(5);   % IWR6843_Startup.lua 완료 대기 (보통 2~3초면 충분)
else
    disp('mmWave Studio 이미 실행 중');
    pause(2);
end

%% RSTD NetStart 자동 실행
RSTD_DLL_Path_Temp = 'C:\ti\mmwave_studio_02_01_01_00\mmWaveStudio\Clients\RtttNetClientController\RtttNetClientAPI.dll';
if (strcmp(which('RtttNetClientAPI.RtttNetClient.IsConnected'), ''))
    NET.addAssembly(RSTD_DLL_Path_Temp);
end
RtttNetClientAPI.RtttNetClient.Init();
RtttNetClientAPI.RtttNetClient.Connect('127.0.0.1', 2777);
pause(2);

%% RSTD 연결
RSTD_DLL_Path = 'C:\ti\mmwave_studio_02_01_01_00\mmWaveStudio\Clients\RtttNetClientController\RtttNetClientAPI.dll';

ErrStatus = Init_RSTD_Connection(RSTD_DLL_Path);
while (ErrStatus ~= 30000)
    disp('Error inside Init_RSTD_Connection');
    pause(5);
    ErrStatus = Init_RSTD_Connection(RSTD_DLL_Path);
end

Lua_String = 'WriteToLog("LUA Script for System Check\n", "blue")';
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand(Lua_String);
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(1000)');

%% SOP 리셋 및 COM 포트 연결
ErrCount = 0;
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.SOPControl(2)');
while (ErrStatus ~= 30000)
    disp('SOP Reset Failure');
    pause(3);
    ErrCount = ErrCount + 1;
    if (ErrCount == 3)
        disp('Program End');
        disp('Check your Radar Board');
        break;
    else
        disp('SOP Reset Retry');
        ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.SOPControl(2)');
    end
end
Lua_String = 'WriteToLog("SOP Reset Success\n", "blue")';
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand(Lua_String);
disp('SOP Reset Success');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(1000)');

ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.Connect(13, 921600, 1000)');
while (ErrStatus ~= 30000)
    disp('RS232 Connect Failure');
    pause(3);
    ErrCount = ErrCount + 1;
    if (ErrCount == 3)
        disp('Program End');
        disp('Check COM PORT NUM');
        break;
    else
        disp('RS232 Connect Retry');
        ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.Connect(13, 921600, 1000)');
    end
end
Lua_String = 'WriteToLog("RS232 Connect Success\n", "blue")';
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand(Lua_String);
disp('RS232 Connect Success');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(1000)');

%% 펌웨어 다운로드
Lua_String = 'BSS_FW = "C:\\ti\\mmwave_studio_02_01_01_00\\rf_eval_firmware\\radarss\\xwr68xx_radarss.bin"';
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand(Lua_String);
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.DownloadBSSFw(BSS_FW)');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

Lua_String = 'MSS_FW = "C:\\ti\\mmwave_studio_02_01_01_00\\rf_eval_firmware\\masterss\\xwr68xx_masterss.bin"';
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand(Lua_String);
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.DownloadMSSFw(MSS_FW)');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

%% SPI 연결 및 RF 파워업
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.PowerOn(1, 1000, 0, 0)');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(1000)');

ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.RfEnable()');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(1000)');

%% 파라미터 설정
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.ChanNAdcConfig(1, 1, 1, 1, 1, 1, 1, 2, 1, 0)');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.LPModConfig(0, 0)');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.SetMiscConfig(1, 0, 0, 0)');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.RfInit()');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(1000)');

ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.DataPathConfig(513, 1216644097, 0)');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.LvdsClkConfig(1, 1)');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.LVDSLaneConfig(0, 1, 1, 1, 1, 1, 0, 0)');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

%% Chirp 설정
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.ProfileConfig(0, 60.25, 5, 4.8, 60, 0, 0, 0, 0, 0, 0, 4.0, 1, 256, 4652, 0, 0, 30)');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.ChirpConfig(0, 0, 0, 0, 0, 0, 0, 1, 0, 0)');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.ChirpConfig(1, 1, 0, 0, 0, 0, 0, 0, 1, 0)');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.ChirpConfig(2, 2, 0, 0, 0, 0, 0, 0, 0, 1)');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

%% 프레임 설정
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.FrameConfig(0, 2, 1, 255, 100, 0, 1)');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

%% LAN 연결
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.SelectCaptureDevice("DCA1000")');
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.CaptureCardConfig_EthInit("192.168.33.30", "192.168.33.180", "12:34:56:78:90:12", 4096, 4098)');
if (ErrStatus ~= 30000)
    disp('CaptureCardConfig_EthInit failure');
    disp('LAN Port or IP address Check');
else
    disp('CaptureCardConfig_EthInit Success');
    ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.CaptureCardConfig_Mode(1, 1, 1, 2, 3, 30)');
    ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.CaptureCardConfig_PacketDelay(25)');
end

%% 데이터 수집 및 신호처리 루프
for Frame_Loop = 1:Frame_Num

    ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('data_path = "C:\\ti\\mmwave_studio_02_01_01_00\\mmWaveStudio\\PostProc"');
    ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('adc_data_path = data_path.."\\adc_data.bin"');
    ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('adc_data_path = string.gsub(adc_data_path, ".bin", "")');
    ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(1000)');

    ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('adc_data_path_N = adc_data_path..tostring(0)..".bin"');
    ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.CaptureCardConfig_StartRecord(adc_data_path_N, 1)');
    ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

    disp('Start Record ADC data');
    ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('ar1.StartFrame()');
    ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(2500)');
    pause(5);
    disp('END Record ADC data');

    disp('Start Signal Processing');

    adc_bin_path = 'C:\ti\mmwave_studio_02_01_01_00\mmWaveStudio\PostProc\adc_data0.bin';
    fid = fopen(adc_bin_path, 'r');
    if fid == -1
        error('[DCA1000 오류] ADC 데이터 파일을 찾을 수 없습니다: %s\n→ DCA1000 이더넷 케이블 연결 및 IP(192.168.33.30) 확인 필요', adc_bin_path);
    end
    RawData = fread(fid, [8, loadChirp*numTx*numADCSamples], 'int16');
    fclose(fid);

    adcData = RawData(1:4,:) + sqrt(-1)*RawData(5:8,:);

    for rx = 1:numRx
        Rx_Data(:,:,:,rx) = reshape(adcData(rx,:), numADCSamples, numTx, loadChirp);
    end

    for tx = 1:numTx
        for rx = 1:numRx
            vAnt_idx = (tx-1)*numRx + rx;
            virtual_ant(:,:,vAnt_idx) = squeeze(Rx_Data(:,tx,:,rx));
        end
    end

    range_fft = zeros(fft_point, loadChirp, numVirtualAnt);
    for vAnt = 1:numVirtualAnt
        for chirp = 1:loadChirp
            range_fft(:,chirp,vAnt) = fft(virtual_ant(:,chirp,vAnt), fft_point);
        end
    end

    doppler_fft = zeros(fft_doppler_point, fft_point, numVirtualAnt);
    for vAnt = 1:numVirtualAnt
        for r = 1:fft_point
            doppler_fft(:,r,vAnt) = fftshift(fft(range_fft(r,:,vAnt), fft_doppler_point));
        end
    end

    angle_abs = zeros(fft_angle_point, fft_doppler_point, fft_point);
    for d = 1:fft_doppler_point
        for r = 1:fft_point
            angle_abs(:,d,r) = abs(fftshift(fft(squeeze(doppler_fft(d,r,:)), fft_angle_point)));
        end
    end

    Threshold = 0.01 * 10^2;

    [~, idx] = max(angle_abs(:));
    [ang_i, dop_i, rng_i] = ind2sub(size(angle_abs), idx);

    angle_range_map = squeeze(angle_abs(:, dop_i, :)).';
    angle_range_map(angle_range_map < Threshold) = 0;
    max_v = max(max(angle_range_map));

    Detection_Range(Frame_Loop) = range_step(rng_i);
    Detection_Velocity(Frame_Loop) = step_doppler_Vel(dop_i);
    Detection_Angle(Frame_Loop) = step_Angle_value(ang_i);

    fprintf('Range = %.2f m\n', Detection_Range(Frame_Loop));
    fprintf('Velocity = %.2f m/s\n', Detection_Velocity(Frame_Loop));
    fprintf('Angle = %.2f deg\n', Detection_Angle(Frame_Loop));

    figure(1)
    subplot(3,1,1); plot(Detection_Range(:), '*'); title('Detection Range');
    subplot(3,1,2); plot(Detection_Velocity(:), '*'); title('Detection Velocity');
    subplot(3,1,3); plot(Detection_Angle(:), '*'); title('Detection Angle');

    figure(2);
    surf(step_Angle_value, range_step(1:fft_point), angle_range_map);
    shading interp
    view([0 90])
    axis([-90 90 0 50 0 max_v*1.1])

end


function ErrStatus = Init_RSTD_Connection(RSTD_DLL_Path)
if (strcmp(which('RtttNetClientAPI.RtttNetClient.IsConnected'), ''))
    disp('Adding RSTD Assembly');
    RSTD_Assembly = NET.addAssembly(RSTD_DLL_Path);
    if ~strcmp(RSTD_Assembly.Classes{1}, 'RtttNetClientAPI.RtttClient')
        disp('RSTD Assembly not loaded correctly. Check DLL path');
        ErrStatus = -10;
        return
    end
    needInit = 1;
elseif ~RtttNetClientAPI.RtttNetClient.IsConnected()
    needInit = 1;
else
    needInit = 0;
end
if needInit
    disp('Initializing RSTD client');
    ErrStatus = RtttNetClientAPI.RtttNetClient.Init();
    if (ErrStatus ~= 0)
        disp('Unable to initialize NetClient DLL');
        return;
    end
    disp('Connecting to RSTD client');
    ErrStatus = RtttNetClientAPI.RtttNetClient.Connect('127.0.0.1', 2777);
    if (ErrStatus ~= 0)
        disp('Unable to connect to Radarstudio');
        disp('Reopen port in Radarstudio. Type RSTD.NetClose() followed by RSTD.NetStart()')
        return;
    end
    pause(1);
end
disp('Sending test message to RSTD');
Lua_String = 'WriteToLog("Running script from MATLAB\n", "green")';
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand(Lua_String);
Lua_String = 'WriteToLog("Opening Gpio Control Port()\n", "green")';
ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand(Lua_String);
if (ErrStatus ~= 30000)
    disp('Radarstudio Connection Failed');
end
disp('Test message success');
end
