% Packet is a value class that defines a packet object 

classdef Packet
	properties
		Transmitter;
		Receiver;
		Payload;
		Header;
	end

	methods 
		% Constructor
		function obj = Packet(tx, rx, payload, header)
			obj.Transmitter = tx;
			obj.Receiver = rx;
			obj.Payload = payload;
			obj.Header = header;
		end

		function sz = getPayloadSize(obj)
			sz = length(obj.Payload);
		end

		function sz = getHeaderSize(obj)
			sz = length(obj.Header);
		end

		function sz = getPayloadSize(obj)
			sz = length(obj.Payload) + length(obj.Header);
		end
	end
end