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
				obj.StationConfigs.(stationString).LSP = lsp3gpp38901(obj.Channel.getAreaType(station));
			end
		end
		
		function propagateWaveforms(obj, Stations, Users, Mode)
			
			Pairing = obj.Channel.getPairing(Stations);
			numLinks = length(Pairing(1,:));
			for i = 1:numLinks
				obj.clearTempVariables()
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
				
				
				% Calculate recieved power between station and user
				[receivedPower, receivedPowerWatt] = obj.computeLinkBudget(station, user, Mode);
				obj.TempSignalVariables.RxPower = receivedPower;

				% Calculate SNR using thermal noise
				[SNR, SNRdB, noisePower] = obj.computeSNR();
				obj.TempSignalVariables.RxSNR = SNR;
				obj.TempSignalVariables.RxSNRdB = SNRdB;

				% Add/compute interference
				SINR = obj.computeSINR(station, user, Stations, receivedPowerWatt, noisePower, Mode);
				obj.TempSignalVariables.RxSINR = SINR;

				% Compute N0
				N0 = obj.computeSpectralNoiseDensity(station, Mode);

				% Add AWGN
				noise = N0*complex(randn(size(obj.TempSignalVariables.RxWaveform)), randn(size(obj.TempSignalVariables.RxWaveform)));
				rxSig = obj.TempSignalVariables.RxWaveform + noise;
				obj.TempSignalVariables.RxWaveform = rxSig;

				% Add fading
				if obj.Channel.enableFading
					obj.addFading(station, user, Mode);
				end

				% Receive signal at Rx module
				switch Mode
					case 'downlink'
						obj.setReceivedSignal(user);
					case 'uplink'
						obj.setReceivedSignal(station, user);
				end
				
			end
		end
		
		function N0 = computeSpectralNoiseDensity(obj, Station, Mode)
			% Compute spectral noise density NO
			switch Mode
			case 'downlink'
				Es = sqrt(2.0*Station.CellRefP*double(obj.TempSignalVariables.RxWaveformInfo.Nfft));
				N0 = 1/(Es*obj.TempSignalVariables.RxSINR);
			case 'uplink'
				N0 = 1/(obj.TempSignalVariables.RxSINR * sqrt(double(obj.TempSignalVariables.RxWaveformInfo.Nfft)))/sqrt(2);
			end

		end 

		function [SNR, SNRdB, noise] = computeSNR(obj)
			% Calculate SNR using thermal noise. Thermal noise is bandwidth dependent.
			thermalLossdBm = obj.thermalLoss();
			rxNoiseFloor = thermalLossdBm;
			noise = 10^((rxNoiseFloor-30)/10);
			SNRdB = obj.TempSignalVariables.RxPower-rxNoiseFloor;
			SNR = 10^((SNRdB)/20);
		end

		function [SNR, SINR] = getSNRandSINR(obj, Stations, station, user)
			% Used for obtaining a SINR estimation of a given position
			obj.TempSignalVariables.RxWaveform = station.Tx.Waveform; % Temp variable for BW indication
			obj.TempSignalVariables.RxWaveformInfo = station.Tx.WaveformInfo; % Temp variable for BW indication
			[receivedPower, receivedPowerWatt] = obj.computeLinkBudget(station, user, 'downlink');
			obj.TempSignalVariables.RxPower = receivedPower;
			[SNR, ~, noisePower] = obj.computeSNR();
			SINR = obj.computeSINR(station, user, Stations, receivedPowerWatt, noisePower, 'downlink');
			obj.clearTempVariables();
		end

		function [SINR] = computeSINR(obj, station, user, Stations, receivedPowerWatt, noisePower, Mode)
			% Compute SINR using received power and the noise power.
			% Interference is given as the power of the received signal, given the power of the associated base station, over the power of the neighboring base stations.
			% 
			% v1. InterferenceType Full assumes full power, thus the SINR computation can be done using just the link budget.
			% TODO: Add waveform type interference. 
			% TODO: clean up function arguments.
			if strcmp(obj.Channel.InterferenceType,'Full')
				interferingStations = obj.Channel.getInterferingStations(station, Stations);
				listCellPower = obj.listCellPower(user, interferingStations, Mode);
				
				intStations  = fieldnames(listCellPower);
				intPower = 0;
				% Sum power from interfering stations
				for intStation = 1:length(fieldnames(listCellPower))
					intPower = intPower + listCellPower.(intStations{intStation}).receivedPowerWatt;
				end

				SINR = receivedPowerWatt / (intPower + noisePower);
			else
				SINR = obj.TempSignalVariables.RxSNR;
			end
		end

		function list = listCellPower(obj, User, Stations, Mode)
			% Get list of recieved power from all stations

			list = struct();
			for iStation = 1:length(Stations)
				station = Stations(iStation);
				stationStr = sprintf('stationNCellID%i',station.NCellID);
				list.(stationStr).receivedPowerdBm = obj.computeLinkBudget(station, User, Mode);
				list.(stationStr).receivedPowerWatt = 10^((list.(stationStr).receivedPowerdBm-30)/10);
			end
			
		end


		
		function [receivedPower, receivedPowerWatt] = computeLinkBudget(obj, Station, User, mode)
			% Compute link budget for Tx -> Rx
			%
			% This requires a :meth:`computePathLoss` method, which is supplied by child classes.
			% returns updated RxPwdBm of RxNode.Rx
			% The channel is reciprocal in terms of received power, thus the path
			% loss is extracted from channel conditions provided by
			switch mode
				case 'downlink'
					lossdB = obj.computePathLoss(Station, User, Station.Tx.Freq);
					EIRPdBm = Station.Tx.getEIRPdBm;
					receivedPower = EIRPdBm-lossdB-User.Rx.NoiseFigure; %dBm
				case 'uplink'
					lossdB = obj.computePathLoss(Station, User, User.Tx.Freq);
					EIRPdBm = User.Tx.getEIRPdBm;
					receivedPower = EIRPdBm-lossdB-Station.Rx.NoiseFigure; %dBm
			end
			receivedPowerWatt = 10^((receivedPower-30)/10);

			
		end
		
		
		function [lossdB] = computePathLoss(obj, TxNode, RxNode, Freq)
			% Computes path loss. uses the following parameters
			%
			% ..todo:: Compute indoor depth from mobility class
			%
			% * `f` - Frequency in GHz
			% * `hBs` - Height of Tx
			% * `hUt` - height of Rx
			% * `d2d` - Distance in 2D
			% * `d3d` - Distance in 3D
			% * `LOS` - Link LOS boolean, determined by :meth:`ch.SonohiChannel.isLinkLOS`
			% * `shadowing` - Boolean for enabling/disabling shadowing using log-normal distribution
			% * `avgBuilding` - Average height of buildings
			% * `avgStreetWidth` - Average width of the streets
			f = Freq/10e2; % Frequency in GHz
			hBs = TxNode.Position(3);
			hUt = RxNode.Position(3);
			distance2d =  obj.Channel.getDistance(TxNode.Position(1:2),RxNode.Position(1:2));
			distance3d = obj.Channel.getDistance(TxNode.Position,RxNode.Position);
			
			areatype = obj.Channel.getAreaType(TxNode);
			seed = obj.Channel.getLinkSeed(RxNode, TxNode);
			[LOS, prop] = obj.Channel.isLinkLOS(TxNode, RxNode, false);
			if ~isnan(prop)
				% LOS state is determined by comparing with spatial map of
				% random variables, if the probability of determining LOS
				% is used.
				LOS = obj.spatialLOSstate(TxNode, RxNode.Position, prop);
			end
			
			
			shadowing = obj.Channel.enableShadowing;
			avgBuilding = mean(obj.Channel.BuildingFootprints(:,5));
			avgStreetWidth = obj.Channel.BuildingFootprints(2,2)-obj.Channel.BuildingFootprints(1,4);
			try
			lossdB = loss3gpp38901(areatype, distance2d, distance3d, f, hBs, hUt, avgBuilding, avgStreetWidth, LOS);
			catch
			if strcmp(ME.identifier,'Pathloss3GPP:Range')
					minRange = 10;
					lossdB = loss3gpp38901(areatype, minRange, distance3d, f, hBs, hUt, avgBuilding, avgStreetWidth, LOS);
			end
			end
				
			RxNode.Rx.ChannelConditions.BaseLoss = lossdB;
			
			if RxNode.Mobility.Indoor
				% Low loss model consists of LOS
				materials = {'StandardGlass', 'Concrete'; 0.3, 0.7};
				sigma_P = 4.4;
				
				% High loss model consists of
				%materials = {'IIRGlass', 'Concrete'; 0.7, 0.3}
				%sigma_P = 6.5;
				
				PL_tw = buildingloss3gpp38901(materials, f);
				
				% If indoor depth can be computed
				%PL_in = indoorloss3gpp38901('', 2d_in);
				% Otherwise sample from uniform
				PL_in  = indoorloss3gpp38901(areatype);
				indoorLosses = PL_tw + PL_in + randn(1, 1)*sigma_P;
				lossdB = lossdB + indoorLosses;
				obj.Channel.storeChannelCondition(TxNode, RxNode, 'IndoorLoss', indoorLosses);
				
			end
			
			% Return of channel conditions if required.
			% TODO: For atomic reasonability, consider moving this to class properties instead.
			%obj.Channel.storeChannelCondition(TxNode, RxNode, 'baseloss', lossdB);
			%obj.Channel.storeChannelCondition(TxNode, RxNode, 'LOS', LOS);
			%obj.Channel.storeChannelCondition(TxNode, RxNode, 'LOSprop', prop);
			
			if shadowing
				XCorr = obj.computeShadowingLoss(TxNode, RxNode.Position, LOS);
				%obj.Channel.storeChannelCondition(TxNode, RxNode, 'LSP', XCorr); % Only large scale parameters at the moment is shadowing.
				lossdB = lossdB + XCorr;
			end
			
			%obj.Channel.storeChannelCondition(TxNode, RxNode, 'pathloss', lossdB);
			
		end
		

		function addFading(obj, station, user, mode)
			% TODO: Add possibility to change the fading model used from parameters.
			fadingmodel = 'tdl';
			v = user.Mobility.Velocity * 3.6;                    % UT velocity in km/h
			switch mode
			case 'downlink'
				fc = station.Tx.Freq*10e5;          % carrier frequency in Hz
				samplingRate = station.Tx.WaveformInfo.SamplingRate;
				seed = obj.Channel.getLinkSeed(user, station);
			case 'uplink'
				fc = user.Tx.Freq*10e5;          % carrier frequency in Hz
				samplingRate = user.Tx.WaveformInfo.SamplingRate;
				seed = obj.Channel.getLinkSeed(station, user);
			end

			c = physconst('lightspeed'); % speed of light in m/s
			fd = (v*1000/3600)/c*fc;     % UT max Doppler frequency in Hz
			sig = [obj.TempSignalVariables.RxWaveform;zeros(200,1)];

			switch fadingmodel
				case 'cdl'
					cdl = nrCDLChannel;
					cdl.DelayProfile = 'CDL-C';
					cdl.DelaySpread = 300e-9;
					cdl.CarrierFrequency = fc;
					cdl.MaximumDopplerShift = fd;
					cdl.SampleRate = TxNode.Tx.WaveformInfo.SamplingRate;
					cdl.InitialTime = obj.Channel.getSimTime();
					cdl.TransmitAntennaArray.Size = [1 1 1 1 1];
					cdl.ReceiveAntennaArray.Size = [1 1 1 1 1];
					cdl.SampleDensity = 256;
					cdl.Seed = seed;
					obj.TempSignalVariables.RxWaveform = cdl(sig);
				case 'tdl'
					tdl = nrTDLChannel;

					% Set transmission direction for MIMO correlation
					switch mode
						case 'downlink'
						tdl.TransmissionDirection = 'Downlink';
						case 'uplink'
						tdl.TransmissionDirection = 'Uplink';
					end
					% TODO: Add MIMO to fading channel
					tdl.DelayProfile = 'TDL-E';
					tdl.DelaySpread = 300e-9;
					%tdl.MaximumDopplerShift = 0;
					tdl.MaximumDopplerShift = fd;
					tdl.SampleRate = samplingRate;
					tdl.InitialTime = obj.Channel.getSimTime();
					tdl.NumTransmitAntennas = 1;
					tdl.NumReceiveAntennas = 1;
					tdl.NormalizePathGains = false;
					tdl.NormalizeChannelOutputs = false;
					tdl.Seed = seed;
					%tdl.KFactorScaling = true;
					%tdl.KFactor = 3;
					[obj.TempSignalVariables.RxWaveform, obj.TempSignalVariables.RxPathGains, ~] = tdl(sig);
					obj.TempSignalVariables.RxPathFilters = getPathFilters(tdl);

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
			if isempty(TxNode.Tx.Waveform)
				sonohilog('Transmitter waveform is empty.', 'ERR', 'MonsterChannel:EmptyTxWaveform')
			end
			
			if isempty(TxNode.Tx.WaveformInfo)
				sonohilog('Transmitter waveform info is empty.', 'ERR', 'MonsterChannel:EmptyTxWaveformInfo')
			end
			
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
		
		function RxNode = setReceivedSignal(obj, RxNode, varargin)
			% Copies waveform and waveform info to Rx module, enables transmission.
			% Based on the class of RxNode, uplink or downlink can be determined
			%
			if isa(RxNode, 'EvolvedNodeB')
				userId = varargin{1}.NCellID;
				RxNode.Rx.createRecievedSignalStruct(userId);
				RxNode.Rx.ReceivedSignals{userId}.Waveform = obj.TempSignalVariables.RxWaveform;
				RxNode.Rx.ReceivedSignals{userId}.WaveformInfo = obj.TempSignalVariables.RxWaveformInfo;
				RxNode.Rx.ReceivedSignals{userId}.RxPwdBm = obj.TempSignalVariables.RxPower;
				RxNode.Rx.ReceivedSignals{userId}.SNR = obj.TempSignalVariables.RxSNR;
			elseif isa(RxNode, 'UserEquipment')
				RxNode.Rx.Waveform = obj.TempSignalVariables.RxWaveform;
				RxNode.Rx.WaveformInfo =  obj.TempSignalVariables.RxWaveformInfo;
				RxNode.Rx.RxPwdBm = obj.TempSignalVariables.RxPower;
				RxNode.Rx.SNR = obj.TempSignalVariables.RxSNR;
				RxNode.Rx.SINR = obj.TempSignalVariables.RxSINR;
				RxNode.Rx.PathGains = obj.TempSignalVariables.RxPathGains;
				RxNode.Rx.PathFilters = obj.TempSignalVariables.RxPathFilters;
			end
			
			
		end
		
		function clearTempVariables(obj)
			% Clear temporary variables. These are used for waveform manipulation and power tracking
			% The property TempSignalVariables is used, and is a struct of several parameters.
			obj.TempSignalVariables.RxPower = [];
			obj.TempSignalVariables.RxSNR = [];
			obj.TempSignalVariables.RxSINR = [];
			obj.TempSignalVariables.RxWaveform = [];
			obj.TempSignalVariables.RxWaveformInfo = [];
			obj.TempSignalVariables.RxPathGains = [];
			obj.TempSignalVariables.RxPathFilters = [];
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
				radius = obj.Channel.getAreaSize(); % Get range of grid
				
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
		
		function LOS = spatialLOSstate(obj, station, userPosition, LOSprop)
			% Determine spatial LOS state by realizing random variable from
			% spatial correlated map and comparing to LOS probability. Done
			% according to 7.6.3.3
			config = obj.findStationConfig(station);
			map = config.SpatialMaps.LOSprop;
			axisXY = config.SpatialMaps.axisLOSprop;
			LOSrealize = interp2(axisXY(1,:), axisXY(2,:), map, userPosition(1), userPosition(2), 'spline');
			if LOSrealize < LOSprop
				LOS = 1;
			else
				LOS = 0;
			end
			
		end
		
		function XCorr = computeShadowingLoss(obj, station, userPosition, LOS)
			% Interpolation between the random variables initialized
			% provides the magnitude of shadow fading given the LOS state.
			%
			% .. todo:: Compute this using the cholesky decomposition as explained in the WINNER II documents of all LSP.
			config = obj.findStationConfig(station);
			if LOS
				map = config.SpatialMaps.LOS;
				axisXY = config.SpatialMaps.axisLOS;
			else
				map = config.SpatialMaps.NLOS;
				axisXY = config.SpatialMaps.axisNLOS;
			end
			
			obj.checkInterpolationRange(axisXY, userPosition);
			XCorr = interp2(axisXY(1,:), axisXY(2,:), map, userPosition(1), userPosition(2), 'spline');
		end

		function lossdBm = thermalLoss(obj)
			% Compute thermal loss based on bandwidth, at T = 290 K.
			% Worst case given by the number of resource blocks. Bandwidth is
			% given based on the waveform. Computed using matlabs :obj:`obw`
			bw = obw(obj.TempSignalVariables.RxWaveform, obj.TempSignalVariables.RxWaveformInfo.SamplingRate);
			T = 290;
			k = physconst('Boltzmann');
			thermalNoise = k*T*bw;
			lossdBm = 10*log10(thermalNoise*1000);
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
		
		function [LOS, varargout] = LOSprobability(Channel, Station, User)
			% LOS probability using table 7.4.2-1 of 3GPP TR 38.901
			areaType = Channel.getAreaType(Station);
			dist2d = Channel.getDistance(Station.Position(1:2), User.Position(1:2));
			
			% TODO: make this a simplified function 
			switch areaType
				case 'RMa'
					if dist2d <= 10
						prop = 1;
					else
						prop = exp(-1*((dist2d-10)/1000));
					end
					
				case 'UMi'
					if dist2d <= 18
						prop = 1;
					else
						prop = 18/dist2d + exp(-1*((dist2d)/36))*(1-(18/dist2d));
					end
					
				case 'UMa'
					if dist2d <= 18
						prop = 1;
					else
						if User.Position(3) <= 13
							C = 0;
						elseif (User.Position(3) > 13) && (User.Position(3) <= 23)
							C = ((User.Position(3)-13)/10)^(1.5);
						else
							sonohilog('Error in computing LOS. Height out of range','ERR');
						end
						prop = (18/dist2d + exp(-1*((dist2d)/63))*(1-(18/dist2d)))*(1+C*(5/4)*(dist2d/100)^3*exp(-1*(dist2d/150)));
					end
					
				otherwise
					sonohilog(sprintf('AreaType: %s not valid for the LOSMethod %s',areaType, Channel.LOSMethod),'ERR');
					
			end
			
			x = rand;
			if x > prop
				LOS = 0;
			else
				LOS = 1;
			end
			
			
			if nargout > 1
				varargout{1} = prop;
				varargout{2} = x;
				varargout{3} = dist2d;
			end
			
		end
		
	end
	
	
	
	
end