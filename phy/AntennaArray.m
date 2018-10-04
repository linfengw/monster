classdef AntennaArray
 
    
    properties
        noAntennas;
        bearing;
        tilt; 
    end
    
    properties (Access = private)
        Hspacing; % Horizontal spacing
        Vspacing; % Vertical spacing
    end
    
    methods
        function obj = AntennaArray(noAntennas, bearing, tilt)
            obj.noAntennas = noAntennas;
            obj.bearing = bearing;
            obj.tilt = tilt;
            obj.constructAntennaArray()

        end
        
        function constructAntennaArray(obj)
            antennaElements = cell(obj.noAntennas,1);
            for iAntenna = 1:obj.noAntennas
                antennaElements{iAntenna} = AntennaElement(obj.tilt,'');
            end
        end
    end
end

