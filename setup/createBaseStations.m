function [Stations, Param] = createBaseStations (Param)

%   CREATE BASE Stations is used to generate a struct with the base Stations
%
%   Function fingerprint
%   Param.numMacro      		->  number of macro eNodeBs
%   Param.numSubFramesMacro	->  number of LTE subframes for macro eNodeBs
%   Param.numMicro      		-> 	number of micro eNodeBs
%   Param.numSubFramesMacro ->  number of LTE subframes for micro eNodeBs
%   Param.buildings 				-> building position matrix
%
%   Stations  							-> struct with all Stations details and PDSCH

	% Check that we only have at most 1 macro cell, as only 1 is supported as of now
	if Param.numMacro >= 0 && Param.numMacro <= 19
		

		xc = (Param.area(3)-Param.area(1))/2;
		yc = (Param.area(4)-Param.area(2))/2;
		networkLayout = NetworkLayout(xc,yc,Param);
		
		%TODO: Replace with new config class
		Param = networkLayout.Param; %To update parameters to match a chosen scenario

		%Draw the base stations
		if Param.draw
			networkLayout.draweNBs(Param);
		end
		%eNB indexing - The CellID array now contains the ID of the eNB (row(:,1)) and the corresponding index in all eNB (row(:,2))
		macroCellID = zeros(networkLayout.NumMacro,2);
		microCellID = zeros(networkLayout.NumMicro,2);
		picoCellID  = zeros(networkLayout.NumPico,2);
		for iCell = 1:length(macroCellID(:,1))
			macroCellID(iCell,1) = networkLayout.MacroCells{iCell}.CellID;
			macroCellID(iCell,2) = iCell;
		end

		for iCell = 1:length(microCellID(:,1))
			microCellID(iCell,1) = networkLayout.MicroCells{iCell}.CellID;
			microCellID(iCell,2) = iCell + macroCellID(length(macroCellID(:,1)),2);
		end

		for iCell = 1:length(picoCellID(:,1))
			picoCellID(iCell,1) = networkLayout.PicoCells{iCell}.CellID;
			picoCellID(iCell,2) = iCell + microCellID(length(microCellID(:,1)),2);
		end

		%Create the EvovledNodeB objects
		for iStation = 1:networkLayout.NumMacro
			Stations(iStation) = EvolvedNodeB(Param, 'macro', macroCellID(iStation,1));
			Stations(iStation).Position = [networkLayout.MacroCoordinates(iStation, :), Param.macroHeight];
		end
		for iStation = 1:networkLayout.NumMicro
			Stations(microCellID(iStation,2)) = EvolvedNodeB(Param, 'micro', microCellID(iStation,1));
			Stations(microCellID(iStation,2)).Position = [networkLayout.MicroCoordinates(iStation, :), Param.microHeight];
		end
		for iStation = 1:networkLayout.NumPico
			Stations(picoCellID(iStation,2)) = EvolvedNodeB(Param, 'pico', picoCellID(iStation,1));
			Stations(picoCellID(iStation,2)).Position = [networkLayout.PicoCoordinates(iStation, :), Param.picoHeight];
		end

		% Add neighbours to each eNodeB
		for iStation = 1:length(Stations)
			Stations(iStation) = setNeighbours(Stations(iStation), Stations, Param);
		end

		plotSNR(Param, Stations);

		plotSINR(Param, Stations);

		%Draw the base stations on the corresponding plots
		plotControl = ones(length(Param.LayoutAxes),4);
		%plotControl(1,:) = [1 1 1 1]; %Plot all kinds of eNBs for overview plot
		%plotControl(2,:) = [1 1 1 1]; %Plot all kinds of eNBs for heat map plot
		plotControl(3,:) = [1 0 0 1]; %Plot Macro eNBs for macro voronoi
		plotControl(4,:) = [0 1 0 1]; %Plot Micro eNBs for macro voronoi
		plotControl(5,:) = [0 0 1 1]; %Plot Macro eNBs for macro voronoi
		%plotControl(6,:) = [1 1 1 1]; %Plot all kinds of eNBs for UE association plot
		plotControl(7,:) = [1 0 0 0]; %Plot Macro eNBs for SNR plot
		plotControl(8,:) = [0 1 0 0]; %Plot Micro eNBs for SNR plot
		plotControl(9,:) = [0 0 1 0]; %Plot pico eNBs for SNR plot
		plotControl(10,:) = [1 0 0 0]; %Plot Macro eNBs for SINR plot
		plotControl(11,:) = [0 1 0 0]; %Plot Micro eNBs for SINR plot
		plotControl(12,:) = [0 0 1 0]; %Plot pico eNBs for SINR plot
		%plotControl(10,:) = [1 1 1 1]; %Plot all kinds of eNBs for spider plot
		networkLayout.draweNBs(Param, plotControl);
		
		voronoiPlots(Param, networkLayout);
		
		


		


	else
		sonohilog('(CREATE BASE STATIONS) error, at most 1 macro eNodeB currently supported','ERR');
	end
	

end
