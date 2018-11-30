%Plot SINR for the use case
function plotSINR(Param, StationsIn)
    Stations = StationsIn;
    %generate dummy user
    User = UserEquipment(Param, 99);

    Param.channel.enableInterference = false;
    Param.channel.enableFading = false;
    Param.channel.LOSMethod = 'NLOS';
    Param.channel.modeDL = '3GPP38901';
    Param.channel.region = struct();
    Param.mobilityScenario = 'pedestrian';
    Param.channel.region.macroScenario = 'UMa';
	Param.channel.region.microScenario = 'UMi';
	Param.channel.region.picoScenario = 'UMi';
    Param.channel.enableInterference = true;
    %Is this needed?
    setpref('sonohiLog','logLevel', 4);

    %Consider scaling properly
    sweepRes = 100; %de correlation factor for UMa
    lengthXY = [Param.area(1):sweepRes:Param.area(3)+10; Param.area(2):sweepRes:Param.area(4)+10];
    N = length(lengthXY(1,:));

    %Think about dimension of the factor
    resultsUMa = cell(length(Stations),N,N);
    UMaResultsRxPw = nan(N,N,length(Stations));
    ChannelUMa = ChBulk_v2(Stations, User, Param);
    for iStation=1:length(Stations)
        

        Stations(iStation).Users = struct('UeId', User.NCellID, 'CQI', -1, 'RSSI', -1);
        Stations(iStation).ScheduleDL(1,1).UeId = User.NCellID;
        User.ENodeBID = Stations(iStation).NCellID;
        %maybe get dummyframe for these 3 lines:
        Stations(iStation).Tx.Waveform = Stations(iStation).Tx.Frame;
        Stations(iStation).Tx.WaveformInfo = Stations(iStation).Tx.FrameInfo;
        Stations(iStation).Tx.ReGrid = Stations(iStation).Tx.FrameGrid;

       
        counter = 0;

        %Go through coordinates
        for Xpos = 1:length(lengthXY(1,:))
    
            for Ypos = 1:length(lengthXY(2,:))
                fprintf('Sim %i/%i\n',counter,N^2);
                ue = User;
                ue.Position(1:2) = [lengthXY(1,Xpos), lengthXY(2,Ypos)];
                % Traverse channel
                try

                    [~, ueUMaS] = ChannelUMa.traverse(Stations,ue,'downlink');
                catch ME
                    
                end
                    resultsUMa{iStation,Xpos,Ypos} = ueUMaS.Rx.ChannelConditions;
                    resultsUMa{iStation,Xpos,Ypos}.SINRdB = ueUMaS.Rx.SINRdB;
                counter = counter +1;
                
            end
        end

        %Visualization vectors and matrices

        for Xpos = 1:length(lengthXY(1,:))
            
            for Ypos = 1:length(lengthXY(2,:))

                UMaResultsRxPw(Xpos,Ypos,iStation) = resultsUMa{iStation,Xpos,Ypos}.SINRdB;

            end
        end

        

    end

    %split UMaResults by bst type and plot
    %plot for macro
    if Param.numMacro > 0
        contourf(Param.LayoutAxes(10),lengthXY(1,:), lengthXY(2,:), min(UMaResultsRxPw(:,:,1:Param.numMacro),[],3), 10)
        c = colorbar(Param.LayoutAxes(10));
        c.Label.String = 'Receiver Power [dBm]';
        c.Label.FontSize = 12;
        colormap(hot)
    end

    %plot for micro
    if Param.numMicro > 0
        contourf(Param.LayoutAxes(11),lengthXY(1,:), lengthXY(2,:), min(UMaResultsRxPw(:,:,Param.numMacro+1:Param.numMacro+Param.numMicro),[],3), 10)
        c = colorbar(Param.LayoutAxes(11));
        c.Label.String = 'Receiver Power [dBm]';
        c.Label.FontSize = 12;
        colormap(hot)
    end

    %plot for micro
    if Param.numPico > 0
        contourf(Param.LayoutAxes(12),lengthXY(1,:), lengthXY(2,:),... 
                min(UMaResultsRxPw(:,:,Param.numMacro+Param.numMicro+1:Param.numMacro+Param.numMicro+Param.numPico),[],3), 10)
        c = colorbar(Param.LayoutAxes(12));
        c.Label.String = 'Receiver Power [dBm]';
        c.Label.FontSize = 12;
        colormap(hot)
    end

end
