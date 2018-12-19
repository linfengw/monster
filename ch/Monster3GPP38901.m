classdef Monster3GPP38901 < handle

properties 
	StationConfigs;
	Channel;
	TempSignalVariables = struct(); 	
end

methods

	function obj = Monster3GPP38901(MonsterChannel, Stations)
		obj.Channel = MonsterChannel;
		obj.setupStationConfigs(Stations)
		obj.createSpatialMaps()
	end

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

	function propagateWaveforms(obj, Stations, Users, Mode)
		Pairing = obj.Channel.getPairing(Stations);
		numLinks = length(Pairing(1,:));
		for i = 1:numLinks
				% Local copy for mutation
				station = Stations([Stations.NCellID] == Pairing(1,i));
				user = Users(find([Users.NCellID] == Pairing(2,i))); %#ok
				
				% Set waveform to be manipulated
				switch Mode
				case 'downlink'
					obj.setWaveform(station)
				case 'uplink'
					obj.setWaveform(user)
				end
		end
	end

	%%% UTILITY FUNCTIONS
	function config = findStationConfig(obj, station)
		% Find station config
		stationString = sprintf('station%i',station.NCellID);
		config = obj.StationConfigs.(stationString);
	end

	function setWaveform(obj, TxNode)
		% Copies waveform and waveform info to Rx module, enables transmission.
		obj.TempSignalVariables.RxWaveform = TxNode.Tx.Waveform;
		obj.TempSignalVariables.RxWaveformInfo =  TxNode.Tx.WaveformInfo;
	end
	
	function h = plotSFMap(obj, station)
		config = obj.findStationConfig(station);
		h = figure;
		contourf(config.SpatialMaps.axisLOS(1,:), config.SpatialMaps.axisLOS(2,:), config.SpatialMaps.LOS)
		hold on
		plot(config.Position(1),config.Position(2),'o', 'MarkerSize', 20, 'MarkerFaceColor', 'auto')
		xlabel('x [Meters]')
		ylabel('y [Meters]')
	end

end

methods (Access = private)

function createSpatialMaps(obj)
	% Construct structure for containing spatial maps
	stationStrings = fieldnames(obj.StationConfigs);
	for iStation = 1:length(stationStrings)
		config = obj.StationConfigs.(stationStrings{iStation});
		spatialMap = struct();
		fMHz = config.Tx.Freq;  % Freqency in MHz
		radius = obj.getAreaSize(); % Get range of grid
		
		if obj.Channel.enableShadowing
			% Spatial correlation map of LOS Large-scale SF
			[mapLOS, xaxis, yaxis] = obj.spatialCorrMap(config.LSP.sigmaSFLOS, config.LSP.dCorrLOS, fMHz, radius, config.Seed, 'gaussian');
			axisLOS = [xaxis; yaxis];
			
			% Spatial correlation map of NLOS Large-scale SF
			[mapNLOS, xaxis, yaxis] = obj.spatialCorrMap(config.LSP.sigmaSFNLOS, config.LSP.dCorrNLOS, fMHz, radius, config.Seed, 'gaussian');
			axisNLOS = [xaxis; yaxis];
			spatialMap.LOS = mapLOS;
			spatialMap.axisLOS = axisLOS;
			spatialMap.NLOS = mapNLOS;
			spatialMap.axisNLOS = axisNLOS;
		end

		% Configure LOS probability map G, with correlation distance
		% according to 7.6-18. 
		[mapLOSprop, xaxis, yaxis] = obj.spatialCorrMap([], config.LSP.dCorrLOSprop, fMHz, radius,  config.Seed, 'uniform');
		axisLOSprop = [xaxis; yaxis];

		spatialMap.LOSprop = mapLOSprop;
		spatialMap.axisLOSprop = axisLOSprop;

		obj.StationConfigs.(stationStrings{iStation}).SpatialMaps = spatialMap;

	end
end

function areatype = getAreaType(obj,Station)
	if strcmp(Station.BsClass, 'macro')
		areatype = obj.Channel.Region.macroScenario;
	elseif strcmp(Station.BsClass,'micro')
		areatype = obj.Channel.Region.microScenario;
	elseif strcmp(Station.BsClass,'pico')
		areatype = obj.Channel.Region.picoScenario;
	end
end

function area = getAreaSize(obj)
	extraSamples = 5000; % Extra samples for allowing interpolation. Error will be thrown in this is exceeded.
	area = (max(obj.Channel.BuildingFootprints(:,3)) - min(obj.Channel.BuildingFootprints(:,1))) + extraSamples;
end


end

methods (Static)
	function [map, xaxis, yaxis] = spatialCorrMap(sigmaSF, dCorr, fMHz, radius, seed, distribution)
		% Create a map of independent Gaussian random variables according to the decorrelation distance. 
		% Interpolation between the random variables can be used to realize the 2D correlations. 
		lambdac=300/fMHz;   % wavelength in m
		interprate=round(dCorr/lambdac);
		Lcorr=lambdac*interprate;
		Nsamples=round(radius/Lcorr);
		rng(seed);
		switch distribution
			case 'gaussian'
				map = randn(2*Nsamples,2*Nsamples)*sigmaSF;
			case 'uniform'
				map = rand(2*Nsamples,2*Nsamples);
		end
		xaxis=[-Nsamples:Nsamples-1]*Lcorr;
		yaxis=[-Nsamples:Nsamples-1]*Lcorr;
		
	end

			
	function checkInterpolationRange(axisXY, Position)
		% Function used to check if the position can be interpolated
		extrapolation = false;
		if Position(1) > max(axisXY(1,:))
			extrapolation = true;
		elseif Position(1) < min(axisXY(1,:))
			extrapolation = true;
		elseif Position(2) > max(axisXY(2,:))
			extrapolation = true;
		elseif Position(3) < min(axisXY(2,:))
			extrapolation = true;
		end
		
		if extrapolation
				pos = sprintf('(%s)',num2str(Position));
				bound = sprintf('(%s)',num2str([min(axisXY(1,:)), min(axisXY(2,:)), max(axisXY(1,:)), max(axisXY(2,:))]));
				sonohilog(sprintf('Position of Rx out of bounds. Bounded by %s, position was %s. Increase Channel.getAreaSize',bound,pos), 'ERR')
		end
			
		end
end


end