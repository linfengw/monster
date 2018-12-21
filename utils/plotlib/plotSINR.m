%Plot SINR for the use case
function plotSINR(Param, StationsIn)

    %Consider scaling properly
    sweepRes = 50; %de correlation factor for UMa
    lengthXY = [Param.area(1):sweepRes:Param.area(3)+10; Param.area(2):sweepRes:Param.area(4)+10];
    N = length(lengthXY(1,:));

    if false %Param.posScheme == "Single Cell" && Param.seed == 42 && isfile('utils/plotlib/preplottedResults/SINRSingleCell42.mat')
        load('utils/plotlib/preplottedResults/SINRSingleCell42.mat');
    else
        Stations = StationsIn;
        %generate dummy users for interfeering
        for iUser = 1: length(Stations)
            Users(iUser) = UserEquipment(Param, iUser+99);
        end
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


        %Think about dimension of the factor
        resultsUMa = cell(length(Stations),N,N);
        UMaResultsSINR = nan(N,N,length(Stations));
        

        %fill something in the scheduler for all stations
        for iStation=1:length(Stations)
            Stations(iStation).Users = struct('UeId', Users(iStation).NCellID, 'CQI', -1, 'RSSI', -1);
            Stations(iStation).ScheduleDL(1,1).UeId = Users(iStation).NCellID;
            Users(iStation).ENodeBID = Stations(iStation).NCellID;
            %maybe get dummyframe for these 3 lines:
            Stations(iStation).Tx.Waveform = Stations(iStation).Tx.Frame;
            Stations(iStation).Tx.WaveformInfo = Stations(iStation).Tx.FrameInfo;
            Stations(iStation).Tx.ReGrid = Stations(iStation).Tx.FrameGrid;

        end


        for iStation=1:length(Stations)
           
            %TO: DO Refactorize with a simplified function call, only investigating power and not waveforms.
            counter = 0;
            ChannelUMa = ChBulk_v2(Stations, Users(iStation), Param);
            %Go through coordinates
            for Xpos = 1:length(lengthXY(1,:))
        
                for Ypos = 1:length(lengthXY(2,:))
                    fprintf('Sim %i/%i\n',counter,N^2);
                    
                    Users(iStation).Position(1:2) = [lengthXY(1,Xpos), lengthXY(2,Ypos)];
                    % Traverse channel
                    try

                        [~, ueUMaS] = ChannelUMa.traverse(Stations,Users,'downlink');
                    catch ME
                        
                    end
                    resultsUMa{iStation,Xpos,Ypos} = ueUMaS(iStation).Rx.ChannelConditions;
                    resultsUMa{iStation,Xpos,Ypos}.SINRdB = ueUMaS(iStation).Rx.SINRdB;
                    counter = counter +1;
                    
                end
            end

            %Visualization vectors and matrices

            for Xpos = 1:length(lengthXY(1,:))
                
                for Ypos = 1:length(lengthXY(2,:))

                    UMaResultsSINR(Xpos,Ypos,iStation) = resultsUMa{iStation,Xpos,Ypos}.SINRdB;

                end
            end

            

        end
        if Param.posScheme == "Single Cell" && Param.seed == 42
            save('utils/plotlib/preplottedResults/SINRSingleCell42.mat', 'UMaResultsSINR');
        end
    end
    %split UMaResults by bst type and plot
    %plot for macro
    if Param.numMacro > 0
        contourf(Param.LayoutAxes(10),lengthXY(1,:), lengthXY(2,:), max(UMaResultsSINR(:,:,1:Param.numMacro),[],3), 10)
        c = colorbar(Param.LayoutAxes(10));
        c.Label.String = 'Max SINR [dBm]';
        c.Label.FontSize = 12;
        colormap(hot)
    end

    %plot for micro
    if Param.numMicro > 0
        contourf(Param.LayoutAxes(11),lengthXY(1,:), lengthXY(2,:), max(UMaResultsSINR(:,:,Param.numMacro+1:Param.numMacro+Param.numMicro),[],3), 10)
        c = colorbar(Param.LayoutAxes(11));
        c.Label.String = 'Max SINR [dBm]';
        c.Label.FontSize = 12;
        colormap(hot)
    end

    %plot for micro
    if Param.numPico > 0
        contourf(Param.LayoutAxes(12),lengthXY(1,:), lengthXY(2,:),... 
                max(UMaResultsSINR(:,:,Param.numMacro+Param.numMicro+1:Param.numMacro+Param.numMicro+Param.numPico),[],3), 10)
        c = colorbar(Param.LayoutAxes(12));
        c.Label.String = 'Max SINR [dBm]';
        c.Label.FontSize = 12;
        colormap(hot)
    end

end
