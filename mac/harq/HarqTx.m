%   HARQ TX defines a value class for creating anf handling a single HARQ transmitter
%		a property called state is used to handle the protocol behaviour of each individual process
%		0 means idle, 1 means in use, 2 means awaiting retransmission slot, 3 means retransmitting
% 	4 means retransmission failure

classdef HarqTx
	properties
		txId;
		rxId;
		bitsSize = 0;
		tbSize = 0;
		rrCurrentProc = -1;
		rrNextProc = -1;
		processes(8,1) = struct(...
			'rtxCount',0,...
			'rv', 0, ....
			'tb', [],...
			'state', 0, ...
			'timeStart', -1,...
			'procId', -1);
	end

	methods
		% Constructor
		function obj = HarqTx(Param, transmitter, receiver, timeNow)
			obj.txId = transmitter;
			obj.rxId = receiver;
			obj.bitsSize = 0;
			obj.tbSize = 0;
			obj = createProcesses(obj, Param, timeNow);
		end

		% Returns a HARQ PID based on a SQN if the process exists
		% otherwise it terminates one
		function [obj, pid, newTb] = findProcess(obj, sqn)
			newTb = false;
			procs = obj.processes;
			pid = -1;
			for iProc = 1:length(procs)
				if sqn == decodeSqn(procs(iProc).tb)
					pid = procs(iProc).procId;
				else 
					if iProc == length(procs)
					% if there is no match for the SQN and we are at the last process slot
					% then we need to start a new process 
					newTb = true;
					[obj, pid] = startNewProcess(obj, sqn);
					end
				end
			end
		end

		% Used to insert a new TB and start a new HARQ process
		function obj = handleTbInsert(obj, pid, timeNow, tb)
			iProc = find([obj.processes.procId] == pid);
			obj.processes(iProc).tb = tb;
			obj.processes(iProc).timeStart = timeNow;
			obj.bitsSize = obj.bitsSize + length(tb);
			obj.tbSize = obj.tbSize + 1;
		end

		% Utility to check whether any retransmission should be done
		function info = getRetransmissionState(obj)
			% check if this receiver has anything at all
			if obj.bitsSize > 0 
				rtxProcessesIndices = find([obj.processes.state] == 2);
				if isempty(rtxBuffersIndices)
					info.flag = false;
				else
					info.flag = true;
					% In case we need to take a TB from a HARQ process, we apply a RR scheme among the 
					% 8 processes to choose which one to schedule for this turn.
					rtxProcesses = obj.processes(rtxBuffersIndices);
					% Starting case where the current is the first one and the next is set if it exists
					if obj.rrCurrentProc == -1 
						obj.rrCurrentProc = rtxProcesses(1).procId;
						if length(rtxProcessesIndices) > 1
							obj.rrNextProc = rtxProcesses(2).procId;
						else
							obj.rrNextProc = obj.rrCurrentProc;
						end
					else
						nextProcIndex = find([rtxProcesses.procId] == obj.rrNextProc);
						if ~isempty(nextProcIndex)
							% We found the process that should be scheduled for this turn
							% update the attributes in the overall object
							obj.rrCurrentProc = obj.rrNextProc;
							info.procId = obj.rrCurrentProc;
							% find the index of the process that will be the next one 
							procIndexInRtxList = find([rtxProcesses.procId] == obj.rrCurrentProc);
							if procIndexInRtxList ~= length(rtxProcesses)
								% set the next in line 
								obj.rrNextProc = rtxProcesses(procIndexInRtxList + 1).procId;
							else
								% restart the round 
								obj.rrNextProc = rtxProcesses(1).procId;
							end
						else
							% the process that should have used this retransmission slot is no longer
							% in an "awaiting retransmission" state, so restart from the beginning
							% TODO check this
							obj.rrCurrentProc = rtxProcesses(1).procId;
							if length(rtxProcessesIndices) > 1
								obj.rrNextProc = rtxProcesses(2).procId;
							else
								obj.rrNextProc = obj.rrCurrentProc;
							end
						end
					end
				end
			else
				info.flag = false;
			end	
		end

		% Set a process in retransmission state
		function obj = setRetransmissionState(obj, procId){
			iProc = find([obj.processes.procId] == procId);
			obj.processes(iProc).state = 3;
			obj.processes(iProc).rtxCount = obj.processes(iProc).rtxCount + 1;
		}

		% Handle the reception of a ACK/NACk
		function obj = handleReply(obj, ack, procId, timeNow, Param)
			% find index
			iProc = [obj.processes.procId] == procId;
			if ack.msg == 1
				% clean
				obj.processes(iProc).rtxCount = 0;
				obj.processes(iProc).rv = 0;
				obj.processes(iProc).tb = [];
				obj.processes(iProc).timeStart = -1;
				obj.processes(iProc).state = 0;
			else
				% check whether the maximum number has been exceeded
				if obj.processes(iProc).rtxCount > Param.harq.rtxMax
					% log failure (and notify RLC?)
					obj.processes(iProc).state = 4;
				else
					% log rtx
					obj.processes(iProc).rtxCount = obj.processes(iProc).rtxCount + 1;
					obj.processes(iProc).rv = Param.harq.rv(obj.rtxCount);
					obj.processes(iProc).state = 3;
					obj.processes(iProc).timeStart = timeNow;
				end
			end
		end

		% Handle the expiration of the retransmission timer
		function obj = handleTimeout(obj, timeNow)
			% find index
			iProc = [obj.processes.procId] == procId;
			% log failure
			obj.processes(iProc).rtxCount = obj.processes(iProc).rtxCount + 1;
			obj.processes(iProc).rv = Param.harq.rv(obj.processes(iProc).rtxCount);
			obj.processes(iProc).state = 2;
			obj.processes(iProc).timeStart = timeNow;
		end

	end

	methods (Access = private)
		function obj = createProcesses(obj, Param, timeNow)
			% TODO check if pre-allocation can be removed or better the entire
			% function
			for iProc = 1:Param.harq.proc
				obj.processes(iProc).procId = iProc;
				obj.processes(iProc).timeStart = timeNow;
			end
		end

		% Decode the SQN from a TB in storage and returns it
		function sqn = decodeSqn(tb, varargin)
			% Check if there are any options, otherwise assume default
			outFmt = 'd';
			if nargin > 0
				if varargin{1} == 'format'
					outFmt = varargin{2};
				end
			end

			if ~isempty(tb)
				sqnBits(1:10, 1) = tb(1:10,1); 
				if outFmt == 'b'
					sqn = sqnBits;
				else
					sqn = bi2de(sqnBits');
				end
			else
				sqn = -1;
			end	
		end

		% Utility to start a new process 
		function [obj, pid] = startNewProcess(obj)
			% First of all, find whether there is any process that is not used currently
			idleProcsIndices = find([obj.processes.state] == 0);
			if ~isempty(idleProcsIndices ~= 0)
				% A free process is available
				iProc = idleProcsIndices(1);
				obj.processes(iProc).state = 1;
				pid = obj.processes(iProc).procId;
			else
				% Stop a process and use that slot for the new TB
				% Get the process that has been in the buffer the longest and delete that
				timeStartValues = [obj.processes.timeStart];
				[~, pid] = min(timeStartValues);
				obj.processes(pid).state = 1;
			end
		end

	end
end
