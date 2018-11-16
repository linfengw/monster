clear all
close all
initParam
load('SimulationParameters.mat');
Param.posScheme = 'none';
Param.numMacro = 1;
Param.numMicro = 0;
Param.numPico = 0;
Param.numUsers = 1;

Param.channel.enableInterference = false;
Param.channel.enableFading = false;
Param.channel.enableShadowing = true;
Param.channel.LOSMethod = 'NLOS';
Param.channel.modeDL = '3GPP38901';
Param.area = [-3000, -3000, 3000, 3000];
Param.channel.region = struct();
Param.channel.region.macroScenario = 'UMa';
Param.mobilityScenario = 'pedestrian';


if Param.draw
	Param = createLayoutPlot(Param);
	Param = createPHYplot(Param);
end

% Create Stations and Users
[Station, Param] = createBaseStations(Param);



User = createUsers(Param);



%StationS1 = Station;
% StationS1.Tx.AntennaArray.Bearing = 30;
% StationS2 = Station;
% StationS2.Tx.AntennaArray.Bearing = 150;
StationS3 = Station;
% StationS3.Tx.AntennaArray.Bearing = 270;

% Create Channel scenario
ChannelUMa = ChBulk_v2(Station, User, Param);
ChannelUMa.plotHeatmap([StationS3], User, Param.LayoutAxes(7));


Param.channel.region.macroScenario = 'RMa';
ChannelRMa = ChBulk_v2(Station, User, Param);

Station.Users = struct('UeId', User.NCellID, 'CQI', -1, 'RSSI', -1);
Station.ScheduleDL(1,1).UeId = User.NCellID;
User.ENodeBID = Station.NCellID;

% A full LTE frame is stored in Tx.Frame which can be used to debug and
% test.
Station.Tx.Waveform = Station.Tx.Frame;
Station.Tx.WaveformInfo = Station.Tx.FrameInfo;
Station.Tx.ReGrid = Station.Tx.FrameGrid;

%% Produce heatmap for channel conditions with spatial correlation
% This includes:
% * LOS stateStation
% * Shadowing
% * Pathloss
setpref('sonohiLog','logLevel', 4);
Station.Position(1:2) = [0, 0];
% Set up coordinates of UE
sweepRes = 200; %1m

StationS1 = Station;
StationS1.Tx.AntennaArray.Bearing = 30;
StationS2 = Station;
StationS2.Tx.AntennaArray.Bearing = 150;
StationS3 = Station;
StationS3.Tx.AntennaArray.Bearing = 270;


% Get area size
lengthXY = [Param.area(1):sweepRes:Param.area(3); Param.area(2):sweepRes:Param.area(4)];
N = length(lengthXY(1,:));
resultsUMa = cell(N,N,3);
resultsRMa = cell(N,N);
counter = 0;
for Xpos = 1:length(lengthXY(1,:))
    
    for Ypos = 1:length(lengthXY(2,:))
        fprintf('Sim %i/%i\n',counter,N^2);
        ue = User;
        ue.Position(1:2) = [lengthXY(1,Xpos), lengthXY(2,Ypos)];
        % Traverse channel
        try
            %[~, ueUMaS1] = ChannelUMa.traverse(StationS1,ue,'downlink');
						%[~, ueUMaS2] = ChannelUMa.traverse(StationS2,ue,'downlink');
						[~, ueUMaS3] = ChannelUMa.traverse(StationS3,ue,'downlink');
            %[~, ueRMa] = ChannelRMa.traverse(Station,ue,'downlink');
        catch ME
            
        end
        
%        resultsUMa{Xpos,Ypos,1} = ueUMaS1.Rx.ChannelConditions;
%				resultsUMa{Xpos,Ypos,1}.RxPw = ueUMaS1.Rx.RxPwdBm;
%				resultsUMa{Xpos,Ypos,2} = ueUMaS2.Rx.ChannelConditions;
%				resultsUMa{Xpos,Ypos,2}.RxPw = ueUMaS2.Rx.RxPwdBm;
				resultsUMa{Xpos,Ypos,3} = ueUMaS3.Rx.ChannelConditions;
				resultsUMa{Xpos,Ypos,3}.RxPw = ueUMaS3.Rx.RxPwdBm;
%        resultsRMa{Xpos,Ypos} = ueRMa.Rx.ChannelConditions;
        counter = counter +1;
        
    end
end

%% Create visualization vectors/matrices

