%   EVOLVED NODE B defines a value class for creating and working with eNodeBs

classdef EvolvedNodeB
	%   EVOLVED NODE B defines a value class for creating and working with eNodeBs
	properties
		NCellID;
		DuplexMode;
		Position;
		NDLRB;
		CellRefP;
		CyclicPrefix;
		CFI;
		DlFreq;
		PHICHDuration;
		Ng;
		TotSubframes;
		OCNG;
		Windowing;
		Users;
		Schedule;
		RrNext;
		Channel;
		NSubframe;
		BsClass;
		Status;
		Neighbours;
		HystCount;
		SwitchCount;
		Pmax;
		P0;
		DeltaP;
		Psleep;
		Tx;
		Rx;
		HarqProc;
	end

	methods
		% Constructor
		function obj = EvolvedNodeB(Param, BsClass, cellId)
			switch BsClass
				case 'macro'
					obj.NDLRB = Param.numSubFramesMacro;
					obj.Pmax = 20; % W
					obj.P0 = 130; % W
					obj.DeltaP = 4.7;
					obj.Psleep = 75; % W
				case 'micro'
					obj.NDLRB = Param.numSubFramesMicro;
					obj.Pmax = 6.3; % W
					obj.P0 = 56; % W
					obj.DeltaP = 2.6;
					obj.Psleep = 39.0; % W
			end
			obj.BsClass = BsClass;
			obj.NCellID = cellId;
			obj.CellRefP = 1;
			obj.CyclicPrefix = 'Normal';
			obj.CFI = 1;
			obj.PHICHDuration = 'Normal';
			obj.Ng = 'Sixth';
			obj.TotSubframes = Param.schRounds;
			obj.NSubframe = 0;
			obj.OCNG = 'On';
			obj.Windowing = 0;
			obj.DuplexMode = 'FDD';
			obj.RrNext = struct('UeId',0,'Index',1);
			obj.Users = zeros(Param.numUsers, 1);
			obj = resetSchedule(obj);
			obj.Status = 1;
			obj.Neighbours = zeros(1, Param.numMacro + Param.numMicro);
			obj.HystCount = 0;
			obj.SwitchCount = 0;
			obj.DlFreq = Param.dlFreq;
			obj.HarqProc = [];
			obj.Tx = BSTransmitterModule(obj, Param);
			obj.Rx = BSReceiverModule(Param);
		end

		% Posiiton base station
		function obj = setPosition(obj, pos)
			obj.Position = pos;
		end

		% reset users
		function obj = resetUsers(obj, Param)
			obj.Users = zeros(Param.numUsers, 1);
		end

		% reset schedule
		function obj = resetSchedule(obj)
			temp(1:obj.NDLRB,1) = struct('UeId', 0, 'Mcs', 0, 'ModOrd', 0);
			obj.Schedule = temp;
		end

		% set subframe number
		function obj = set.NSubframe(obj, num)
			obj.NSubframe =  num;
		end

    function [indPdsch, info] = getPDSCHindicies(obj)
      enb = cast2Struct(obj);
      % get PDSCH indexes
      [indPdsch, info] = ltePDSCHIndices(enb, enb.Tx.PDSCH, enb.Tx.PDSCH.PRBSet);
    end

		% create list of neighbours
		function obj = setNeighbours(obj, Stations, Param)
			% the macro eNodeB has neighbours all the micro
			if obj.BsClass == 'macro'
				obj.Neighbours(1:Param.numMicro) = find([Stations.NCellID] ~= obj.NCellID);
			% the micro eNodeBs only get the macro as neighbour and all the micro eNodeBs
			% in a circle of radius Param.nboRadius
			else
				for iStation = 1:length(Stations)
					if Stations(iStation).BsClass == 'macro'
						% insert in array at lowest index with 0
						ix = find(not(obj.Neighbours), 1 );
						obj.Neighbours(ix) = Stations(iStation).NCellID;
					elseif Stations(iStation).NCellID ~= obj.NCellID
						pos = obj.Position(1:2);
						nboPos = Stations(iStation).Position(1:2);
						dist = pdist(cat(1, pos, nboPos));
						if dist <= Param.nboRadius
							ix = find(not(obj.Neighbours), 1 );
							obj.Neighbours(ix) = Stations(iStation).NCellID;
						end
					end
				end
			end
		end

		% check utilisation wrapper
		function obj = checkUtilisation(obj, util, Param, loThr, hiThr, Stations)
			% overload
			if util >= hiThr
				obj.Status = 2;
				obj.HystCount = obj.HystCount + 1;
				if obj.HystCount >= Param.tHyst/10^-3
					% The overload has exceeded the hysteresis timer, so find an inactive
					% neighbour that is micro to activate
					nboMicroIxs = find([obj.Neighbours] ~= Stations(1).NCellID);

					% Loop the neighbours to find an inactive one
					for iNbo = 1:length(nboMicroIxs)
						if nboMicroIxs(iNbo) ~= 0
							% find this neighbour in the stations
							nboIx = find([Stations.NCellID] == obj.Neighbours(nboMicroIxs(iNbo)));

							% Check if it can be activated
							if (~isempty(nboIx) && Stations(nboIx).Status == 5)
								% in this case change the status of the target neighbour to "boot"
								% and reset the hysteresis and the switching on/off counters
								Stations(nboIx).Status = 6;
								Stations(nboIx).HystCount = 0;
								Stations(nboIx).SwitchCount = 0;
								break;
							end
						end
					end
				end

			% underload, shutdown, inactive or boot
			elseif util <= loThr
				switch obj.Status
					case 1
						% eNodeB active and going in underload for the first time
						obj.Status = 3;
						obj.HystCount = 1;
					case 3
						% eNodeB already in underload
						obj.HystCount = obj.HystCount + 1;
						if obj.HystCount >= Param.tHyst/10^-3
							% the underload has exceeded the hysteresis timer, so start switching
							obj.Status = 4;
							obj.SwitchCount = 1;
						end
					case 4
						obj.SwitchCount = obj.SwitchCount + 1;
						if obj.SwitchCount >= Param.tSwitch/10^-3
							% the shutdown is completed
							obj.Status = 5;
							obj.SwitchCount = 0;
							obj.HystCount = 0;
						end
					case 6
						obj.SwitchCount = obj.SwitchCount + 1;
						if obj.SwitchCount >= Param.tSwitch/10^-3
							% the boot is completed
							obj.Status = 1;
							obj.SwitchCount = 0;
							obj.HystCount = 0;
						end
				end

			% normal operative range
			else
				obj.Status = 1;
				obj.HystCount = 0;
				obj.SwitchCount = 0;

			end

		end

		% cast object to struct
		function enbStruct = cast2Struct(obj)
			enbStruct = struct(obj);
		end

	end

end
