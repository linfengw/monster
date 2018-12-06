classdef enbReceiverModule < handle
	properties
		NoiseFigure;
		UeData;
		ReceivedSignals; %Cells containing: waveform(s) from a user, and userID
		Waveform;
		Waveforms;
	end
	
	properties(Access=private)
		enbObj; % Parent object
	end
	
	methods
		
		function obj = enbReceiverModule(enbObj, Param)
			obj.NoiseFigure = Param.eNBNoiseFigure;
			obj.ReceivedSignals = cell(Param.numUsers,1);
			obj.enbObj = enbObj;
		end
		
		function createRecievedSignalStruct(obj, id)
			obj.ReceivedSignals{id} = struct('Waveform', [], 'WaveformInfo', [], 'RxPwdBm', [], 'SNR', []);
		end

		function obj = set.UeData(obj,UeData)
			obj.UeData = UeData;
		end
		
		function foundSignals = anyReceivedSignals(obj)
			numberOfUsers = length(obj.ReceivedSignals);
			foundSignals = false;
			for iUser = 1:numberOfUsers
				if isempty(obj.ReceivedSignals{iUser})
					continue
				end
				
				if isempty(obj.ReceivedSignals{iUser}.Waveform)
					continue
				end
				
				foundSignals = true;
						
			end
			
		end
		
		function plotSpectrum(obj)
			figure
			plot(10*log10(abs(fftshift(fft(obj.Waveform)))))
		end
		
	 function plotSpectrums(obj)
			figure
			hold on
			uniqueUes = unique([obj.enbObj.ScheduleUL]);
			for iUser = 1:length(uniqueUes)
				plot(10*log10(abs(fftshift(fft(obj.Waveforms(iUser,:))))))	
				
			end
		end

		function createReceivedSignal(obj)
			uniqueUes = obj.enbObj.getUserIDsScheduledUL();

			% Check length of each received signal
			for iUser = 1:length(uniqueUes)
				ueId = uniqueUes(iUser);
				waveformLengths(iUser) =  length(obj.ReceivedSignals{ueId}.Waveform);
			end
			
			% This will break with MIMO
			obj.Waveform = zeros(max(waveformLengths),1);

			for iUser = 1:length(uniqueUes)
				ueId = uniqueUes(iUser);
				% Add waveform with corresponding power
				obj.Waveforms(iUser,:) = setPower(obj.ReceivedSignals{ueId}.Waveform, obj.ReceivedSignals{ueId}.RxPwdBm);
			end
			
			% Create finalized waveform
			obj.Waveform = sum(obj.Waveforms, 1).';

			% Waveform is transposed due to the SCFDMA demodulator requiring a column vector.
		end

		% Used to split the received waveform into the different portions of the different
		% UEs scheduled in the UL
		function parseWaveform(obj, enbObj)
			uniqueUes = unique([enbObj.ScheduleUL]);
			for iUser = 1:length(uniqueUes)
				ueId = uniqueUes(iUser);
				obj.UeData(iUser).UeId = ueId;
				obj.UeData(iUser).Waveform = obj.ReceivedSignals{ueId}.Waveform;
			end
		end
		
		% Used to demodulate each single UE waveform separately
		function obj = demodulateWaveforms(obj, ueObjs)
			for iUser = 1:length(ueObjs)
				localIndex = find([obj.UeData.UeId] == ueObjs(iUser).NCellID);
				ue = cast2Struct(ueObjs(iUser));
				
				testSubframe = lteSCFDMADemodulate(ue, obj.UeData(localIndex).Waveform);
				
				if all(testSubframe(:) == 0)
					obj.UeData(localIndex).Subframe = [];
					obj.UeData(localIndex).DemodBool = 0;
				else
					obj.UeData(localIndex).Subframe = testSubframe;
					obj.UeData(localIndex).DemodBool = 1;
				end
			end
			
		end
		
		
		function obj = estimateChannels(obj, ueObjs, cec)
			for iUser = 1:length(ueObjs)
				localIndex = find([obj.UeData.UeId] == ueObjs(iUser).NCellID);
				ue = struct(ueObjs(iUser));
				if (ueObjs(iUser).Tx.PUSCH.Active)
					[obj.UeData(localIndex).EstChannelGrid, obj.UeData(localIndex).NoiseEst] = ...
						lteULChannelEstimate(ue, cec, obj.UeData(localIndex).Subframe);
				end
			end
		end
		
		function obj = equaliseSubframes(obj, ueObjs)
			for iUser = 1:length(ueObjs)
				localIndex = find([obj.UeData.UeId] == ueObjs(iUser).NCellID);
				ue = struct(ueObjs(iUser));
				ueObj = ueObjs(iUser);
				if (ueObjs(iUser).Tx.PUSCH.Active)
					obj.UeData(localIndex).EqSubframe = lteEqualizeMMSE(obj.UeData(localIndex).Subframe,...
						obj.UeData(localIndex).EstChannelGrid, obj.UeData(localIndex).NoiseEst);
				end
			end
		end
		
		function obj = estimatePucch(obj, enbObj, ueObjs, timeNow)
			for iUser = 1:length(ueObjs)
				localIndex = find([obj.UeData.UeId] == ueObjs(iUser).NCellID);
				ue = struct(ueObjs(iUser));
				ueObj = ueObjs(iUser);
				
				switch ueObj.Tx.PUCCH.Format
					case 1
						obj.UeData(localIndex).PUCCH = ltePUCCH1Decode(ue, ueObj.Tx.PUCCH, 0, ...
							obj.UeData(localIndex).Subframe(ueObj.Tx.PUCCH.Indices));
					case 2
						obj.UeData(localIndex).PUCCH = ltePUCCH2Decode(ue, ueObj.Tx.PUCCH, ...
							obj.UeData(localIndex).Subframe(ueObj.Tx.PUCCH.Indices));
					case 3
						obj.UeData(localIndex).PUCCH = ltePUCCH3Decode(ue, ueObj.Tx.PUCCH, ...
							obj.UeData(localIndex).Subframe(ueObj.Tx.PUCCH.Indices));
				end
				
				% Estimate soft bits to hard bits
				% TODO this feels a bit dumb, let's try something smarter
				for iSym = 1:length(obj.UeData(localIndex).PUCCH)
					if obj.UeData(localIndex).PUCCH(iSym) > 0
						obj.UeData(localIndex).PUCCH(iSym) = int8(1);
					else
						obj.UeData(localIndex).PUCCH(iSym) = int8(0);
					end
				end
				
			end
		end
		
		function obj = estimatePusch(obj, enbObj, ueObjs, timeNow)
			for iUser = 1:length(ueObjs)
				localIndex = find([obj.UeData.UeId] == ueObjs(iUser).NCellID);
				ue = cast2Struct(ueObjs(iUser));
				ueObj = ueObjs(iUser);
				if (ueObj.Tx.PUSCH.Active)
					
				end
			end
		end

		%waveformsIn is array of length n, where n > 1 for MIMO
		%user is an UserEquipment object
		function obj = addWaveforms(obj, waveformsIn, user) 
			%Add info to the cell array
			obj.Waveforms(user.NCellID,:) =  {waveformsIn, user};
			%to call the waveforms array, use obj.Waveforms{userID,1}
			%to call the user equipment field, use obj.Waveforms{userID,2}
		end

		%Returns a compiled waveform, consisting of all waveforms from all users.
		function compiledWaveform = compileWaveform(obj)
			
			temp =0;
			for iCell=1:length(obj.Waveforms(:,1))
				for iWave=1:length(obj.Waveforms{iCell,1})
					%Add the waveform times Rx power of the ue 
					temp = temp + obj.Waveforms{iCell,1}(iWave)*obj.Waveforms{iCell,2}.Rx.RxPwdBm; %If RxPwddBm has not been set it all goes wrong
				end
			end
			compiledWaveform = temp; %Return the compiled waveforms
		end

		function obj = reset(obj)
			obj.UeData = [];
			obj.Waveform = [];
			obj.Waveforms = {};
			obj.ReceivedSignals = {};
		end
		
	end
	
	
	
end
