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

		for iStation = 1:networkLayout.NumMacro
			Stations(iStation) = EvolvedNodeB(Param, 'macro', networkLayout.MacroCells{iStation}.CellID);
			Stations(iStation).Position = [networkLayout.MacroCoordinates(iStation, :), Param.macroHeight];
		end
		for iStation = 1:networkLayout.NumMicro
			Stations(iStation+networkLayout.NumMacro) = EvolvedNodeB(Param, 'micro', networkLayout.MicroCells{iStation}.CellID);
			Stations(iStation+networkLayout.NumMacro).Position = [networkLayout.MicroCoordinates(iStation, :), Param.microHeight];
		end
		for iStation = 1:networkLayout.NumPico
			Stations(iStation+networkLayout.NumMacro+networkLayout.NumMicro) = EvolvedNodeB(Param, 'pico', networkLayout.PicoCells{iStation}.CellID);
			Stations(iStation+networkLayout.NumMacro+networkLayout.NumMicro).Position = [networkLayout.PicoCoordinates(iStation, :), Param.picoHeight];
		end


		% Add neighbours to each eNodeB
		for iStation = 1:length(Stations)
			Stations(iStation) = setNeighbours(Stations(iStation), Stations, Param);
		end

		%plotSNR(Param, Stations);

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
		%plotControl(10,:) = [1 1 1 1]; %Plot all kinds of eNBs for spider plot
		networkLayout.draweNBs(Param, plotControl);
		
		voronoiPlots(Param, networkLayout);
		
		


		


	else
		sonohilog('(CREATE BASE STATIONS) error, at most 1 macro eNodeB currently supported','ERR');
	end
	

end
