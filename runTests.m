import matlab.unittest.TestSuite;
% Folders to test
suite = TestSuite.fromFolder('ch', 'IncludingSubfolders', true);
result = run(suite);