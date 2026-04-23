clc;
clear all;
close all;

%####################################################################################
% 명령어를 불러오기 위한 경로 설정
mmWaveStudio_Path = genpath('C:\ti\mmwave_studio_03_00_00_14');
addpath(mmWaveStudio_Path);

%####################################################################################
% 레이다 신호처리를 위한 파라메타 설정
% change based on sensor config
Frame_Num  = 1;  % 프레임 반복 횟수 지정 필요 기본값 1

numADCBits = 16; % number of ADC bits per sample
numADCSamples = 256; % number of ADC samples per chirp
numRx = 4; % number of receivers
numLanes = 4; % do not change. number of lanes is always 2
isReal = 0; % set to 1 if real only data, 0 if complex data0
sampling_rate_sps=4652E3;    n_adc_samples=256;
n_chirps=255 * 5;              n_frame=1;
slope_Hz_per_sec=4E6;

fft_point = 256;
fft_doppler_point = 256;
fft_3D_point = 16;
C=3E8;
PRI = 60E-6;
BW = 240E6;
Fc=77E9;
freq_step = [0:(sampling_rate_sps/fft_point): (sampling_rate_sps)-(sampling_rate_sps/fft_point)]; % (+) 주파수만
range_step = ((C*PRI*freq_step)/(2*BW));

T_doppler=fft_doppler_point*PRI; 

Vres=C*(1/T_doppler)/(2*Fc)/5;%5로 나눈 이유는 TBF가 5개이기 때문임.
step_doppler_Vel=[-1*Vres*(fft_doppler_point/2):Vres:Vres*(fft_doppler_point/2-1)];

step_Angle_Freq=-fft_3D_point/2:fft_3D_point/2-1/2;
step_Angle_value = (180*(asin(2*step_Angle_Freq/fft_3D_point)))/pi;


loadChirp =255;
Dopplerbin = 256;
BeamAngle = 5;
Anglebin = 16;
Rangebin = numADCSamples;

%####################################################################################
% mmWave Studio 호출

[status, cmdout]=system("C:\Users\Public\Desktop\mmWave Studio 03.00.00.14.lnk &");
%system('Taskkill/IM cmd.exe');

%####################################################################################
%======================================================================================
% RSTD 연결
% Initialize Radarstudio .NET connection
RSTD_DLL_Path = 'C:\ti\mmwave_studio_03_00_00_14\mmWaveStudio\Clients\RtttNetClientController\RtttNetClientAPI.dll';

ErrStatus = Init_RSTD_Connection(RSTD_DLL_Path);
while (ErrStatus ~= 30000)
    disp('Error inside Init_RSTD_Connection');
    pause(5);
    ErrStatus = Init_RSTD_Connection(RSTD_DLL_Path);
    
end

Lua_String = 'WriteToLog("LUA Script for System Check\n", "blue")';
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand(Lua_String);
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(1000)');

%======================================================================================
% 제어 보드 리셋 및 Com 포트 연결
ErrCount =0;
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.SOPControl(2)');
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
     ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.SOPControl(2)');
     end
   
end
Lua_String = 'WriteToLog("SOP Reset Success\n", "blue")';
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand(Lua_String);
disp('SOP Reset Success');
 
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(1000)');

ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.Connect(13,921600,1000)');
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
     ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.Connect(13,921600,1000)');
     end
   
end
Lua_String = 'WriteToLog("RS232 Connect Success\n", "blue")';
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand(Lua_String);
disp('RS232 Connect Success');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(1000)');

%======================================================================================
% Download Firmware
Lua_String = 'BSS_FW    = "C:\\ti\\mmwave_studio_03_00_00_14\\rf_eval_firmware\\AWR2243_ES1_0\\radarss\\xwr22xx_radarss.bin"';
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand(Lua_String);
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.DownloadBSSFw(BSS_FW)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

Lua_String = 'MSS_FW    = "C:\\ti\\mmwave_studio_03_00_00_14\\rf_eval_firmware\\AWR2243_ES1_0\\masterss\\xwr22xx_masterss.bin"';
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand(Lua_String);
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.DownloadMSSFw(MSS_FW)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

