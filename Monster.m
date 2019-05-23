classdef Monster < matlab.mixin.Copyable
	% This class provides the main logic for a simulation
	% An instance of the class Monster has the following properties
	% 
	% :Config: (MonsterConfig) simulation config class instance
	% :Stations: (Array<EvolvedNodeB>) simulation eNodeBs class instances
	% :Users: (Array<UserEquipment>) simulation UEs class instances
	% :Channel: (Channel) simulation channel class instance
	% :Traffic: (TrafficGenerator) simulation traffic generator class instance

	properties 
		Config;
		Stations;
		Users;
		Channel;
		Traffic;
		Results;
		Backhaul;
	end

	methods 
		function obj = Monster(Config)
			% Monster constructor 
			%
			% :Config: MonsterConfig instance
			% :Stations: Array<EvolvedNodeB> instances
			% :Users: Array<UserEquipment> instances
			% :Channel: SonohiChannel instance
			% :Traffic: TrafficGenerator instance
			% :Results: MetricRecorder instance

			monsterLog('(MONSTER) setting up simulation', 'NFO');
			obj.setupSimulation(Config);
			monsterLog('(MONSTER) simulation setup completed', 'NFO');

			if obj.Config.SimulationPlot.runtimePlot
				% Draw the eNodeBs
				obj.Config.Plot.Layout.draweNBs(obj.Config);
				% Draw the UEs
				obj.Config.Plot.Layout.drawUes(obj.Users, obj.Config);
			end
		end

		function obj = setupSimulation(obj, Config)
			% setupSimulation calls the initialisation functions for the simulation properties
			% 
			% :param obj: Monster instance
			% :returns obj: initialised Monster instance
			%
			
			% Configure logs
			setpref('monsterLog', 'logToFile', Config.Logs.logToFile);
			setpref('monsterLog', 'logFile', Config.Logs.defaultLogName);

			% Create network layout
			monsterLog('(MONSTER - setupSimulation) setting up network layout', 'NFO');
			Config.setupNetworkLayout();

			% Setup eNodeBs
			monsterLog('(MONSTER - setupSimulation) setting up simulation eNodeBs', 'NFO');
			Stations = setupStations(Config);

			% Setup UEs
			monsterLog('(MONSTER - setupSimulation) setting up simulation UEs', 'NFO');
			Users = setupUsers(Config);

			% Setup channel
			monsterLog('(MONSTER - setupSimulation) setting up simulation channel', 'NFO');
			Channel = setupChannel(Stations, Users, Config);

			% Setup traffic
			monsterLog('(MONSTER - setupSimulation) setting up simulation traffic', 'NFO');
			[Traffic, Users] = setupTraffic(Users, Config);

			% Setup results
			monsterLog('(MONSTER - setupSimulation) setting up simulation metrics recorder', 'NFO');
			Results = setupResults(Config);

			%Setup Backhaul
			monsterLog('(MONSTER - setupSimulation) setting up simulation backhaul','NFO');
			Backhaul = setupBackhaulAggregation(Stations, Traffic, Config);

			% Assign the properties to the Monster object
			obj.Config = Config;
			obj.Stations = Stations;
			obj.Users = Users;
			obj.Channel = Channel;
			obj.Traffic = Traffic;
			obj.Results = Results;		
			obj.Backhaul = Backhaul;	
		end
		
		function obj = setupRound(obj, iRound)
			% setupRound configures the simulation runtime parameters prior the start of a round
			%
			% :obj: Monster instance
			% :iRound: Integer that represents the new simulation round
			%

			% Update Config property
			obj.Config.Runtime.currentRound = iRound;
			obj.Config.Runtime.currentTime = iRound*10e-3;  
			obj.Config.Runtime.remainingTime = (obj.Config.Runtime.totalRounds - obj.Config.Runtime.currentRound)*10e-3;
			obj.Config.Runtime.remainingRounds = obj.Config.Runtime.totalRounds - obj.Config.Runtime.currentRound - 1;
			% Update Channel property
			obj.Channel.setupRound(obj.Config.Runtime.currentRound, obj.Config.Runtime.currentTime);
		
		end

		function obj = run(obj)
			% run performs all the calls to methods needed for a single simulation round
			%
			% :obj: Monster instance
			%

			monsterLog('(MONSTER - run) performing UE movement', 'NFO');
			obj.moveUsers();

			monsterLog('(MONSTER - run) checking UE-eNodeB association', 'NFO');
			obj.associateUsers();

			monsterLog('(MONSTER - run) updating UE transmission queues', 'NFO');
			obj.updateUsersQueues();

			monsterLog('(MONSTER - run) downlink UE scheduling', 'NFO');
			obj.schedule();

			monsterLog('(MONSTER - run) creating TB, codewords and waveforms for downlink', 'NFO');
			obj.setupEnbTransmitters();

			monsterLog('(MONSTER - run) traversing channel in downlink', 'NFO');
			obj.downlinkTraverse();

			monsterLog('(MONSTER - run) downlink UE reception', 'NFO');
			obj.downlinkUeReception();

			monsterLog('(MONSTER - run) downlink UE data decoding', 'NFO');
			obj.downlinkUeDataDecoding();

			monsterLog('(MONSTER - run) setting up UE uplink', 'NFO');
			obj.setupUeTransmitters();
			
			monsterLog('(MONSTER - run) traversing channel in uplink', 'NFO');
			obj.uplinkTraverse();

			monsterLog('(MONSTER - run) uplink eNodeB reception', 'NFO');
			obj.uplinkEnbReception();

			% TODO: no data is actually being sent
			%monsterLog('(MONSTER - run) uplink eNodeB data decoding', 'NFO');
			%obj.uplinkEnbDataDecoding();
		end

		function obj = collectResults(obj)
			% collectResults performs the collection and processing of a simulation round
			%
			% :obj: Monster instance
			%

			monsterLog('(MONSTER - collectResults) eNodeB metrics recording', 'NFO');
			obj.Results = obj.Results.recordEnbMetrics(obj.Stations, obj.Config);

			monsterLog('(MONSTER - collectResults) UE metrics recording', 'NFO');
			obj.Results = obj.Results.recordUeMetrics(obj.Users, obj.Config.Runtime.currentRound);

			monsterLog('(MONSTER - collectResults) Backhaul metrics recording', 'NFO');
			obj.Results = obj.Results.recordBackhaulMetrics(obj.Backhaul, obj.Config.Runtime.currentRound);
		
		end

		function obj = clean(obj)
			% clean performs a cleanup of the simulation data structures for the next round
			%
			% :obj: Monster instance
			%

			monsterLog('(MONSTER - clean) eNodeB end of round cleaning', 'NFO');
			arrayfun(@(x)x.reset(obj.Config.Runtime.currentRound + 1), obj.Stations);

			monsterLog('(MONSTER - clean) eNodeB end of round cleaning', 'NFO');
			arrayfun(@(x)x.reset(), obj.Users);		
		end
			

	end	

	methods (Access = private)
		function obj = moveUsers(obj)
			% moveUsers performs UE movements at the beginning of each round
			%
			% :obj: Monster instanceo

			arrayfun(@(x)x.move(obj.Config.Runtime.currentRound), obj.Users);
		end

		function obj = associateUsers(obj)
			% associateUsers associates UEs to eNodeBs based on the association refresh timer
			%
			% :obj: Monster instance

			if mod(obj.Config.Runtime.currentTime, obj.Config.Scheduling.refreshAssociationTimer) == 0
				monsterLog('(MONSTER - associateUsers) UEs-eNodeBs re-associating', 'NFO');
				[obj.Users, obj.Stations] = refreshUsersAssociation(obj.Users, obj.Stations, obj.Channel, obj.Config);
			else
				monsterLog('(MONSTER - associateUsers) UEs-eNodeBs not re-associated', 'NFO');
			end			
		end
		
		function obj = updateUsersQueues(obj)
			% updateUsersQueues is used to update the transmission queues for a UE based on the current simulation time
			% 
			% :obj: Monster instance

			% Backhaul limits define which users have acces to data and how much
			% Find users associated with each eNB and aggregate their traffic.
			for iStation = 1:(obj.Config.MacroEnb.number+obj.Config.MicroEnb.number)
				Users = zeros(1,obj.Config.Ue.number);
				%Find associated UEs
				for iUser = 1: obj.Config.Ue.number
					if obj.Stations(iStation).Users(iUser).UeId > 0
						Users(iUser) = obj.Stations(iStation).Users(iUser).UeId;
					end
				end
				Users = Users(Users > 0); %UserIDs of UEs associated with the eNB


				%Apply delay
				obj.Backhaul(iStation).updateAllQueues(obj.Users(Users), obj.Config.Runtime.currentTime);

				%Update the transmission for users 
				for iUser = 1: length(Users)
					%UeTrafficGenerator = obj.Traffic([obj.Traffic.Id] == obj.Users(Users(iUser)).Traffic.generatorId);
					%obj.Users(Users(iUser)).Queue = UeTrafficGenerator.updateTransmissionQueue(obj.Users(Users(iUser)), obj.Config.Runtime.currentTime);
					obj.Users(Users(iUser)).Queue = obj.Backhaul(iStation).Queues(iUser);
				end
				
			end
		end

		function obj = schedule(obj) 
			% schedule is used to perform the allocation of eNodeB resources in the downlink to the UEs
			% 
			% :obj: Monster instance
			%
			
			% Set the ShouldSchedule flag for all the eNodeBs 
			arrayfun(@(x)x.evaluateScheduling(obj.Users), obj.Stations);

			% Now call the schedule method on the eNodeBs
			arrayfun(@(x)x.downlinkSchedule(obj.Users, obj.Config), obj.Stations);

			% Finally, evaluate the power state for the eNodeBs
			% TODO revise for multiple macro eNodeBs
			% arrayfun(@(x)x.evaluatePowerState(obj.Config, obj.Stations), obj.Stations)
		end

		function obj = setupEnbTransmitters(obj)
			% setupEnbTransmitters is used to prepare the data for the downlink transmission
			% 
			% :obj: Monster instance
			%
			
			% Create the transport blocks for all the UEs
			arrayfun(@(x)x.generateTransportBlockDL(obj.Stations, obj.Config), obj.Users);

			% Create the codewords for all the UEs
			arrayfun(@(x)x.generateCodewordDL(), obj.Users);

			% Setup the reference signals at the eNB transmitters 
			arrayfun(@(x)x.setupGrid(obj.Config.Runtime.currentRound), [obj.Stations.Tx]);

			% Create the symbols for all the UEs' codewords at the eNodeBs
			arrayfun(@(x)x.setupPdsch(obj.Users), obj.Stations);

			% Finally modulate the waveform for all the eNodeBs
			arrayfun(@(x)x.modulateTxWaveform(), [obj.Stations.Tx]);

		end

		function obj = downlinkTraverse(obj)
			% donwlinkTraverse is used to perform a channel traversal in the downlink
			% 
			% :obj: Monster instance
			%
			
			obj.Channel.traverse(obj.Stations, obj.Users, 'downlink');

		end

		function obj = downlinkUeReception(obj)
			% donwlinkUeReception is used to perform the reception of the eNodeBs waveforms in downlink at the UEs
			% 
			% :obj: Monster instance
			%
			
			arrayfun(@(x)x.downlinkReception(obj.Stations, obj.Channel.Estimator.Downlink), obj.Users);

		end

		function obj = downlinkUeDataDecoding(obj)
			% downlinkUeDataDecoding is used to decode the data contained in the demodulated waveform
			% 
			% :obj: Monster instance
			%

			arrayfun(@(x)x.downlinkDataDecoding(obj.Config), obj.Users);
		end

		function obj = setupUeTransmitters(obj)
			% setupUeTransmitters is used to setup the UE transmitters for the uplink
			% 
			% :obj: Monster instance
			% 
			arrayfun(@(x)x.setupTransmission(), [obj.Users.Tx]);
		
		end

		function obj = uplinkTraverse(obj)
			% uplinkTraverse is used to perform a channel traversal in the uplink
			% 
			% :obj: Monster instance
			% 
			obj.Channel.traverse(obj.Stations, obj.Users,'uplink');
		
		end

		function obj = uplinkEnbReception(obj)
			% uplinkEnbReception performs the reception of the UEs waveforms in uplink at the eNodeBs
			% 
			% :obj: Monster instance
			%
			arrayfun(@(x)x.createReceivedSignal(), [obj.Stations.Rx]);
			arrayfun(@(x)x.uplinkReception(obj.Users, obj.Config.Runtime.currentTime, obj.Channel.Estimator), obj.Stations);			
		
		end 

		function obj = uplinkEnbDataDecoding(obj)
			% uplinkEnbDataDecoding performs the decoding of the data contained in the demodulated waveform
			%
			% :obj: Monster instance
			%

			arrayfun(@(x)x.uplinkDataDecoding(obj.Users, obj.Config), obj.Stations);
		
		end
	end
end