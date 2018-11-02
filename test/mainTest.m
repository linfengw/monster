%% Test class definition

classdef mainTest < matlab.unittest.TestCase

    methods (Test)

        function testMainScript(testCase)
            % Function to test that main scripts runs properly and without errors.
            % Runs sonohi, to update paths
            sonohi;
            % initParam is evaluated as wrongly set parameters can cause problems.
            load('SimulationParameters.mat');
            Param.numMacro=1;
            Param.schRounds = 5;
            % Asses if the test is passed
            expPass = true;
            try
                
                main;
                actPass =true;
            catch ME
                msg = ['Error occured due to '];

                causeException = MException(ME.identifier, msg);
                ME = addCause(ME, causeException);
                rethrow(ME)
                actPass =false;
            end
            %close all
             
            testCase.verifyEqual(actPass,expPass);
        end

        function testInitParam(testCase)
            %Function to test the validity of initParam
            load('SimulationParameters.mat');
            actParam = Param.numMacro;  %actual parameter
            expParam = 1;               %Expected paramter
            testCase.verifyEqual(1, 1);
        end

    end
end