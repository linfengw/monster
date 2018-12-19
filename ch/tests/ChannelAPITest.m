%% Test Class Definition
classdef ChannelAPITest < matlab.unittest.TestCase


		properties
			Channel
			ChannelModel
			ChannelNoSF;
			ChannelNoSFModel;
			Param
			Stations
			Users;
			SFplot
		end

		methods (TestMethodSetup)
		
			function createChannel(testCase)

				load('ChTestParam.mat','Param');
				
				Stations = createBaseStations(Param);
				Users = createUsers(Param);
				testCase.Param = Param;
				testCase.Stations = Stations;
				testCase.Users = Users;
				testCase.Channel = MonsterChannel(Stations, Users, Param);
				testCase.ChannelModel = testCase.Channel.ChannelModel;
				testCase.SFplot = testCase.ChannelModel.plotSFMap(Stations(1));
				Param.channel.enableShadowing = 0;
				testCase.ChannelNoSF = MonsterChannel(Stations, Users, Param);
				testCase.ChannelNoSFModel = testCase.ChannelNoSF.ChannelModel;
			end

		end
		
		methods (TestMethodTeardown)
		
			function closePlots(testCase)
				close(testCase.SFplot)
			end

		end
    
    %% Test Method Block
    methods (Test)
        
        %% Test Function
        function testConstructor(testCase)
            testCase.verifyTrue(isa(testCase.Channel,'MonsterChannel'))
				end

				function testChannelModel(testCase)
					switch testCase.Param.channel.mode
						case '3GPP38901'
							testCase.verifyTrue(isa(testCase.ChannelModel,'Monster3GPP38901'))
						case 'Quadriga'
							testCase.verifyTrue(isa(testCase.ChannelModel,'MonsterQuadriga'))
						end
				end
				
				function testSetup3GPPStationConfigs(testCase)
					testCase.verifyTrue(~isempty(testCase.ChannelModel.StationConfigs))
					testCase.verifyEqual(length(fieldnames(testCase.ChannelModel.StationConfigs)),length(testCase.Stations))
				end

				function test3GPPStationConfigs(testCase)
					for iStation = 1:length(testCase.Stations)
						station = testCase.Stations(iStation);
						config = testCase.ChannelModel.findStationConfig(station);
						testCase.verifyTrue(~isempty(config.Position))
						testCase.verifyTrue(isa(config.Tx,'enbTransmitterModule'))
						testCase.verifyTrue(isa(config.SpatialMaps, 'struct'))
						testCase.verifyTrue(isa(config.LSP, 'struct'))
						testCase.verifyTrue(isa(config.Seed, 'double'))
						testCase.verifyTrue(all(isfield(config.LSP, {'sigmaSFLOS', 'sigmaSFNLOS', 'dCorrLOS', 'dCorrNLOS', 'dCorrLOSprop'})))
					end
				end

				function test3GPPSpatialMaps(testCase)
					for iStation = 1:length(testCase.Stations)
						station = testCase.Stations(iStation);
						config = testCase.ChannelModel.findStationConfig(station);
						testCase.verifyTrue(isfield(config.SpatialMaps, 'LOS'))
						testCase.verifyTrue(isfield(config.SpatialMaps, 'axisLOS'))
						testCase.verifyTrue(isfield(config.SpatialMaps, 'NLOS'))
						testCase.verifyTrue(isfield(config.SpatialMaps, 'axisNLOS'))
						testCase.verifyTrue(isfield(config.SpatialMaps, 'LOSprop'))
						testCase.verifyTrue(isfield(config.SpatialMaps, 'axisLOSprop'))
						testCase.verifyTrue(isa(config.SpatialMaps.LOS, 'double'))
						testCase.verifyTrue(isa(config.SpatialMaps.axisLOS, 'double'))
						testCase.verifyTrue(isa(config.SpatialMaps.NLOS, 'double'))
						testCase.verifyTrue(isa(config.SpatialMaps.axisNLOS, 'double'))
						testCase.verifyTrue(isa(config.SpatialMaps.LOSprop, 'double'))
						testCase.verifyTrue(isa(config.SpatialMaps.axisLOSprop, 'double'))
					end
				end

				function test3GPPSpatialMapsNoSF(testCase)
					for iStation = 1:length(testCase.Stations)
						station = testCase.Stations(iStation);
						config = testCase.ChannelNoSFModel.findStationConfig(station);
						testCase.verifyTrue(~isfield(config.SpatialMaps, 'LOS'))
						testCase.verifyTrue(~isfield(config.SpatialMaps, 'axisLOS'))
						testCase.verifyTrue(~isfield(config.SpatialMaps, 'NLOS'))
						testCase.verifyTrue(~isfield(config.SpatialMaps, 'axisNLOS'))
						testCase.verifyTrue(isfield(config.SpatialMaps, 'LOSprop'))
						testCase.verifyTrue(isfield(config.SpatialMaps, 'axisLOSprop'))
						testCase.verifyTrue(isa(config.SpatialMaps.LOSprop, 'double'))
						testCase.verifyTrue(isa(config.SpatialMaps.axisLOSprop, 'double'))
					end
				end

				function testTraverseValidator(testCase)
					testCase.verifyError(@() testCase.Channel.traverse(testCase.Stations, testCase.Users, ''),'MonsterChannel:noChannelMode')
					testCase.verifyError(@() testCase.Channel.traverse(testCase.Stations, [], 'downlink'),'MonsterChannel:WrongUserClass')	
					testCase.verifyError(@() testCase.Channel.traverse([], [], 'downlink'),'MonsterChannel:WrongStationClass')
					
					% No users assigned
					testCase.verifyError(@() testCase.Channel.traverse(testCase.Stations, testCase.Users, 'downlink'),'MonsterChannel:NoUsersAssigned')					
				end

				function testTraverseDownlink(testCase)

					% Assign user
					testCase.Stations(1).Users = struct('UeId', testCase.Users(1).NCellID, 'CQI', -1, 'RSSI', -1);
					testCase.Users(1).ENodeBID = testCase.Stations(1).NCellID;

					% Traverse channel downlink
					testCase.Channel.traverse(testCase.Stations, testCase.Users, 'downlink')
					testCase.verifyTrue(~isempty(testCase.ChannelModel.TempSignalVariables.RxWaveform))
					testCase.verifyTrue(~isempty(testCase.ChannelModel.TempSignalVariables.RxWaveformInfo))
					
					testCase.verifyTrue(~isempty(testCase.Users(1).Rx.Waveform))

				end
				
    end
end