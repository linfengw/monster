function generateHeatMap(Stations, Channel, Param)

%   GENERATE HEATMAP is used to gnerate a pathloss map in the scenario
%
%   Generates a heatmap per station.
%
%   Function fingerprint
%   Stations		->  array of eNodeBs
%
%   heatMap 		->  2D matrix with combined pathloss levels

% create a dummy UE that we move around in the grid for the heatMap
ue = UserEquipment(Param, 99);

Channel.plotHeatmap(Stations,ue);

end
