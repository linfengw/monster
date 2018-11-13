clear all
close all
load('SimulationParameters.mat');
Param.numMacro = 1;
Param.numMicro = 0;
Param.numPico = 0;
Param.numUsers = 1;
Param.channel.region = struct();
Param.channel.region.macroScenario = 'UMa';
Param.channel.enableShadowing = true;
Param.channel.enableFading = true;
Param.channel.modeDL = '3GPP38901';


if Param.draw
	Param = createLayoutPlot(Param);
	Param = createPHYplot(Param);
end

% Create Stations and Users
[Station, Param] = createBaseStations(Param);
User = createUsers(Param);

% Create Channel scenario
Channel = ChBulk_v2(Station, User, Param);
ChannelEstimator = createChannelEstimator();

Station.Users = struct('UeId', User.NCellID, 'CQI', -1, 'RSSI', -1);
Station.ScheduleDL(1,1).UeId = User.NCellID;
User.ENodeBID = Station.NCellID;

Station.Tx.createReferenceSubframe()
Station.Tx.assignReferenceSubframe()


% Traverse channel
[~, User] = Channel.traverse(Station,User,'downlink');

%% Downlink
% Get offset
User.Rx.Offset = lteDLFrameOffset(Station, User.Rx.Waveform);
% Apply offset
User.Rx.Waveform = User.Rx.Waveform(1+User.Rx.Offset:end);
% UE reference measurements
User.Rx = User.Rx.referenceMeasurements(Station);
% Demod waveform
[demodBool, User.Rx] = User.Rx.demodulateWaveform(Station);
% Estimate Channel
User.Rx = User.Rx.estimateChannel(Station, ChannelEstimator.Downlink);
% Equalize signal
User.Rx = User.Rx.equaliseSubframe();
% Calculate the CQI to use
User.Rx = User.Rx.selectCqi(Station);

%% Create uplink

User.Tx = User.Tx.mapGridAndModulate(User, Param);
figure
surf(abs(User.Tx.ReGrid))
figure
plot(10*log10(abs(fftshift(fft(User.Tx.Waveform)))))

%% Traverse channel uplink
[Station, ~] = Channel.traverse(Station,User,'uplink');

%% Get uplink CSI
