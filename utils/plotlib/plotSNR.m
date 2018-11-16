%Plot function to plot SNR
function plotSNR(Param, StationsIn)

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

    %Is this needed?
    setpref('sonohiLog','logLevel', 4);

    %Consider scaling properly
    sweepRes = 50; %de correlation factor for UMa
    lengthXY = [Param.area(1):sweepRes:Param.area(3)+10; Param.area(2):sweepRes:Param.area(4)+10];
    N = length(lengthXY(1,:));

    %Think about dimension of the factor
    resultsUMa = cell(length(Stations),N,N);
    UMaResultsRxPw = nan(N,N,length(Stations));

    for iStation=1:length(Stations)
        ChannelUMa = ChBulk_v2(Stations(iStation), User, Param);

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

                    [~, ueUMaS] = ChannelUMa.traverse(Stations(iStation),ue,'downlink');
                catch ME
                    
                end
                    resultsUMa{iStation,Xpos,Ypos} = ueUMaS.Rx.ChannelConditions;
                    resultsUMa{iStation,Xpos,Ypos}.RxPw = ueUMaS.Rx.RxPwdBm;
                counter = counter +1;
                
            end
        end

        %Visualization vectors and matrices

        for Xpos = 1:length(lengthXY(1,:))
            
            for Ypos = 1:length(lengthXY(2,:))

                UMaResultsRxPw(Xpos,Ypos,iStation) = resultsUMa{iStation,Xpos,Ypos}.RxPw;

            end
        end

        

    end

    %split UMaResults by bst type and plot
    %plot for macro
    if Param.numMacro > 0
        contourf(Param.LayoutAxes(7),lengthXY(1,:), lengthXY(2,:), max(UMaResultsRxPw(:,:,1:Param.numMacro),[],3), 10)
        c = colorbar(Param.LayoutAxes(7));
        c.Label.String = 'Receiver Power [dBm]';
        c.Label.FontSize = 12;
        colormap(hot)
    end

    %plot for micro
    if Param.numMicro > 0
        contourf(Param.LayoutAxes(8),lengthXY(1,:), lengthXY(2,:), max(UMaResultsRxPw(:,:,Param.numMacro+1:Param.numMacro+Param.numMicro),[],3), 10)
        c = colorbar(Param.LayoutAxes(8));
        c.Label.String = 'Receiver Power [dBm]';
        c.Label.FontSize = 12;
        colormap(hot)
    end

    %plot for micro
    if Param.numPico > 0
        contourf(Param.LayoutAxes(9),lengthXY(1,:), lengthXY(2,:),... 
                max(UMaResultsRxPw(:,:,Param.numMacro+Param.numMicro+1:Param.numMacro+Param.numMicro+Param.numPico),[],3), 10)
        c = colorbar(Param.LayoutAxes(9));
        c.Label.String = 'Receiver Power [dBm]';
        c.Label.FontSize = 12;
        colormap(hot)
    end
end
