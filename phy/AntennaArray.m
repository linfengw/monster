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

        function numPanels = NumberOfPanels(obj)
            numPanels = length(obj.Panels);
        end
    end
end

