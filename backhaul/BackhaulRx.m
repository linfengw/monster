% BackhaulRx

classdef BackhaulRx
	properties 
		Id;
		Technology;
		RxSensitivity;
		Bandwidth;
		CarrierFrequency;
		Fec;
		RxSignal;
	end

	methods 
		function obj = BackhaulRx(id, tech, pow, bdRate, bw, cf)
			obj.Id = id; 
			obj.Technology = tech;
			obj.RxSensitivity = pow;
			obj.Bandwidth = bw;
			obj.CarrierFrequency = cf;
		end

		% Receive signal
		function obj = receiveSignal(obj, sig)
			
		end
	end
	
end