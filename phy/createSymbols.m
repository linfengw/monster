function [Station, User] = createSymbols(Station, User)

% 	CREATE SYMBOLS is used to generate the arrays of complex symbols
%
%   Function fingerprint
%   Station							-> 	the eNodeB processing the codeword
%   User								->	the UE for this codeword
%
%   Station							-> 	updated eNodeB
%   User								->	the UE for this codeword

	% cast eNodeB object to struct for the processing
	% find all the PRBs assigned to this UE to find the most conservative MCS (min)
	sch = Station.ScheduleDL;
	ixPRBs = find([sch.UeId] == User.NCellID);
	listMCS = [sch(ixPRBs).Mcs];

	% get the correct Parameters for this UE
	[~, mod, ~] = lteMCS(min(listMCS));

	% get the codeword
	cwd = User.Codeword;

	% setup the PDSCH for this UE
	Station.Tx.PDSCH.Modulation = mod;	% conservative modulation choice from above
	Station.Tx.PDSCH.PRBSet = (ixPRBs - 1).';	% set of assigned PRBs

	% Get info and indexes
	[pdschIxs, SymInfo] = ltePDSCHIndices(struct(Station), Station.Tx.PDSCH, Station.Tx.PDSCH.PRBSet);
	
	if length(cwd) ~= SymInfo.G
		% In this case seomthing went wrong with the rate maching and in the
		% creation of the codeword, so we need to flag it
		sonohilog('Something went wrong in the codeword creation and rate matching. Size mismatch','WRN');
	end

	% error handling for symbol creation
	try
		sym = ltePDSCH(struct(Station), Station.Tx.PDSCH, cwd);
	catch ME
		fSpec = 'symbols generation failed for codeword with length %i\n';
		s=sprintf(fSpec, length(cwd));
    sonohilog(s,'WRN')
		sym = [];
	end
	
	SymInfo.symSize = length(sym);
	SymInfo.pdschIxs = pdschIxs;
	SymInfo.indexes = ixPRBs;
	User.SymbolsInfo = SymInfo;

	% Set the symbols into the grid of the eNodeB
	Station.Tx = Station.Tx.setPDSCHGrid(Station, sym);
	% Write back into station
	Station.Tx.ReGrid = Station.Tx.ReGrid;
end
