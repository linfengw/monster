%   BackhaulLink defines a value class for the core network

classdef BackhaulLink
	%   Backhaul lLink 
	properties
		Id;
		Technology;
		Capacity;
		Status;
		Length;
		TxQueue(1000,1) = struct('Signal', [], 'DeliveryTime', -1);
		ProcessingDelay;
	end
	
	methods
		% Constructor
		function obj = BackhaulLink(id, tech, cp, status, len)
			obj.Id = id;
			obj.Technology = tech;
			obj.Capacity = cp;
			obj.Status = status;
			obj.Length = len;
			obj.ProcessingDelay = 0;
		end

		% Used to receive a signal from a transmitter and add it to the TxQueue
		function obj = queueTransmission(obj, sig, sz, rate, tNow)
			% Calculate the time this signal as to be delivered at the receiver
			% Transmission delay is given by the packet size and the agreed rate
			delayTx = sz/rate;
			% The propagation delay is given by the medium propagation constant and the length
			velocityProp = physconst('LightSpeed');
			switch obj.Technology
				case 'fibre'
					velocityProp = velocityProp/1.444;
				case 'radio'
					velocityProp = velocityProp/1.000293;
				case 'copper'
					velocityProp = velocityProp/1.5708;
			end
			delayProp = obj.Length/velocityProp;
			% Add processing delay and queueing delay (currently 0)
			delayE2E = delayTx + delayProp + obj.ProcessingDelay;
			% Find a position in the queue
			for iQueue = 1:length(obj.TxQueue)
				if isempty(obj.TxQueue(iQueue).Signal) && obj.TxQueue(iQueue).DeliveryTime == -1
					obj.TxQueue(iQueue).Signal = sig;
					obj.TxQueue(iQueue).DeliveryTime = tNow + delayE2E;
					break;
				end
			end

		end

		% Used to loop the TxQueue to check whether any signal should be propagated through the link
		function [obj, out] = propagate(obj, tNow)
			out = find(...
				(~isempty([obj.TxQueue.Signal])) &&...
				([obj.TxQueue.Signal] ~= -1) &&...
				([obj.TxQueue.Signal] <= tNow));
		end
		
				
	end
	
end
