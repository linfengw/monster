classdef MonsterChannel < handle


	properties
		Mode;
		Region;
		BuildingFootprints;
		StationConfigs;
	end

	methods 
		function obj = MonsterChannel(Stations, Users, Param)
			obj.Mode = Param.channel.mode;
			obj.Region = Param.channel.region;
			obj.BuildingFootprints = Param.buildings;
			obj.setupChannel(Stations)
		end
		
		function setupChannel(obj, Stations, Users)
			switch obj.Mode
				case '3GPP38901'
					obj.setupStationConfigs(Stations)
					obj.createSpatialMaps()
				case 'Quadriga'
					obj.setupQuadrigaLayout(Stations, Users)
					
			end
		end

		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%% 3GPP 38901 model %%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		function setupStationConfigs(obj, Stations)
			% Setup structure for Station configs
			for stationIdx = 1:length(Stations)
				station = Stations(stationIdx);
				stationString = sprintf('station%i',station.NCellID);
				obj.StationConfigs.(stationString) = struct();
				obj.StationConfigs.(stationString).Tx = station.Tx;
				obj.StationConfigs.(stationString).Position = station.Position;
				obj.StationConfigs.(stationString).Seed = station.Seed;
				obj.StationConfigs.(stationString).LSP = lsp3gpp38901(obj.getAreaType(station));
			end
		end

		%%% UTILITY FUNCTIONS
		function config = findStationConfig(obj, station)
			% Find station config
			stationString = sprintf('station%i',station.NCellID);
			config = obj.StationConfigs.(stationString);
		end
		

		%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%% Quardiga model %%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%
		function setupQuadrigaLayout(obj, Stations, Users)
			% Call Quadriga setup function
		end

	end

	methods (Access = private)

		function createSpatialMaps(obj)
			% Construct structure for containing spatial maps
			stationStrings = fieldnames(obj.StationConfigs);
			for iStation = 1:length(stationStrings)
				config = obj.StationConfigs.(stationStrings{iStation});
				spatialMap = struct();
				fMHz = config.Tx.Freq;
				radius = obj.getAreaSize();
				
				% Spatial correlation map of LOS Large-scale SF
				[mapLOS, xaxis, yaxis] = obj.spatialCorrMap(config.LSP.sigmaSFLOS, config.LSP.dCorrLOS, fMHz, radius, config.Seed);
				axisLOS = [xaxis; yaxis];
				

				% Spatial correlation map of NLOS Large-scale SF
				[mapNLOS, xaxis, yaxis] = obj.spatialCorrMap(config.LSP.sigmaSFNLOS, config.LSP.dCorrNLOS, fMHz, radius, config.Seed);
				axisNLOS = [xaxis; yaxis];
								

				spatialMap.LOS = mapLOS;
				spatialMap.axisLOS = axisLOS;
				spatialMap.NLOS = mapNLOS;
				spatialMap.axisNLOS = axisNLOS;

				obj.StationConfigs.(stationStrings{iStation}).SpatialMaps = spatialMap;

			end
		end



		function areatype = getAreaType(obj,Station)
			if strcmp(Station.BsClass, 'macro')
				areatype = obj.Region.macroScenario;
			elseif strcmp(Station.BsClass,'micro')
				areatype = obj.Region.microScenario;
			elseif strcmp(Station.BsClass,'pico')
				areatype = obj.Region.picoScenario;
			end
		end

		function area = getAreaSize(obj)
			extraSamples = 5000; % Extra samples for allowing interpolation. Error will be thrown in this is exceeded.
			area = (max(obj.BuildingFootprints(:,3)) - min(obj.BuildingFootprints(:,1))) + extraSamples;
		end

	end

methods (Static)
	function [map, xaxis, yaxis] = spatialCorrMap(sigmaSF, dCorr, fMHz, radius, seed)
		% Create a map of independent Gaussian random variables according to the decorrelation distance. 
		% Interpolation between the random variables can be used to realize the 2D correlations. 
		lambdac=300/fMHz;   % wavelength in m
		interprate=round(dCorr/lambdac);
		Lcorr=lambdac*interprate;
		Nsamples=round(radius/Lcorr);
		rng(seed);
		map = randn(2*Nsamples,2*Nsamples)*sigmaSF;
		xaxis=[-Nsamples:Nsamples-1]*Lcorr;
		yaxis=[-Nsamples:Nsamples-1]*Lcorr;
		
	end
end

end