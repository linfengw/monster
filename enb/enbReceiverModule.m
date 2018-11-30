classdef enbReceiverModule < handle
	properties
		NoiseFigure;
		Waveform;
		WaveformInfo;
		UeData;
		RxPwdBm;
		SNR;
		Waveforms; %Cells containing: waveform(s) from a user, and userID
	end
	
	methods
		
		function obj = enbReceiverModule(Param)
			obj.NoiseFigure = Param.eNBNoiseFigure;
			obj.Waveforms = cell(Param.numUsers,2);
		end
		
		function obj = set.Waveform(obj,Sig)
			obj.Waveform = Sig;
		end
		
		function obj = set.RxPwdBm(obj,RxPwdBm)
			obj.RxPwdBm = RxPwdBm;
		end

		function obj = set.UeData(obj,UeData)
			obj.UeData = UeData;
		end
		
		function plotSpectrum(obj)
			figure
			plot(10*log10(abs(fftshift(fft(obj.Waveform)))))
		end

		% Used to split the received waveform into the different portions of the different
		% UEs scheduled in the UL
		function obj = parseWaveform(obj, enbObj)
			uniqueUes = unique([enbObj.ScheduleUL]);
			scFraction = length(obj.Waveform)/length(uniqueUes);
			for iUser = 1:length(uniqueUes)
				scStart = (iUser - 1)*scFraction ;
				scEnd = scStart + scFraction;
				obj.UeData(iUser).UeId = uniqueUes(iUser);
				obj.UeData(iUser).Waveform = obj.Waveform(scStart + 1 : scEnd, 1);
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
			obj.RxPwdBm = [];
			obj.Waveforms = {};
		end
		
	end
	
	
	
end
