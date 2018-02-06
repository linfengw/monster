%   BackhaulLink defines a value class for the core network

classdef BackhaulLink
	%   Backhaul lLink 
	properties
		Id;
		Technology;
		Capacity;
		Status;
		Length;
	end
	
	methods
		% Constructor
		function obj = BackhaulLink(id, tech, cp, status, len)
			obj.Id = id;
			obj.Technology = tech;
			obj.Capacity = cp;
			obj.Status = status;
			obj.Length = len;
		end

		% Propagate a signal
		function obj = propagate(obj, sig)
			
		end
		
				
	end
	
end
