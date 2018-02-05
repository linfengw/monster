%   BackhaulLink defines a value class for the core network

classdef BackhaulLink
	%   BackhaulLink 
	properties
		MediaType;
		Capacity;
		Latency;
		Technology;
		LinkStatus;
	end
	
	methods
		% Constructor
		function obj = BackhaulLink(Param)
			obj.MediaType = Param.backhaul.MediaType;
			obj.Capacity = Param.backhaul.Capacity;
			obj.Latency = Param.backhaul.Latency;
			obj.Technology = Param.backhaul.Technology;
			obj.LinkStatus = 1;
		end

		% Send packet
		function obj = sendPacket(obj, pkt)
			
		end
		
				
	end
	
end
