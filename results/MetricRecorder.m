classdef MetricRecorder
	% This is class is used for defining and recording statistics in the network
	properties
		infoUtilLo;
		infoUtilHi;
		util;
		powerConsumed;
		schedule;
		harqRtx;
		arqRtx;
		powerState;
		ber;
		snrdB;
		sinrdB
		bler;
		cqi;
		preEvm;
		postEvm;
		throughput;
		receivedPowerdBm;
		rsrqdB;
		rsrpdBm;
		rssidBm;
		Param;
	end
	
	methods
		% Constructor
		function obj = MetricRecorder(Param, utilLo, utilHi)
			% Store main config
			obj.Param = Param;
			% Store utilisation thresholds for information
			obj.infoUtilLo = utilLo;
			obj.infoUtilHi = utilHi;
			% Initialise for eNodeB
			obj.util = zeros(Param.schRounds, Param.numEnodeBs);
			obj.powerConsumed = zeros(Param.schRounds, Param.numEnodeBs);
			temp(1:Param.schRounds, Param.numEnodeBs, 1:Param.numSubFramesMacro) = struct('UeId', NaN, 'Mcs', NaN, 'ModOrd', NaN, 'NDI', NaN);
			obj.schedule = temp;
			if Param.rtxOn
				obj.harqRtx = zeros(Param.schRounds, Param.numEnodeBs);
				obj.arqRtx = zeros(Param.schRounds, Param.numEnodeBs);
			end
			obj.powerState = zeros(Param.schRounds, Param.numEnodeBs);
			
			% Initialise for UE
			obj.ber = zeros(Param.schRounds,Param.numUsers);
			obj.snrdB = zeros(Param.schRounds,Param.numUsers);
			obj.sinrdB = zeros(Param.schRounds,Param.numUsers);
			obj.bler = zeros(Param.schRounds,Param.numUsers);
			obj.cqi = zeros(Param.schRounds,Param.numUsers);
			obj.preEvm = zeros(Param.schRounds,Param.numUsers);
			obj.postEvm = zeros(Param.schRounds,Param.numUsers);
			obj.throughput = zeros(Param.schRounds,Param.numUsers);
			obj.receivedPowerdBm = zeros(Param.schRounds,Param.numUsers);
			obj.rsrpdBm = zeros(Param.schRounds,Param.numUsers);
			obj.rssidBm = zeros(Param.schRounds,Param.numUsers);
			obj.rsrqdB = zeros(Param.schRounds,Param.numUsers);
		end
		
		% eNodeB metrics
		function obj = recordEnbMetrics(obj, Stations, schRound, Param, utilLo)
			% Increment the scheduling round for Matlab's indexing
			schRound = schRound + 1;
			obj = obj.recordUtil(Stations, schRound);
			obj = obj.recordPower(Stations, schRound, Param.otaPowerScale, utilLo);
			obj = obj.recordSchedule(Stations, schRound);
			obj = obj.recordPowerState(Stations, schRound);
			if Param.rtxOn
				obj = obj.recordHarqRtx(Stations, schRound);
				obj = obj.recordArqRtx(Stations, schRound);
			end
		end
		
		function obj = recordUtil(obj, Stations, schRound)
			for iStation = 1:length(Stations)
				sch = find([Stations(iStation).ScheduleDL.UeId] ~= -1);
				utilPercent = 100*find(sch, 1, 'last' )/length(Stations(iStation).ScheduleDL);
				
				% check utilPercent and change to 0 if null
				if isempty(utilPercent)
					utilPercent = 0;
				end
				
				obj.util(schRound, iStation) = utilPercent;
			end
		end
		
		function obj = recordPower(obj, Stations, schRound, otaPowerScale, utilLo)
			for iStation = 1:length(Stations)
				if ~isempty(obj.util(schRound, iStation))
					Stations(iStation) = Stations(iStation).calculatePowerIn(obj.util(schRound, iStation)/100, otaPowerScale, utilLo);
					obj.powerConsumed(schRound, iStation) = Stations(iStation).PowerIn;
				else
					sonohilog('powerConsumed consumed cannot be recorded. Please call recordUtil first.','ERR')
				end
			end
		end
		
		function obj = recordSchedule(obj, Stations, schRound)
			for iStation = 1:length(Stations)
				numPrbs = length(Stations(iStation).ScheduleDL);
				obj.schedule(schRound, iStation, 1:numPrbs) = Stations(iStation).ScheduleDL;
			end
		end
		
		function obj = recordHarqRtx(obj, Stations, schRound)
			for iStation = 1:length(Stations)
				harqProcs = [Stations(iStation).Mac.HarqTxProcesses.processes];
				obj.harqRtx(schRound, iStation) = sum([harqProcs.rtxCount]);
			end
		end
		
		function obj = recordArqRtx(obj, Stations, schRound)
			for iStation = 1:length(Stations)
				arqProcs = [Stations(iStation).Rlc.ArqTxBuffers.tbBuffer];
				obj.arqRtx(schRound, iStation) = sum([arqProcs.rtxCount]);
			end
		end
		
		function obj = recordPowerState(obj, Stations, schRound)
			for iStation = 1:length(Stations)
				obj.powerState(schRound, iStation) = Stations(iStation).PowerState;
			end
		end
		
		% UE metrics
		function obj = recordUeMetrics(obj, Users, schRound)
			% Increment the scheduling round for Matlab's indexing
			schRound = schRound + 1;
			obj = obj.recordBer(Users, schRound);
			obj = obj.recordBler(Users, schRound);
			obj = obj.recordSnrdB(Users, schRound);
			obj = obj.recordSinrdB(Users, schRound);
			obj = obj.recordCqi(Users, schRound);
			obj = obj.recordEvm(Users, schRound);
			obj = obj.recordThroughput(Users, schRound);
			obj = obj.recordReceivedPowerdBm(Users, schRound);
			obj = obj.recordRSMeasurements(Users,schRound);
		end
		
		function obj = recordBer(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.Bits) && Users(iUser).Rx.Bits.tot ~= 0
					obj.ber(schRound, iUser) = Users(iUser).Rx.Bits.err/Users(iUser).Rx.Bits.tot;
				else
					obj.ber(schRound, iUser) = NaN;
				end
			end
		end
		
		function obj = recordBler(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.Blocks) && Users(iUser).Rx.Blocks.tot ~= 0
					obj.bler(schRound, iUser) = Users(iUser).Rx.Blocks.err/Users(iUser).Rx.Blocks.tot;
				else
					obj.bler(schRound, iUser) = NaN;
				end
			end
		end
		
		function obj = recordRSMeasurements(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.RSSIdBm)
					obj.rssidBm(schRound, iUser) = Users(iUser).Rx.RSSIdBm;
				end
				if ~isempty(Users(iUser).Rx.RSRPdBm)
					obj.rsrpdBm(schRound, iUser) = Users(iUser).Rx.RSRPdBm;
				end
				if ~isempty(Users(iUser).Rx.RSRQdB)
					obj.rsrqdB(schRound, iUser) = Users(iUser).Rx.RSRQdB;
				end
			end
		end
		
		function obj = recordSnrdB(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.SNR)
					obj.snrdB(schRound, iUser) = 10*log10(Users(iUser).Rx.SNR);
				end
			end
		end
		
		function obj = recordSinrdB(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.SINR)
					obj.sinrdB(schRound, iUser) = 10*log10(Users(iUser).Rx.SINR);
				end
			end
		end
		
		function obj = recordCqi(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.CQI)
					obj.cqi(schRound, iUser) = Users(iUser).Rx.CQI;
				end
			end
		end
		
		function obj = recordEvm(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.PreEvm)
					obj.preEvm(schRound, iUser) = Users(iUser).Rx.PreEvm;
				end
				if ~isempty(Users(iUser).Rx.PostEvm)
					obj.postEvm(schRound, iUser) = Users(iUser).Rx.PostEvm;
				end
			end
		end
		
		function obj = recordThroughput(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.Bits) && Users(iUser).Rx.Bits.tot ~= 0
					obj.throughput(schRound, iUser) = Users(iUser).Rx.Bits.ok*10e3;
				else
					obj.throughput(schRound, iUser) = NaN;
				end
			end
		end
		
		function obj = recordReceivedPowerdBm(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.RxPwdBm)
					obj.receivedPowerdBm(schRound, iUser) = Users(iUser).Rx.RxPwdBm;
				end
			end
		end
		
		
	end
end