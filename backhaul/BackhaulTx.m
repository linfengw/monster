% Backhaul transmitter class

classdef BackhaulTx
	properties 
		Id;
		Technology;
		TxPower;
		BaudRate;
		Bandwidth;
		CarrierFrequency;
		Modulation;
		TxSignal;
	end

	methods 
		function obj = BackhaulTx(id, tech, pow, bdRate, bw, cf, modulation)
			obj.Id = id; 
			obj.Technology = tech;
			obj.TxPower = pow;
			obj.BaudRate = bdrate;
			obj.Bandwidth = bw;
			obj.CarrierFrequency = cf;
			obj.Modulation = modulation;
			obj.TxSignal = [];
		end

		% Send packet
		function obj = sendPacket(obj, pkt)
			
		end
	end
	
end