%======================================================================================
% SPI Connect & RF Power UP
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.PowerOn(1, 1000, 0, 0)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.RfEnable()');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

%======================================================================================
% Parameter Setup
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.ChanNAdcConfig(1, 1, 1, 1, 1, 1, 1, 2, 1, 0)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.RfLdoBypassConfig(0x1)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.LPModConfig(0, 0)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.SetMiscConfig(1, 0, 0, 0)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.RfInit()');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(1000)');

ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.DataPathConfig(513, 1216644097, 0)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.LvdsClkConfig(1, 1)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.LVDSLaneConfig(0, 1, 1, 1, 1, 1, 0, 0)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

%======================================================================================
% Chirp Config
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.ProfileConfig(0, 76.0100021, 5, 4.8, 60, 0, 0, 0, 0, 0, 0, 4.007, 1, 256, 4652, 0, 0, 108)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.ChirpConfig(0, 0, 0, 0, 0, 0, 0, 1, 1, 1)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.ChirpConfig(1, 1, 0, 0, 0, 0, 0, 1, 1, 1)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.ChirpConfig(2, 2, 0, 0, 0, 0, 0, 1, 1, 1)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.ChirpConfig(3, 3, 0, 0, 0, 0, 0, 1, 1, 1)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.ChirpConfig(4, 4, 0, 0, 0, 0, 0, 1, 1, 1)');

ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.SetPerChirpPhaseShifterConfig(0, 0, 0, 32, 1)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.SetPerChirpPhaseShifterConfig(1, 1, 0, 47, 30)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.SetPerChirpPhaseShifterConfig(2, 2, 0, 0, 0)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.SetPerChirpPhaseShifterConfig(3, 3, 0, 16, 33)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.SetPerChirpPhaseShifterConfig(4, 4, 0, 31, 62)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

%======================================================================================
% Frame Config
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.FrameConfig(0, 4, 1, 255, 100, 0, 1)');
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

%======================================================================================
% LAN connect
ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.SelectCaptureDevice("DCA1000")');

ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.CaptureCardConfig_EthInit("192.168.33.30", "192.168.33.180", "12:34:56:78:90:12", 4096, 4098)');
if (ErrStatus ~= 30000)
     disp('CaptureCardConfig_EthInit failure');
     disp('LAN Port or IP address Check');    
     else
      disp('CaptureCardConfig_EthInit Success');
     ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.CaptureCardConfig_Mode(1, 1, 1, 2, 3, 30)');
     ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.CaptureCardConfig_PacketDelay(25)');
end
   
