classdef sonohiWINNER
    
    properties
        WconfigLayout; % Layout of winner model
        WconfigParset; % Model parameters
        numRx; % Number of receivers, per model
        h; % Stored impulse response
        Channel;
    end
    
    methods
        
        function obj = sonohiWINNER(Stations, Users, Channel)
            sonohilog('Initializing WINNER II channel model...','NFO0')
            obj.Channel = Channel;
            classes = unique({Stations.BsClass});
            for class = 1:length(classes)
                varname = classes{class};
                types.(varname) = find(strcmp({Stations.BsClass},varname));
                
            end
            
            Snames = fieldnames(types);
            
            obj.WconfigLayout = cell(numel(Snames),1);
            obj.WconfigParset = cell(numel(Snames),1);
            
            
            for model = 1:numel(Snames)
                type = Snames{model};
                stations = types.(Snames{model});
                
                % Get number of links associated with the station.
                users = nonzeros([Stations(stations).Users]);
                numLinks = nnz(users);
                
                if isempty(users)
                    % If no users are associated, skip the model
                    continue
                end
                [AA, eNBIdx, userIdx] = sonohiWINNER.configureAA(type,stations,users);
                
                range = max(Channel.Area);
                
                obj.WconfigLayout{model} = obj.initializeLayout(userIdx, eNBIdx, numLinks, AA, range);
                
                obj.WconfigLayout{model} = obj.addAssociated(obj.WconfigLayout{model} ,stations,users);
                
                obj.WconfigLayout{model} = obj.setPositions(obj.WconfigLayout{model} ,Stations,Users);
                
                
                obj.WconfigLayout{model}.Pairing = Channel.getPairing(Stations(obj.WconfigLayout{model}.StationIdx));
                
                obj.WconfigLayout{model}  = obj.updateIndexing(obj.WconfigLayout{model} ,Stations);
                
                obj.WconfigLayout{model}  = obj.setPropagationScenario(obj.WconfigLayout{model} ,Stations,Users, Channel);
                
                obj.WconfigParset{model}  = obj.configureModel(obj.WconfigLayout{model},Stations);
                
            end
            
        end
        
        function obj = setup(obj)
            % Computes impulse response of initalized winner model
            for model = 1:length(obj.WconfigLayout)
                
                if isempty(obj.WconfigParset{model})
                    % No users associated, skip the model.
                    continue
                end
                
                wimCh = comm.WINNER2Channel(obj.WconfigParset{model}, obj.WconfigLayout{model});
                chanInfo = info(wimCh);
                numTx    = chanInfo.NumBSElements(1);
                Rs       = chanInfo.SampleRate(1);
                obj.numRx{model} = chanInfo.NumLinks(1);
                impulseR = [ones(1, numTx); zeros(obj.WconfigParset{model}.NumTimeSamples-1, numTx)];
                h{model} = wimCh(impulseR);
            end
            obj.h = h;
            
            
            
        end
        
        function Users = run(obj,Stations,Users)
            for model = 1:length(obj.WconfigLayout)
                
                if isempty(obj.WconfigLayout{model})
                    sonohilog(sprintf('Nothing assigned to %i model',model),'NFO0')
                    continue
                end
                
                
                
                % Debugging code. Use of direct waveform for validating
                % transferfunction
                %release(wimCh)
                %rxSig2 = wimCh(Stations(obj.WconfigLayout{model}.StationIdx(1)).TxWaveform);
                
                % Go through all links for the given scenario
                % 1. Compute transfer function for each link
                % 2. Apply transferfunction and  compute loss
                % 3. Add loss as AWGN
                for link = 1:obj.numRx{model}
                    % Get TX from the WINNER layout idx
                    txIdx = obj.WconfigLayout{model}.Pairing(1,link);
                    % Get RX from the WINNER layout idx
                    rxIdx = obj.WconfigLayout{model}.Pairing(2,link)-length(obj.WconfigLayout{model}.StationIdx);
                    Station = Stations(obj.WconfigLayout{model}.StationIdx(txIdx));
                    User = Users([Users.UeId] == obj.WconfigLayout{model}.UserIdx(rxIdx));
                    % Get corresponding TxSig
                    txSig = [Station.TxWaveform;zeros(25,1)];
                    txPw = 10*log10(bandpower(txSig));
                    
                    %figure
                    %plot(10*log10(abs(fftshift(fft(txSig)).^2)))
                    %hold on
                    
                    rxSig = obj.addFading(txSig,obj.h{model}{link});
                    
                    rxPw_ = 10*log10(bandpower(rxSig));
                    
                    lossdB = txPw-rxPw_;
                    %plot(10*log10(abs(fftshift(fft(rxSig)).^2)));
                    %plot(10*log10(abs(fftshift(fft(rxSig2{1}))).^2));
                    
                    % Normalize signal and add loss as AWGN based on
                    % noise floor
                    rxSigNorm = rxSig.*10^(lossdB/20);
                    [rxSigNorm, SNRLin, rxPw] = obj.addPathlossAwgn(Station, User, rxSigNorm, lossdB);
                    
                    %plot(10*log10(abs(fftshift(fft(rxSigNorm)).^2)),'Color',[0.5,0.5,0.5,0.2]);
                    
                    % Assign to user
                    Users([Users.UeId] == obj.WconfigLayout{model}.UserIdx(rxIdx)).RxInfo.SNRdB = 10*log10(SNRLin);
                    Users([Users.UeId] == obj.WconfigLayout{model}.UserIdx(rxIdx)).RxInfo.SNR = SNRLin;
                    Users([Users.UeId] == obj.WconfigLayout{model}.UserIdx(rxIdx)).RxInfo.rxPw = rxPw;
                    Users([Users.UeId] == obj.WconfigLayout{model}.UserIdx(rxIdx)).RxWaveform = rxSigNorm;
                    
                end
                
            end
            
        end
        
        
       function [rxSig, SNRLin, rxPw] = addPathlossAwgn(obj, Station, User, txSig, lossdB)
            % Compute thermalnoise based on bandwidth
            thermalNoise = obj.Channel.ThermalNoise(Station.NDLRB);
            % Get distance of Tx - Rx
            distance = obj.Channel.getDistance(Station.Position,User.Position)/1e3;
            
            % Compute transmission power
            txPw = 10*log10(Station.Pmax)+30; %dBm.
            
            % Setup link budget
            rxPw = txPw-lossdB;
            % SNR = P_rx_db - P_noise_db
            rxNoiseFloor = 10*log10(thermalNoise)+User.NoiseFigure;
            SNR = rxPw-rxNoiseFloor;
            SNRLin = 10^(SNR/10);
            str1 = sprintf('Station(%i) to User(%i)\n Distance: %s\n SNR:  %s\n',...
                Station.NCellID,User.UeId,num2str(distance),num2str(SNR));
            sonohilog(str1,'NFO0');
            
            %% Apply SNR
            
            % Compute average symbol energy
            % This is based on the number of useed subcarriers.
            % Scale it by the number of used RE since the power is
            % equally distributed
            Es = sqrt(2.0*Station.CellRefP*double(Station.WaveformInfo.Nfft)*Station.WaveformInfo.OfdmEnergyScale);
            
            % Compute spectral noise density NO
            N0 = 1/(Es*SNRLin);
            
            % Add AWGN
            
            noise = N0*complex(randn(size(txSig)), ...
                randn(size(txSig)));
            
            rxSig = txSig + noise;
            
            
        end
        
        
    end
    
    
    methods(Static)
        
        function rx = addFading(tx,h)
            H = fft(h,length(tx));
            % Apply transfer function to signal
            X = fft(tx)./length(tx);
            Y = X.*H;
            rx = ifft(Y)*length(tx);  
        end
        
        
 
        
        
        function [AA, eNBIdx, userIdx] = configureAA(type,stations,users)

            % Select antenna array based on station class.
            if strcmp(type,'macro')
                %Az = -180:179;
                %pattern(1,:,1,:) = winner2.dipole(Az,10);
                %AA(1) = winner2.AntennaArray( ...
                %    'ULA', 12, 0.15, ...
                %    'FP-ECS', pattern, ...
                %    'Azimuth', Az);
                
                AA(1) = winner2.AntennaArray('UCA', 8,  0.2);
            elseif strcmp(type,'micro')
                %Az = -180:179;
                %pattern(1,:,1,:) = winner2.dipole(Az,10);
                %AA(1) = winner2.AntennaArray( ...
                %    'ULA', 6, 0.15, ...
                %    'FP-ECS', pattern, ...
                %    'Azimuth', Az);
                AA(1) = winner2.AntennaArray('UCA', 4,  0.15);
            else
                
                sonohilog(sprintf('Antenna type for %s BsClass not defined, defaulting...',type),'WRN')
                AA(1) = winner2.AntennaArray('UCA', 1,  0.3);
            end
            
            % User antenna array
            AA(2) = winner2.AntennaArray('ULA', 1,  0.05);
            
            % Number of sectors.
            numSec = 1;
            % TODO, requires changes ot the way pairing is done
            eNBIdx = cell(length(stations),1);
            for iStation = 1:length(stations)
                eNBIdx{iStation} = [ones(1,numSec)];
            end
            % For users use antenna configuration 2
            userIdx = repmat(2,1,length(users));
            
        end
        
        function cfgLayout =initializeLayout(useridx, eNBidx, numLinks, AA, range)
            % Initialize layout struct by antenna array and number of
            % links.
            cfgLayout = winner2.layoutparset(useridx, eNBidx, numLinks, AA, range);
            
        end
        
        function cfgLayout = addAssociated(cfgLayout, stations, users)
            % Adds the index of the stations and users associated, e.g.
            % how they link with the station and user objects.
            cfgLayout.StationIdx = stations;
            cfgLayout.UserIdx = users;
            
        end
        
        
        function cfgLayout = setPositions(cfgLayout, Stations, Users)
            % Set the position of the base station
            for iStation = 1:length(cfgLayout.StationIdx)
                cfgLayout.Stations(iStation).Pos(1:3) = int64(floor(Stations(cfgLayout.StationIdx(iStation)).Position(1:3)));
            end
            
            % Set the position of the users
            % TODO: Add velocity vector of users
            for iUser = 1:length(cfgLayout.UserIdx)
                cfgLayout.Stations(iUser+length(cfgLayout.StationIdx)).Pos(1:3) = int64(ceil(Users([Users.UeId] == cfgLayout.UserIdx(iUser)).Position(1:3)));
            end
            
        end
        
        function cfgLayout =updateIndexing(cfgLayout,Stations)
            % Change useridx of pairing to reflect
            % cfgLayout.Stations, e.g. If only one station, user one is
            % at cfgLayout.Stations(2)
            for ll = 1:length(cfgLayout.Pairing(2,:))
                cfgLayout.Pairing(2,ll) =  length(cfgLayout.StationIdx)+ll;
            end
            
            
        end
        
        function cfgLayout = setPropagationScenario(cfgLayout, Stations, Users, Ch)
            numLinks = length(cfgLayout.Pairing(1,:));
            
            for i = 1:numLinks
                userIdx = cfgLayout.UserIdx(cfgLayout.Pairing(2,i)-length(cfgLayout.StationIdx));
                stationIdx =  cfgLayout.StationIdx(cfgLayout.Pairing(1,i));
                cBs = Stations(stationIdx);
                cMs = Users([Users.UeId] == userIdx);
                % Apparently WINNERchan doesn't compute distance based
                % on height, only on x,y distance. Also they can't be
                % doubles...
                distance = Ch.getDistance(cBs.Position(1:2),cMs.Position(1:2));
                if cBs.BsClass == 'micro'
                    
                    if distance <= 20
                        msg = sprintf('(Station %i to User %i) Distance is %s, which is less than supported for B1 with LOS, swapping to B4 LOS',...
                            stationIdx,userIdx,num2str(distance));
                        sonohilog(msg,'NFO0');
                        
                        cfgLayout.ScenarioVector(i) = 6; % B1 Typical urban micro-cell
                        cfgLayout.PropagConditionVector(i) = 1; %1 for LOS
                        
                    elseif distance <= 50
                        msg = sprintf('(Station %i to User %i) Distance is %s, which is less than supported for B1 with NLOS, swapping to B1 LOS',...
                            stationIdx,userIdx,num2str(distance));
                        sonohilog(msg,'NFO0');
                        
                        cfgLayout.ScenarioVector(i) = 3; % B1 Typical urban micro-cell
                        cfgLayout.PropagConditionVector(i) = 1; %1 for LOS
                    else
                        cfgLayout.ScenarioVector(i) = 3; % B1 Typical urban micro-cell
                        cfgLayout.PropagConditionVector(i) = 0; %0 for NLOS
                    end
                elseif cBs.BsClass == 'macro'
                    if distance < 50
                        msg = sprintf('(Station %i to User %i) Distance is %s, which is less than supported for C2 NLOS, swapping to LOS',...
                            stationIdx,userIdx,num2str(distance));
                        sonohilog(msg,'NFO0');
                        cfgLayout.ScenarioVector(i) = 11; %
                        cfgLayout.PropagConditionVector(i) = 1; %
                    else
                        cfgLayout.ScenarioVector(i) = 11; % C2 Typical urban macro-cell
                        cfgLayout.PropagConditionVector(i) = 0; %0 for NLOS
                    end
                end
                
                
            end
            
        end
        
        function cfgModel = configureModel(cfgLayout,Stations)
            % Use maximum fft size
            % However since the same BsClass is used these are most
            % likely to be identical
            sw = [Stations(cfgLayout.StationIdx).WaveformInfo];
            swNfft = [sw.Nfft];
            swSamplingRate = [sw.SamplingRate];
            cf = max([Stations(cfgLayout.StationIdx).DlFreq]); % Given in MHz
            
            frmLen = double(max(swNfft));   % Frame length
            
            % Configure model parameters
            % TODO: Determine maxMS velocity
            maxMSVelocity = max(cell2mat(cellfun(@(x) norm(x, 'fro'), ...
                {cfgLayout.Stations.Velocity}, 'UniformOutput', false)));
            
            
            cfgModel = winner2.wimparset;
            cfgModel.CenterFrequency = cf*10e5; % Given in Hz
            cfgModel.NumTimeSamples     = frmLen; % Frame length
            cfgModel.IntraClusterDsUsed = 'yes';   % No cluster splitting
            cfgModel.SampleDensity      = max(swSamplingRate)/50;    % To match sampling rate of signal
            cfgModel.PathLossModelUsed  = 'yes';  % Turn on path loss
            cfgModel.ShadowingModelUsed = 'yes';  % Turn on shadowing
            cfgModel.SampleDensity = round(physconst('LightSpeed')/ ...
                cfgModel.CenterFrequency/2/(maxMSVelocity/max(swSamplingRate)));
            
        end
        
        
        
    end
    
end