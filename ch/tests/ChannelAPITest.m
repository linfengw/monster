%% Test Class Definition
classdef ChannelAPITest < matlab.unittest.TestCase


		properties
			Channel
			Param
			Stations
		end

		methods (TestMethodSetup)
		
			function createChannel(testCase)

				load('ChTestParam.mat','Param');
				
				Stations = createBaseStations(Param);
				Users = [];
				testCase.Param = Param;
				testCase.Stations = Stations;
				testCase.Channel = MonsterChannel(Stations, Users, Param);
			end

		end
    
    %% Test Method Block
    methods (Test)
        
        %% Test Function
        function testConstructor(testCase)
            testCase.verifyTrue(isa(testCase.Channel,'MonsterChannel'))
				end
				
				function testSetupStationConfigs(testCase)
					testCase.verifyTrue(~isempty(testCase.Channel.StationConfigs))
					testCase.verifyEqual(length(fieldnames(testCase.Channel.StationConfigs)),length(testCase.Stations))
				end

				function testStationConfigs(testCase)
					for iStation = 1:length(testCase.Stations)
						station = testCase.Stations(iStation);
						config = testCase.Channel.findStationConfig(station);
						testCase.verifyTrue(~isempty(config.Position))
						testCase.verifyTrue(isa(config.Tx,'enbTransmitterModule'))
						testCase.verifyTrue(isa(config.SpatialMaps, 'struct'))
						testCase.verifyTrue(isa(config.LSP, 'struct'))
						testCase.verifyTrue(isa(config.Seed, 'double'))
						testCase.verifyTrue(all(isfield(config.LSP, {'sigmaSFLOS', 'sigmaSFNLOS', 'dCorrLOS', 'dCorrNLOS', 'dCorrLOSprop'})))
					end
				end

				function testSpatialMaps(testCase)
					for iStation = 1:length(testCase.Stations)
						station = testCase.Stations(iStation);
						config = testCase.Channel.findStationConfig(station);
						testCase.verifyTrue(isfield(config.SpatialMaps, 'LOS'))
						testCase.verifyTrue(isfield(config.SpatialMaps, 'axisLOS'))
						testCase.verifyTrue(isfield(config.SpatialMaps, 'NLOS'))
						testCase.verifyTrue(isfield(config.SpatialMaps, 'axisNLOS'))
						testCase.verifyTrue(isa(config.SpatialMaps.LOS, 'double'))
						testCase.verifyTrue(isa(config.SpatialMaps.axisLOS, 'double'))
						testCase.verifyTrue(isa(config.SpatialMaps.NLOS, 'double'))
						testCase.verifyTrue(isa(config.SpatialMaps.axisNLOS, 'double'))

					end
				end
    end
end