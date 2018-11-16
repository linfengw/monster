clear all
close all
load('SimulationParameters.mat');
Param.numMacro = 1;
Param.numMicro = 0;
Param.numPico = 0;
Param.numUsers = 1;
Param.draw = 0;
Param.schRounds = 800;
Param.channel.region = struct();
Param.channel.region.macroScenario = 'UMa';
Param.channel.enableShadowing = true;
Param.channel.enableFading = true;
Param.channel.enableInterference = false;
Param.channel.modeDL = '3GPP38901';
Param.channel.modeUL = '3GPP38901';


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

%% Downlink
downlink_cqi = nan(Param.schRounds,1);
for subframe = 1:Param.schRounds
Station.NSubframe = subframe-1;
Station.Tx.createReferenceSubframe();
Station.Tx.assignReferenceSubframe();

% Traverse channel
Channel.iRound = subframe-1;
[~, User] = Channel.traverse(Station,User,'downlink');

User.Rx.receiveDownlink(Station, ChannelEstimator.Downlink);
fprintf("Subframe %i Downlink CQI: %i \n", subframe-1, User.Rx.CQI)
downlink_cqi(subframe) = User.Rx.CQI;
end

%% Uplink
User.Tx = User.Tx.mapGridAndModulate(User, Param);

User.Tx.plotSpectrum()
User.Tx.plotResources()

% Traverse channel uplink
[Station, ~] = Channel.traverse(Station,User,'uplink');

Station.Rx.plotSpectrum()
%Station.Rx.plotResources()

% TODO: move this to Rx module logic
testSubframe = lteSCFDMADemodulate(struct(User), setPower(Station.Rx.Waveform, Station.Rx.RxPwdBm) );
[EstChannelGrid, NoiseEst] = lteULChannelEstimate(struct(User), User.Tx.PUSCH, ChannelEstimator.Uplink, testSubframe);
[EqGrid, csi] = lteEqualizeMMSE(testSubframe, EstChannelGrid, NoiseEst);



figure
subplot(2,1,1)
mesh(abs(User.Rx.CSI))
subplot(2,1,2)
mesh(abs(csi))

figure
subplot(2,1,1)
mesh(abs(User.Rx.EqSubframe))
subplot(2,1,2)
mesh(abs(EqGrid))

figure
plot(downlink_cqi_fading_tdlc)
hold on
plot(downlink_cqi_fading_tdla)
plot(downlink_cqi_nofading)

legend('TDL-C profile', 'TDL-A profile', 'no fading')
xlabel('Subframe #')
ylabel('CQI downlink')
ylim([0 16])