UMaResultsLOS = nan(N,N);
UMaResultsRxPw = nan(N,N,3);
UMaResultsPL = nan(N,N);
UMaResultsLOSprop = nan(N,N);
RMaResultsLOS = nan(N,N);
RMaResultsPL = nan(N,N);
RMaResultsLOSprop = nan(N,N);

if Param.channel.enableShadowing
	UMaResultsLSP = nan(N,N);
	RMaResultsLSP = nan(N,N);
end

for Xpos = 1:length(lengthXY(1,:))
    
    for Ypos = 1:length(lengthXY(2,:))
        
        %UMaResultsLOS(Xpos,Ypos) = resultsUMa{Xpos,Ypos}.LOS;

				
				
				%UMaResultsRxPw(Xpos,Ypos,1) = resultsUMa{Xpos,Ypos,1}.RxPw;
				%UMaResultsRxPw(Xpos,Ypos,2) = resultsUMa{Xpos,Ypos,2}.RxPw;
				UMaResultsRxPw(Xpos,Ypos,3) = resultsUMa{Xpos,Ypos,3}.RxPw;
        %UMaResultsPL(Xpos,Ypos) = resultsUMa{Xpos,Ypos}.pathloss;
		
        %UMaResultsLOSprop(Xpos,Ypos) = resultsUMa{Xpos,Ypos}.LOSprop;
        
        %RMaResultsLOS(Xpos,Ypos) = resultsRMa{Xpos,Ypos}.LOS;
        %RMaResultsPL(Xpos,Ypos) = resultsRMa{Xpos,Ypos}.pathloss;
				%RMaResultsLOSprop(Xpos,Ypos) = resultsRMa{Xpos,Ypos}.LOSprop;
		
		if Param.channel.enableShadowing
			
        %RMaResultsLSP(Xpos,Ypos) = resultsRMa{Xpos,Ypos}.LSP;
				%UMaResultsLSP(Xpos,Ypos) = resultsUMa{Xpos,Ypos}.LSP;
		end
        
    end
end

%% Plotting

close all

figure
contourf(lengthXY(1,:), lengthXY(2,:), UMaResultsRxPw(:,:,3), 10)
%caxis([70 150])
c = colorbar;
c.Label.String = 'Receiver Power [dBm]';
c.Label.FontSize = 12;
colormap(hot)
title('UMa \mu received power, 1.84 GHz')
xlabel('X [m]')
ylabel('Y [m]')
%%
% 
% figure
% contourf(lengthXY(1,:), lengthXY(2,:), UMaResultsPL)
% caxis([70 150])
% c = colorbar;
% c.Label.String = 'loss [dB]';
% c.Label.FontSize = 12;
% colormap jet
% title('UMa \mu pathloss, 1.84 GHz')
% xlabel('X [m]')
% ylabel('Y [m]')
% 
% 
% 
% figure
% contourf(lengthXY(1,:), lengthXY(2,:), RMaResultsPL)
% caxis([70 150])
% c = colorbar;
% c.Label.String = 'loss [dB]';
% c.Label.FontSize = 12;
% colormap jet
% title('RMa \mu pathloss, 1.84 GHz')
% xlabel('X [m]')
% ylabel('Y [m]')
% 
% 
% 
% 
% figure
% contourf(lengthXY(1,:), lengthXY(2,:), UMaResultsLOS,1)
% title('LOS state for UMa')
% 
% figure
% contourf(lengthXY(1,:), lengthXY(2,:), RMaResultsLOS,1)
% title('LOS state for RMa')
% colormap summer
% 
% if Param.channel.enableShadowing
% 	
% 	
% figure
% contourf(lengthXY(1,:), lengthXY(2,:), UMaResultsLSP)
% colorbar
% colormap jet
% end
% 
% figure
% contourf(lengthXY(1,:), lengthXY(2,:), UMaResultsLOSprop)
% colorbar
% colormap jet
% title('RMa \mu pathloss, 1.84 GHz')
% xlabel('X [m]')
% ylabel('Y [m]')
% 
% 
% 
% 
% figure
% contourf(lengthXY(1,:), lengthXY(2,:), UMaResultsLOS,1)
% title('LOS state for UMa')
% 
% figure
% contourf(lengthXY(1,:), lengthXY(2,:), RMaResultsLOS,1)
% title('LOS state for RMa')
% colormap summer
% 
% if Param.channel.enableShadowing
% 	
% 	
% 	figure
% 	contourf(lengthXY(1,:), lengthXY(2,:), UMaResultsLSP)
% 	colorbar
% 	colormap jet
% end
% 
% figure
% contourf(lengthXY(1,:), lengthXY(2,:), UMaResultsLOSprop)
% colorbar
% colormap jet
