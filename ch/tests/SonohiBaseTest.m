classdef SonohiBaseTest < matlab.unittest.TestCase
	%SonohiBaseTest tests base calculations done in the sonohibase
	
	methods (Test)
		function testConstructor(testCase)
			actSolution = sonohiBase('test','test');
		end
	end
	
end