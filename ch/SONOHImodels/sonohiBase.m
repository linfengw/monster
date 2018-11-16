classdef sonohiBase < handle
	% This is the parent class for all channel modelling. Wrappers for channel models should be written using this structure. For examples on how to do so see the other implementations.
	
	properties
		Channel % For accessing variables in the channel coordinator :class:`ch.SonohiChannel`
	end
	
	methods
		function obj = sonohiBase(Channel)
			sonohilog('Initializing channel model.','NFO0')
			obj.Channel = Channel;
		end

		function obj = setup(obj, ~, ~, ~)
			% pass
		end
		
		function [stations,users] = run(obj,Stations,Users, chtype, varargin)
			% Main execution method, switches between uplink and downlink logic.
			%
			% :param varargin: If the channel property needs to be updated before execution it can be added as 'channel, :class:`ch.SonohiChannel`'
			if ~isempty(varargin)
				vargs = varargin;
				nVargs = length(vargs);
				
				for k = 1:nVargs
					if strcmp(vargs{k},'channel')
						obj.Channel = vargs{k+1};
					end
				end
			end
			
			
			switch chtype
				case 'downlink'
					users = obj.downlink(Stations,Users);
					stations = Stations;
				case 'uplink'
					stations = obj.uplink(Stations,Users);
					users = Users;
			end
			
		end
		
		function [stations] = uplink(obj, Stations, Users)
			
			stations = Stations;
			numLinks = length(Users);
			Pairing = obj.Channel.getPairing(Stations);
			
			for i = 1:numLinks
				% Local copy for mutation
				station = Stations([Stations.NCellID] == Pairing(1,i));
				user = Users(find([Users.NCellID] == Pairing(2,i))); %#ok
				
				%% TODO: replace this with compound waveform selection (shaping of all received waveforms)
				station = obj.setWaveform(user, station);
				
				% Get channel conditions (Slow variants, i.e. path loss
				[station, ~] = obj.computeLinkBudget(station, user, 'uplink');
				
				if strcmp(obj.Channel.fieldType,'full')
					if obj.Channel.enableFading
						station = obj.addFading(user, station, 'uplink');
					end
					station = obj.addAWGN(user, station, 'uplink');
				else
					station = obj.addAWGN(user, station,  'uplink');
				end
				
				
				stations(find([Stations.NCellID] == Pairing(1,i))) = station;
			end

		end

		function [users] = downlink(obj,Stations,Users)
			% Standard downlink logic. Output of this function is written into the :class:`ue.ueReceiverModule` of the users. If the users are scheduled for transmission
			% The downlink logic follows the follow flow
			%
			% 1. Find links and eNB - UE pairing.
			% 2. Setup transmission by copying :attr:`Stations.Tx.Waveform` into :attr:`Users.Rx.Waveform`.
			% 3. Compute link budget and thus calucated receiver power.
			% 4. If :attr:`Channel.enableFading`, add fading to waveform.
			% 5. Add AWGN based on thermal noise and receiver power. Compute SNR.
			% 6. Add propagation delay.
			%
			% :param Stations: Primarily need :attr:`Stations.Tx` Transmitter module
			% :type Stations: :class:`enb.EvolvedNodeB`
			% :param Users: Primarily need :attr:`Users.Tx` Receiver module
			% :type Users: :class:`ue.UserEquipment`
			users = Users;
			numLinks = length(Users);
			Pairing = obj.Channel.getPairing(Stations);
			for i = 1:numLinks
				% Local copy for mutation
				station = Stations([Stations.NCellID] == Pairing(1,i));
				user = Users(find([Users.NCellID] == Pairing(2,i))); %#ok
				
				% Setup transmission
				user = obj.setWaveform(station, user);
				
				% compute link budget and calculate Receiver power
				[~, user] = obj.computeLinkBudget(station, user, 'downlink');
				
				if strcmp(obj.Channel.fieldType,'full')
					if obj.Channel.enableFading
						user = obj.addFading(station, user, 'downlink');
					end
					user = obj.addAWGN(station, user, 'downlink');
				else
					user = obj.addAWGN(station, user, 'downlink');
				end
				
				user = obj.addPropDelay(station, user);
				
				% Write changes to user object in array.
				users(find([Users.NCellID] == Pairing(2,i))) = user;
			end
		end
		
		function setupShadowing(obj, varargin)
			% Function needs overwrite from models to enable shadowing
			sonohilog(sprintf('No setupShadowing method detected on chosen model %s',obj.Chtype),'ERR');
		end
		
		function RxNode = addPropDelay(obj,  TxNode, RxNode)
			% Adds propagation delay based on distance and frequency
			RxNode.Rx.PropDelay = obj.Channel.getDistance(TxNode.Position, RxNode.Position);
		end
		
		function [Station, User] = computeLinkBudget(obj, Station, User, mode)
			% Compute link budget for Tx -> Rx
			%
			% This requires a :meth:`computePathLoss` method, which is supplied by child classes.
			% returns updated RxPwdBm of RxNode.Rx
			% The channel is reciprocal in terms of received power, thus the path
			% loss is extracted from channel conditions provided by 
			switch mode
				case 'downlink'
					lossdB = obj.computePathLoss(Station, User, Station.Tx.Freq);
					EIRPdBm = Station.Tx.getEIRPdBm;
					rxPwdBm = EIRPdBm-lossdB-User.Rx.NoiseFigure; %dBm
					User.Rx.RxPwdBm = rxPwdBm;
				case 'uplink'
					lossdB = obj.computePathLoss(Station, User, User.Tx.Freq);
					EIRPdBm = User.Tx.getEIRPdBm;
					rxPwdBm = EIRPdBm-lossdB-Station.Rx.NoiseFigure; %dBm
					Station.Rx.RxPwdBm = rxPwdBm;
			end

		end

		
		function [RxNode] = addAWGN(obj, TxNode, RxNode,mode)
			% Adds gaussian noise based on thermal noise and calculated recieved power.
			
			% TODO: Gas Loss relevant to compute when moving into mmWave range
			%gasLossdB = obj.atmosphericLoss(TxNode, RxNode);
			thermalLossdBm = obj.thermalLoss(RxNode);
			
			%rxNoiseFloor = thermalLossdB-gasLossdB;
			rxNoiseFloor = thermalLossdBm;
			SNR = RxNode.Rx.RxPwdBm-rxNoiseFloor;
			SNRLin = 10^(SNR/10);
			str1 = sprintf('Station(%i) to User(%i)\n SNR:  %s\n RxPw:  %s\n', TxNode.NCellID,RxNode.NCellID,num2str(SNR),num2str(RxNode.Rx.RxPwdBm));
			sonohilog(str1,'NFO0');
			
			% Compute spectral noise density NO
			switch mode
				case 'downlink'
				Es = sqrt(2.0*TxNode.CellRefP*double(RxNode.Rx.WaveformInfo.Nfft));
				N0 = 1/(Es*SNRLin);
				case 'uplink'
				N0 = 1/(SNRLin * sqrt(double(RxNode.Rx.WaveformInfo.Nfft)))/sqrt(2);
			end
			
			% Add AWGN
			noise = N0*complex(randn(size(RxNode.Rx.Waveform)), randn(size(RxNode.Rx.Waveform)));
			rxSig = RxNode.Rx.Waveform + noise;
			
			% Write info to receiver object
			RxNode.Rx.SNR = SNRLin;
			RxNode.Rx.Waveform = rxSig;
			
		end
		
		
		
	end
	
	methods(Static)
		
		function RxNode = setWaveform(TxNode, RxNode)
			% Copies waveform and waveform info to Rx module, enables transmission.
			RxNode.Rx.Waveform = TxNode.Tx.Waveform;
			RxNode.Rx.WaveformInfo =  TxNode.Tx.WaveformInfo;
		end
		
		function lossdBm = thermalLoss(RxNode)
			% Compute thermal loss based on bandwidth, at T = 290 K.
			% Worst case given by the number of resource blocks. Bandwidth is
			% given based on the waveform. Computed using matlabs :obj:`obw`
			bw = obw(RxNode.Rx.Waveform, RxNode.Rx.WaveformInfo.SamplingRate);
			T = 290;
			k = physconst('Boltzmann');
			thermalNoise = k*T*bw;
			lossdBm = 10*log10(thermalNoise*1000);
		end
		
		
	end
	
	
	
end
