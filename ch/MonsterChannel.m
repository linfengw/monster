classdef MonsterChannel < handle


	properties
		Mode;
		Region;
		BuildingFootprints;
		ChannelModel;
		enableFading;
		InterferenceType;
		enableShadowing;
		LOSMethod;
		iRound = 0;
		extraSamplesArea = 1200;
	end

	methods 
		function obj = MonsterChannel(Stations, Users, Param)
			obj.Mode = Param.channel.mode;
			obj.Region = Param.channel.region;
			obj.enableFading = Param.channel.enableFading;
			obj.InterferenceType = Param.channel.InterferenceType;
			obj.enableShadowing = Param.channel.enableShadowing;
			obj.BuildingFootprints = Param.buildings;
			obj.LOSMethod = Param.channel.LOSMethod;
			obj.setupChannel(Stations)
		end
		
		function setupChannel(obj, Stations, Users)
			switch obj.Mode
				case '3GPP38901'
					obj.ChannelModel = Monster3GPP38901(obj, Stations);
				case 'Quadriga'
					obj.setupQuadrigaLayout(Stations, Users)
			end
		end

		function traverse(obj, Stations, Users, Mode)
			% This function manipulates the waveform of the Tx module of either stations, or users depending on the selected mode
			% E.g. `Mode='uplink'` uses the Tx modules of the Users, and hereof waveforms, transmission power etc.
			% `Mode='downlink'` uses the Tx modules of the Stations, and hereof configurations. 
			% 
			% This function can only be used if the Stations have assigned users.
			if ~strcmp(Mode,'downlink') && ~strcmp(Mode,'uplink')
				sonohilog('Unknown channel type selected.','ERR', 'MonsterChannel:noChannelMode')
			end

			if any(~isa(Stations, 'EvolvedNodeB'))
				sonohilog('Unknown type of stations.','ERR', 'MonsterChannel:WrongStationClass')
			end

			if any(~isa(Users, 'UserEquipment'))
				sonohilog('Unknown type of users.','ERR', 'MonsterChannel:WrongUserClass')
			end

			% Filter stations and users
			[stations,users] = obj.getAssociated(Stations,Users);
			
			% Propagate waveforms
			if ~isempty(stations)
				obj.callChannelModel(Stations, Users, Mode)
			else
				sonohilog('No users found for any of the stations. Quitting traverse', 'ERR', 'MonsterChannel:NoUsersAssigned')
			end

		end

		function callChannelModel(obj, Stations, Users, Mode)
			if isa(obj.ChannelModel, 'Monster3GPP38901')
				obj.ChannelModel.propagateWaveforms(Stations, Users, Mode)
			end

		end

		
		function seed = getLinkSeed(obj, rxObj, txObj)
			seed = rxObj.Seed * txObj.Seed + 10* obj.iRound;
		end

		function areatype = getAreaType(obj,Station)
			if strcmp(Station.BsClass, 'macro')
				areatype = obj.Region.macroScenario;
			elseif strcmp(Station.BsClass,'micro')
				areatype = obj.Region.microScenario;
			elseif strcmp(Station.BsClass,'pico')
				areatype = obj.Region.picoScenario;
			end
		end

		function [SINRmap, SNRmap, axis] = SignalQualityMap(obj, Stations, selectedStation, User, Resolution)
			% If selectedStation is a list, the matrix returned is for each station.

			
			areaSize = obj.getAreaSize;
			X = -areaSize:Resolution:areaSize;
			Y = -areaSize:Resolution:areaSize;
			axis = [X; Y];
			SINRmap = nan(length(X),length(Y));
			SNRmap = nan(length(X),length(Y));

			% Add reference subframe for BW indicator
			selectedStationCopy = copy(selectedStation);
			selectedStationCopy.Tx.createReferenceSubframe();
			selectedStationCopy.Tx.assignReferenceSubframe();
			for x = 1:length(X)
				for y = 1:length(Y)
					user = copy(User);
					user.Position(1:2) = [X(x), Y(y)];
					[SNRmap(y, x), SINRmap(y, x)] = obj.ChannelModel.getSNRandSINR(Stations, selectedStationCopy, user);
				end
			end
		end

		function h = plotSINR(obj, Stations, User, Resolution)
			sonohilog('Computing SINR map...')
			parfor iStation = 1:length(Stations)
				selectedStation = Stations(iStation);
				[SINRmap(:,:,iStation), SNRmap(:,:,iStation), axis(:,:,iStation)] = obj.SignalQualityMap(Stations, selectedStation, User, Resolution);
			end
			
			
			h = figure;
			contourf(axis(1,:,1),axis(2,:,1),20*log10(max(SINRmap,[],3)))
			c = colorbar();
			c.Label.String = 'SINR [dB]';
			xlabel('X [meters]')
			ylabel('Y [meters]')
			hold on
			for iStation = 1:length(Stations)
				plot(Stations(iStation).Position(1), Stations(iStation).Position(2), 'o', 'MarkerSize', 10, 'MarkerFaceColor', 'r')
			end

			
			
		end

		

		
		function area = getAreaSize(obj)
			 % Extra samples for allowing interpolation. Error will be thrown in this is exceeded.
			area = (max(obj.BuildingFootprints(:,3)) - min(obj.BuildingFootprints(:,1))) + obj.extraSamplesArea;
		end


		

		%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%% Quardiga model %%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%
		function setupQuadrigaLayout(obj, Stations, Users)
			% Call Quadriga setup function
		end


		function [LOS, prop] = isLinkLOS(obj, Station, User, draw)
			% Check if link between `txPos` and `rxPos` is LOS using one of two methods
			%
			% 1. :attr:`SonohiChannel.LOSMethod` : :attr:`fresnel` 1st Fresnel zone and the building footprint.
			% 2. :attr:`SonohiChannel.LOSMethod` : :attr:`3GPP38901-probability` Uses probability given table 7.4.2-1 of 3GPP TR 38.901. See :meth:`ch.SONOHImodels.3GPP38901.sonohi3GPP38901.LOSprobability` for more the implementation.
			%
			% :param Station: Need :attr:`Stations.Position` and :attr:`Stations.DlFreq`.
			% :type Station: :class:`enb.EvolvedNodeB`
			% :param User: Need :attr:`User.Position`
			% :type User: :class:`ue.UserEquipment`
			% :param bool draw: Draws fresnel zone and elevation profile.
			% :returns: LOS (bool) indicating LOS
            % :returns: (optional) probability is returned if :attr:`3GPP38901-probability` is assigned
            
            % Check if User is indoor
            % Else use probability to determine LOS state
            if User.Mobility.Indoor 
                LOS = 0;
                prop = NaN;
            else
			
                switch obj.LOSMethod
                    case 'fresnel'
                        LOS = obj.fresnelLOScomputation(Station, User, draw);
                        prop = NaN;
                    case '3GPP38901-probability'
                        [LOS, prop] = Monster3GPP38901.LOSprobability(obj, Station, User);
												
										case 'NLOS'
											LOS = 0;
											prop = NaN;

										case 'LOS'
											LOS = 1;
											prop = NaN;
										
                end
                
            end
		end
		
		function LOS = fresnelLOScomputation(obj, Station, User, draw)
			txPos = Station.Position;
			txFreq = Station.DlFreq;
			rxPos = User.Position;
			
			[numPoints,distVec,elevProfile] = obj.getElevation(txPos,rxPos);
			
			distVec = distVec(2:end); % First is zero
			totalDistance = distVec(end); % Meters
			nthFresnel = 1;
			fRadius = zeros(length(distVec),nthFresnel);
			LOSPath = linspace(txPos(3), rxPos(3),  length(distVec))';
			
			for dist = 1:length(distVec)
				% Compute zones
				for zone = 1:nthFresnel
					fRadius(dist, zone) = fresnelZone(zone,  distVec(dist),  totalDistance-distVec(dist), txFreq*10e6);
				end
			end
			
			upperLos = LOSPath+fRadius;
			lowerLos = LOSPath-fRadius;
			losBoundary = lowerLos+(fRadius.*2)*0.6; % 60% which is needed to define LOS/NLOS
			LOS = true;
			
			% Check if any obstacles occupy 60% of the fresnel zone
			if sum(elevProfile' >= losBoundary)
				LOS = false;
			end
			
			if draw
				figure
				plot(distVec, elevProfile)
				hold on
				plot(distVec, LOSPath,'r--')
				plot(distVec, lowerLos, 'k--')
				plot(distVec, upperLos, 'k--')
				xlabel('Distance (m)')
				ylabel('Height (m)')
				legend('Building footprints', 'LOS path', '1st Fresnel zone')
			end
		end
		
		
		function [numPoints,distVec,elavationProfile] = getElevation(obj,txPos,rxPos)
			% Moves through the building footprints structure and gathers the
			% height. A resolution of 0.05 meters used. Outputs a distance vector
			%
			% :param txPos: Position consisting of x, y, z coordinates
			% :param rxPos: Position consisting of x, y, z coordinates
			% :returns: `numPoints` number of elevation points between txPos and rxPos
			% :returns: `distVec` vector with resolution 0.05 meters from txPos to rxPos
			% :returns: `elevationProfile` vector of height values
			elavationProfile(1) = 0;
			distVec(1) = 0;
			
			% Check if x and y are equal
			if txPos(1:2) == rxPos(1:2)
				numPoints = 0;
				distVec = 0;
				elavationProfile = 0;
			else
				
				% Walk towards rxPos
				signX = sign(rxPos(1)-txPos(1));
				
				signY = sign(rxPos(2)-txPos(2));
				
				avgG = (txPos(1)-rxPos(1))/(txPos(2)-rxPos(2))+normrnd(0,0.01); %Small offset
				position(1:2,1) = txPos(1:2);
				i = 2;
				max_i = 10e6;
				numPoints = 0;
				resolution = 0.05; % Given in meters
				
				while true
					if i >= max_i
						break;
					end
					
					% Check current distance
					distance = norm(position(1:2,i-1)'-rxPos(1:2));
					
					% Move position
					[moved_dist,position(1:2,i)] = move(position(1:2,i-1),signX,signY,avgG,resolution);
					distVec(i) = distVec(i-1)+moved_dist; %#ok
					
					% Check if new position is at a greater distance, if so, we
					% passed it.
					distance_n = norm(position(1:2,i)'-rxPos(1:2));
					if distance_n >= distance
						break;
					else
						% Check if we're inside a building
						fbuildings_x = obj.BuildingFootprints(obj.BuildingFootprints(:,1) < position(1,i) & obj.BuildingFootprints(:,3) > position(1,i),:);
						fbuildings_y = fbuildings_x(fbuildings_x(:,2) < position(2,i) & fbuildings_x(:,4) > position(2,i),:);
						
						if ~isempty(fbuildings_y)
							elavationProfile(i) = fbuildings_y(5); %#ok
							if elavationProfile(i-1) == 0
								numPoints = numPoints +1;
							end
						else
							elavationProfile(i) = 0; %#ok
							
						end
					end
					i = i+1;
					
				end
				
			end
			
			
			
			function [distance,position] = move(position,signX,signY,avgG,moveS)
				if abs(avgG) > 1
					moveX = abs(avgG)*signX*moveS;
					moveY = 1*signY*moveS;
					position(1) = position(1)+moveX;
					position(2) = position(2)+moveY;
					
				else
					moveX = 1*signX*moveS;
					moveY = (1/abs(avgG))*signY*moveS;
					position(1) = position(1)+moveX;
					position(2) = position(2)+moveY;
				end
				distance = sqrt(moveX^2+moveY^2);
			end
			
		end

		function simTime = getSimTime(obj)
			% TODO: This should be moved to a parent API
			simTime = obj.iRound*10^-3;
		end

	end

	methods(Static)
		
		function interferingStations = getInterferingStations(SelectedStation, Stations)
			interferingStations = Stations(find(strcmp({Stations.BsClass},SelectedStation.BsClass)));
			interferingStations = interferingStations([interferingStations.NCellID]~=SelectedStation.NCellID);
		end
		
		function distance = getDistance(txPos,rxPos)
			% Get distance between txPos and rxPos
			distance = norm(rxPos-txPos);
		end
		
		
		function [stations, users] = getAssociated(Stations,Users)
			% Returns stations and users that are associated
			stations = [];
			for istation = 1:length(Stations)
				UsersAssociated = [Stations(istation).Users.UeId];
				UsersAssociated = UsersAssociated(UsersAssociated ~= -1);
				if ~isempty(UsersAssociated)
					stations = [stations, Stations(istation)];
				end
			end
			
			
			UsersAssociated = [Stations.Users];
			UserIds = [UsersAssociated.UeId];
			UserIds = unique(UserIds);
			UserIds = UserIds(UserIds ~= -1);
			users = Users(ismember([Users.NCellID],UserIds));
			
		end

		function Pairing = getPairing(Stations)
			% Output: [Nlinks x 2] sized vector with pairings
			% where Nlinks is equal to the total number of scheduled users
			% for Input Stations.
			% E.g. Pairing(1,:) = All station ID's
			% E.g. Pairing(2,:) = All user ID's
			% and Pairing(1,1) = Describes the pairing of Station and User
					
			% Get number of links associated with the station.
			
			nlink=1;
			for i = 1:length(Stations)
				schedule = [Stations(i).Users];
				users = extractUniqueIds([schedule.UeId]);
				for ii = 1:length(users)
					Pairing(:,nlink) = [Stations(i).NCellID; users(ii)]; %#ok
					nlink = nlink+1;
				end
			end
			
		end
		
	end





end