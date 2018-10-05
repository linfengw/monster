classdef AntennaArray
    % Implementation of Antenna Array configuration pr. ITU M.2412/3GPP 38.901
    % Copyright Jakob Thrane/DTU 2018
    properties
        Panels;
        ElementsPerPanel
        Polarizations;
        Bearing;
        Tilt; 
    end
    
    properties (Access = private)
        HEspacing; % Horizontal antenna element spacing
        VEspacing; % Vertical antenna element spacing
    end
    
    methods
        function obj = AntennaArray(arrayTuple, bearing, tilt)
            % arrayTuple defines structure of array in accordance with 3GPP
            % 38.901. (Mg, Ng, M, N, P). Where
            % Mg x Ng = Number of panels in rectangular grid
            % M x N = Number of elements per panel in rectangular grid
            % P = Number of polarizations per element.
            obj.Panels = cell((arrayTuple(1)*arrayTuple(2)),1);
            obj.ElementsPerPanel = arrayTuple(3:4);
            obj.Polarizations = arrayTuple(5);
            obj.Bearing = bearing;
            obj.Tilt = tilt;
            for iPanel = 1:length(obj.Panels)
                obj.Panels{iPanel} = obj.constructAntennaElements();
            end

        end
        
        function antennaElements = constructAntennaElements(obj)
            % Generate elements in rectangular grid
            antennaElements = cell(obj.ElementsPerPanel);
            for iAntennaM = 1:obj.ElementsPerPanel(1)
                for iAntennaN = 1:obj.ElementsPerPanel(2)
                 antennaElements{iAntennaM,iAntennaN} = AntennaElement(obj.Tilt,'');
                end
            end
				end
				
				function antennaGains = getAntennaGains(obj, TxPosition, RxPosition)
					% compute antenna gains for all elements given position of array
					% and position of receiver
					
					deltaX = RxPosition(1)-TxPosition(1);
					deltaY = RxPosition(2)-TxPosition(2);

% 					
% 					figure
% 					plot(RxPosition(1), RxPosition(2),'o')
% 					hold on
% 					plot(TxPosition(1), TxPosition(2),'x')
% 					xlim([0 500])
% 					ylim([0 500])
					% Compute bearing of Rx to Tx counterclockwise. North is 0 degrees
					RxBearing = -1*rad2deg(atan2(deltaX,deltaY));
					
					% Azimuth angle is then the bearing of the array - the bearing of
					% the rx to the antennarray.
					AzimuthAngle = obj.Bearing -  RxBearing;
					
					% Elevation is given by tan(theta) = deltaH/dist2d
					% Horizontal is 90 degrees, zenith is 0
					deltaH = TxPosition(3)-RxPosition(3);
					dist2d = norm(RxPosition(1:2)-TxPosition(1:2));
					ElevationAngle = rad2deg(atan(deltaH/dist2d))+90;
					
					antennaGains = cell([length(obj.Panels),obj.ElementsPerPanel]);
					% Loop all panels, and elements and get the gain of each 
					for iPanel = 1:length(obj.Panels)
						elements = obj.Panels{1};
						for iAntennaM = 1:obj.ElementsPerPanel(1)
							for iAntennaN = 1:obj.ElementsPerPanel(2)
								antennaGains{iPanel,iAntennaM,iAntennaN} = elements{iAntennaM, iAntennaN}.get3DGain(ElevationAngle, AzimuthAngle);
							end
						end
					end
			
				end

        function numPanels = NumberOfPanels(obj)
            numPanels = length(obj.Panels);
        end
    end
end