%======================================
% Frame_Num 횟수 만큼 데이터 획득 및 신호처리 반복함
for Frame_Loop = 1: Frame_Num 

    %======================================================================================
    % ADC Data File Path
    ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('data_path     = "C:\\ti\\mmwave_studio_03_00_00_14\\mmWaveStudio\\PostProc"');
    ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('adc_data_path  = data_path.."\\adc_data.bin"');
    ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('adc_data_path = string.gsub(adc_data_path, ".bin","");');
    ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(1000)');
    %======================================================================================
    % Start Record ADC data
    ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('adc_data_path_N=adc_data_path..tostring(0)..".bin"');
    ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.CaptureCardConfig_StartRecord(adc_data_path_N, 1)');
    ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(100)');

    disp('Start Record ADC data');
    ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.StartFrame()');
    ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('RSTD.Sleep(2500)');

    %ErrStatus =RtttNetClientAPI.RtttNetClient.SendCommand('ar1.StartMatlabPostProc(adc_data_path_N)');
    pause(5);
    disp('END Record ADC data');
    %####################################################################################
    % DGIST 신호처리 시작
    %======================================================================================
    % 파일 로드
    % 필요시 경로 수정을 해야 됨
    disp('Start Signal Processing');
   fid = fopen('C:\ti\mmwave_studio_03_00_00_14\mmWaveStudio\PostProc\adc_data0.bin','r');
  % fid = fopen('D:\Work\TechB_Project\2차년도\코모텍 RF 테스트\2022_06_14\코모텍 모듈 데이터\adc_data0.bin','r');
    RawData = fread(fid,[8,loadChirp*5*256] ,'int16');
   
    fclose(fid);

    %======================================================================================
    % 데이터 분류
    % organize data by LVDS lane
    % for real only data
 
    adcData = RawData([1,2,3,4],:) + sqrt(-1)*RawData([5,6,7,8],:);

    Rx_1_Data =reshape(adcData(1,:),numADCSamples,BeamAngle,loadChirp);
    Rx_2_Data =reshape(adcData(2,:),numADCSamples,BeamAngle,loadChirp);
    Rx_3_Data =reshape(adcData(3,:),numADCSamples,BeamAngle,loadChirp);
    Rx_4_Data =reshape(adcData(4,:),numADCSamples,BeamAngle,loadChirp);
    
    full_sum(:,:,1) = squeeze(Rx_1_Data(:,1,:))+  squeeze(Rx_1_Data(:,2,:)) + squeeze(Rx_1_Data(:,3,:)) + squeeze(Rx_1_Data(:,4,:)) + squeeze(Rx_1_Data(:,5,:));
    full_sum(:,:,2) =squeeze(Rx_2_Data(:,1,:)) + squeeze(Rx_2_Data(:,2,:)) + squeeze(Rx_2_Data(:,3,:)) + squeeze(Rx_2_Data(:,4,:)) + squeeze(Rx_2_Data(:,5,:));
    full_sum(:,:,3) =squeeze(Rx_3_Data(:,1,:)) + squeeze(Rx_3_Data(:,2,:)) + squeeze(Rx_3_Data(:,3,:)) + squeeze(Rx_3_Data(:,4,:)) + squeeze(Rx_3_Data(:,5,:));
    full_sum(:,:,4) =squeeze(Rx_4_Data(:,1,:)) + squeeze(Rx_4_Data(:,2,:)) + squeeze(Rx_4_Data(:,3,:)) + squeeze(Rx_4_Data(:,4,:)) + squeeze(Rx_4_Data(:,5,:));


    %======================================================================================
    % Range FFT & ABS
    for i = 1:numRx
        for Ramp = 1:255
       
            D1_full_sum_fft_data(i,Ramp,:) = fft(full_sum(20:250,Ramp,i),256);
            D1_full_sum_abs_data(i,Ramp,:) = abs(D1_full_sum_fft_data(i,Ramp,:));
        end

    end


    %======================================================================================
    % Doppler FFT & ABS
    for i = 1:4
        for sample = 1:256

            D2_full_sum_fft_data(i,:,sample) = fftshift(fft(D1_full_sum_fft_data(i,:,sample),256));
        end

    end

    %======================================================================================
    % Angle FFT & ABS
    for Ramp = 1: 256
        for Sample = 1:256


            D3_full_sum_fft_data(:,Ramp,Sample) = fftshift(fft(D2_full_sum_fft_data(:,Ramp,Sample),16));
       
            D3_full_sum_abs_data(:,Ramp,Sample) = abs(D3_full_sum_fft_data(:,Ramp,Sample));

             end

    end


    %======================================================================================
    % Target Detection
    [dist_max_v,dist_max_i]=max(squeeze(abs(D2_full_sum_fft_data(3,:,:))));
    [vel_max_v,vel_max_i]=max(dist_max_v);
    doppler_peak_index=dist_max_i(vel_max_i);
    aaa = squeeze(D3_full_sum_abs_data(:,doppler_peak_index,:));

    Threshold=0.01*10^2;

    % Angle,Ramp,Sample

    D3_full_sum_abs_data_plot_tmp=squeeze(D3_full_sum_abs_data(:,doppler_peak_index,1:end)).';
    D3_full_sum_abs_data_plot_index=find(D3_full_sum_abs_data_plot_tmp>Threshold);
    D3_full_sum_abs_data_plot=zeros(size(D3_full_sum_abs_data_plot_tmp,1),size(D3_full_sum_abs_data_plot_tmp,2));
    D3_full_sum_abs_data_plot(D3_full_sum_abs_data_plot_index)=D3_full_sum_abs_data_plot_tmp(D3_full_sum_abs_data_plot_index);


    % Angle,Ramp,Sample


    %======================================================================================
    % Target Detection Display
    max_v=max(max(D3_full_sum_abs_data_plot));

    
    [s1 s2 s3] = size(D3_full_sum_abs_data);
    [maxval, ind] =max(reshape(D3_full_sum_abs_data(:), s1*s2, []));
    [i, j] =ind2sub([s1 s2], ind);
    x = [maxval' i' j'];
    [val Target_det] = max(x(:,1,1));

    Detection_Range(Frame_Loop) = range_step(Target_det);
    Detection_Velocity(Frame_Loop) = step_doppler_Vel(x(Target_det,3));
    Detection_Angle(Frame_Loop) = step_Angle_value(x(Target_det,2));


    dis_range = sprintf('Range = %f\n',range_step(Target_det));
    dis_velocity = sprintf('Velocity = %f\n',step_doppler_Vel(x(Target_det,3)));
    dis_angle = sprintf('Angle = %f\n',step_Angle_value(x(Target_det,2)));
    disp(dis_range);
    disp(dis_velocity);
    disp(dis_angle);

    figure(1)
    subplot(3,1,1)
    plot(Detection_Range(:),'*');
   title('Detection Range');
    subplot(3,1,2)
    plot(Detection_Velocity(:),'*');
      title('Detection Velocity');
    subplot(3,1,3)
    plot(Detection_Angle(:),'*');
    title('Detection Angle');
    
    
 figure(2);surf(step_Angle_value, range_step(1:end), D3_full_sum_abs_data_plot);
    shading interp
    view([0 90])
     axis([-100 80 0 180 0 max_v*1.1])
 %   axis([-50 50 0 15 0 max_v*1.1])
end %Frame Loop end




function ErrStatus = Init_RSTD_Connection(RSTD_DLL_Path)
%This script establishes the connection with Radarstudio software
%   Pre-requisites:
%   Type RSTD.NetStart() in Radarstudio Luashell before running the script. This would open port 2777
%   Returns 30000 if no error.

if (strcmp(which('RtttNetClientAPI.RtttNetClient.IsConnected'),'')) %First time the code is run after opening MATLAB
    disp('Adding RSTD Assembly');
    RSTD_Assembly = NET.addAssembly(RSTD_DLL_Path);
    if ~strcmp(RSTD_Assembly.Classes{1},'RtttNetClientAPI.RtttClient')
        disp('RSTD Assembly not loaded correctly. Check DLL path');
        ErrStatus = -10;
        return
    end
    Init_RSTD_Connection = 1;
elseif ~RtttNetClientAPI.RtttNetClient.IsConnected() %Not the first time but port is diconnected
    % Reason:
    % Init will reset the value of Isconnected. Hence Isconnected should be checked before Init
    % However, Isconnected returns null for the 1st time after opening MATLAB (since init was never called before)
    Init_RSTD_Connection = 1;
else
    Init_RSTD_Connection = 0;
end
if Init_RSTD_Connection
    disp('Initializing RSTD client');
    ErrStatus = RtttNetClientAPI.RtttNetClient.Init();
    if (ErrStatus ~= 0)
        disp('Unable to initialize NetClient DLL');
        return;
    end
    disp('Connecting to RSTD client');
    ErrStatus = RtttNetClientAPI.RtttNetClient.Connect('127.0.0.1',2777);
    if (ErrStatus ~= 0)
        disp('Unable to connect to Radarstudio');
        disp('Reopen port in Radarstudio. Type RSTD.NetClose() followed by RSTD.NetStart()')
        return;
    end
    pause(1);%Wait for 1sec. NOT a MUST have.
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


